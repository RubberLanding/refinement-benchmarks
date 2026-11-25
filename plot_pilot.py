#!/usr/bin/env python3
"""Plot the fluid particles over simulated time of a run of `pilot.jl`.

    python3 benchmarks/plot_pilot.py <directory with progress.csv> [--developed T]
Writes `particles.png` in the directory. `--developed` marks the time from which the mean is
taken as the developed state.
"""

import argparse
import csv
import statistics
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=Path)
parser.add_argument("--developed", type=float)
args = parser.parse_args()

with open(args.directory / "progress.csv") as io:
    rows = list(csv.DictReader(io))
t = [float(r["t"]) for r in rows]
n = [int(r["n_fluid"]) for r in rows]

ink, muted = "#222222", "#777777"
fig, ax = plt.subplots(figsize=(8, 3.8), layout="constrained")
ax.plot(t, n, color="#2a78d6", linewidth=2)
ax.set_ylim(0, 1.12 * max(n))
ax.set_xlim(0, max(t))
ax.set_xlabel("simulated time", color=ink)
ax.set_ylabel("active fluid particles", color=ink)
ax.set_title("Fluid particles over time", loc="left", color=ink)
ax.grid(axis="y", color="#e5e5e5", linewidth=0.8)
ax.set_axisbelow(True)
ax.spines[["top", "right"]].set_visible(False)
ax.annotate(f"start {n[0]:,}", (t[0], n[0]), xytext=(8, -14), textcoords="offset points",
            color=ink, fontsize=9)
peak = max(range(len(n)), key=n.__getitem__)
ax.annotate(f"peak {n[peak]:,} at t = {t[peak]:.1f}", (t[peak], n[peak]), xytext=(0, 8),
            textcoords="offset points", ha="center", color=ink, fontsize=9)
if args.developed is not None:
    late = [m for s, m in zip(t, n) if s >= args.developed]
    ax.axvline(args.developed, color=muted, linewidth=1, linestyle="--")
    ax.annotate(f"from t = {args.developed:g}: mean {statistics.mean(late):,.0f}, "
                f"{min(late):,} to {max(late):,}", (args.developed, 0.5 * max(n)), xytext=(8, 0),
                textcoords="offset points", color=ink, fontsize=9)
out = args.directory / "particles.png"
fig.savefig(out, dpi=150)
print(f"Saved {out}")
