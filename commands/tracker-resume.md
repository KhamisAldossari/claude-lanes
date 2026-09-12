---
description: Resume work in a repo that tracks state via the tracker/ convention — root STATUS.md, feature lanes, phase checklists, and dated session files
argument-hint: [status | lane slug | focus or next-action override]
---

Resume work in a repo that uses the `tracker/` convention, picking up the single next action with zero re-derivation.

## Input

$ARGUMENTS — optional, one of three things:
- **`status`** (light mode): answer a question about the tracker's state without resuming work — see "Light mode" below. Also use light mode, without being asked, when the invoking message is a question ("what is the status", "what's next", "which issues are open") rather than an instruction to work.
- **A lane/feature slug** (`root`, or a name matching a directory under `tracker/features/`; lane layout only): switch the Active lane to it before resuming — Step 1 handles the switch.
- **A focus or next-action override**: anything else; execute that instead of the ▶ NEXT ACTION the active STATUS.md marks.

## Ownership

This command owns **resuming** the `tracker/` convention — both layouts it appears in (see the next section). `/tracker-init` owns scaffolding a tracker; this command never scaffolds. `/resume` owns resuming from `.claude/handoff.md` (the lighter, non-tracker convention) — hand off to it when a repo has no `tracker/`. `/handoff` routes its writes by convention: in tracker repos it writes the tracker protocol (lane session file + STATUS/LEARNINGS/ISSUES refresh); elsewhere it writes `.claude/handoff.md`. Either way, the resume side of the tracker convention stays here — `/handoff` writes it, this command picks it up.

## Light mode (`status`, or any question about state)

Cost target: ≤ 5k tokens of reads, zero writes, one turn.

1. Read root `tracker/STATUS.md` with `limit: 80` (the convention keeps ▶ NEXT ACTION, Current state, the Features index and the newest changelog lines at the top). Read further only if a section the answer needs is not in that window.
2. Lane layout: read the active lane's `STATUS.md` with `limit: 60`. Legacy flat: stop after step 1 unless the question names a phase checklist.
3. For a question about issues, read only the `## Open` section of the relevant `ISSUES.md` (Grep for `^## Open` to find the line, then Read from it with `limit: 60`).
4. Answer in prose: the ▶ NEXT ACTION verbatim, the Current state lines, and whatever the question asked. Cite paths instead of restating file contents.
5. Do **not** run Step 3 verification, do **not** spawn workers, do **not** write a session file or touch any tracker file. If the user then asks to proceed, resume with the normal flow from Step 1.

## Read budget (all modes)

Tracker files are meant to be small; some have grown past what a resume should load. Before reading any tracker file in Step 2, check its size (`wc -c`). Over 12,000 bytes (≈3k tokens): read the head (`limit: 80`) and Grep for the lane, ISS id, or topic in play instead of reading it whole; note the oversized file in the report ("over budget: tracker/STATUS.md 58 KB — archive history into STATUS-ARCHIVE.md") so the user can trim it. Never load the whole tree; `tracker/analysis/` and archived files are read only when the next action names them.

## The two layouts

- **Legacy flat** (older repos): session files sit directly in `tracker/` alongside `STATUS.md`, `PHASE-N-CHECKLIST.md`, `TEMPLATE.md`, and `RESUME-PROMPT.md`. Behavior for these repos is unchanged: changelog links resolve as written, checklists are read and flipped, `RESUME-PROMPT.md`'s procedures apply.
- **Lane layout** (what `/tracker-init` scaffolds): root `tracker/STATUS.md` carries an `**Active lane:**` pointer and a Features index; each feature lane lives under `tracker/features/<slug>/` with its own `STATUS.md`, `LEARNINGS.md`, `ISSUES.md`, and `sessions/`; the root doubles as the general lane (its own `LEARNINGS.md`, `ISSUES.md`, and `sessions/`, sharing the root `TEMPLATE.md` with all lanes).

**Detection is by following root `STATUS.md`, not by guessing:** if it has an `**Active lane:**` pointer, it's the lane layout — the pointer says whose `STATUS.md` to read next; if it has none, it's the legacy flat layout — read it as always.

## Rules

