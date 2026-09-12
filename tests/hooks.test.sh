#!/bin/sh
# Hook contract tests. Run: sh tests/hooks.test.sh  (needs sh, python3)
# Each hook must never break a session: exit 0 on every path, speak only when it should.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail=0
check() { if [ "$1" -eq 0 ]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }

# --- manifests wire real files -------------------------------------------------
python3 - "$ROOT" <<'PY'; check $? "manifests: plugin.json, marketplace.json, hooks.json valid and every hook script exists"
import json, os, re, sys
root = sys.argv[1]
p = json.load(open(f"{root}/.claude-plugin/plugin.json")); assert p["name"] and p["version"] and p["hooks"]
m = json.load(open(f"{root}/.claude-plugin/marketplace.json")); assert m["plugins"][0]["name"] == p["name"]
h = json.load(open(f"{root}/hooks/hooks.json"))["hooks"]
for event, groups in h.items():
    for g in groups:
        for hk in g["hooks"]:
            path = re.search(r'\$\{CLAUDE_PLUGIN_ROOT\}/(\S+?)"', hk["command"]).group(1)
            assert os.path.isfile(f"{root}/{path}"), path
assert "matcher" in h["PostToolUse"][0], "PostToolUse must carry a matcher (it used to fire on every Read)"
for c in os.listdir(f"{root}/commands"):
    assert open(f"{root}/commands/{c}").read().startswith(("---", "#")), c
PY

# --- orchestrator policy -------------------------------------------------------
out=$(echo '{"source":"startup"}' | sh "$ROOT/hooks/orchestrator-sessionstart.sh"); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "^Triage every ask" && echo "$out" | grep -q "$ROOT/contracts/worker-core.md"
check $? "orchestrator-sessionstart: exits 0, prints the ladder, resolves contract paths inside the plugin"
for f in $(echo "$out" | grep -o "$ROOT/contracts/[a-z-]*\.md" | sort -u); do [ -f "$f" ]; check $? "  contract on disk: $(basename "$f")"; done

# --- tracker orientation -------------------------------------------------------
out=$(echo "{\"cwd\":\"$TMP\",\"source\":\"startup\"}" | sh "$ROOT/hooks/tracker-sessionstart.sh"); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ]; check $? "tracker-sessionstart: silent outside a tracker repo"
out=$(echo "{\"cwd\":\"$ROOT/examples\",\"source\":\"startup\"}" | sh "$ROOT/hooks/tracker-sessionstart.sh")
echo "$out" | grep -q "tracker/STATUS.md names the active lane"; check $? "tracker-sessionstart: orients when cwd/tracker/STATUS.md exists"
out=$(echo "{\"cwd\":\"$ROOT/examples\",\"source\":\"compact\"}" | sh "$ROOT/hooks/tracker-sessionstart.sh")
echo "$out" | grep -q "just compacted"; check $? "tracker-sessionstart: compaction note on source=compact"
out=$(echo 'not json' | sh "$ROOT/hooks/tracker-sessionstart.sh"); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ]; check $? "tracker-sessionstart: garbage stdin exits 0 silently"

# --- context guard -------------------------------------------------------------
export CLAUDE_CONFIG_DIR="$TMP/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR"; echo '{"model":"claude-sonnet-5"}' > "$CLAUDE_CONFIG_DIR/settings.json"
tr_line() { printf '{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":5}}}\n' "$1"; }
guard() { printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s"}' "$1" "$2" "$3" | CLAUDE_HANDOFF_WINDOW=1000 sh "$ROOT/hooks/tracker-context-guard.sh"; }
tr_line 100 > "$TMP/low.jsonl"; out=$(guard s-low "$TMP/low.jsonl" "$TMP"); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ]; check $? "context-guard: silent at 10% of the window"
tr_line 250 > "$TMP/mid.jsonl"; out=$(guard s-mid "$TMP/mid.jsonl" "$TMP")
echo "$out" | python3 -c 'import sys,json; d=json.load(sys.stdin)["hookSpecificOutput"]; assert d["hookEventName"]=="PostToolUse" and "25%" in d["additionalContext"] and "handoff" in d["additionalContext"]'
check $? "context-guard: nudges once at 25% (default nudge 20%) with hookSpecificOutput JSON"
out=$(guard s-mid "$TMP/mid.jsonl" "$TMP"); [ -z "$out" ]; check $? "context-guard: second call for the same session stays silent (one-shot flag)"
tr_line 400 > "$TMP/hi.jsonl"; out=$(guard s-hi "$TMP/hi.jsonl" "$ROOT/examples")
echo "$out" | grep -q "Tracker context guard (final)"; check $? "context-guard: final escalation at 40% uses tracker wording when cwd has a tracker"
out=$(guard s-none "$TMP/missing.jsonl" "$TMP"); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ]; check $? "context-guard: missing transcript exits 0 silently"

# --- check-sync ----------------------------------------------------------------
out=$(LANES_MANUAL="$TMP/no-such-manual.md" sh "$ROOT/contracts/check-sync.sh"); rc=$?
[ $rc -eq 0 ] && [ -z "$out" ]; check $? "check-sync: silent when no operating manual is configured"
echo "different manual" > "$TMP/manual.md"; out=$(LANES_MANUAL="$TMP/manual.md" sh "$ROOT/contracts/check-sync.sh")
echo "$out" | grep -q "run /manual-sync"; check $? "check-sync: reports stale contracts when the manual's hash differs"

[ $fail -eq 0 ] && echo "all hook tests passed" || { echo "hook tests FAILED"; exit 1; }
