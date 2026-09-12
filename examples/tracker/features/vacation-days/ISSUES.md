# ISSUES — shift-scheduler (lane vacation-days)

> Open problems, blockers, and deferred work — each carrying the condition that unblocks or closes
> it. NOT the next action (that's STATUS.md ▶ NEXT ACTION) and NOT session narrative (that's
> `sessions/`). Routing: lane-specific issues go in that lane's ISSUES.md, not here.
>
> **Entry format (IDs are stable and never reused):**
> `- [ ] **ISS-001** <issue> — <one-line detail> · *unblocks/closes when:* <condition> · (raised sNN)`
>
> New entry ID = max existing ID in THIS file + 1 (each ISSUES.md numbers independently). From any
> other file cite the lane-qualified form — `root/ISS-003`, `vacation-days/ISS-007` — so a STATUS.md's
> ▶ NEXT ACTION can point at an issue instead of restating it.
> Closing an issue: tick it, move it to **Closed**, append `· (closed sNN)`. Never delete — closed
> issues are the record of what was already tried and settled (their IDs stay retired).

## Open
- <none open>

## Closed
- [x] **ISS-001** Mid-Setup month/staff edits silently discard leave rows typed during that screen visit — Streamlit 1.50 mints the leave data_editor's identity from column_config (month-bounded DateColumns + staff SelectboxColumn), so a month/staff change mid-visit resets the editor to a stale seed, which the end-of-render mirror write then persists (rows typed on the same visit are lost; rows saved on a previous visit re-seed fine). Reviewer's fix sketch: fingerprint the editor's config inputs `(year, month, tuple(employees))` in session_state; on change, rebuild `_leave_seed` from the current mirror before instantiating the editor. Merge-created seam (neither parent had both features); minor — visible, recoverable by retyping. · *unblocks/closes when:* fingerprint-reseed implemented and an AppTest covers month-change-mid-visit row survival — fixed in PR #9 · (raised s01) · (closed s02 — merged as dd615a4)
