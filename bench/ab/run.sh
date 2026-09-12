#!/usr/bin/env bash
# A/B driver for the lanes layer: one run = one fresh copy of the sample repo
# plus two sequential headless sessions over the same two-part feature.
#
#   usage: run.sh <plain|lanes> <run-number>
#
# Environment:
#   AB_SRC    (required) path to the sample repo to copy
#   AB_VENV   virtualenv to symlink into the copy   (default: $AB_SRC/.venv)
#   AB_RUNS   where run directories go              (default: <script dir>/runs)
#   AB_MODEL  model for both arms                   (default: claude-sonnet-5)
#   AB_CLAUDE claude executable                     (default: claude)
#
# Layout per run: $AB_RUNS/<arm>-<n>/{repo/,s1.jsonl,s2.jsonl,result.json}
# Logs live beside the copy, never inside it, so the git tree stays clean.
set -uo pipefail

ARM="${1:?arm: plain|lanes}"
N="${2:?run number}"

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${AB_SRC:?set AB_SRC to the sample repo}"
VENV="${AB_VENV:-$SRC/.venv}"
RUNS="${AB_RUNS:-$HERE/runs}"
MODEL="${AB_MODEL:-claude-sonnet-5}"
CLAUDE="${AB_CLAUDE:-claude}"
SLUG="max-consec-day"
PY="$VENV/bin/python"

case "$ARM" in
  plain) SETTINGS='{"disableAllHooks":true,"enabledPlugins":{"ponytail@ponytail":false}}' ;;
  lanes) SETTINGS='{"enabledPlugins":{"ponytail@ponytail":false}}' ;;
  *) echo "unknown arm: $ARM (want plain|lanes)" >&2; exit 2 ;;
esac

ROOT="$RUNS/$ARM-$N"
REPO="$ROOT/repo"
rm -rf "$ROOT"
mkdir -p "$REPO"

# ---- 1. fresh copy of the sample repo --------------------------------------
rsync -a --exclude .venv --exclude .omc "$SRC/" "$REPO/"
ln -sfn "$VENV" "$REPO/.venv"
# .gitignore lists ".venv/", which matches a directory and not this symlink, so
# the copy would start dirty. Exclude it locally rather than editing a tracked file.
printf '.venv\n' >> "$REPO/.git/info/exclude"
# No pushes to the sample repo's real remote from a benchmark session.
git -C "$REPO" remote remove origin >/dev/null 2>&1

# ---- 2. the benchmark commit (identical in every copy) ---------------------
cp "$HERE/FEATURE.md" "$REPO/FEATURE.md"
mkdir -p "$REPO/tests"
cp "$HERE/test_ab.py" "$REPO/tests/test_ab.py"
git -C "$REPO" add FEATURE.md tests/test_ab.py
git -C "$REPO" -c user.name="Benchmark" -c user.email="benchmark@example.invalid" \
  commit -q -m "Add FEATURE.md and the A/B acceptance test" || exit 1
BENCH="$(git -C "$REPO" rev-parse HEAD)"

# ---- 3. lanes arm only: hand-built feature lane ----------------------------
if [ "$ARM" = "lanes" ]; then
  LANE="$REPO/tracker/features/$SLUG"
  mkdir -p "$LANE/sessions"

  cat > "$LANE/STATUS.md" <<'MD'
# STATUS — lane: max-consec-day

> Lane-scoped rollup — read when working this lane; the root `tracker/STATUS.md` Features index
> points here. Same rules as root, lane-scoped:
> - **Caps:** ▶ NEXT ACTION = ONE action (forks are menus, not work orders) · Current state ≤5
>   lines · changelog = ONE line per session, ≤12-word headline, newest first — format
>   `- sNN (YYYY-MM-DD): <headline> → sessions/YYYY-MM-DD-session-NN.md`.
> - **Routing:** this lane's session files → `sessions/` here (copy root `tracker/TEMPLATE.md`) ·
>   durable verified facts → this lane's LEARNINGS.md · open problems → this lane's ISSUES.md ·
>   anything cross-cutting → the root tier files.
> - **End of session touching this lane:** update THIS file first (changelog line, ▶ NEXT ACTION,
>   Current state), then refresh this lane's row — and the Active-lane line, if it changed — in the
>   root `tracker/STATUS.md` Features index. NEVER paste session prose into either STATUS.md.

