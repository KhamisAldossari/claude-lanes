# ISSUES — shift-scheduler (lane redesign-ui-ux)

> Open problems, blockers, and deferred work — each carrying the condition that unblocks or closes
> it. NOT the next action (that's STATUS.md ▶ NEXT ACTION) and NOT session narrative (that's
> `sessions/`). Routing: lane-specific issues go in that lane's ISSUES.md, not here.
>
> **Entry format (IDs are stable and never reused):**
> `- [ ] **ISS-001** <issue> — <one-line detail> · *unblocks/closes when:* <condition> · (raised sNN)`
>
> New entry ID = max existing ID in THIS file + 1 (each ISSUES.md numbers independently). From any
> other file cite the lane-qualified form — `root/ISS-003`, `redesign-ui-ux/ISS-007` — so a STATUS.md's
> ▶ NEXT ACTION can point at an issue instead of restating it.
> Closing an issue: tick it, move it to **Closed**, append `· (closed sNN)`. Never delete — closed
> issues are the record of what was already tried and settled (their IDs stay retired).

## Open
- [ ] **ISS-001** Browser refresh clears the whole wizard session — typed staff + generated roster lost (inherent Streamlit session lifecycle; same behavior as the pre-redesign UI, so not a regression) · *unblocks/closes when:* a persistence approach is deliberately chosen (st.query_params / file-backed) or the limitation is accepted in the usage guide · (raised s01)

## Closed
- <none yet>
