---
name: manual-sync
description: Re-syncs the distilled worker contracts and agent embeds from the operating manual after manual edits; audits contract adoption and runs the eval battery.
---

# Manual sync

The operating manual (`$LANES_MANUAL`, default `~/Documents/operating-manual.md`) is the single source of truth for how
workers operate. The distilled artifacts each carry a `distilled-from` section list and a
`manual-sha` marker (first 12 hex chars of the manual's sha256). This skill is the only sanctioned
way to change them — never hand-edit a distillation.

## Sync targets
- `contracts/worker-floor.md` — floor tier (haiku / mechanical seats)
- `contracts/worker-core.md` — core tier (sonnet/opus implementation seats)
- `contracts/worker-full.md` — full tier (deep-review / architect seats, fable seats, max-effort seats)
- `agents/executor.md` — embedded copy of the core contract (directly-invocable seat)
- `agents/{architect,verifier,critic,code-reviewer}.md` — embedded copies of the full
  contract. No agent reads the manual at runtime any more (2026-09-12: the end-to-end read cost
  ≈14k tokens per spawn); the embed is the distillation they run on.

## Process
1. Hash the manual: `shasum -a 256 "${LANES_MANUAL:-$HOME/Documents/operating-manual.md}" | cut -c1-12`.
2. Find every sync target whose `manual-sha` differs. If none differ and no manual edit is claimed,
   report "in sync" and stop.
3. For each stale artifact: re-read the manual sections named in its `distilled-from` line, then
   re-derive the distillation from that text — never patch the old wording from memory. Preserve
   the tier's structure and register (short, positive, procedural steps; plain measured language).
4. Size budgets are hard: floor ≤ 12 numbered lines, core ≤ 1 page (~45 lines), full ≤ 40 lines and
   ≤ 6,000 bytes (≈1.5k tokens). If a new manual point doesn't fit, something else must leave —
   surface the trade to the user rather than growing the file.
5. Update `manual-sha` and `synced` on every re-derived artifact. Each embed must match its
   contract below the marker line apart from heading depth (embeds demote headings one level to
   nest inside the agent file). Check the core embed:
   `diff <(sed -n '/^## Evidence/,$p' contracts/worker-core.md | sed 's/^#\{1,\} //') <(sed -n '/^### Evidence/,$p' agents/executor.md | sed 's/^#\{1,\} //')`
   and each full embed (`for a in architect verifier critic code-reviewer`):
   `diff <(sed -n '/^## Evidence/,$p' contracts/worker-full.md | sed 's/^#\{1,\} //') <(sed -n '/^### Evidence/,$p' agents/$a.md | sed 's/^#\{1,\} //')`
   The session-start tripwire (`contracts/check-sync.sh`) checks the marker on all eight files.
6. Adoption audit: sample recent subagent transcripts under the current project's `subagents/`
   directory; report (a) what fraction of worker prompts carry a contract header (grep for the
   current `manual-sha:` value), (b) what fraction of worker reports use evidence labels
   ("verified by", "assuming", "checked:"). For (b), grep only the transcript tail — the final
   report, e.g. `tail -c 4000` — never the whole file: the prompt embeds the contract text, so a
   whole-file grep matches every contract-carrying worker and reads 100% forever. Falling rates are
   decay — report them as numbers. Baseline 2026-07-11: headers 4/4 post-wiring workers, labels 3/4.
7. Eval battery: after any resync, run the fixtures in `contracts/eval/README.md`
   (one worker per fixture, contract appended per tier) and score against the pass criteria there.
   A fixture that regresses means the new distillation lost a load-bearing behavior — fix the
   distillation, not the fixture.