## ▶ NEXT ACTION
Implement Part 1 of FEATURE.md (settings tunable + validator rule + preflight check). Part 2 (CP-SAT enforcement, make tests/test_ab.py pass) is the session after.

## Current state (≤5 lines)
- FEATURE.md and tests/test_ab.py are committed on main; nothing implemented yet.

## Session changelog (one line each; newest first; ALL detail → the session file)
- <none yet>
MD

  cat > "$LANE/LEARNINGS.md" <<'MD'
# LEARNINGS — shift-scheduler (lane max-consec-day)

> Durable, **verified** facts only — things a future session could not cheaply re-derive: gotchas,
> landmines, environment quirks, decisions-with-why that keep paying rent. NOT a diary — session
> narrative belongs in `sessions/`; open problems belong in ISSUES.md; the current plan belongs in
> STATUS.md. Newest first.
>
> **Entry format (one bullet per learning):**
> `- (sNN, YYYY-MM-DD) **<topic>** — <the fact> · *verified by:* <command run / file:line / doc §>`
>
> A learning without its verification is a guess — mark it `(unverified)` explicitly or leave it
> out. Routing: lane-specific learnings go in that lane's LEARNINGS.md, not here.

- <none yet>
MD

  cat > "$LANE/ISSUES.md" <<'MD'
# ISSUES — shift-scheduler (lane max-consec-day)

> Open problems, blockers, and deferred work — each carrying the condition that unblocks or closes
> it. NOT the next action (that's STATUS.md ▶ NEXT ACTION) and NOT session narrative (that's
> `sessions/`). Routing: lane-specific issues go in that lane's ISSUES.md, not here.
>
> **Entry format (IDs are stable and never reused):**
> `- [ ] **ISS-001** <issue> — <one-line detail> · *unblocks/closes when:* <condition> · (raised sNN)`
>
> New entry ID = max existing ID in THIS file + 1 (each ISSUES.md numbers independently). From any
> other file cite the lane-qualified form — `root/ISS-003`, `<slug>/ISS-007` — so a STATUS.md's
> ▶ NEXT ACTION can point at an issue instead of restating it.
> Closing an issue: tick it, move it to **Closed**, append `· (closed sNN)`. Never delete — closed
> issues are the record of what was already tried and settled (their IDs stay retired).

## Open
- <none yet>

## Closed
- <none yet>
MD

  # Register the lane in the root rollup: index row, Active lane, and a root
  # next action/state that points at the lane instead of the scaffold placeholders.
  "$PY" - "$REPO/tracker/STATUS.md" "$SLUG" <<'PY' || exit 1
import io, sys
path, slug = sys.argv[1], sys.argv[2]
src = io.open(path, encoding="utf-8").read()

def rep(old, new):
    global src
    assert src.count(old) == 1, (path, src.count(old), old[:60])
    src = src.replace(old, new, 1)

rep("## ▶ NEXT ACTION\n<the single next step a cold session can run right now — or a fork: 2–3 options with one-line trade-offs>",
    "## ▶ NEXT ACTION\nWork the active lane `%s` — `tracker/features/%s/STATUS.md` carries its single next action." % (slug, slug))
rep("## Current state (≤5 lines)\n- <fill in at first session close>",
    "## Current state (≤5 lines)\n- Active lane is `%s`: FEATURE.md and tests/test_ab.py are committed on main, nothing implemented yet." % slug)
rep("| root | active | see ▶ NEXT ACTION above |",
    "| root | active | see ▶ NEXT ACTION above |\n| %s | active | Implement Part 1 of FEATURE.md (settings + validator + preflight) |" % slug)
rep("**Active lane:** root", "**Active lane:** %s" % slug)

io.open(path, "w", encoding="utf-8").write(src)
PY
fi

