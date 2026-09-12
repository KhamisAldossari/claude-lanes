# A/B benchmark — what the lanes layer costs on a two-session feature

## The question

The "lanes" layer is three things working together: a git-ignored `tracker/` ledger that cold
sessions resume from (`/tracker-resume`), SessionStart hooks that print an orchestration policy,
and a PostToolUse context guard. On the same two-session feature task, what does the layer cost
or save in tokens, dollars, wall-clock, turns and subagent spawns — and does the feature still
get finished?

## Method

**Date:** 2026-09-12. **Model:** `claude-sonnet-5` for both arms. **CLI:** Claude Code 2.1.269
on macOS (darwin 24.6.0). **Sample repo:** a ~1,800-line Python scheduling engine
(`scheduler.py`, OR-Tools CP-SAT) with a Streamlit front-end and a `CLAUDE.md` documenting its
four stages and landmines; Python 3.9 virtualenv with `ortools`, `openpyxl`, `pandas`,
`streamlit`, `pytest`.

**Two arms, same task, same model, same flags except the settings blob:**

| Arm | `--settings` | Effect |
|---|---|---|
| `plain` | `{"disableAllHooks":true,"enabledPlugins":{"ponytail@ponytail":false}}` | no hooks, no plugin |
| `lanes` | `{"enabledPlugins":{"ponytail@ponytail":false}}` | the installed hooks and `/tracker-resume` |

Every session also got `--permission-mode acceptEdits`, `--allowedTools
"Bash,Read,Edit,Write,MultiEdit,Glob,Grep,Agent,TodoWrite"`, `--max-turns 80`,
`--output-format stream-json --verbose`, and `-p`. `--dangerously-skip-permissions` was never
used. Both arms ran in the default config directory, since that is where auth lives. Both arms therefore also carried the author's user-level agents and commands (about two dozen agents and eighty commands and skills visible to the model, including the same three tracker commands this plugin ships), identical on both sides; the arms differ only in hooks. The numbers isolate the hooks and the tracker flow, not a clean install of this plugin alone.

Arm separation was verified two ways: a direct probe (asking whether the context contains a
block titled ORCHESTRATION POLICY returned "No" for `plain` and "Yes" for `lanes`), and by
grepping the six measured session-1 logs — 1 hit per `lanes` log, 0 per `plain` log.

**The task.** A `max_consec_day` tunable (a cap on consecutive day shifts). The engine already
caps combined working runs (`max_consec_work`, 4) and night runs (`max_consec_night`, 3) but not
day runs, so the feature threads one new value through settings → preflight → CP-SAT model →
independent validator, which is exactly the shape this repo's `CLAUDE.md` demands. Part 1 is the
settings field, the validator rule and the preflight check; Part 2 is the CP-SAT constraint.
`FEATURE.md` and `tests/test_ab.py` (in this directory — the exact files the arms saw) were
committed into every copy under the author name "Benchmark" before any session started, so each
session began on a clean tree.

Feasibility was confirmed before benchmarking, in a scratch copy that was not reused: the test
fails on the pristine engine (`2 failed, 1 passed` — test 3 is the no-regression guard and passes
either way) and passes once the feature is implemented (`3 passed`). The default cap of 4 is
non-binding, so a default solve stays bit-identical to the pristine engine (same grid hash).

**Prompts.** `plain` got a plain-English instruction to do Part 1 and stop, then a second to do
Part 2 and make the test pass. `lanes` got `/tracker-resume` for both sessions, with a
hand-built lane registered in the root ledger and its ▶ NEXT ACTION naming Part 1. The exact
strings live in `run.sh`. The lane text was written against `tracker-resume.md` so it could not
trip that command's "tracker disagrees with reality: stop" rule or its "fork: ask the user" rule,
which a headless session cannot answer.

**Design.** 3 runs per arm, 2 sequential sessions per run, all six runs launched concurrently as
independent driver processes so both arms met the same API conditions. Wall-clock per session is
what gets recorded.

**Measurements.** Per session, from the stream-json log: `total_cost_usd`, `duration_ms`,
`num_turns`, and tokens as the sum of `input_tokens`, `cache_read_input_tokens`,
`cache_creation_input_tokens` and `output_tokens`; `tool_use` blocks named `Agent` (subagent
spawns) and total `tool_use` blocks. After each session, `git diff --stat` against the benchmark
commit (so committed and uncommitted work count alike — the ledger itself is git-ignored and
never shows up) plus any commits the session made. After session 2, the acceptance test with its
pytest summary line. Session 1's discipline was checked exactly, by comparing the text of
`build_and_solve` before and after rather than reading diff hunk headers.

### Harness notes

- The virtualenv is symlinked into each copy. `.gitignore` lists `.venv/`, which matches a
  directory and not a symlink, so each copy would have started dirty; the driver adds `.venv`
  to `.git/info/exclude` instead of editing a tracked file.