- Read root `tracker/STATUS.md` first, then what the layout calls for (Step 2): legacy — the phase checklists it references; lane layout — the Active lane's `STATUS.md`, then that lane's `LEARNINGS.md`/`ISSUES.md` and root `LEARNINGS.md`/`ISSUES.md` (whole when under the read budget, head + Grep when over it — cross-cutting debt is routed to root `ISSUES.md`). In both, read the latest session file the changelog links to. Read older sessions or frozen checklists only if the next action actually needs them.
- Verify the state STATUS.md claims against reality — the env/tool checks and `git status`/branch/HEAD comparisons the tracker calls for — before touching anything.
- If the tracker and reality disagree, stop and report the exact discrepancy to the user before doing anything else. Reconcile only on their word; never silently patch the tracker to match reality or the other way around.
- Cite `tracker/`, project memory, and `docs/` by path instead of restating what they already record.
- Run the docs-drift check after every build step when the tracker defines one (the legacy layout's `tracker/RESUME-PROMPT.md` procedure); when no such procedure exists — the default in the lane layout — skip it silently.
- STATUS.md's ▶ NEXT ACTION may be a single concrete step or a fork (more than one viable option). A fork is not a work order: present the options with trade-offs and a recommendation through AskUserQuestion, as discrete selectable options, then stop and wait for the pick. Never self-select or start any option's work first, even when only one is autonomously executable.
- Do exactly the one action in play — the single next step, or the $ARGUMENTS override — not a bundle of several.
- Write the end-of-session updates only after the action is actually done, never speculatively.

## Flow

Execute these steps in order. Stop and report if any step fails.

### Step 1: Locate the tracker and detect the layout

Check for `tracker/STATUS.md` in the repo root.

- If it's missing, stop. Tell the user this repo has no `tracker/` convention: `/tracker-init` scaffolds one (`/tracker-init <slug>` to start straight into a feature lane), and `/resume` handles `.claude/handoff.md`-based resumption. Never scaffold ad hoc — scaffolding is `/tracker-init`'s job.
- If present, detect the layout (see "The two layouts"): an `**Active lane:**` pointer in root `STATUS.md` means the lane layout; none means legacy flat.
- **`status` / question:** take the light-mode path above and stop; nothing below applies.
- **Lane switch (lane layout only):** if $ARGUMENTS names a lane — `root`, or an existing `tracker/features/<slug>/` — update root `STATUS.md`'s `**Active lane:**` pointer to it before reading further; that lane is what gets resumed, and $ARGUMENTS is consumed (it is not also a Step 4 override). If it looks like a slug (a single kebab-case token) but no such lane exists, stop and point the user at `/tracker-init <slug>`. In a legacy repo, $ARGUMENTS is always a focus override, never a lane switch.

### Step 2: Read the tracker

**Legacy flat layout** (unchanged):
- Read `tracker/STATUS.md` in full: current state, ▶ NEXT ACTION, the docs-drift process, the session changelog index.
- Read the active phase's `PHASE-N-CHECKLIST.md` (skip frozen phases unless the next action needs them).
- Read the latest dated session file the changelog links to (sessions sit directly in `tracker/`; links resolve as written).

**Lane layout:**
- Read root `tracker/STATUS.md` in full: the `**Active lane:**` pointer, the Features index, and — when root is the active lane — its own ▶ NEXT ACTION, Current state, and changelog.
- Read the active lane's `STATUS.md` (for a feature lane, `tracker/features/<slug>/STATUS.md`; for root, the root file just read): Current state, ▶ NEXT ACTION, changelog.
- Read the latest session file that lane's changelog links to (in the lane's `sessions/`).
- Read the lane's `LEARNINGS.md` and `ISSUES.md`, plus root `LEARNINGS.md` and root `ISSUES.md` — whole when under the read budget, head + Grep when over it (cross-cutting/repo-wide debt is routed to root `ISSUES.md`; for ISSUES the `## Open` section is what a resume needs).

Both layouts: note whether $ARGUMENTS carried a focus/next-action override (anything that wasn't consumed as a lane switch in Step 1) — it overrides the next action decided in Step 4.

### Step 3: Verify state against reality

- Run the environment/tool checks and `git status` (plus branch/HEAD comparisons) that STATUS.md or its resume material call for.
- Compare the result against what STATUS.md claims. If it matches, proceed. If it doesn't, stop, report the exact discrepancy, and wait for the user rather than guessing which side is right.

### Step 4: Determine and run the action

- If $ARGUMENTS carried a focus/next-action override (per Step 2 — a lane switch doesn't count), that's the action.
- Otherwise take STATUS.md's ▶ NEXT ACTION as read in Step 2:
  - Single concrete step: proceed — implement, verify with the repo's own build/lint/test commands, commit per the repo's conventions.
  - Fork: use AskUserQuestion to present each option as a discrete choice with trade-offs and a recommendation, then stop and wait for the pick before starting any of them.
- Run the docs-drift check after each build step inside the action.

### Step 5: Close the session

Only once the action is actually done:

**Legacy flat layout** (unchanged):
- Update `tracker/STATUS.md`: prepend one changelog line, refresh ▶ NEXT ACTION, update the current-state summary in place.
- Flip the changed cells in the relevant `PHASE-N-CHECKLIST.md`.
- Copy `tracker/TEMPLATE.md` to a new dated session file and fill it in with what actually happened this session.

**Lane layout** — the same persist protocol `/handoff` writes; each tracker file's header carries its entry formats — follow them:
- Copy the shapes `tracker/TEMPLATE.md` defines into a new dated session file in the active lane's `sessions/` (per-lane NN = max existing + 1).
- Refresh the lane's `STATUS.md`: prepend exactly ONE changelog line (≤12-word headline → `sessions/<file>`), refresh ▶ NEXT ACTION, update Current state in place (≤5 lines). Never paste session prose into a STATUS file — link to the session file.
- Refresh root `tracker/STATUS.md`: the `**Active lane:**` pointer plus the lane's one-line Features-index row (when the lane is root, its own changelog/state was the previous step).
- Flush discoveries per the routing rule the files' headers state (lane-scoped → the lane's `LEARNINGS.md`/`ISSUES.md`, cross-cutting → root's), deduping before appending; where issue entries carry numeric ISS IDs, new ID = max existing in that file + 1.

Then, in both layouts:
- Report to the user: what was done, what changed in the tracker, and what the refreshed ▶ NEXT ACTION now is.

### Step 6: Prove the close

Before the final report, run one command whose output shows the close happened — `ls` the new session file and `grep` the new changelog line in the lane's `STATUS.md` (plus the root Features-index row when the lane is not root) — and quote that output. If anything is missing, Step 5 is not done: do it now, then re-run the check. A session that finishes its action and skips this leaves ▶ NEXT ACTION stale, which is the exact failure the tracker exists to prevent (measured before this step existed: 2 of 3 headless sessions skipped the close).
