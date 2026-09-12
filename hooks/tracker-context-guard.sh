#!/bin/sh
# tracker-context-guard.sh — PostToolUse hook (hooks.json scopes it to Edit|Write|Bash|Agent|Workflow calls).
# Watches context-window consumption via the session transcript and injects a
# one-time nudge at the nudge threshold (default 20%) and a one-time escalation at
# the final threshold (default 35%) (the /handoff
# convention — tracker-flavored text when the session's cwd carries a
# tracker/STATUS.md, generic session-convention text everywhere else).
# Must be fast and must NEVER break a session: every failure path exits 0 silently.
#
# Env overrides:
#   CLAUDE_HANDOFF_WINDOW     context window in tokens — set + numeric wins outright;
#                             otherwise detected from settings.json "model" vs the
#                             transcript's message.model (see the resolution comment)
#   CLAUDE_HANDOFF_NUDGE_PCT  nudge threshold as a fraction (default 0.20)
#   CLAUDE_HANDOFF_FINAL_PCT  escalation threshold as a fraction (default 0.35)

python3 -c "$(cat <<'PYEOF'
import json, os, sys, time

def main():
    data = json.load(sys.stdin)
    sid = data.get("session_id") or ""
    transcript = data.get("transcript_path") or ""
    cwd = data.get("cwd") or ""
    if not sid or not transcript:
        return

    # One base dir for settings.json and the flag cache — the hook is invoked
    # via ${CLAUDE_CONFIG_DIR:-$HOME/.claude}, so honor the same resolution.
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    cache = os.path.join(config_dir, "cache", "handoff-guard")
    os.makedirs(cache, exist_ok=True)
    flag70 = os.path.join(cache, sid + "-final")
    flag50 = os.path.join(cache, sid + "-nudge")

    # Cheapest path first: once escalated, this session never speaks again.
    if os.path.exists(flag70):
        return

    # Opportunistic cleanup: drop flag files older than 7 days.
    now = time.time()
    try:
        for name in os.listdir(cache):
            path = os.path.join(cache, name)
            try:
                if now - os.path.getmtime(path) > 7 * 86400:
                    os.remove(path)
            except OSError:
                pass
    except OSError:
        pass

    # Context window size, in priority order:
    #   (a) CLAUDE_HANDOFF_WINDOW, when set and numeric, wins outright;
    #   (b) otherwise settings.json "model" (base = trailing "[1m]" stripped)
    #       is compared against the transcript's message.model further down.
    window = None
    env_window = os.environ.get("CLAUDE_HANDOFF_WINDOW")
    if env_window:
        try:
            candidate = int(env_window)
            if candidate > 0:
                window = candidate
        except ValueError:
            pass

    settings_model = ""
    if window is None:
        try:
            with open(os.path.join(config_dir, "settings.json")) as fh:
                settings_model = str(json.load(fh).get("model", ""))
        except Exception:
            pass
    settings_1m = settings_model.endswith("[1m]")
    base = settings_model[: -len("[1m]")] if settings_1m else settings_model

    # Current usage — and the model that produced it — from the last
    # non-sidechain assistant entry with message.usage, scanning only the
    # final ~2MB of the transcript (files can be huge).
    usage = None
    transcript_model = None
    with open(transcript, "rb") as fh:
        fh.seek(0, 2)
        size = fh.tell()
        fh.seek(max(0, size - 2 * 1024 * 1024))
        chunk = fh.read()
    for line in chunk.split(b"\n"):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except Exception:
            continue
        if entry.get("type") != "assistant" or entry.get("isSidechain"):
            continue
        message = entry.get("message")
        if not isinstance(message, dict):
            continue
        u = message.get("usage")
        if not isinstance(u, dict):
            continue
        usage = (
            (u.get("input_tokens") or 0)
            + (u.get("cache_read_input_tokens") or 0)
            + (u.get("cache_creation_input_tokens") or 0)
        )
        transcript_model = message.get("model")
    if usage is None:
        return

    if window is None:
        # Conservative fallback: a transcript model that differs from the
        # settings base means a /model switch happened, so the settings
        # "[1m]" flag no longer describes this session — assume 200k.
        # Firing the nudge early is harmless; never firing (assuming 1M
        # for a 200k session) is a silent total failure.
        if transcript_model and transcript_model != base:
            window = 200000
        else:
            window = 1000000 if settings_1m else 200000

    def threshold(env_name, default):
        raw = os.environ.get(env_name)
        if raw:
            try:
                value = float(raw)
                if 0 < value < 1:
                    return value
            except ValueError:
                pass
        return default

    nudge_pct = threshold("CLAUDE_HANDOFF_NUDGE_PCT", 0.20)
    final_pct = threshold("CLAUDE_HANDOFF_FINAL_PCT", 0.35)

    def claim(path):
        # O_CREAT|O_EXCL makes the one-shot guarantee atomic: under parallel
        # PostToolUse invocations exactly one run creates the flag and
        # speaks; EEXIST (or any other failure) stays silent.
        try:
            os.close(os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
            return True
        except OSError:
            return False

    # Wording: tracker-convention text only when the session's cwd actually
    # carries a tracker; otherwise — including a missing/empty cwd — the
    # generic session-convention text.
    tracker = bool(cwd) and os.path.isfile(os.path.join(cwd, "tracker", "STATUS.md"))

    pct = usage / window
    text = None
    if pct >= final_pct:
        if claim(flag70):
            if tracker:
                text = (
                    "Tracker context guard (final): ~{p}% of the context window is now "
                    "consumed — this session is past its handoff point. Per the tracker "
                    "convention the remaining actions are: run /handoff auto, then stop; "
                    "no new task gets started."
                ).format(p=round(pct * 100))
            else:
                text = (
                    "Context guard (final): ~{p}% of the context window is now "
                    "consumed — this session is past its handoff point. Per the "
                    "session convention the remaining actions are: run /handoff auto, "
                    "then stop; no new task gets started."
                ).format(p=round(pct * 100))
    elif pct >= nudge_pct:
        if claim(flag50):
            if tracker:
                text = (
                    "Tracker context guard: this session has used ~{p}% of its {w}-token "
                    "context window ({u} tokens). The repo tracker convention treats {n}% "
                    "as the handoff point: the current atomic step gets finished, "
                    "/handoff auto writes the handoff, and the session stops rather than "
                    "starting new work; the user resumes fresh via /tracker-resume."
                ).format(p=round(pct * 100), w=window, u=usage, n=round(nudge_pct * 100))
            else:
                text = (
                    "Context guard: this session has used ~{p}% of its {w}-token "
                    "context window ({u} tokens). The session convention treats {n}% "
                    "as the handoff point: the current atomic step gets finished, "
                    "/handoff auto writes a handoff brief to .claude/handoff.md, and "
                    "the session stops rather than starting new work; the user "
                    "resumes in a fresh session that reads it."
                ).format(p=round(pct * 100), w=window, u=usage, n=round(nudge_pct * 100))

    if text:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": text,
            }
        }))

try:
    main()
except Exception:
    pass
sys.exit(0)
PYEOF
)" 2>/dev/null
exit 0