- The driver removes the copy's `origin` remote, identically in both arms, so no benchmark
  session can push to the real repository.
- The sample repo's root ledger shipped with unfilled scaffold placeholders. In the `lanes` arm
  the driver fills them with true statements pointing at the active lane, so a headless session
  cannot stall on an ambiguous next action.
- Both copies keep the repo's pre-existing `tracker/` tree (three unrelated lanes). Only the
  `lanes` arm gets the new lane and the hooks that read it. A `plain` session could in principle
  read the ledger on its own; none did beyond an incidental mention.
- A session can emit more than one `result` event when it schedules a wakeup and resumes. One
  did (`lanes-3` session 2). The collector sums every `result` event rather than keeping the
  last; the fix was verified against an independent `jq` aggregation of the same logs.
- `timeout(1)` does not exist on this machine, so the driver relies on `--max-turns` instead.

### A first batch was discarded

The first six runs were placed under the Claude configuration directory. Claude Code classifies
every path there as a *sensitive file* and refuses to edit it even in `acceptEdits` mode
(`decision_reason_type: "safetyCheck"`), producing 34 permission denials across the 12 sessions.
That batch is not reported as a result because the denial, not the layer, drove the outcome: the
`lanes` sessions recognised the boundary and stopped to ask rather than route around it, while
the `plain` sessions reached the file another way and passed — an artifact about permission-guard
behaviour, not about the ledger. The runs below were relaunched from an ordinary temporary
directory, everything else identical, and recorded **0 permission denials**.

## Per-session results

| arm | run | session | tokens | cost $ | minutes | turns | spawns | tools | diff lines | test |
|---|---|---|---|---|---|---|---|---|---|---|
| plain | 1 | s1 | 1,132,990 | 0.4829 | 2.0 | 21 | 0 | 20 | 33 | — |
| plain | 1 | s2 | 445,630 | 0.2034 | 1.0 | 12 | 0 | 11 | 39 | PASS |
| plain | 2 | s1 | 1,075,596 | 0.5064 | 2.5 | 20 | 0 | 19 | 15 | — |
| plain | 2 | s2 | 348,957 | 0.1676 | 0.8 | 9 | 0 | 8 | 21 | PASS |
| plain | 3 | s1 | 1,278,324 | 0.5500 | 2.7 | 23 | 0 | 22 | 25 | — |
| plain | 3 | s2 | 350,671 | 0.1696 | 0.7 | 10 | 0 | 9 | 31 | PASS |
| lanes | 1 | s1 | 2,565,322 | 1.0082 | 5.0 | 42 | 0 | 40 | 21 | — |
| lanes | 1 | s2 | 813,358 | 0.3580 | 3.5 | 18 | 0 | 17 | 30 | PASS |
| lanes | 2 | s1 | 2,319,508 | 0.8912 | 3.8 | 39 | 0 | 37 | 25 | — |
| lanes | 2 | s2 | 963,678 | 0.3740 | 3.5 | 23 | 0 | 22 | 30 | PASS |
| lanes | 3 | s1 | 2,915,957 | 1.1788 | 5.2 | 38 | 0 | 36 | 19 | — |
| lanes | 3 | s2 | 1,581,692 | 0.9999 | 4.8 | 31 | 0 | 29 | 26 | PASS |

## Medians per arm (both sessions pooled)

| arm | tokens | cost $ | minutes | turns | spawns | tools | diff lines |
|---|---|---|---|---|---|---|---|
| plain | 760,613 | 0.3432 | 1.5 | 16 | 0 | 15 | 28 |
| lanes | 1,950,600 | 0.9456 | 4.3 | 34 | 0 | 32 | 26 |

## Medians per arm and session index

| arm / session | tokens | cost $ | minutes | turns | spawns | tools | diff lines |
|---|---|---|---|---|---|---|---|
| plain s1 | 1,132,990 | 0.5064 | 2.5 | 21 | 0 | 20 | 25 |
| plain s2 | 350,671 | 0.1696 | 0.8 | 10 | 0 | 9 | 31 |
| lanes s1 | 2,565,322 | 1.0082 | 5.0 | 39 | 0 | 37 | 21 |
| lanes s2 | 963,678 | 0.3740 | 3.5 | 23 | 0 | 22 | 30 |

## Per-run outcomes

| arm | run | acceptance test | pytest summary | s1 touched build_and_solve | commits | sessions ok |
|---|---|---|---|---|---|---|
| plain | 1 | PASS | 3 passed in 0.73s | no (stopped as asked) | 0 | yes |
| plain | 2 | PASS | 3 passed in 0.68s | no (stopped as asked) | 0 | yes |
| plain | 3 | PASS | 3 passed in 0.69s | no (stopped as asked) | 0 | yes |
| lanes | 1 | PASS | 3 passed in 0.81s | no (stopped as asked) | 1 | yes |
| lanes | 2 | PASS | 3 passed in 0.97s | no (stopped as asked) | 1 | yes |
| lanes | 3 | PASS | 3 passed in 0.77s | no (stopped as asked) | 2 | yes |

