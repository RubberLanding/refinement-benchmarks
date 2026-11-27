"""Figures and LaTeX tables of the draft chapter "Computational cost of the refinement".

Run from the repository root:
    python3 benchmarks/thesis_draft/make_figures.py

Reads the time budgets from `benchmarks/results/budget/*/budget.md` (written by
`time_budget.py`). Numbers that exist only in PLAN.md or in session reports are written
below with the key of their source in PROVENANCE.md. Writes `figures/*.pdf` and
`generated/*.tex`, which `chapter_performance.tex` includes.
"""

import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
RESULTS = HERE.parent / "results"
FIGURES = HERE / "figures"
GENERATED = HERE / "generated"

# Default categorical palette of the dataviz reference (slots 1 to 4, fixed order)
BLUE, ORANGE, AQUA, YELLOW = "#257de0", "#f47230", "#00b894", "#f2a600"
GRAY = "#8a8a8a"
TEXT = "#333333"

plt.rcParams.update({
    "font.size": 9, "axes.titlesize": 9, "axes.labelsize": 9, "legend.fontsize": 8,
    "xtick.labelsize": 8, "ytick.labelsize": 8, "axes.spines.top": False,
    "axes.spines.right": False, "axes.edgecolor": GRAY, "axes.labelcolor": TEXT,
    "xtick.color": TEXT, "ytick.color": TEXT, "text.color": TEXT,
    "pdf.fonttype": 42,
})


# ==== Parse the time budgets (source keys B1 and B2 in PROVENANCE.md)
def parse_budget(path):
    """Return {(run, state): {"n": fluid particles, "step": ms, "sections": {...}}}."""
    runs, key = {}, None
    group = None
    for line in path.read_text().splitlines():
        if m := re.match(r"### (\S+), (early|developed)", line):
            key = (m[1], m[2])
            runs[key] = {"sections": {}}
            continue
        if key is None:
            continue
        if m := re.match(r"- (\d+) to (\d+) fluid particles", line):
            runs[key]["n"] = (int(m[1]) + int(m[2])) / 2
            # Same line: one RHS per fluid particle and wall time per simulated time
            m = re.search(r"RHS [\d.]+ ms, ([\d.]+) us per fluid particle, (\d+) s per", line)
            runs[key]["rhs_per_particle"] = float(m[1])
            runs[key]["s_per_time"] = float(m[2])
        elif m := re.match(r"- step time: median ([\d.]+) ms", line):
            runs[key]["step"] = float(m[1])
        elif m := re.match(r"- startup: ([\d.]+) s, of which shifting ([\d.]+) s", line):
            runs[key]["startup"] = (float(m[1]), float(m[2]))
        elif m := re.match(r"\| \*\*(.+?)\*\* \| \*\*([\d.]+)\*\* \|", line):
            group = m[1]
            runs[key]["sections"][group] = float(m[2])
        elif m := re.match(r"\| &nbsp; (.+?) \| ([\d.]+) \|", line):
            runs[key]["sections"][f"{group}: {m[1]}"] = float(m[2])
    return runs


refined = parse_budget(RESULTS / "budget/20261125_vortex/budget.md")          # B1
uniform = parse_budget(RESULTS / "budget/20261126_vortex_uniform/budget.md")  # B2

# The runs used for each case, as in PLAN.md "Time budget": uniform early from the 100-step
# runs, developed from the reruns without stalls (coarse 500 steps, fine 100 steps x 5).
CASES = [
    ("uniform coarse", {"early": uniform[("uniform_max_grid", "early")],
                        "developed": uniform[("uniform_max_grid_500", "developed")]}),
    ("uniform fine", {"early": uniform[("uniform_min_grid", "early")],
                      "developed": uniform[("uniform_min_grid_dev5", "developed")]}),
    ("ratio 2, grid", {s: refined[("ratio2_grid", s)] for s in ("early", "developed")}),
    ("ratio 2, pruned tree", {s: refined[("ratio2_tree_pruned", s)]
                              for s in ("early", "developed")}),
    ("ratio 4, pruned tree", {s: refined[("ratio4_tree_pruned", s)]
                              for s in ("early", "developed")}),
]


