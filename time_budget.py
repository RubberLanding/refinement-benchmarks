#!/usr/bin/env python3
"""Time budget of `time_budget.jl`: where the time of a refined run goes.

Run with
    python3 benchmarks/time_budget.py <directory> [<directory> ...]
where each directory is the `out` of one configuration (with `early/` and `developed/`).

Prints Markdown: per state and configuration the step time, the share of each section in
ms per step and percent of the step, and the startup. Medians over the runs with at most
`--max-load` cores of other load, or over all runs if none is clean (marked).
"""

import argparse
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from summarize import read_csv, read_meta  # noqa: E402

KICK = "kick!"
UP = "kick! / update systems and nhs / "
INT = "kick! / system interaction"
REF = "refinement / "
CB = "update callback"


def budget(t):
    """Non-overlapping sections [ms per run] of one run, as a list of (group, name, ms)."""
    g = lambda path: t.get(path, 0.0)  # noqa: E731
    fluid = g(INT + " / fluid1-fluid1")
    rows = [
        ("RHS", "interaction fluid-fluid", fluid),
        ("RHS", "interaction other pairs", g(INT) - fluid),
        ("RHS", "density", g(UP + "compute density")),
        ("RHS", "avg. pressure + beta", g(UP + "compute average pressure and beta")),
        ("RHS", "update nhs", g(UP + "update nhs")),
        ("RHS", "boundary pressure", g(UP + "compute boundary pressure")),
        ("RHS", "characteristics", g(UP + "evaluate characteristics")),
    ]
    rows.append(("RHS", "rest", g(KICK) - sum(r[2] for r in rows)))
    shift = REF + "shift"
    ref = [
        ("refinement", "shift: compute shift", g(shift + " / compute shift")),
        ("refinement", "shift: apply shift", g(shift + " / apply shift")),
        ("refinement", "shift: rest", g(shift) - g(shift + " / compute shift") -
         g(shift + " / apply shift")),
        ("refinement", "merge", g(REF + "merge before splitting") +
         g(REF + "merge after splitting")),
        ("refinement", "split", g(REF + "split")),
        ("refinement", "criteria + target spacing", g(REF + "criteria") +
         g(REF + "target spacing")),
        ("refinement", "update systems before/after", g(REF + "update systems before") +
         g(REF + "update systems after")),
    ]
    ref.append(("refinement", "rest", g("refinement") - sum(r[2] for r in ref)))
    cb = [
        ("update callback", "PST (update shifting)", g(CB + " / update shifting")),
        ("update callback", "update systems and nhs", g(CB + " / update systems and nhs")),
        ("update callback", "open boundary", g(CB + " / update open boundary")),
    ]
    cb.append(("update callback", "rest", g(CB) - sum(r[2] for r in cb)))
    return rows + ref + cb + [("drift", "drift!", g("drift!"))]


def load(directory, max_load):
    runs = read_csv(directory / "runs.csv")
    clean = [r for r in runs if float(r["foreign_cores"]) <= max_load]
    used = clean or runs
    timers = read_csv(directory / "timers.csv")
    result = []
    for run in used:
        t = {r["path"]: int(r["time_ns"]) / 1e6 for r in timers if r["run"] == run["run"]}
        result.append((run, t))
    return result, len(clean), len(runs)


def med(values):
    return statistics.median(values)


def summarize(directory, max_load):
    if not (directory / "runs.csv").exists():
        return
    meta = read_meta(directory)
    result, n_clean, n_all = load(directory, max_load)
    step = [1e3 * float(r["time_steps"]) / int(r["steps"]) for r, _ in result]
    nf = [int(r["rhs_evaluations"]) / int(r["steps"]) for r, _ in result]
    rhs = [(t["kick!"] + t.get("drift!", 0.0)) / int(r["rhs_evaluations"]) for r, t in result]
    wall = [float(r["time_steps"]) / (float(r["t_end"]) - float(r["t_begin"]))
            for r, _ in result]
    first = result[0][0]
    flag = "" if n_clean else ", **no clean run**"
    print(f"\n### {directory.parent.name}, {directory.name}\n")
    print(f"- {meta['case']} {meta['size']}, {meta['nhs']}, {meta['options']}, "
          f"shifting {meta['shifting']}, {meta['trixiparticles']}, PointNeighbors "
          f"{meta['pointneighbors']}, {meta['threads']} threads")
    print(f"- {n_clean} clean of {n_all} runs{flag}, other load "
          f"{', '.join('%.1f' % float(r['foreign_cores']) for r, _ in result)} cores, "
          f"t = {float(first['t_begin']):.3f} to {float(first['t_end']):.3f}")
    print(f"- {first['n_startup']} to {first['n_end']} fluid particles, "
          f"{med(nf):.2f} RHS/step, RHS {med(rhs):.2f} ms, "
          f"{med([1e3 * r_ / int(f['n_end']) for r_, (f, _) in zip(rhs, result)]):.3f} us per "
          f"fluid particle, {med(wall):.0f} s per simulated time")
    print(f"- step time: median {med(step):.2f} ms, minimum {min(step):.2f} ms")
    if float(first["time_init"]) > 1:
        tot = [t.get("refinement startup", 0.0) for _, t in result]
        sh = [t.get("refinement startup / shift", 0.0) for _, t in result]
        print(f"- startup: {med(tot) / 1e3:.2f} s, of which shifting {med(sh) / 1e3:.2f} s")
    print("\n| section | ms per step | % of step |\n|---|---|---|")
    budgets = [dict(((g, n), x / int(r["steps"])) for g, n, x in budget(t))
               for r, t in result]
    total = med(step)
    groups = {}
    for (group, name) in budgets[0]:
        groups.setdefault(group, []).append(name)
    used = 0.0
    for group, names in groups.items():
        values = {n: med([b[(group, n)] for b in budgets]) for n in names}
        s = sum(values.values())
        used += s
        print(f"| **{group}** | **{s:.2f}** | **{100 * s / total:.1f}** |")
        if len(names) > 1:
            for n, v in values.items():
                print(f"| &nbsp; {n} | {v:.2f} | {100 * v / total:.1f} |")
    print(f"| **time integration and rest** | **{total - used:.2f}** | "
          f"**{100 * (total - used) / total:.1f}** |")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directories", nargs="+", type=Path)
    parser.add_argument("--max-load", type=float, default=0.5)
    options = parser.parse_args()
    for directory in options.directories:
        for state in ("early", "developed"):
            summarize(directory / state, options.max_load)


if __name__ == "__main__":
    main()
