---
description: Wrap up a session — write the dated session file and refresh STATUS/LEARNINGS/ISSUES in tracker repos, or .claude/handoff.md elsewhere; `auto` runs without gates
argument-hint: [note | auto]
---

# /handoff — Wrap up a session, preserve learnings, and prepare for the next one

Package everything valuable from the current session into a handoff brief so a new session can pick up where this one left off.

## Input

$ARGUMENTS — optional note to include in the handoff (e.g., "blocked on API key from the platform team" or "next priority is the dashboard filter"). One value is reserved: when $ARGUMENTS is exactly `auto`, it is a mode switch, not a note — the run is non-interactive auto mode (see the Auto mode section) and nothing gets woven into Next Steps from it.

## Rules

- Invoking `/handoff` is your permission to read git state, scan the conversation, and draft the handoff brief without asking first. Writing that brief to disk is the exception: in interactive mode it happens only after the user confirms at the Step 5 review gate, so nothing is persisted unseen. Auto mode (see the Auto mode section) is the deliberate exception to that exception — it writes without the gate, because it fires mid-autonomous-work where no one can answer, and its targets are git-ignored tracker files that never leave the machine.
- Step 0 routes the handoff target by convention: repos with `tracker/STATUS.md` hand off into the tracker, detecting the layout exactly the way `/tracker-resume` does — root `STATUS.md` containing a line starting `**Active lane:**` → lane layout (lane session file + STATUS/LEARNINGS/ISSUES refresh — the tracker protocol in Steps 4 and 6); no such line → legacy flat layout (a dated session file directly in `tracker/` + the refresh the repo's own STATUS.md update protocol documents — the legacy close protocol in Steps 4 and 6); all other repos target `.claude/handoff.md` exactly as before. `/tracker-init` owns scaffolding a tracker; `/tracker-resume` owns resuming one — this command only writes into what already exists.
- Commit messages carry no `Co-Authored-By` trailer, keeping authorship single-author as configured.
- Leave `CLAUDE.md` untouched: it holds permanent project rules, and session-specific context belongs in the handoff artifact instead.
- Always run the review step (Step 5) and show the user what will be persisted before saving, so nothing is written without their sight of it. (Interactive mode only — auto mode skips this gate by design.)
- If the session was trivial (quick question, no meaningful work), the user can opt out in Step 5 — respect that. In auto mode this opt-out does not apply: always write.
- If `$ARGUMENTS` is provided (and is not the reserved `auto`), feature it prominently in the "Next Steps" section of the handoff brief.
- Every user interaction in this command goes through the `AskUserQuestion` tool with discrete selectable options, because a free-text prompt is easy to skim past or answer ambiguously, whereas discrete options make each choice explicit and deliberate. (Interactive mode only — auto mode has zero user interactions.) Concretely:
  - Render each choice as its own selectable option, never as a comma-separated or concatenated text line — not `"save, add, remove, or skip?"`.
  - Ask for no free-text reply such as `"Reply 'save' and I'll archive the previous handoff"`, `"say 'yes' to continue"`, or `"let me know when you're done"`. Even yes/no confirmations go through `AskUserQuestion` with explicit "Yes" / "No" options.
  - This holds for every gate here: the lane confirmation (Step 0), the uncommitted-changes prompt (Step 1), plan-drift review (Step 2), handoff-review prompt (Step 5), and any follow-up prompts. The "Other" option rides along as a property of the tool call, not as a replacement for it.
  - Whenever this command needs input for any reason, the mechanism is `AskUserQuestion`.

## Auto mode ($ARGUMENTS exactly `auto`)

The tracker context-guard hook instructs `/handoff auto` when a session crosses its context handoff point — mid-autonomous-work, where a blocking question cannot be answered. The run is therefore fully NON-INTERACTIVE:

- Skip every `AskUserQuestion` gate: the Step 0 lane confirmation, the Step 1 uncommitted-changes prompt, the Step 2 drift review, and the Step 5 review gate included. Nothing blocks, nothing waits.
- **Never touch git**: no commit, no stash, no prompts about either. Record uncommitted work as a **WARNING** section in the session file (or handoff brief) — which files, what they change, why they were left in place — so the next session decides with eyes open.
- Lane layout: use the current Active lane without asking; fall back to root when the pointer is unset or dangling. Legacy flat layout: take the same non-interactive path through the legacy close protocol (Steps 4, 6, and 7's legacy variants) — no lane determination, and never adding an `**Active lane:**` pointer, a Features index, or new LEARNINGS/ISSUES files to what the repo doesn't already have. Never invoke `/tracker-init` from auto mode.
- The "trivial session" opt-out does not apply — always write, however small the session.
- Writing without the review gate is safe here because tracker files are git-ignored (`.git/info/exclude`) — nothing is committed, nothing leaves the machine.
- Every standing rule still binds in auto mode: no `Co-Authored-By` trailers anywhere, `CLAUDE.md` untouched.
- End by stating plainly that the session is handed off and **stops here** — start no new work after the write. The user resumes in a fresh session via `/tracker-resume` (tracker repos) or `/resume` (non-tracker repos).
- In a repo with no `tracker/STATUS.md`, auto mode still runs non-interactively: it targets `.claude/handoff.md` per the normal Step 6 archive-and-persist, with the same no-git, no-gates, always-write rules. Unlike tracker files, `.claude/handoff.md` may be git-tracked — an accepted trade-off, because auto mode never commits: the WARNING section plus the user's own later commit review is the gate on anything actually leaving the machine.

## Flow

### Step 0: Convention detection

Decide the target and the mode before anything else:

1. **Mode.** $ARGUMENTS exactly `auto` → auto mode (all the Auto mode section's deviations apply to the steps below); anything else → interactive.
2. **Target.** Check for `tracker/STATUS.md` in the repo root.
   - **Absent** → non-tracker repo: the existing flow below runs unchanged, targeting `.claude/handoff.md`. Skip the layout detection and lane determination.
   - **Present** → tracker repo: the handoff target is the tracker, not `.claude/handoff.md` (which is neither read nor written here). Steps 1–3 and 5 run as written. Detect the layout next.
3. **Layout (tracker repos only).** Detect it exactly the way `/tracker-resume` does — by following root `tracker/STATUS.md`, not by guessing:
   - It contains a line starting `**Active lane:**` → **lane layout** (what `/tracker-init` scaffolds): Steps 4, 6, and 7 use their "Tracker repos (lane layout)" variants. Determine the lane next.
   - No such line → **legacy flat layout** (session files sit directly in `tracker/`, often alongside `PHASE-N-CHECKLIST.md`, `TEMPLATE.md`, and `RESUME-PROMPT.md`): Steps 4, 6, and 7 use their "Tracker repos (legacy flat)" variants. Skip the lane determination — a legacy tracker has no lanes.

**Lane determination (lane layout only).** Read root `tracker/STATUS.md`'s `**Active lane:**` pointer and its Features index.

- **Interactive:** confirm or override via AskUserQuestion — one selectable option per lane in the Features index (each `tracker/features/<slug>/`), plus "root (general)", plus "new feature…". List the current Active lane first as the recommended pick. If the user picks "new feature…", stop and point them at `/tracker-init <slug>` to scaffold the lane, then re-run `/handoff` — this command never scaffolds.
- **Auto:** use the current Active lane without asking; if the pointer is unset, or names a lane whose directory doesn't exist, fall back to root.

The chosen lane's directory (`tracker/` itself for root, `tracker/features/<slug>/` otherwise) is where the session file and STATUS refresh land in Steps 4 and 6. In tracker repos — both layouts — every later mention of "the handoff brief" means the dated session file — the WARNING section, the stash notes, the Step 5 review all apply to it.

### Step 1: Detect uncommitted changes

Run `git status` and `git diff HEAD` to check the working tree.

- If the working tree is **clean**, proceed silently to Step 2.
- **Auto mode:** never touch git — skip the AskUserQuestion below entirely. If there are uncommitted changes, record them as a WARNING section in the session file (files, what they change, why left in place) and proceed to Step 2.
- If there are **uncommitted changes** (interactive), show a summary of what changed (files modified, lines added/removed) and use AskUserQuestion with these options:
  1. "Commit now" — follow up with an AskUserQuestion whose first selectable option is a commit message suggested from the diff (the user can pick it or choose "Other" to write their own), then stage all changes and commit. No `Co-Authored-By` trailer.
  2. "Stash for later" — run `git stash push -m "handoff: <brief description of changes>"` and note the stash in the handoff brief.
  3. "Leave uncommitted" — do not touch the changes. Add a WARNING section to the handoff brief flagging exactly what is uncommitted and why.

Also check `git stash list` — if there are existing stashes, note them in the handoff brief.

### Step 2: Detect plan drift

Scan for plan artifacts that may exist in the session:
- Task lists (if any task-tracking tool was used)
- Any spec or plan files referenced during the conversation

For each plan artifact found:
- Compare the plan's intended steps against what was actually done (check git log for session commits, files changed, tasks completed vs. remaining).
- Identify where mid-session decisions changed the plan's assumptions.
- Look for **cascading effects**: if decision X changed how component A works, check whether other planned tasks still assume the old behavior of A.

**Auto mode:** skip the AskUserQuestion below — include the drift findings as detected (option 1's behavior) and move on.

If plan drift is detected (interactive), present the findings to the user via AskUserQuestion:
1. "This is accurate" — include drift findings as-is in the handoff.
2. "Let me clarify" — follow up with a second AskUserQuestion listing each detected drift point as a selectable option so the user picks which to correct (or "Other" to add context freely).
3. "No plan drift" — the plan is still valid as written, skip this section.

If no plan artifacts are found, skip this step silently.

### Step 3: Extract session learnings

Scan the current conversation context and extract the following categories. Review the whole conversation from its first message, not just the recent turns; you are done once every category below has been checked against the full transcript.

1. **Decisions made** — what was decided and why. Include the rationale, trade-offs considered, and alternatives rejected.
2. **Dead ends** — what was tried and abandoned, and why it did not work, so the next session does not repeat failed approaches.
3. **Task state** — what is done, what is in-progress, what is remaining. Be specific about completion state.
4. **Next steps** — ordered list of specific actions for the next session, starting with the highest priority. If $ARGUMENTS was provided, incorporate it here.
5. **Plan drift** — from Step 2, how mid-session decisions changed the remaining plan and what needs to be re-evaluated.
6. **Git state** — current branch, last commit, stashed items, uncommitted changes (from Step 1).
7. **Codebase insights** — patterns, architecture discoveries, or gotchas the next session could not learn by reading the code or git log alone; include an item when surfacing it took investigation, and leave out anything already obvious from the code.
8. **User corrections** — approaches or preferences the user corrected during the session (e.g., "use GraphQL fragments instead of props", "prefer X pattern over Y").
9. **Open questions / blockers** — unresolved issues that need answers before work can continue.
10. **Key files** — files created, modified, or critical for understanding the work. Include file paths and a brief note on why each matters.

### Step 4: Compose the handoff brief

**Tracker repos (lane layout):** compose a dated session file instead of the brief below, copying the shapes `tracker/TEMPLATE.md` defines (Summary, Accomplished, Findings, Decisions + why, Blockers, Verification state, Next steps — whatever sections the template carries; fold the Step 3 categories into them, and $ARGUMENTS — when it's a note, not `auto` — into Next steps). Name it `YYYY-MM-DD-session-NN.md`, where NN is **per-lane**: the max NN across the chosen lane's existing `sessions/` files + 1, two digits. Alongside it, draft — but do not write yet — the deltas Step 6's tracker protocol will persist: the lane `STATUS.md` refresh, the root `STATUS.md` refresh, and any `LEARNINGS.md`/`ISSUES.md` entries. In auto mode, add the WARNING section from Step 1 when there was uncommitted work.

**Tracker repos (legacy flat):** compose a dated session file shaped by the repo's own convention: copy `tracker/TEMPLATE.md` when it exists; when it doesn't (some legacy trackers carry none), mirror the structure of the repo's most recent session file. Name it `YYYY-MM-DD-session-NN.md`, where NN continues the repo's own numbering: the max NN parsed from the existing `tracker/*session-NN*.md` filenames + 1, keeping the repo's own zero-padding style. Fold the Step 3 categories into whatever sections that shape carries (and $ARGUMENTS — when it's a note, not `auto` — into its next-steps section). Alongside it, draft — but do not write yet — exactly the refresh the legacy STATUS.md's own documented end-of-session/update protocol calls for (Step 6's legacy variant). In auto mode, add the WARNING section from Step 1 when there was uncommitted work.

**Non-tracker repos:** organize the extracted learnings into a structured markdown document:

```
---
handoff: true
created: <ISO 8601 timestamp>
branch: <current git branch>
previous: <path to archived handoff if any, or "none">
---

# Session Handoff

## Status
<one-paragraph TL;DR: the original goal of the session and the bottom-line outcome — what got done, what remains>

## Done
<concrete work actually completed this session — finished tasks, merged changes, resolved issues. Include commit hashes where they exist. Omit if nothing shippable was finished.>
- <completed item> (<commit hash if applicable>)
- <completed item>

## Remaining

### Next Steps
<ordered list, highest priority first. If `$ARGUMENTS` was provided to /handoff, weave it in here.>
1. <highest priority action>
2. <next action>
3. ...

### Open Questions
<unresolved blockers — list these only if a Next Step actually depends on the answer>
- <question>: <what's needed to resolve it>

### Plan Drift
<how mid-session decisions changed the remaining plan — cascading effects, tasks that need re-evaluation>
<omit this subsection if no plan drift was detected>

## Learnings
<context the next session will need that it cannot read off the code or git log>

### Key Decisions
- <decision>: <rationale, alternatives rejected>

### Dead Ends
<approaches tried and abandoned — the next session should not retry these>
- <approach>: <why it failed>

### Codebase Insights
<non-obvious patterns, gotchas, architecture discoveries surfaced during the session>
- <insight>

### User Corrections
<preferences the user corrected mid-session — apply going forward>
- <what was corrected>: <do this instead>

## Key Files
<files created, modified, or critical for understanding the work>
- <file path> — <why it matters>

## Git State
- Branch: <branch name>
- Last commit: <hash> <message>
- Stash: <stash entries, or "none">
- Uncommitted: <description, or "clean">
```

### Step 5: Present for review

**Auto mode:** skip this gate entirely — proceed straight to Step 6 with what Step 4 composed.

Show the composed handoff brief — for tracker repos, the session file **plus every delta Step 6 will write** (lane layout: the lane STATUS.md changelog line / ▶ NEXT ACTION / Current state, the root STATUS.md changes, and each LEARNINGS.md / ISSUES.md entry; legacy flat: each refresh the repo's own update protocol names — STATUS.md, checklist flips, RESUME-PROMPT.md, and the like) — to the user, then use AskUserQuestion with these options:

1. "Looks good — save this handoff"
2. "I want to add something" — follow up with a second AskUserQuestion listing the composed document's sections (non-tracker brief: Done, Next Steps, Open Questions, Plan Drift, Key Decisions, Dead Ends, Codebase Insights, User Corrections, Key Files; tracker session file: whatever sections `tracker/TEMPLATE.md` gave it, plus the LEARNINGS/ISSUES deltas) as selectable options so the user picks which section to add to (or "Other" to specify freely). Then ask what to add, offering suggested entries as selectable options drawn from conversation context.
3. "I want to remove something" — follow up with a second AskUserQuestion listing all items in the handoff brief as selectable options so the user picks which to remove (or "Other" to specify freely).
4. "This session was trivial — skip the handoff" — exit without persisting anything. Report "No handoff created" and stop.

Keep iterating (add/remove/re-show) until the user confirms with option 1.

### Step 6: Archive and persist

**Non-tracker repos** (unchanged): if `.claude/handoff.md` already exists in the project root, create `.claude/handoffs/` if needed and move that old file to `.claude/handoffs/handoff-<YYYY-MM-DD>.md`; otherwise proceed. Then save the confirmed brief to `.claude/handoff.md` in the project root as the canonical handoff file.

**Tracker repos — the tracker persist protocol.** One standing rule governs all of it: **never paste session prose into a STATUS file** — all detail lives in the session file; the STATUS files link to it. Each tracker file's own header carries its entry formats and caps — follow them.

1. **Write the session file** into the chosen lane's `sessions/` directory: `tracker/sessions/` for root, `tracker/features/<slug>/sessions/` for a feature lane.
2. **Refresh the lane's `STATUS.md`**: PREPEND exactly ONE changelog line — `- sNN (YYYY-MM-DD): <≤12-word headline> → sessions/<file>` — newest first; REFRESH ▶ NEXT ACTION (the single next step, or a small fork of options — ≤10 lines total); UPDATE Current state in place (≤5 lines). Nothing else in the file changes.
3. **Refresh root `tracker/STATUS.md`**: set the `**Active lane:**` pointer to the lane just handed off, and update that feature's one-line row in the Features index (state + next-action line). If the lane IS root, step 2 already refreshed root's own changelog/state — just confirm the Active lane pointer reads root.
4. **Flush session discoveries** per the routing rule the tracker files' headers state: lane-scoped → that lane's files, cross-cutting or repo-wide → root's. Durable **verified** facts → the correct `LEARNINGS.md`; open problems, blockers, and deferred work (with their unblock conditions) → the correct `ISSUES.md`. **Dedupe before appending**: if an entry already covers the discovery, extend or update it rather than duplicating. Follow each file's embedded entry format; where a file's issue entries carry numeric ISS IDs, a new entry's ID = the max existing ID in that file + 1. Tick/close any issues this session resolved per the file's closing rule.

**Tracker repos (legacy flat) — the repo's own protocol.** Write the dated session file directly into `tracker/` — never create a `sessions/` directory there. Then perform exactly the refresh the repo's own documented end-of-session/update protocol calls for — the update-protocol trailer in its `STATUS.md`/`TEMPLATE.md` (typically: prepend ONE changelog line in the repo's existing format, refresh ▶ NEXT ACTION, update Current state in place, flip only the changed checklist cells, and refresh `RESUME-PROMPT.md` when the repo's protocol mandates it). That protocol's own wording is authoritative — do what it says and nothing the lane protocol adds: never write an `**Active lane:**` pointer or a Features index into a legacy STATUS.md, and never create `LEARNINGS.md`/`ISSUES.md` there. Flush learnings and issues only into files the repo already maintains for them (an existing findings file, for example); otherwise they stay in the session file's own sections.

### Step 7: Report and instruct

**Tracker repos (lane layout):** copy `/tracker-resume` to the clipboard using `pbcopy`, then display:

```
Handoff written to tracker.

  Session file:  <lane sessions path>/<file name>
  Lane STATUS:   refreshed (changelog + ▶ NEXT ACTION + Current state)
  Root STATUS:   Active lane = <lane>
  Learnings:     <n appended, or "none">
  Issues:        <n appended, n closed, or "none">

To resume: start a fresh session in this project and run /tracker-resume
(already copied to your clipboard).
```

**Tracker repos (legacy flat):** copy `/tracker-resume` to the clipboard using `pbcopy`, then display:

```
Handoff written to tracker (legacy layout).

  Session file:  tracker/<file name>
  Refreshed:     <each file the repo's own update protocol named — STATUS.md, checklists, RESUME-PROMPT.md, …>

To resume: start a fresh session in this project and run /tracker-resume
(already copied to your clipboard).
```

In auto mode — either tracker layout — close with the hard stop: state plainly that the session is handed off and **stops here** — no new work follows — and that the user resumes via `/tracker-resume` in a fresh session.

**Non-tracker repos:** copy the following text to the clipboard using `pbcopy`:

```
Read .claude/handoff.md and continue the work described there.
```

Then display to the user:

```
Handoff saved.

  Artifact:  .claude/handoff.md
  Archived:  <path to archived handoff, or "no previous handoff">

To resume in a new session:
  1. Start a new Claude Code session in this project
  2. Run /resume (if you have the companion command installed), or paste:
     "Read .claude/handoff.md and continue the work described there."
     (already copied to your clipboard)

  Or to continue this raw session: claude --continue
```

## Notes

- In non-tracker repos the handoff file is written to `.claude/handoff.md` — whether it is git-tracked depends on the project's `.gitignore`. Add `.claude/handoff.md` and `.claude/handoffs/` to `.gitignore` to keep handoffs local.
- In tracker repos nothing is archived — the tracker is append-and-refresh by design (session files accumulate in `sessions/`; STATUS files are refreshed in place) — and `.claude/handoff.md` is neither read nor written. The whole `tracker/` tree is git-ignored via `.git/info/exclude` (per `/tracker-init`), so tracker writes are never committed.
- Auto mode is normally invoked by the tracker context-guard hook (`/handoff auto`), but running it by hand works the same way: non-interactive, git-untouched, always writes, ends with the stop.
- Old handoffs are archived, not deleted. Check `.claude/handoffs/` for history.
- The clipboard copy uses `pbcopy` (macOS). On Linux, substitute `xclip -selection clipboard` or `xsel --clipboard`. If clipboard is unavailable, display the text and tell the user to copy it manually.
- Plan drift detection depends on plan artifacts existing (task lists, plan/spec files). With no plan artifacts, Step 2 is skipped silently.
- The command scans the current conversation for learnings. In very short sessions some categories may be empty — that is fine; omit empty sections from the handoff brief rather than filling them with placeholders.
