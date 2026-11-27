#!/usr/bin/env python3
"""Ratios of the block sizes to block 0 (no balancing), per turn, from `blocks.jl`.
    python3 analyse_blocks.py <out> [<out> ...]
Turn 0 is discarded. Prints every turn, then the medians and minima."""
import csv
import statistics
import sys
from collections import defaultdict

for out in sys.argv[1:]:
    rows = list(csv.DictReader(open(f"{out}/runs.csv")))
    print(f"\n## {out}")
    for state in ("early", "developed"):
        r = [x for x in rows if x["state"] == state and x["turn"] != "0"]
        if not r:
            continue
        blocks = sorted({int(x["block"]) for x in r})
        by = defaultdict(dict)
        for x in r:
            by[int(x["turn"])][int(x["block"])] = x
        print(f"\n### {state}: {r[0]['n_fluid']} fluid particles, "
              f"{r[0]['steps']} steps, {r[0]['nf']} RHS per turn")
        same = {(x["steps"], x["nf"], x["n_fluid"], x["t_end"]) for x in r}
        print(f"- same steps, RHS, particles and t in all runs: {len(same) == 1}")
        print("\n| turn | " + " | ".join(f"block {b}: step / RHS [ms] (stall)" for b in blocks) + " |")
        print("|---" * (len(blocks) + 1) + "|")
        for turn in sorted(by):
            cells = [f"{float(by[turn][b]['step_ms']):.2f} / {float(by[turn][b]['rhs_ms']):.3f} "
                     f"({float(by[turn][b]['stall']):.2f})" for b in blocks]
            print(f"| {turn} | " + " | ".join(cells) + " |")
        print("\n| block | step median / min [ms] | RHS median / min [ms] | step / block 0, per turn: median (min, max) | RHS / block 0: median (min, max) |")
        print("|---|---|---|---|---|")
        for b in blocks:
            step = [float(by[t][b]["step_ms"]) for t in by]
            rhs = [float(by[t][b]["rhs_ms"]) for t in by]
            rs = [float(by[t][b]["step_ms"]) / float(by[t][0]["step_ms"]) for t in by]
            rr = [float(by[t][b]["rhs_ms"]) / float(by[t][0]["rhs_ms"]) for t in by]
            print(f"| {b} | {statistics.median(step):.2f} / {min(step):.2f} | "
                  f"{statistics.median(rhs):.3f} / {min(rhs):.3f} | "
                  f"{statistics.median(rs):.3f} ({min(rs):.3f}, {max(rs):.3f}) | "
                  f"{statistics.median(rr):.3f} ({min(rr):.3f}, {max(rr):.3f}) |")