Total permission denials across all sessions: 0

## Per-run totals (both sessions summed)

| arm | run | total tokens | total cost $ | total minutes | total turns |
|---|---|---|---|---|---|
| plain | 1 | 1,578,620 | 0.6863 | 3.0 | 33 |
| plain | 2 | 1,424,553 | 0.6740 | 3.3 | 29 |
| plain | 3 | 1,628,995 | 0.7196 | 3.4 | 33 |
| lanes | 1 | 3,378,680 | 1.3663 | 8.5 | 60 |
| lanes | 2 | 3,283,186 | 1.2652 | 7.3 | 62 |
| lanes | 3 | 4,497,649 | 2.1787 | 10.0 | 69 |

| arm | median tokens/run | median $/run | median min/run | median turns/run |
|---|---|---|---|---|
| plain | 1,578,620 | 0.6863 | 3.3 | 33 |
| lanes | 3,378,680 | 1.3663 | 8.5 | 62 |

Ratios, `lanes` over `plain`, on per-run medians: **2.14x tokens, 1.99x cost, 2.58x wall-clock,
1.88x turns**.

## What the numbers show

The layer cost about twice as much and bought nothing measurable on this task. Both arms
finished the feature in all three runs — 6/6 acceptance tests pass — and both respected the
Part 1 / Part 2 split perfectly: no session 1 in either arm touched `build_and_solve`, verified
by comparing that function's text against the benchmark commit. The code produced was
equivalent in shape too: all six runs added the settings field and referenced the new tunable
inside `preflight`, `build_and_solve` and `validate`, with median diff sizes of 26 lines
(`lanes`) against 28 (`plain`). The `lanes` arm spent 2.14x the tokens, 1.99x the dollars and
2.58x the wall-clock to arrive at the same place. The separation is clean rather than marginal:
with three runs per arm there is no overlap on any cost axis — the most expensive `plain` run
(1.63M tokens, $0.72, 3.4 min) is cheaper than the cheapest `lanes` run (3.28M tokens, $1.27,
7.3 min).

The surprise is *where* the cost comes from. The hooks inject about 7,400 characters of policy
per session, which shows up as a perfectly reproducible fixed prefix: first-turn cache creation
was 23,579 tokens in every `lanes` session against 18,186 in every `plain` one, so the injected
text costs about 5,400 tokens per session. Across two sessions that is roughly 11k of the
1.80M median per-run difference — under 1%. The prefix is not the bill. The behaviour it
induces is: `lanes` runs took 62 turns per run against 33, and each extra turn re-reads a
context that the ledger work keeps growing. Reading the root ledger, reading the lane, verifying
state against git, writing a dated session file and refreshing three files afterwards is simply
more work than the task needs, and the tokens scale with the turns.

A second surprise cuts against the layer's own purpose. The ledger was maintained reliably at
the handoff *into* session 2 — all three `lanes` runs had session 1 record Part 1 and set
▶ NEXT ACTION to Part 2, and all three session 2s picked that up and finished. But the close
*after* session 2 was skipped in two of three runs: `lanes-1` and `lanes-2` finished Part 2,
passed the tests, and left the lane still holding one session file and a ▶ NEXT ACTION reading
"Implement Part 2", which is exactly the staleness the ledger exists to prevent. Only `lanes-3`
wrote both session files and closed the lane as complete. So the layer charged twice the price
and delivered its bookkeeping guarantee once out of three times at the point it mattered most.

Two other observations. Neither arm spawned a single subagent, despite `Agent` being in
`--allowedTools` and the injected policy being explicitly about orchestration and delegation —
every session did the work itself, so the "spawns" column is zero throughout and the policy's
routing advice had no observable effect. And the `lanes` sessions reached for other machinery
instead: all three session 1s invoked `handoff` to close out (the /handoff command this plugin ships, which the model sees as a skill), and all three session 2s
called `ScheduleWakeup` (a scheduling tool present in the author's environment, not part of this plugin) (one of them twice, which is what split that session into two `result`
events). The `plain` arm used neither.

The honest caveat is that this task is close to a best case for the `plain` arm. `FEATURE.md`
is a well-written, self-contained spec that names the two parts and the acceptance command, so
a cold session 2 needs no memory of session 1 — the file *is* the handoff artifact, and it is
committed in the repo where any session will find it. A ledger has little to add when the spec
already carries the plan. The result here should not be read as "the layer never pays"; it
should be read as "on a two-session task with a good spec in the repo, the layer is pure
overhead, roughly 2x, and its own upkeep is unreliable". Where it might pay is the case this
benchmark does not cover: many sessions, no written spec, accumulated findings and dead ends
that nothing else records. Testing that claim needs a longer task than this one.
