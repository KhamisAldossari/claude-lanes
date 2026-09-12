"""Acceptance test for the `max_consec_day` feature (see FEATURE.md).

Engine only -- no Streamlit, no Excel. The solves are deliberately small (one
30-day month, the default 7-person roster) so the whole file runs in seconds.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import scheduler as sch

MONTH = dict(year=2026, month=9)        # 30 days; the repo's own smoke config


def _longest_day_run(grid):
    """Longest run of consecutive DAY cells anywhere in the grid."""
    best = 0
    for row in grid:
        run = 0
        for cell in row:
            run = run + 1 if cell == sch.DAY else 0
            best = max(best, run)
    return best


def _failed(settings, grid):
    return {r.name for r in sch.validate(settings, grid) if not r.passed}


def test_validate_flags_a_day_run_over_the_cap():
    """A hand-built 3-day run must be flagged under a cap of 2 and not under the default."""
    lenient = sch.ScheduleSettings(**MONTH)
    strict = sch.ScheduleSettings(**MONTH, max_consec_day=2)
    assert lenient.max_consec_day >= 3, "the default cap must allow a 3-day run"

    grid = [[sch.OFF] * lenient.days for _ in lenient.employees]
    for d in range(3):
        grid[0][d] = sch.DAY
    assert _longest_day_run(grid) == 3

    new_failures = _failed(strict, grid) - _failed(lenient, grid)
    assert new_failures, (
        "validate() reports no rule that fails at max_consec_day=2 while passing "
        "at the default cap, so the day-run cap is not being checked")


def test_solved_roster_respects_the_cap():
    """With the cap below the run the solver otherwise picks, no run may violate it."""
    S = sch.ScheduleSettings(**MONTH, max_consec_day=3)
    assert sch.preflight(S) == [], [p.message for p in sch.preflight(S)]
    sol = sch.build_and_solve(S)
    assert sol.grid, f"solver returned {sol.status}"
    assert _longest_day_run(sol.grid) <= S.max_consec_day, (
        f"longest day run {_longest_day_run(sol.grid)} > cap {S.max_consec_day}")
    failed = _failed(S, sol.grid)
    assert not failed, f"{sol.status} roster fails: {sorted(failed)}"


def test_default_keeps_the_baseline_solvable():
    """The out-of-box default must leave the existing small instance solvable and all-PASS."""
    S = sch.ScheduleSettings(**MONTH)
    assert sch.preflight(S) == [], [p.message for p in sch.preflight(S)]
    sol = sch.build_and_solve(S)
    assert sol.grid, f"solver returned {sol.status}"
    failed = _failed(S, sol.grid)
    assert not failed, f"{sol.status} roster fails: {sorted(failed)}"
