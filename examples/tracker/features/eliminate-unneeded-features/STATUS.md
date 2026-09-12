# STATUS — lane: eliminate-unneeded-features

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
Ask the owner for the next trim candidate — the s01 request list ended with a dangling "-",
suggesting a third item was never stated.

## Current state (≤5 lines)
- PR #5 MERGED to main (602aca4, rebase): UI no longer offers rotate-nights or fairness
  tuning; engine untouched (rotate + fairness stay CLI/ScheduleSettings-only).
- Fairness RESULTS tab + banner kept — only config knobs hidden (deliberate, see s01 decisions).
- Verified via AppTest end-to-end + headless rotate solve; independent review approved.

## Session changelog (one line each; newest first; ALL detail → the session file)
- s01 (2026-07-14): UI trim shipped as draft PR #5 → sessions/2026-07-14-session-01.md
