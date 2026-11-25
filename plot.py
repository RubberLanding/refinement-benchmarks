"""Plot where the time of a step goes, from the results of `run_full.jl`.

One stacked bar per result directory, from the run with the median step time, with the
minimum and maximum over the runs as error bar. Run with
    python3 benchmarks/plot.py [--out=FILE] <directory> ...
where each directory contains `runs.csv` and `timers.csv`. The default output is
`benchmarks/results/step_time.png`.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from summarize import read_csv, read_meta  # noqa: E402

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

UPDATE = "kick! / update systems and nhs / "
# Label, timer paths, color. The sections don't overlap.
SECTIONS = (
    ("interaction", ("kick! / system interaction",), "#4477AA"),
    ("update shifting", (UPDATE + "update shifting",), "#66CCEE"),
    ("avg. pressure + beta", (UPDATE + "compute average pressure", UPDATE + "compute beta",
                              UPDATE + "compute average pressure and beta"), "#228833"),
    ("density", (UPDATE + "compute density",), "#EE8866"),
    ("update nhs", (UPDATE + "update nhs",), "#CCBB44"),
    ("rest of RHS", None, "#BBBBBB"),
    ("refinement", ("refinement",), "#EE6677"),
    ("update callback", ("update callback",), "#AA3377"),
    ("other (time integration)", None, "#E5E5E5"),
)


def breakdown(directory):
    meta = read_meta(directory)
    runs = sorted(read_csv(directory / "runs.csv"), key=lambda r: float(r["time_steps"]))
    run = runs[(len(runs) - 1) // 2]
    steps = int(run["steps"])
    if steps == 0:
        sys.exit(f"{directory}: no time steps")
    times = {row["path"]: int(row["time_ns"]) / 1e6 / steps
             for row in read_csv(directory / "timers.csv") if row["run"] == run["run"]}
    step = [1e3 * float(r["time_steps"]) / int(r["steps"]) for r in (run, runs[0], runs[-1])]

    values = {label: sum(times.get(p, 0.0) for p in paths)
              for label, paths, _ in SECTIONS if paths}
    rhs = times.get("kick!", 0.0) + times.get("drift!", 0.0)
    inside = sum(values[label] for label, paths, _ in SECTIONS
                 if paths and paths[0].startswith("kick!"))
    values["rest of RHS"] = max(rhs - inside, 0.0)
    values["other (time integration)"] = max(
        step[0] - rhs - values["refinement"] - values["update callback"], 0.0)

    folder = directory.parent.name if directory.name.startswith("full_") else ""
    details = (meta["size"], meta["nhs"], f"refinement={meta['refinement']}",
               meta.get("options", ""))
    name = "\n".join(filter(None, (meta["case"], " ".join(filter(None, details)), folder)))
    return name, values, step


def main(args):
    out = Path(__file__).parent / "results" / "step_time.png"
    directories = []
    for arg in args:
        if arg.startswith("--out="):
            out = Path(arg[len("--out="):])
        else:
            path = Path(arg).resolve()
            # `full_*` also matches the log files, and failed runs have no results
            if (path / "runs.csv").is_file():
                directories.append(path)
            elif path.suffix != ".log":
                print(f"Skipped {arg}: no runs.csv")
    if not directories:
        sys.exit("No results found.\n\n" + __doc__)

    data = [breakdown(d) for d in directories]
    fig, ax = plt.subplots(figsize=(10, 1.8 + 0.8 * len(data)), layout="constrained")
    y = range(len(data))
    left = [0.0] * len(data)
    for label, _, color in SECTIONS:
        widths = [values[label] for _, values, _ in data]
        ax.barh(y, widths, left=left, color=color, label=label, height=0.65)
        left = [a + b for a, b in zip(left, widths)]
    limit = max(high for _, _, (_, _, high) in data)
    for i, (_, _, (median, low, high)) in enumerate(data):
        ax.errorbar(median, i, xerr=[[median - low], [high - median]], color="black",
                    capsize=4)
        ax.text(high + 0.01 * limit, i, f"{median:.1f} ms", va="center")
    ax.set_yticks(list(y), [name for name, _, _ in data], fontsize=8)
    ax.invert_yaxis()
    ax.set_xlim(0, 1.12 * limit)
    ax.set_xlabel("wall time per step [ms] (median run, bars: min and max over runs)")
    ax.spines[["top", "right"]].set_visible(False)
    fig.legend(*ax.get_legend_handles_labels(), loc="outside upper center", ncols=4,
               frameon=False, fontsize=8)
    fig.savefig(out, dpi=150)
    print(f"Saved {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
