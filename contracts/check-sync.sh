#!/bin/sh
# SessionStart tripwire: compare the operating manual's hash to the sync markers
# in every distilled artifact. Prints one line when stale; silent when in sync.
MANUAL="${LANES_MANUAL:-$HOME/Documents/operating-manual.md}"
CFG=$(cd "$(dirname "$0")/.." && pwd)
DIR="$CFG/contracts"
[ -f "$MANUAL" ] || exit 0
SHA=$( (shasum -a 256 "$MANUAL" 2>/dev/null || sha256sum "$MANUAL") | cut -c1-12)
STALE=""
for f in "$DIR/worker-floor.md" "$DIR/worker-core.md" "$DIR/worker-full.md" \
         "$CFG/agents/executor.md" "$CFG/agents/architect.md" "$CFG/agents/verifier.md" \
         "$CFG/agents/critic.md" "$CFG/agents/code-reviewer.md"; do
  [ -f "$f" ] || { STALE="$STALE $(basename "$f")(missing)"; continue; }
  grep -q "manual-sha: $SHA" "$f" || STALE="$STALE $(basename "$f")"
done
if [ -n "$STALE" ]; then
  echo "operating manual changed since worker contracts were synced — run /manual-sync (stale:$STALE)"
fi
exit 0
