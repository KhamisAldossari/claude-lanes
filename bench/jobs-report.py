#!/usr/bin/env python3
"""Token and wall-clock cost per job class, from the local Claude Code job records.

Reads ~/.claude/jobs/*/state.json (written by the Claude Code background-job daemon)
and prints aggregates only: no prompts, no paths, nothing identifying leaves the machine.

    bench/jobs-report.py                 # one table over every job
    bench/jobs-report.py --split 2026-09-12   # two cohorts: created before / on-or-after the date

Classes are keyword heuristics over the job's recorded intent and name:
  question  a question or status ask, no code change requested
  resume    a /tracker-resume session (work resumed from the tracker)
  review    a merge-request / code review
  change    everything else (implementation, investigation, drafting)
"span" is minutes from job creation to its last terminal output and includes idle time.
"""
import glob
import json
import os
import statistics
import sys
from datetime import datetime


def classify(intent: str, name: str) -> str:
    t = f"{intent} {name}".strip().lower()
    if "?" in t or t.startswith(("what ", "how ", "which ", "is ", "are ", "can ", "does ", "did ")):
        return "question"
    if "tracker-resume" in t or "tracker" in name.lower():
        return "resume"
    if "review" in t:
        return "review"
    return "change"


def parse(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00")) if ts else None


def load():
    rows = []
    for path in glob.glob(os.path.expanduser("~/.claude/jobs/*/state.json")):
        try:
            s = json.load(open(path))
        except (OSError, ValueError):
            continue
        tokens = int(s.get("tokens") or 0)
        if not tokens:
            continue
        created = parse(s.get("createdAt"))
        ended = parse(s.get("lastTerminalAt") or s.get("updatedAt"))
        rows.append({
            "cls": classify(s.get("intent") or "", s.get("name") or ""),
            "tokens": tokens,
            "span": (ended - created).total_seconds() / 60 if created and ended else None,
            "created": created,
        })
    return rows


def q(values, frac):
    values = sorted(values)
    return values[min(len(values) - 1, int(round(frac * (len(values) - 1))))]


def table(rows, title):
    total = sum(r["tokens"] for r in rows) / 1e6
    print(f"\n### {title}: {len(rows)} jobs, {total:.1f}M tokens\n")
    print("| class | jobs | median tokens | p25 – p75 | median span (min) |")
    print("|---|---:|---:|---:|---:|")
    for cls in ("question", "resume", "change", "review"):
        g = [r for r in rows if r["cls"] == cls]
        if not g:
            continue
        t = [r["tokens"] for r in g]
        spans = [r["span"] for r in g if r["span"] is not None]
        span = f"{statistics.median(spans):.0f}" if spans else "–"
        print(f"| {cls} | {len(g)} | {int(statistics.median(t)):,} | {q(t, .25):,} – {q(t, .75):,} | {span} |")
    print(f"| **all** | {len(rows)} | {int(statistics.median([r['tokens'] for r in rows])):,} | | |")


def main(argv):
    rows = load()
    if not rows:
        print("no job records under ~/.claude/jobs")
        return 1
    if "--split" in argv:
        cut = datetime.fromisoformat(argv[argv.index("--split") + 1]).astimezone()
        before = [r for r in rows if r["created"] and r["created"] < cut]
        after = [r for r in rows if r["created"] and r["created"] >= cut]
        table(before, f"before {cut.date()}")
        if after:
            table(after, f"on or after {cut.date()}")
        else:
            print(f"\n(no jobs created on or after {cut.date()} yet)")
    else:
        table(rows, "all jobs")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