# ---- 4. the two sessions ---------------------------------------------------
session () {            # $1 = session index, $2 = prompt
  local idx="$1" prompt="$2"
  local log="$ROOT/s$idx.jsonl"
  local t0 t1
  t0="$(date +%s)"
  ( cd "$REPO" && "$CLAUDE" -p "$prompt" \
      --model "$MODEL" \
      --settings "$SETTINGS" \
      --permission-mode acceptEdits \
      --allowedTools "Bash,Read,Edit,Write,MultiEdit,Glob,Grep,Agent,TodoWrite" \
      --max-turns 80 \
      --output-format stream-json --verbose \
      > "$log" 2> "$log.err" )
  local rc="$?"
  t1="$(date +%s)"
  echo "$rc $((t1 - t0))"
}

P1_PLAIN='Implement Part 1 of the feature described in FEATURE.md. Stop when Part 1 is done; do not start Part 2.'
P2_PLAIN='Continue the feature described in FEATURE.md: implement Part 2 and make ".venv/bin/python -m pytest tests/test_ab.py -q" pass.'

if [ "$ARM" = "lanes" ]; then P1="/tracker-resume"; P2="/tracker-resume"
else P1="$P1_PLAIN"; P2="$P2_PLAIN"; fi

# Snapshot of the committed engine, so "did session 1 touch build_and_solve"
# can be answered exactly rather than from diff hunk headers.
git -C "$REPO" show "$BENCH:scheduler.py" > "$ROOT/scheduler.bench.py"

read -r RC1 WALL1 <<< "$(session 1 "$P1")"
RC1="${RC1:-99}"; WALL1="${WALL1:-0}"
S1_UNCOMMITTED="$(git -C "$REPO" diff --stat HEAD | tail -1)"
S1_TOTAL="$(git -C "$REPO" diff --stat "$BENCH" | tail -1)"
S1_COMMITS="$(git -C "$REPO" log --oneline "$BENCH..HEAD" | wc -l | tr -d ' ')"
cp "$REPO/scheduler.py" "$ROOT/scheduler.s1.py"

read -r RC2 WALL2 <<< "$(session 2 "$P2")"
RC2="${RC2:-99}"; WALL2="${WALL2:-0}"
S2_UNCOMMITTED="$(git -C "$REPO" diff --stat HEAD | tail -1)"
S2_TOTAL="$(git -C "$REPO" diff --stat "$BENCH" | tail -1)"
S2_COMMITS="$(git -C "$REPO" log --oneline "$BENCH..HEAD" | wc -l | tr -d ' ')"

# ---- 5. acceptance test ----------------------------------------------------
( cd "$REPO" && "$PY" -m pytest tests/test_ab.py -q > "$ROOT/pytest.txt" 2>&1 )
TEST_RC="$?"

# ---- 5b. lanes arm: was the lane actually closed after session 2? ----------
# Read-only; the NEXT ACTION text goes to a file rather than a shell variable so
# backticks in it can never be command-substituted by the collector heredoc.
LANE_SESSIONS=-1
LANE_CHANGELOG=-1
if [ "$ARM" = "lanes" ]; then
  LDIR="$REPO/tracker/features/$SLUG"
  LANE_SESSIONS="$(ls -1 "$LDIR/sessions" 2>/dev/null | grep -c . | tr -d ' ')"
  LANE_CHANGELOG="$(grep -c '^- s[0-9]' "$LDIR/STATUS.md" 2>/dev/null | tr -d ' ')"
  sed -n '/^## ▶ NEXT ACTION/{n;p;}' "$LDIR/STATUS.md" > "$ROOT/lane-next-action.txt" 2>/dev/null
fi

# ---- 6. collect ------------------------------------------------------------
"$PY" - <<PY > "$ROOT/result.json" || exit 1
import io, json, re, sys

root, repo = "$ROOT", "$REPO"

