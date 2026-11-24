#!/usr/bin/env python3
"""Report of the interleaved measurements of `ab_interleaved.py`.

Run with
    python3 benchmarks/compare_interleaved.py <session directory> ...
Prints one Markdown report per session. Every block is shown. For each label, the ratio to
the reference is taken within each block. The report has the median ratio with a bootstrap
interval, and next to it the ratio of the minima over all blocks, since other jobs usually
only add time. Both use all measured blocks, also the noisy ones.

Verdict for a metric:
- `faster`/`slower`: the interval excludes 1 and the median differs from 1 by more than
  the A/A noise (if measured: the reference against itself).
- `no change detected`: otherwise.
- `inconclusive (noisy)`: too few clean blocks after the repeats, and not all blocks are
  clearly on the same side of 1.
- `faster/slower, size uncertain`: too few clean blocks, but all blocks are on the same
  side of 1 beyond the A/A noise.
"""

import csv
import json
import random
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from summarize import read_csv  # noqa: E402

SPREAD_LIMIT = 0.05
# Maximum relative difference of the median ratio and the ratio of the minima
AGREE_LIMIT = 0.03

# Sections of the isolated RHS, as in `compare_ab.py`
RHS_SECTIONS = (
    ("interaction", "kick! / system interaction"),
    ("update shifting", "kick! / update systems and nhs / update shifting"),
    ("avg. pressure", "kick! / update systems and nhs / compute average pressure"),
    ("beta", "kick! / update systems and nhs / compute beta"),
    ("avg. pressure + beta", "kick! / update systems and nhs / compute average pressure and beta"),
    ("update nhs", "kick! / update systems and nhs / update nhs"),
)


# ==========================================================================================
# ==== Reading
def load(directory):
    """Values per block of one label and case: {metric: {block: value}}."""
    runs = read_csv(directory / "runs.csv")
    samples = read_csv(directory / "rhs_samples.csv")
    timers = {}
    for row in read_csv(directory / "timers.csv"):
        timers.setdefault(row["run"], {})[row["path"]] = (int(row["ncalls"]),
                                                          int(row["time_ns"]))
    data = {"step": {}, "rhs_in_steps": {}, "refine": {}, "startup": {}, "per_time": {}, "rhs_per_particle": {}, "dt": {},
            "rhs_median": {}, "rhs_min": {}, "rhs_particles": {}, "checks": {}}
    for run in runs:
        block = int(run["block"])
        steps, n_rhs = int(run["steps"]), int(run["rhs_evaluations"])
        t = timers.get(run["run"], {})
        get = lambda path: t.get(path, (0, 0))  # noqa: E731
        data["step"][block] = 1e3 * float(run["time_steps"]) / steps
        data["per_time"][block] = float(run["time_steps"]) / float(run["t_end"])
        data["rhs_in_steps"][block] = (get("kick!")[1] + get("drift!")[1]) / 1e6 / n_rhs
        particles = (int(run["n_startup"]) + int(run["n_end"])) / 2
        data["rhs_per_particle"][block] = 1e3 * data["rhs_in_steps"][block] / particles
        data["dt"][block] = float(run["t_end"]) / steps
        calls, total = get("refinement")
        data["refine"][block] = total / 1e6 / calls if calls else 0.0
        data["startup"][block] = get("refinement startup")[1] / 1e9
        data["checks"][block] = (steps, n_rhs, int(run["rejected"]), int(run["n_startup"]),
                                 int(run["n_end"]), run["t_end"])
    for row in samples:
        data["rhs_median"].setdefault(int(row["block"]), []).append(float(row["ms"]))
        data["rhs_particles"][int(row["block"])] = int(row["particles"])
    for block, values in list(data["rhs_median"].items()):
        data["rhs_median"][block] = statistics.median(values)
        data["rhs_min"][block] = min(values)
    return data


