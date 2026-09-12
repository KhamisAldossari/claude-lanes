# lanes

Run big features in Claude Code as **tracked lanes**: a git-ignored `tracker/` ledger that a cold
session resumes from, plus an orchestration policy and tiered worker contracts for the sessions
that delegate. Measured below, including where it costs more than it saves.

## Measured

**Real jobs, one machine, before the token fixes that ship in this plugin.** 28 background jobs over six weeks
on real work repositories, recorded by the Claude Code job daemon
(`bench/jobs-report.py`, aggregates only). This is what the workflow cost when the orchestrator
was pinned to maximum effort, every review seat re-read a 14k-token manual, and tracker files were
allowed to grow past 50 KB:

| job class | jobs | median tokens | p25 – p75 |
|---|---:|---:|---:|
| question (status ask, no code change) | 7 | 655,585 | 608,927 – 670,253 |
| resume (`/tracker-resume` work session) | 7 | 1,095,358 | 808,794 – 1,097,013 |
| change (implementation, investigation) | 12 | 496,230 | 92,669 – 945,327 |
| review (merge-request review) | 2 | 875,680 | 698,383 – 1,052,977 |

The fixes: effort unpinned, the manual replaced by a 1.2k-token contract, the policy delivered by
a SessionStart hook instead of `CLAUDE.md` (so workers never inherit it), a light `status` path
that reads one file, a 12 KB read budget per tracker file, and a context guard that fires at 20 %
instead of 50 %. Re-run the report after a week of use to see your own before/after:
`python3 bench/jobs-report.py --split <install date>`.

**Controlled A/B, same task, same model.** A two-session feature on a 2.8k-line Python repo (a 1.8k-line engine plus a 1k-line UI)
(the second session must finish what the first started), 3 runs per arm, `claude-sonnet-5`,
plain Claude Code versus this layer. Full method and per-session table in
[`bench/ab/results.md`](bench/ab/results.md).

| arm | tokens per run (median) | cost per run | wall-clock per run | turns per run | feature finished | ledger closed after the last session |
|---|---:|---:|---:|---:|:---:|:---:|
| plain Claude Code | 1.58M | $0.69 | 3.3 min | 33 | 3/3 | n/a |
| lanes | 3.38M | $1.37 | 8.5 min | 62 | 3/3 | 1/3 |

Tokens are cumulative across turns (input, cache reads, cache writes, output), the same measure
the job daemon records above. **The layer cost 2.1x the tokens, 2.0x the dollars and 2.6x the
wall-clock for the same outcome.** The injected policy is under 1 % of that (about 5,400 tokens
per session, identical in every run); the rest is behaviour. Reading the ledger, verifying state
against git, then writing a session file and three rollups doubles the turn count, and every turn
re-reads a context the ledger work keeps growing. Worse, the close after the final session was
skipped in two of three runs, which is the staleness the ledger exists to prevent. A stronger
close instruction (a "prove the close" step appended to `/tracker-resume`) was tried and
re-benchmarked: all three lanes sessions then stopped before starting the work, citing a
handoff threshold no hook had emitted, and finished 0 of 3. It was reverted; the shipped flow
is the measured one, and the unreliable final close is a known open issue. The task is close to a best case for plain Claude Code: `FEATURE.md` is a
committed spec naming both parts, so a cold session needs no memory of the previous one. The case
where a ledger should pay, many sessions and no written spec, is not covered by this benchmark.
Both arms also carried the author's user-level agents and commands, identical on both sides, so
the numbers isolate the hooks and the tracker flow rather than a clean install. Neither arm
spawned a single subagent, so the delegation half of the policy is unmeasured on this task.

## Install

```
/plugin marketplace add KhamisAldossari/claude-lanes
/plugin install lanes@lanes
```

The next session starts with the policy in context. Its first lines:

```
ORCHESTRATION POLICY (main session only; workers never receive this text)

Triage every ask — stop at the first rung that holds:
1. Question, lookup, status → answer from context or one targeted read. No worker, no tracker writes.
2. Trivial change (≤3 files, an existing repo pattern, no auth/money/schema/security) → do it here; the build/test output is the review.
3. Scoped change → one executor with the core contract; it self-verifies with fresh build/test output. Spot-check one load-bearing claim yourself.
4. Auth, money, security, schema/migration, concurrency, an unfamiliar subsystem, or more than ~8 files → executor + a separate reviewer on the full contract; never self-approve.
5. "Audit / comprehensive / thorough" → Workflow fan-out. Before spawning anything, name what each result could change; a fleet that cannot alter your next step is activity, not progress.
```

