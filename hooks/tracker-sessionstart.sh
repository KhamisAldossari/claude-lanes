#!/bin/sh
# tracker-sessionstart.sh — SessionStart hook (all sources).
# If the session's cwd is a repo using the tracker/ convention (tracker/STATUS.md
# exists), print orientation text for the model; plain stdout reaches the model
# for SessionStart. Prints nothing elsewhere. Always exits 0.

python3 -c "$(cat <<'PYEOF'
import json, os, sys

try:
    data = json.load(sys.stdin)
    cwd = data.get("cwd") or ""
    source = data.get("source") or ""
    if cwd and os.path.isfile(os.path.join(cwd, "tracker", "STATUS.md")):
        if source == "compact":
            print(
                "Note: this conversation was just compacted. tracker/STATUS.md is "
                "ground truth for session state — it and the active lane's STATUS.md "
                "take precedence over the compacted summary; re-reading them before "
                "proceeding is the tracker convention, and /handoff followed by a "
                "fresh /tracker-resume session is the preferred continuation."
            )
        else:
            print(
                "This repo tracks session state in tracker/ (git-ignored, never "
                "committed). tracker/STATUS.md names the active lane and the single "
                "NEXT ACTION — the convention is to read it first. /tracker-resume "
                "resumes the work; /handoff closes a session; durable discoveries go "
                "to the lane's LEARNINGS.md and actionable debt to ISSUES.md per the "
                "headers in those files."
            )
except Exception:
    pass
sys.exit(0)
PYEOF
)" 2>/dev/null
exit 0