def noisy_blocks(session, case):
    """Blocks of a case in which some label is 5% above its own minimum, with the reason."""
    info = json.loads((session / "session.json").read_text())
    reasons = {}
    for label in (entry["name"] for entry in info["labels"]):
        data = load(session / label / case)
        for metric, name in (("step", "step"), ("rhs_median", "RHS")):
            values = data[metric]
            if not values:
                continue
            best = min(values.values())
            for block, value in values.items():
                if value > (1 + SPREAD_LIMIT) * best:
                    reasons.setdefault(block, []).append(
                        f"{label} {name} {100 * (value / best - 1):+.0f}%")
    blocks = sorted({b for label in info["labels"]
                     for b in load(session / label["name"] / case)["rhs_median"]})
    return blocks, reasons


def clean_blocks(session, case):
    blocks, noisy = noisy_blocks(session, case)
    return len(blocks) - len(noisy)


def write_rhs_timers(directory):
    """The median of the RHS timers over the blocks, in the format of `profile.jl`."""
    rows = {}
    for row in read_csv(directory / "rhs_timers_blocks.csv"):
        rows.setdefault(row["path"], []).append(row)
    out = []
    for path, group in rows.items():
        per_call = statistics.median(float(r["per_call_ms"]) for r in group)
        out.append({"path": path, "ncalls": group[0]["ncalls"], "per_call_ms": per_call})
    with open(directory / "rhs_timers.csv", "w", newline="") as io:
        writer = csv.DictWriter(io, ["path", "ncalls", "per_call_ms"])
        writer.writeheader()
        writer.writerows(out)


# ==========================================================================================
# ==== Statistics
def bootstrap_median(values, n=10000, level=0.95):
    if len(values) == 1:
        return values[0], values[0]
    rng = random.Random(0)
    medians = sorted(statistics.median(rng.choices(values, k=len(values)))
                     for _ in range(n))
    return medians[int((1 - level) / 2 * n)], medians[int((1 + level) / 2 * n) - 1]


def compare(reference, values):
    """Ratios per block, their median and interval, and the ratio of the minima."""
    blocks = sorted(set(reference) & set(values))
    # E.g. the refinement call of a uniform run takes no time
    if not blocks or min(reference.values()) == 0 or min(values.values()) == 0:
        return None
    ratios = [values[b] / reference[b] for b in blocks]
    low, high = bootstrap_median(ratios)
    return {"blocks": blocks, "ratios": ratios, "median": statistics.median(ratios),
            "low": low, "high": high,
            "min_ratio": min(values.values()) / min(reference.values()),
            "n": len(blocks)}


def verdict(result, noise, clean_enough):
    if result["n"] < 2:
        return "one block only"
    floor = noise if noise is not None else 0.0
    middle = result["median"]
    side = "faster" if middle < 1 else "slower"
    same_side = all((r < 1 - floor) if middle < 1 else (r > 1 + floor)
                    for r in result["ratios"])
    excludes_one = result["low"] > 1 or result["high"] < 1
    if not clean_enough:
        return f"{side}, size uncertain" if same_side else "inconclusive (noisy)"
    if not (excludes_one and abs(middle - 1) > floor):
        return "no change detected"
    if abs(result["min_ratio"] / middle - 1) > AGREE_LIMIT:
        return f"{side}, size uncertain"
    return side


def percent(ratio):
    return f"{100 * (ratio - 1):+.1f}%"


# ==========================================================================================
# ==== Report
METRICS = (("step", "step time [ms]", ".1f"),
           ("rhs_in_steps", "RHS in the steps [ms]", ".2f"),
           ("rhs_median", "isolated RHS, median of the calls [ms]", ".3f"),
           ("rhs_min", "isolated RHS, minimum of the calls [ms]", ".3f"),
           ("rhs_per_particle", "RHS in the steps per fluid particle [µs]", ".3f"),
           ("refine", "refinement call [ms]", ".1f"),
           ("per_time", "wall time per unit of simulated time [s]", ".2f"))