## A feature, three sessions

```
/tracker-init payment-retries      scaffolds tracker/ (root tier) and the lane tracker/features/payment-retries/
/tracker-resume                    session 1: reads root STATUS → lane STATUS → last session file; does the ONE next action;
                                   closes by writing a dated session file and refreshing ▶ NEXT ACTION
/tracker-resume                    session 2, cold: same five reads, no re-exploration, next action already named
/tracker-resume status             a question about state: one file, ≤5k tokens, no writes
/handoff                           closes a session by hand (interactive gates); the guard runs `/handoff auto` for you
                                   when context passes the handoff point
```

Every tracker file carries its own rules in its header, so a session that has never seen this
plugin learns the caps from the files: STATUS.md stays under five lines of state and one changelog
line per session, all narrative goes to the dated session file, verified facts graduate to
LEARNINGS.md, open problems with their unblock condition go to ISSUES.md. `examples/tracker/` is a
real one: three lanes with their sessions, learnings and issues, every file under 4 KB (one lane's
design doc is omitted); the root tier holds the index and the next action.

## What is in the box

| piece | what it does |
|---|---|
| `commands/tracker-init.md` | scaffold the root tier or a lane; idempotent, never overwrites |
| `commands/tracker-resume.md` | resume the active lane, switch lanes, or answer a status question (light mode) |
| `commands/handoff.md` | close a session into the tracker (or `.claude/handoff.md` in repos without one) |
| `hooks/orchestrator-sessionstart.sh` | prints the triage ladder, effort routing and delegation rules to the main session only |
| `hooks/tracker-sessionstart.sh` | one paragraph of orientation when the cwd has a `tracker/`; a re-read reminder after compaction |
| `hooks/tracker-context-guard.sh` | after Edit/Write/Bash/Agent calls: one nudge at 20 % of the window, one escalation at 35 % |
| `contracts/worker-{floor,core,full}.md` | the standard appended to every delegated prompt: 0.4k, 0.8k and 1.2k tokens |
| `agents/` | executor, explore, architect, verifier, critic, code-reviewer; all but explore (haiku, floor tier) carry their contract embedded |
| `skills/manual-sync` | maintainer skill: regenerate the contracts from your own operating manual, if you keep one |

## Settings

| variable | default | effect |
|---|---|---|
| `CLAUDE_HANDOFF_NUDGE_PCT` | `0.20` | fraction of the context window at which the guard nudges once |
| `CLAUDE_HANDOFF_FINAL_PCT` | `0.35` | fraction at which it tells the session to run `/handoff auto` and stop |
| `CLAUDE_HANDOFF_WINDOW` | detected | context window in tokens; set it to override `[1m]` detection |
| `LANES_MANUAL` | `~/Documents/operating-manual.md` | source for `manual-sync`; silent when absent |

## What it does not do

- It does not make a small task cheaper. On a 2.8k-line repo with a written spec the layer was
  2x the tokens and 2.6x the wall-clock of plain Claude Code, and its own close step was skipped
  in two of three runs. The layer can only pay when re-exploration would cost more than the
  reads it replaces: multi-week features, several lanes, sessions that start cold with no spec.
  That case is unmeasured.
- It does not stop you from re-creating the expensive setup it replaced. Pin `effortLevel` to
  `xhigh`, let STATUS.md grow to 50 KB, or make every worker read a manual, and you get the
  "before" column back.
- The tracker is git-ignored by design (`.git/info/exclude`). It never leaves your machine, which
  also means it is not shared with teammates.
- Needs `sh` and `python3`, plus `shasum` or `sha256sum` for the manual sync check. `/handoff` copies the resume command with `pbcopy` (macOS); on Linux
  substitute `xclip` or `xsel`. `/tracker-init` mentions `/local-ignore`, and `/tracker-resume` and `/handoff` mention
  `/resume`; neither companion command ships here (`/local-ignore` appends a line to
  `.git/info/exclude`, `/resume` reads `.claude/handoff.md`).

## Tests and benchmarks

```
sh tests/hooks.test.sh                 # 16 hook-contract checks, no API calls
python3 bench/jobs-report.py           # your own jobs, aggregated by class
bash bench/ab/run.sh plain 1           # one A/B run (costs real tokens)
```

## Credits

Agent role definitions are adapted from [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
(MIT, see `THIRD-PARTY-NOTICES.md`). Packaging and the benchmark-first README follow [ponytail](https://github.com/DietrichGebert/ponytail).
The worker contracts are distilled from a private operating manual; the `distilled-from` markers
record which sections each one condenses.

MIT © Khamis Aldossary