def groups(run):
    s = run["sections"]
    return {"RHS": s["RHS"], "refinement call": s["refinement"],
            "update callback": s["update callback"],
            "time integration and rest": s["drift"] + s["time integration and rest"]}


# ==== Figure 1: time per step and per fluid particle, by part of the step
def figure_budget():
    parts = ["RHS", "refinement call", "update callback", "time integration and rest"]
    colors = [BLUE, ORANGE, AQUA, YELLOW]
    fig, axes = plt.subplots(1, 2, figsize=(6.3, 2.9), sharey=True)
    labels = [name for name, _ in CASES]
    for ax, state in zip(axes, ("early", "developed")):
        left = [0.0] * len(CASES)
        for part, color in zip(parts, colors):
            # us per fluid particle and step
            values = [groups(c[state])[part] * 1e3 / c[state]["n"] for _, c in CASES]
            ax.barh(range(len(CASES)), values, left=left, color=color, height=0.6,
                    edgecolor="white", linewidth=1.0, label=part)
            left = [l + v for l, v in zip(left, values)]
        for i, total in enumerate(left):
            ax.text(total + 0.12, i, f"{total:.1f}", va="center", fontsize=8)
        ax.set_title(f"{state} state")
        ax.set_xlabel(r"time per step and fluid particle [$\mu$s]")
        ax.set_xlim(0, max(left) * 1.18)
        ax.grid(axis="x", color="#e5e5e5", linewidth=0.6)
        ax.set_axisbelow(True)
    axes[0].set_yticks(range(len(CASES)), labels)
    axes[0].invert_yaxis()
    axes[0].legend(loc="upper center", bbox_to_anchor=(1.05, -0.22), ncol=4,
                   frameon=False)
    fig.savefig(FIGURES / "budget_per_particle.pdf", bbox_inches="tight")
    plt.close(fig)


# ==== Figure 2: cost per fluid particle of each loop, refined / uniform fine (developed)
SECTION_ROWS = [
    ("interaction fluid-fluid", "RHS: interaction fluid-fluid"),
    ("density", "RHS: density"),
    ("avg. pressure and beta", "RHS: avg. pressure + beta"),
    ("other pairs", "RHS: interaction other pairs"),
    ("NHS update in the RHS", "RHS: update nhs"),
    ("characteristics (OB)", "RHS: characteristics"),
    ("update callback", "update callback"),
]


def figure_section_ratio():
    fine = dict(CASES)["uniform fine"]["developed"]
    fig, ax = plt.subplots(figsize=(6.3, 2.6))
    width = 0.38
    for k, (case, color) in enumerate((("ratio 2, grid", BLUE),
                                       ("ratio 2, pruned tree", ORANGE))):
        run = dict(CASES)[case]["developed"]
        ratios = [(run["sections"][key] / run["n"]) / (fine["sections"][key] / fine["n"])
                  for _, key in SECTION_ROWS]
        y = [i + (k - 0.5) * width for i in range(len(SECTION_ROWS))]
        ax.barh(y, ratios, height=width, color=color, edgecolor="white", linewidth=1.0,
                label=case)
        for yi, r in zip(y, ratios):
            ax.text(r + 0.05, yi, f"{r:.1f}", va="center", fontsize=7)
    ax.axvline(1.0, color=TEXT, linewidth=0.8)
    ax.text(1.03, -0.75, "uniform fine", fontsize=7, color=TEXT)
    ax.set_yticks(range(len(SECTION_ROWS)), [name for name, _ in SECTION_ROWS])
    ax.invert_yaxis()
    ax.set_xlabel("time per fluid particle, relative to uniform fine")
    ax.grid(axis="x", color="#e5e5e5", linewidth=0.6)
    ax.set_axisbelow(True)
    ax.legend(loc="lower right", frameon=False)
    fig.savefig(FIGURES / "section_ratio.pdf", bbox_inches="tight")
    plt.close(fig)


# ==== Figure 3: decomposition of the RHS cost per fluid particle (source C1, b8a4e7f)
UNIFORM_FINE_RHS = 0.25  # us per fluid particle
REFINED_RHS = 0.81       # tree NHS, ratio 2, early state, before the load balancing
EXCESS_SHARES = [("thread imbalance", 0.43), ("variable-h code (ratio 1)", 0.31),
                 ("grading (ratio 2)", 0.18), ("problem size", 0.05),
                 ("call overhead", 0.03)]


