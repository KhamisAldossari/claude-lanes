# Feature: `max_consec_day` — a cap on consecutive day shifts

## Goal

`ScheduleSettings` already caps combined working runs (`max_consec_work`, default 4) and
night runs (`max_consec_night`, default 3). There is **no** cap on **day** runs: a day-capable
employee can be rostered for as many consecutive day shifts as `max_consec_work` allows.

Add `max_consec_day` as a tunable on `ScheduleSettings` and thread it through the engine the
way this repo's `CLAUDE.md` requires: every rule value lives on `ScheduleSettings`, is enforced
in the CP-SAT model, **and** is re-derived independently in `validate()`.

Read `CLAUDE.md` before changing the engine — it documents the four stages
(`ScheduleSettings` → `preflight` → `build_and_solve` → `validate`), the invariants, and the
landmines. All scheduling logic lives in `scheduler.py`.

## Part 1 — settings, validator, preflight

1. Add `max_consec_day: int = 4` to `ScheduleSettings`, beside the other run-length fields.
   The default equals the `max_consec_work` default on purpose, so the cap is non-binding out
   of the box and a default-configured solve stays bit-identical to today's roster. This repo
   cares about that property; do not pick a default that changes the shipped schedule.
2. Enforce it as a new rule in `validate()`: re-derive the longest run of consecutive `DAY`
   cells from the finished grid and report PASS/FAIL plus the measured streak, in the style of
   the neighbouring "Max N consecutive nights" rule. `validate()` must stay **independent of
   the solver** — derive everything from the grid, never from solver internals.
3. Add the matching `preflight()` feasibility check, so an impossible cap is reported as a
   `Problem` (message **and** suggestion) rather than surfacing later as a bare INFEASIBLE.
   The binding cap on a pure day run is the tighter of `max_consec_day` and `max_consec_work`;
   the night side already does exactly this with `min(S.max_consec_night, S.max_consec_work)`.

Do **not** touch the CP-SAT model in Part 1. After Part 1 the validator can flag a violating
grid, but the solver can still produce one — that is expected at this stage.

## Part 2 — CP-SAT enforcement

Enforce the same cap in `build_and_solve()` so a solved roster can never violate it. For an
employee/day, the day-shift indicator is `work` minus `night`; the max-consecutive-nights
constraint sitting next to it shows the sliding-window encoding to mirror.

## Acceptance

```bash
.venv/bin/python -m pytest tests/test_ab.py -q
```

All three tests must pass. Using the engine only, they assert:

1. `validate()` flags a hand-built grid whose 3-day run exceeds a `max_consec_day=2` setting,
   and does **not** flag that grid at the default cap.
2. A solved 30-day instance with `max_consec_day=3` contains no day run longer than 3 and
   passes every validator rule.
3. The default settings still pass preflight, still solve, and still pass every rule.

Test 3 passes before any change — it is the no-regression guard. Tests 1 and 2 do not.
