"""Summarize the full runs of `run_full.jl` (Phase 2, see `PLAN.md`).

Prints one Markdown table row per result directory with the medians over the runs.
Run with
    python3 -I benchmarks/summarize.py benchmarks/results/full/<dir> ...
or without arguments for all directories in `results/full`.
"""

import csv
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def read_meta(directory):
    meta = {}
    for line in (directory / "meta.toml").read_text().splitlines():
        key, _, value = line.partition(" = ")
        meta[key] = value.strip('"')
    return meta


def read_csv(file):
    if not file.exists():
        return []
    with open(file, newline="") as io:
        return list(csv.DictReader(io))


def summarize(directory):
    meta = read_meta(directory)
    runs = read_csv(directory / "runs.csv")
    timers = defaultdict(dict)
    for row in read_csv(directory / "timers.csv"):
        timers[row["run"]][row["path"]] = (int(row["ncalls"]), int(row["time_ns"]))

    def section(run, path):
        return timers[run].get(path, (0, 0))

    per_run = []
    for run in runs:
        i = run["run"]
        steps = int(run["steps"])
        n_rhs = int(run["rhs_evaluations"])
        kick = section(i, "kick!")[1] + section(i, "drift!")[1]
        n_refine, t_refine = section(i, "refinement")
        _, t_refine_shift = section(i, "refinement / shift")
        n_update, t_update = section(i, "update callback")
        _, t_startup = section(i, "refinement startup")
        _, t_startup_shift = section(i, "refinement startup / shift")
        time_steps = float(run["time_steps"])
        per_run.append({
            "step_ms": 1e3 * time_steps / steps if steps > 0 else 0.0,
            "rhs_ms": kick / 1e6 / n_rhs if n_rhs > 0 else 0.0,
            "rhs_per_step": n_rhs / steps if steps > 0 else 0.0,
            "refine_ms": t_refine / 1e6 / n_refine if n_refine > 0 else 0.0,
            "refine_share": t_refine / 1e9 / time_steps if time_steps > 0 else 0.0,
            "refine_shift_share": t_refine_shift / t_refine if t_refine > 0 else 0.0,
            "update_ms": t_update / 1e6 / n_update if n_update > 0 else 0.0,
            "startup_s": t_startup / 1e9,
            "startup_shift_share": t_startup_shift / t_startup if t_startup > 0 else 0.0,
            "n_startup": int(run["n_startup"]),
            "n_end": int(run["n_end"]),
        })

    def med(key):
        return statistics.median(r[key] for r in per_run)

    def spread(key):
        values = [r[key] for r in per_run]
        m = statistics.median(values)
        return (max(values) - min(values)) / m if m > 0 else 0.0

    n_values = sorted({r["n_startup"] for r in per_run})
    return {
        "case": meta["case"], "size": meta["size"], "nhs": meta["nhs"],
        "refinement": meta["refinement"], "shifting": meta.get("shifting", "default"),
        "threads": meta["threads"],
        "runs": len(per_run), "n_startup": "/".join(map(str, n_values)),
        "n_end": int(med("n_end")),
        "startup_s": med("startup_s"), "startup_shift": med("startup_shift_share"),
        "step_ms": med("step_ms"), "step_spread": spread("step_ms"),
        "rhs_ms": med("rhs_ms"), "rhs_per_step": med("rhs_per_step"),
        "refine_ms": med("refine_ms"), "refine_share": med("refine_share"),
        "refine_shift": med("refine_shift_share"), "update_ms": med("update_ms"),
        "loadavg": meta.get("loadavg", ""),
    }


def main(args):
    root = Path(__file__).parent / "results" / "full"
    directories = [Path(a) for a in args] if args else sorted(
        d for d in root.iterdir() if (d / "runs.csv").exists())

    print("| case | size | NHS | refinement | shifting | threads | runs | n after startup | n end "
          "| startup [s] | shift in startup | step [ms] | spread | RHS [ms] | RHS/step "
          "| refinement/call [ms] | refinement in steps | shift in refinement "
          "| update cb [ms] | load |")
    print("|" + "---|" * 20)
    for directory in directories:
        s = summarize(directory)
        print(f"| {s['case']} | {s['size']} | {s['nhs']} | {s['refinement']} "
              f"| {s['shifting']} | {s['threads']} | {s['runs']} | {s['n_startup']} | {s['n_end']} "
              f"| {s['startup_s']:.2f} | {100 * s['startup_shift']:.0f}% "
              f"| {s['step_ms']:.2f} | {100 * s['step_spread']:.0f}% "
              f"| {s['rhs_ms']:.3f} | {s['rhs_per_step']:.1f} "
              f"| {s['refine_ms']:.1f} | {100 * s['refine_share']:.0f}% "
              f"| {100 * s['refine_shift']:.0f}% | {s['update_ms']:.2f} "
              f"| {s['loadavg']} |")


if __name__ == "__main__":
    main(sys.argv[1:])