def case_report(session, info, case):
    labels = [entry["name"] for entry in info["labels"]]
    ref, aa = info["reference"], info["aa"]
    data = {label: load(session / label / case) for label in labels}
    blocks, noisy = noisy_blocks(session, case)
    # At least as many clean blocks as planned
    clean_enough = len(blocks) - len(noisy) >= info["blocks"]
    lines = [f"\n## {case}\n"]

    # Every block
    for metric, name, _ in METRICS[:1] + METRICS[2:3]:
        if not any(data[label][metric] for label in labels):
            continue
        lines.append(f"{name}, every block:\n")
        lines.append("| block | " + " | ".join(labels) + " | noisy? |")
        lines.append("|---|" + "---|" * (len(labels) + 1))
        for block in blocks:
            cells = [f"{data[label][metric][block]:.2f}" if block in data[label][metric]
                     else "–" for label in labels]
            lines.append(f"| {block} | " + " | ".join(cells) +
                         f" | {'; '.join(noisy.get(block, [])) or ''} |")
        for title, pick in (("**minimum**", min), ("**median**", statistics.median)):
            lines.append(f"| {title} | " + " | ".join(
                f"{pick(data[label][metric].values()):.2f}" if data[label][metric] else "–"
                for label in labels) + " | |")
        lines.append("")

    if any(data[label]["step"] for label in labels):
        lines.append("Work and time per label, median over the blocks:\n")
        lines.append("| label | fluid particles after startup | at the end | steps | RHS/step "
                     "| rejected | mean dt | startup [s] | step [ms] | RHS [ms] "
                     "| RHS per particle [µs] | refinement call [ms] "
                     "| wall time per simulated time [s] |")
        lines.append("|---|" + "---|" * 12)
        for label in labels:
            d = data[label]
            steps, n_rhs, rejected, n_start, n_end, _ = next(iter(d["checks"].values()))
            med = {m: statistics.median(d[m].values()) for m in
                   ("dt", "startup", "step", "rhs_in_steps", "rhs_per_particle", "refine",
                    "per_time")}
            lines.append(f"| {label} | {n_start} | {n_end} | {steps} | {n_rhs / steps:.2f} "
                         f"| {rejected} | {med['dt']:.3e} | {med['startup']:.2f} "
                         f"| {med['step']:.2f} | {med['rhs_in_steps']:.2f} "
                         f"| {med['rhs_per_particle']:.3f} | {med['refine']:.1f} "
                         f"| {med['per_time']:.1f} |")
        lines.append("")

    extra = info.get("extra", {}).get(case, 0)
    lines.append(f"Clean blocks: {len(blocks) - len(noisy)} of {len(blocks)} "
                 f"({extra} extra).\n")

    # Ratios
    lines.append(f"Ratio to `{ref}` (median of the ratios per block, 95% bootstrap interval, "
                 "ratio of the minima):\n")
    lines.append("| label | metric | median | interval | ratio of minima | verdict |")
    lines.append("|---|---|---|---|---|---|")
    noise = {}
    if aa:
        for metric, _, _ in METRICS:
            r = compare(data[ref][metric], data[aa][metric])
            if r:
                noise[metric] = max(abs(r["low"] - 1), abs(r["high"] - 1))
    for label in labels:
        if label == ref:
            continue
        for metric, name, _ in METRICS:
            r = compare(data[ref][metric], data[label][metric])
            if r is None:
                continue
            text = "A/A" if label == aa else verdict(r, noise.get(metric), clean_enough)
            lines.append(f"| {label} | {name} | {percent(r['median'])} | "
                         f"{percent(r['low'])} to {percent(r['high'])} | "
                         f"{percent(r['min_ratio'])} | {text} |")
    lines.append("")
    if noise:
        lines.append("A/A noise (the largest deviation of the A/A interval from 1): " +
                     ", ".join(f"{name.split(' [')[0]} {100 * noise[m]:.1f}%"
                               for m, name, _ in METRICS if m in noise) + ".\n")

    # Sections of the isolated RHS
    sections = {}
    for label in labels:
        values = {}
        for row in read_csv(session / label / case / "rhs_timers_blocks.csv"):
            values.setdefault(row["path"], []).append(float(row["per_call_ms"]))
        sections[label] = {path: statistics.median(v) for path, v in values.items()}
    present = [(n, p) for n, p in RHS_SECTIONS if any(p in s for s in sections.values())]
    if present:
        lines.append("Isolated RHS by section, median over the blocks [ms]:\n")
        lines.append("| label | " + " | ".join(n for n, _ in present) + " |")
        lines.append("|---|" + "---|" * len(present))
        for label in labels:
            lines.append(f"| {label} | " + " | ".join(
                f"{sections[label][p]:.3f}" if p in sections[label] else "–"
                for _, p in present) + " |")
        lines.append("")

    # Checks: the labels must do the same work
    checks = {label: {b: c for b, c in data[label]["checks"].items()} for label in labels}
    problems = []
    for label in labels:
        if len(set(checks[label].values())) > 1:
            problems.append(f"{label}: the runs differ between blocks: "
                            f"{sorted(set(checks[label].values()))}")
    if checks.get(ref) and all(checks[label] for label in labels):
        first = {label: next(iter(checks[label].values())) for label in labels}
        for label in labels:
            if label != ref and first[label] != first[ref]:
                problems.append(f"{label} and {ref} differ in (steps, RHS evaluations, "
                                "rejected, particles after the startup, particles at the "
                                f"end, t_end): {first[label]} vs. {first[ref]}")
    particles = {label: set(data[label]["rhs_particles"].values()) for label in labels}
    for label in labels:
        if label != ref and particles[label] != particles[ref]:
            problems.append(f"{label} and {ref} differ in the particles of the isolated "
                            f"RHS state: {particles[label]} vs. {particles[ref]}")
    if problems:
        lines.append("**Check: the labels don't do exactly the same work:**\n")
        lines += [f"- {p}" for p in problems]
        lines.append("\nFor labels that differ, use the wall time per unit of simulated "
                     "time instead of the step time. If the particle counts differ a lot, "
                     "divide the RHS times by them.\n")
    elif checks.get(ref):
        lines.append("Check: all labels have the same steps, RHS evaluations, particles and "
                     "end time.\n")
    else:
        lines.append("Check: only the isolated RHS was measured, the same number of "
                     "particles in all labels.\n")
    return lines


