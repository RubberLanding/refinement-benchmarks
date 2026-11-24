#!/usr/bin/env python3
"""Tables of the accuracy runs of `run_accuracy.sh`.

    python3 -I benchmarks/compare_accuracy.py <output directory>

Taylor-Green: error against the exact solution (see `accuracy.jl`). Pipe flow: difference
of the velocity on the sections to the finer uniform run `reference`, as the L2 norm over
all section points relative to the L2 norm of the reference.
"""

import csv
import math
import sys
from pathlib import Path


def read(file):
    if not file.exists():
        return []
    with open(file, newline="") as io:
        return list(csv.DictReader(io))


def main(root):
    root = Path(root)
    case = root / "taylor_green"
    if case.exists():
        print("### taylor_green\n")
        print("| run | steps to t_end | dtmax | particles min..max | L2 error at t=0.5 | L2 error "
              "at t_end | L1 error at t_end | max error / U at t_end | energy / exact at t_end "
              "| L2 error in refined box at t_end | failed |")
        print("|---|" + "---|" * 10)
        for d in sorted(case.iterdir()):
            rows, meta = read(d / "accuracy.csv"), read(d / "accuracy_meta.csv")
            if not rows or not meta:
                print(f"| {d.name} | no result |")
                continue
            meta, last = meta[0], rows[-1]
            half = min(rows, key=lambda r: abs(float(r["t"]) - 0.5))
            print(f"| {d.name} | {meta['steps']} | {float(meta['dtmax']):.2e} "
                  f"| {meta['n_min']}..{meta['n_max']} | {100 * float(half['l2']):.2f}% "
                  f"| {100 * float(last['l2']):.2f}% | {100 * float(last['l1']):.2f}% "
                  f"| {float(last['max_over_U']):.3f} | {float(last['energy_over_exact']):.4f} "
                  f"| {100 * float(last['l2_refined_box']):.2f}% | {meta['failed']} |")
        print()
    case = root / "pipe_flow"
    if case.exists():
        print("### pipe_flow\n")
        ref = {(r["x"], r["y"]): r for r in read(case / "reference" / "sections.csv")}
        norm = math.sqrt(sum(float(r["ux"])**2 + float(r["uy"])**2 for r in ref.values()))
        print("| run | steps to t_end | particles min..max | rejected | difference to reference "
              "| x=0.25 | x=0.5 | x=0.75 | centerline u at x=0.75 | failed |")
        print("|---|" + "---|" * 9)
        for d in sorted(case.iterdir()):
            rows, meta = read(d / "sections.csv"), read(d / "accuracy_meta.csv")
            if not rows or not meta:
                print(f"| {d.name} | no result |")
                continue
            meta = meta[0]

            def diff(selection):
                return math.sqrt(sum((float(r["ux"]) - float(ref[r["x"], r["y"]]["ux"]))**2 +
                                     (float(r["uy"]) - float(ref[r["x"], r["y"]]["uy"]))**2
                                     for r in selection))

            cells = [f"{100 * diff(rows) / norm:.2f}%"]
            for x in ("0.25", "0.5", "0.75"):
                part = [r for r in rows if r["x"] == x]
                n = math.sqrt(sum(float(ref[r["x"], r["y"]]["ux"])**2 +
                                  float(ref[r["x"], r["y"]]["uy"])**2 for r in part))
                cells.append(f"{100 * diff(part) / n:.2f}%")
            center = [r for r in rows if r["x"] == "0.75" and abs(float(r["y"]) - 0.2) < 1e-6]
            print(f"| {d.name} | {meta['steps']} | {meta['n_min']}..{meta['n_max']} "
                  f"| {meta['rejected']} | " + " | ".join(cells) +
                  f" | {float(center[0]['ux']) if center else float('nan'):.4f} "
                  f"| {meta['failed']} |")
        print()


if __name__ == "__main__":
    main(sys.argv[1])