def figure_decomposition():
    excess = REFINED_RHS - UNIFORM_FINE_RHS
    fig, ax = plt.subplots(figsize=(6.3, 2.4))
    names = ["uniform fine"] + [n for n, _ in EXCESS_SHARES] + ["refined"]
    bottom = 0.0
    ax.bar(0, UNIFORM_FINE_RHS, color=GRAY, width=0.6)
    ax.text(0, UNIFORM_FINE_RHS + 0.015, f"{UNIFORM_FINE_RHS:.2f}", ha="center",
            fontsize=7)
    bottom = UNIFORM_FINE_RHS
    for i, (name, share) in enumerate(EXCESS_SHARES, start=1):
        value = share * excess
        ax.bar(i, value, bottom=bottom, color=BLUE, width=0.6)
        ax.text(i, bottom + value + 0.015, f"+{value:.2f}", ha="center", fontsize=7)
        bottom += value
    ax.bar(len(names) - 1, REFINED_RHS, color=ORANGE, width=0.6)
    ax.text(len(names) - 1, REFINED_RHS + 0.015, f"{REFINED_RHS:.2f}", ha="center",
            fontsize=7)
    ax.set_xticks(range(len(names)), names, rotation=20, ha="right")
    ax.set_ylabel(r"RHS per fluid particle [$\mu$s]")
    ax.set_ylim(0, REFINED_RHS * 1.15)
    ax.grid(axis="y", color="#e5e5e5", linewidth=0.6)
    ax.set_axisbelow(True)
    fig.savefig(FIGURES / "rhs_decomposition.pdf", bbox_inches="tight")
    plt.close(fig)


# ==== Figure 4: block size of the load balancing (source L1, blocks_summary.md)
BLOCKS = [16, 64, 256]
BLOCK_RATIOS = {  # step time relative to no balancing, median over 6 turns
    ("grid", "early"): [0.682, 0.667, 0.764],
    ("grid", "developed"): [0.768, 0.761, 0.782],
    ("pruned tree", "early"): [0.855, 0.828, 0.872],
    ("pruned tree", "developed"): [0.932, 0.910, 0.916],
}


def figure_blocks():
    fig, ax = plt.subplots(figsize=(4.2, 2.5))
    styles = {"grid": BLUE, "pruned tree": ORANGE}
    for (nhs, state), ratios in BLOCK_RATIOS.items():
        ax.plot(BLOCKS, ratios, color=styles[nhs], linewidth=2,
                linestyle="-" if state == "early" else "--", marker="o", markersize=5)
        nudge = {("grid", "early"): -0.012, ("grid", "developed"): 0.006}.get((nhs, state), 0)
        ax.text(BLOCKS[-1] * 1.12, ratios[-1] + nudge, f"{nhs}, {state}", va="center",
                fontsize=7)
    ax.set_xscale("log", base=2)
    ax.set_xticks(BLOCKS, [str(b) for b in BLOCKS])
    ax.set_xlim(12, 1300)
    ax.set_xlabel("block size [particles]")
    ax.set_ylabel("step time / unbalanced")
    ax.grid(color="#e5e5e5", linewidth=0.6)
    ax.set_axisbelow(True)
    fig.savefig(FIGURES / "block_size.pdf", bbox_inches="tight")
    plt.close(fig)


# ==== Table: shares of the step for the refined runs (source B1)
TABLE_ROWS = [
    ("RHS", "RHS", 0),
    ("interaction fluid-fluid", "RHS: interaction fluid-fluid", 1),
    ("interaction other pairs", "RHS: interaction other pairs", 1),
    ("density (summation)", "RHS: density", 1),
    ("average pressure and $\\beta$", "RHS: avg. pressure + beta", 1),
    ("NHS update", "RHS: update nhs", 1),
    ("open boundary (characteristics)", "RHS: characteristics", 1),
    ("refinement call", "refinement", 0),
    ("shifting", None, 1),
    ("merge, split, criteria", None, 1),
    ("update callback", "update callback", 0),
    ("update of systems and NHS", "update callback: update systems and nhs", 1),
    ("particle shifting (PST)", "update callback: PST (update shifting)", 1),
    ("time integration and rest", None, 0),
]


