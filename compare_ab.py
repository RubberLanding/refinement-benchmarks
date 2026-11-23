"""Compare the measurements of `ab.sh` (Phase 3, see `PLAN.md`).

Prints one Markdown table per case with the step time and the refinement call from the
full runs (medians), and the RHS sections from the isolated RHS timers of `profile.jl`.
Run with
    python3 -I benchmarks/compare_ab.py <label> <label> ...
"""

import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from summarize import summarize  # noqa: E402

ROOT = Path(__file__).parent / "results" / "phase3"

RHS_SECTIONS = (
    ("RHS", "kick!"),
    ("interaction", "kick! / system interaction"),
    ("update shifting", "kick! / update systems and nhs / update shifting"),
    ("avg. pressure", "kick! / update systems and nhs / compute average pressure"),
    ("beta", "kick! / update systems and nhs / compute beta"),
    ("avg. pressure + beta", "kick! / update systems and nhs / compute average pressure and beta"),
    ("update nhs", "kick! / update systems and nhs / update nhs"),
)


def rhs_timers(directory):
    file = directory / "rhs_timers.csv"
    if not file.exists():
        return {}
    with open(file, newline="") as io:
        return {row["path"]: float(row["per_call_ms"]) for row in csv.DictReader(io)}


def main(labels):
    for case in ("taylor_green", "pipe_flow"):
        rows = []
        for label in labels:
            full = ROOT / label / f"full_{case}"
            profile = ROOT / label / f"profile_{case}"
            s = summarize(full) if (full / "runs.csv").exists() else None
            timers = rhs_timers(profile)
            rows.append((label, s, timers))

        present = [name for name, path in RHS_SECTIONS
                   if any(path in timers for _, _, timers in rows)]
        paths = dict(RHS_SECTIONS)
        print(f"\n### {case}\n")
        print("| label | step [ms] | spread | refinement/call [ms] | startup [s] | " +
              " | ".join(f"{name} [ms]" for name in present) + " |")
        print("|" + "---|" * (5 + len(present)))
        base = None
        for label, s, timers in rows:
            step = f"{s['step_ms']:.1f}" if s else "–"
            if s and base is None:
                base = s["step_ms"]
            elif s and base:
                step += f" ({100 * (s['step_ms'] / base - 1):+.0f}%)"
            cells = [label, step, f"{100 * s['step_spread']:.0f}%" if s else "–",
                     f"{s['refine_ms']:.1f}" if s else "–",
                     f"{s['startup_s']:.2f}" if s else "–"]
            cells += [f"{timers[paths[name]]:.3f}" if paths[name] in timers else "–"
                      for name in present]
            print("| " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main(sys.argv[1:])