def report(session):
    session = Path(session)
    info = json.loads((session / "session.json").read_text())
    lines = [f"# Interleaved A/B: {session.name}\n",
             f"- {info['date']}, {info['mode']} measurement, size {info['size']}, "
             f"{info['threads']} threads, CPUs {info['cpus'] or 'not pinned'}, "
             f"PointNeighbors {info['pointneighbors']}",
             "- Labels: " + ", ".join(f"`{e['name']}` = {e['commit']}" + {"min": " uniform at min. spacing", "max": " uniform at max. spacing"}.get(e.get("refinement"), "") for e in info["labels"]),
             f"- {info['blocks']} blocks planned, startup {info.get('startup_s', 0):.0f} s, "
             f"total {info.get('total_s', 0) / 60:.1f} min"]
    turns = [t for t in read_csv(session / "turns.csv")]
    measured = [t for t in turns if int(t["block"]) > 0]
    if measured:
        foreign = [float(t["foreign_cores"]) for t in measured]
        idle = [float(t["idle_workers_cores"]) for t in measured]
        machine = [float(t["machine_cores"]) for t in measured]
        load = [float(t["load1"]) for t in measured]
        lines.append(f"- Other load on our cores and their siblings: median "
                     f"{statistics.median(foreign):.2f}, max {max(foreign):.2f} cores. "
                     f"Whole machine: {min(machine):.0f} to {max(machine):.0f} cores busy, "
                     f"load average {min(load):.0f} to {max(load):.0f}. Waiting workers "
                     f"used at most {max(idle):.3f} cores together.")
    for case in info["cases"]:
        lines += case_report(session, info, case)
    return "\n".join(lines) + "\n"


def main(args):
    for path in args:
        print(report(path))


if __name__ == "__main__":
    main(sys.argv[1:])