def scan(path):
    """Per-session numbers from one stream-json log.

    A session can emit more than one result event (a scheduled wakeup
    resumes it), so every result event is summed rather than last-wins.
    """
    results, agents, tools, rate_limits = [], 0, 0, 0
    try:
        fh = io.open(path, encoding="utf-8", errors="replace")
    except IOError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            t = ev.get("type")
            if t == "assistant":
                # Each content block arrives as its own event, so blocks never double-count.
                for b in (ev.get("message", {}).get("content") or []):
                    if b.get("type") == "tool_use":
                        tools += 1
                        if b.get("name") == "Agent":
                            agents += 1
            elif t == "rate_limit_event":
                rate_limits += 1
            elif t == "result":
                results.append(ev)
    if not results:
        return {"ok": False, "tools": tools, "agents": agents,
                "rate_limit_events": rate_limits}
    fields = ("input_tokens", "cache_read_input_tokens",
              "cache_creation_input_tokens", "output_tokens")
    parts = dict((k, 0) for k in fields)
    for r in results:
        u = r.get("usage") or {}
        for k in fields:
            parts[k] += int(u.get(k) or 0)
    last = results[-1]

    def total(key):
        return sum((r.get(key) or 0) for r in results)

    return {
        "ok": all(not r.get("is_error") and r.get("subtype") == "success"
                  for r in results),
        "result_events": len(results),
        "subtype": last.get("subtype"),
        "stop_reason": last.get("stop_reason"),
        "tokens": sum(parts.values()),
        "token_parts": parts,
        "cost_usd": total("total_cost_usd"),
        "duration_ms": total("duration_ms"),
        "num_turns": total("num_turns"),
        "agent_spawns": agents,
        "tool_uses": tools,
        "permission_denials": sum(len(r.get("permission_denials") or [])
                                  for r in results),
        "rate_limit_events": rate_limits,
    }

def fn_source(text, name):
    """The top-level def block for the named function, or None."""
    lines = text.splitlines()
    start = None
    for i, l in enumerate(lines):
        if l.startswith("def " + name):
            start = i
            break
    if start is None:
        return None
    for j in range(start + 1, len(lines)):
        l = lines[j]
        if l[:1] not in ("", " ", "\t", ")") and re.match(r"(def |class |@)", l):
            return "\n".join(lines[start:j])
    return "\n".join(lines[start:])

ANSI = re.compile(r"\x1b\[[0-9;]*m")

def read(p):
    try:
        return ANSI.sub("", io.open(p, encoding="utf-8", errors="replace").read())
    except IOError:
        return ""

bench_engine = read(root + "/scheduler.bench.py")
s1_engine = read(root + "/scheduler.s1.py")
pytest_out = read(root + "/pytest.txt").strip().splitlines()

sessions = []
for idx, rc, wall, unc, tot, com in (
        (1, $RC1, $WALL1, """$S1_UNCOMMITTED""", """$S1_TOTAL""", "$S1_COMMITS"),
        (2, $RC2, $WALL2, """$S2_UNCOMMITTED""", """$S2_TOTAL""", "$S2_COMMITS")):
    m = scan(root + "/s%d.jsonl" % idx) or {"ok": False}
    m.update({"session": idx, "exit_code": rc, "wall_s": wall,
              "diff_uncommitted": unc.strip(), "diff_since_bench": tot.strip(),
              "commits": int(com or 0)})
    sessions.append(m)

bench_fn = fn_source(bench_engine, "build_and_solve")
s1_fn = fn_source(s1_engine, "build_and_solve")
sessions[0]["build_and_solve_touched"] = (
    None if (bench_fn is None or s1_fn is None) else bench_fn != s1_fn)

ledger = None
if "$ARM" == "lanes":
    nxt = read(root + "/lane-next-action.txt").strip()
    sess_n, chg_n = $LANE_SESSIONS, $LANE_CHANGELOG
    stale = "implement part 2" in nxt.lower()
    ledger = {"session_files": sess_n, "changelog_lines": chg_n,
              "next_action": nxt, "next_action_stale": stale,
              "closed": sess_n >= 2 and chg_n >= 2 and not stale}

json.dump({
    "arm": "$ARM",
    "ledger": ledger,
    "run": int("$N"),
    "model": "$MODEL",
    "settings": json.loads('''$SETTINGS'''),
    "bench_commit": "$BENCH",
    "sessions": sessions,
    "test": {"exit_code": $TEST_RC, "passed": $TEST_RC == 0,
             "summary": pytest_out[-1] if pytest_out else ""},
}, sys.stdout, indent=2, sort_keys=True)
PY

echo "$ARM-$N done: test_rc=$TEST_RC -> $ROOT/result.json"
