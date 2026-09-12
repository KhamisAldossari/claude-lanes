#!/usr/bin/env python3
"""Read the per-run result.json files an A/B run produced and print the results
tables as markdown.

    usage: summarize.py [runs-dir]      (default: ./runs next to this script)
"""
import glob
import json
import os
import re
import statistics
import sys

ARMS = ("plain", "lanes")
DIFF_RE = re.compile(r"(\d+) insertion|(\d+) deletion")


def diff_lines(stat):
    """Insertions + deletions from a `git diff --stat` summary line."""
    if not stat:
        return 0
    return sum(int(a or b) for a, b in DIFF_RE.findall(stat))


def load(runs_dir):
    runs = []
    for path in sorted(glob.glob(os.path.join(runs_dir, "*", "result.json"))):
        with open(path) as fh:
            runs.append(json.load(fh))
    return runs


def med(values):
    vals = [v for v in values if v is not None]
    return statistics.median(vals) if vals else None


def fmt(value, spec="{:.0f}"):
    return "—" if value is None else spec.format(value)


def rows(runs):
    out = []
    for run in sorted(runs, key=lambda r: (ARMS.index(r["arm"]), r["run"])):
        for s in run["sessions"]:
            out.append({
                "arm": run["arm"],
                "run": run["run"],
                "session": s["session"],
                "tokens": s.get("tokens"),
                "cost": s.get("cost_usd"),
                "minutes": (s["duration_ms"] / 60000.0
                            if s.get("duration_ms") is not None else None),
                "turns": s.get("num_turns"),
                "spawns": s.get("agent_spawns"),
                "tools": s.get("tool_uses"),
                "diff": diff_lines(s.get("diff_since_bench")),
                "test": (("PASS" if run["test"]["passed"] else "FAIL")
                         if s["session"] == 2 else "—"),
                "ok": s.get("ok"),
                "denials": s.get("permission_denials"),
            })
    return out


def table(rs):
    lines = ["| arm | run | session | tokens | cost $ | minutes | turns | spawns | tools | diff lines | test |",
             "|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in rs:
        lines.append("| {arm} | {run} | s{session} | {tokens} | {cost} | {minutes} | "
                     "{turns} | {spawns} | {tools} | {diff} | {test} |".format(
                         arm=r["arm"], run=r["run"], session=r["session"],
                         tokens=fmt(r["tokens"], "{:,.0f}"), cost=fmt(r["cost"], "{:.4f}"),
                         minutes=fmt(r["minutes"], "{:.1f}"), turns=fmt(r["turns"]),
                         spawns=fmt(r["spawns"]), tools=fmt(r["tools"]),
                         diff=r["diff"], test=r["test"]))
    return "\n".join(lines)


def medians(rs, label, pick):
    lines = ["| {} | tokens | cost $ | minutes | turns | spawns | tools | diff lines |".format(label),
             "|---|---|---|---|---|---|---|---|"]
    for key, group in pick:
        if not group:
            continue
        lines.append("| {} | {} | {} | {} | {} | {} | {} | {} |".format(
            key,
            fmt(med([r["tokens"] for r in group]), "{:,.0f}"),
            fmt(med([r["cost"] for r in group]), "{:.4f}"),
            fmt(med([r["minutes"] for r in group]), "{:.1f}"),
            fmt(med([r["turns"] for r in group])),
            fmt(med([r["spawns"] for r in group])),
            fmt(med([r["tools"] for r in group])),
            fmt(med([r["diff"] for r in group]))))
    return "\n".join(lines)


def main():
    runs_dir = (sys.argv[1] if len(sys.argv) > 1
                else os.path.join(os.path.dirname(os.path.abspath(__file__)), "runs"))
    runs = load(runs_dir)
    if not runs:
        sys.exit("no result.json under %s" % runs_dir)
    rs = rows(runs)

    print("## Per-session results\n")
    print(table(rs))

    print("\n## Medians per arm (both sessions pooled)\n")
    print(medians(rs, "arm", [(a, [r for r in rs if r["arm"] == a]) for a in ARMS]))

    print("\n## Medians per arm and session index\n")
    print(medians(rs, "arm / session",
                  [("%s s%d" % (a, i), [r for r in rs if r["arm"] == a and r["session"] == i])
                   for a in ARMS for i in (1, 2)]))

    print("\n## Per-run outcomes\n")
    print("| arm | run | acceptance test | pytest summary | s1 touched build_and_solve | commits | sessions ok |")
    print("|---|---|---|---|---|---|---|")
    for run in sorted(runs, key=lambda r: (ARMS.index(r["arm"]), r["run"])):
        s1, s2 = run["sessions"][0], run["sessions"][1]
        touched = s1.get("build_and_solve_touched")
        print("| {} | {} | {} | {} | {} | {} | {} |".format(
            run["arm"], run["run"],
            "PASS" if run["test"]["passed"] else "FAIL",
            run["test"]["summary"] or "—",
            {True: "yes (overran)", False: "no (stopped as asked)"}.get(touched, "unknown"),
            s2.get("commits"),
            "yes" if (s1.get("ok") and s2.get("ok")) else "NO"))

    denials = sum(r["denials"] or 0 for r in rs)
    print("\nTotal permission denials across all sessions: %d" % denials)


if __name__ == "__main__":
    main()