def value(run, key, label):
    s = run["sections"]
    if label == "shifting":
        return sum(s[f"refinement: shift: {k}"] for k in ("compute shift", "apply shift",
                                                        "rest"))
    if label == "merge, split, criteria":
        return (s["refinement: merge"] + s["refinement: split"]
                + s["refinement: criteria + target spacing"])
    if label == "time integration and rest":
        return s["drift"] + s["time integration and rest"]
    return s[key]


def table_shares():
    cols = [(c, st) for c in ("ratio 2, grid", "ratio 2, pruned tree",
                              "ratio 4, pruned tree") for st in ("early", "developed")]
    runs = [dict(CASES)[c][st] for c, st in cols]
    lines = [r"\begin{tabular}{l" + "r" * len(cols) + "}", r"\toprule",
             r" & \multicolumn{2}{c}{ratio 2, grid} & \multicolumn{2}{c}{ratio 2, pruned tree}"
             r" & \multicolumn{2}{c}{ratio 4, pruned tree} \\",
             r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}",
             r" & early & dev. & early & dev. & early & dev. \\", r"\midrule",
             "step [ms] & " + " & ".join(f"{r['step']:.0f}" for r in runs) + r" \\",
             "fluid particles & " + " & ".join(f"{r['n'] / 1e3:.1f}k" for r in runs)
             + r" \\", r"\midrule"]
    for label, key, indent in TABLE_ROWS:
        cells = [f"{100 * value(r, key, label) / r['step']:.1f}" for r in runs]
        name = ("\\quad " if indent else "") + label
        if not indent:
            name = f"\\textbf{{{name}}}"
            cells = [f"\\textbf{{{c}}}" for c in cells]
        lines.append(name + " & " + " & ".join(cells) + r" \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    (GENERATED / "table_shares.tex").write_text("\n".join(lines) + "\n")


# ==== Table: per fluid particle, refined and uniform (source B1, B2)
def table_uniform():
    lines = [r"\begin{tabular}{lrrrrr}", r"\toprule",
             r" & \multicolumn{2}{c}{uniform} & \multicolumn{3}{c}{refined} \\",
             r"\cmidrule(lr){2-3}\cmidrule(lr){4-6}",
             r" & coarse & fine & r2 grid & r2 pruned & r4 pruned \\", r"\midrule"]
    for state in ("early", "developed"):
        runs = [c[state] for _, c in CASES]
        lines.append(rf"\multicolumn{{6}}{{l}}{{\emph{{{state} state}}}} \\")
        lines.append(r"\quad fluid particles & "
                     + " & ".join(f"{r['n'] / 1e3:.1f}k" for r in runs) + r" \\")
        lines.append(r"\quad step [ms] & "
                     + " & ".join(f"{r['step']:.1f}" for r in runs) + r" \\")
        lines.append(r"\quad step per fluid particle [$\mu$s] & "
                     + " & ".join(f"{1e3 * r['step'] / r['n']:.2f}" for r in runs) + r" \\")
        lines.append(r"\quad one RHS per fluid particle [$\mu$s] & "
                     + " & ".join(f"{r['rhs_per_particle']:.2f}" for r in runs) + r" \\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    (GENERATED / "table_uniform.tex").write_text("\n".join(lines) + "\n")


def startup_values():
    out = []
    for name in ("ratio2_grid", "ratio2_tree_pruned", "ratio4_tree_pruned"):
        total, shifting = refined[(name, "early")]["startup"]
        out.append(f"% {name}: startup {total:.2f} s, shifting {shifting:.2f} s")
    (GENERATED / "startup.tex").write_text("\n".join(out) + "\n")


if __name__ == "__main__":
    FIGURES.mkdir(exist_ok=True)
    GENERATED.mkdir(exist_ok=True)
    figure_budget()
    figure_section_ratio()
    figure_decomposition()
    figure_blocks()
    table_shares()
    table_uniform()
    startup_values()
    for state in ("early", "developed"):
        for name, c in CASES:
            r = c[state]
            print(f"{state:9s} {name:22s} n {r['n']:8.0f} step {r['step']:7.2f} ms "
                  f"{1e3 * r['step'] / r['n']:.2f} us/particle")
