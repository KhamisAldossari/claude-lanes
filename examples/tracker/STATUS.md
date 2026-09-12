# STATUS — shift-scheduler

> Always-current rollup — **read first each session** (`/tracker-resume` starts here). This file
> stays LEAN: state + the single ▶ NEXT ACTION + the Features index + one line per session.
> ALL per-session detail lives in the dated session file — NEVER paste session prose here; link to it.
> `tracker/` is git-ignored (`.git/info/exclude`) — read/update, never commit.
>
> **Convention rules (embedded so no external doc is needed):**
> - **Caps:** ▶ NEXT ACTION = ONE action (a fork lists 2–3 options with one-line trade-offs, and is
>   a menu for the user, not a work order) · Current state ≤5 lines · changelog = exactly ONE line
>   per session, ≤12-word headline, newest first.
> - **Routing:** work scoped to one feature lane → that lane's `features/<slug>/` files; cross-cutting
>   or repo-wide → this root tier. Durable verified facts → LEARNINGS.md · open problems/blockers →
>   ISSUES.md · session narrative → `sessions/YYYY-MM-DD-session-NN.md` (copy `TEMPLATE.md`).
> - **Changelog line format:** `- sNN (YYYY-MM-DD): <≤12-word headline> → sessions/YYYY-MM-DD-session-NN.md`
> - **End of session:** write the dated session file FIRST (all detail there), then prepend ONE
>   changelog line here, refresh ▶ NEXT ACTION, update Current state in place. A session is not
>   closed until this file matches reality.

## ▶ NEXT ACTION
Resume the `redesign-ui-ux` lane: eyeball draft PR #7 on its branch and mark it ready (its own ▶ NEXT ACTION in features/redesign-ui-ux/STATUS.md).

## Current state (≤5 lines)
- Three lanes: vacation-days done and merged; eliminate-unneeded-features merged its first trim and waits on the next candidate; redesign-ui-ux has a draft PR open.
- No cross-cutting work yet: root LEARNINGS.md and ISSUES.md are empty because every finding so far was lane-scoped.

## Features index
> One row per lane; `root` covers cross-cutting work. **Active lane** is what the next session
> picks up by default (its canonical root value is the literal `root`). A lane's own next action
> lives in its `features/<slug>/STATUS.md`.

| Lane | State | Next action (one line) |
|---|---|---|
| root | active | see ▶ NEXT ACTION above |
| redesign-ui-ux | active | Draft PR #7 open — eyeball the app on the branch, mark ready (see lane STATUS.md) |
| eliminate-unneeded-features | active | PR #5 merged; ask for the next trim candidate |
| vacation-days | done | Complete: b669b2a + dd615a4 on main; no open issues |

**Active lane:** redesign-ui-ux

## Session changelog (one line each; newest first; ALL detail → the session file)
- (no root sessions yet — all work so far was lane-scoped; see each lane's changelog)
