#!/usr/bin/env python3
"""Interactive dashboard of the results of `run_full.jl`, `profile.jl` and `ab_interleaved.py`.

Run with
    python3 benchmarks/dashboard.py <directory> [<directory> ...]
A directory is an output directory (`out=...`) or a directory containing some, e.g.
a session of `ab_interleaved.py`. Only charts with data in these results are shown.

Writes one self-contained HTML file, `dashboard.html` in the first directory, and opens it
through a server on localhost, which VS Code forwards from a remote machine. Stop it with
Ctrl-C.

Options:
    --out FILE   write the HTML file there
    --port N     port of the server (default: any free port)
    --no-open    only write the file
"""

import argparse
import functools
import http.server
import json
import math
import re
import statistics
import sys
import webbrowser
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from summarize import read_csv, read_meta  # noqa: E402

TEMPLATE = Path(__file__).resolve().parent / "dashboard_template.html"
DATA_FILES = ("runs.csv", "rhs_timers.csv", "pairs.csv", "shift_history.csv",
              "distribution.csv", "profile_rhs_flat.txt", "profile_shift_flat.txt")
FLAT_LINE = re.compile(r"^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+|\?)\s+(.*)$")
UPDATE = "kick! / update systems and nhs / "


def number(value):
    """The value as float, or `None` if it is missing or NaN."""
    try:
        x = float(value)
    except (TypeError, ValueError):
        return None
    return x if math.isfinite(x) else None


def rhs_segments(times):
    """Split the time of `kick!` into sections that don't overlap."""
    get = lambda path: times.get(path, 0.0)  # noqa: E731
    segs = {
        "interaction": get("kick! / system interaction"),
        "shifting": get(UPDATE + "update shifting"),
        "avgp": (get(UPDATE + "compute average pressure") + get(UPDATE + "compute beta") +
                 get(UPDATE + "compute average pressure and beta")),
        "density": get(UPDATE + "compute density"),
        "nhs": get(UPDATE + "update nhs"),
    }
    segs["other"] = max(get("kick!") - sum(segs.values()), 0.0)
    return {"segs": segs, "total": get("kick!")}


def read_step(directory):
    runs = [r for r in read_csv(directory / "runs.csv") if int(r["steps"]) > 0]
    if not runs:
        return None
    runs.sort(key=lambda r: float(r["time_steps"]) / int(r["steps"]))
    run = runs[(len(runs) - 1) // 2]  # the run with the median step time
    steps = int(run["steps"])
    rows = [r for r in read_csv(directory / "timers.csv") if r["run"] == run["run"]]
    ms = {r["path"]: int(r["time_ns"]) / 1e6 for r in rows}
    get = lambda path: ms.get(path, 0.0) / steps  # noqa: E731
    step_ms = [1e3 * float(r["time_steps"]) / int(r["steps"]) for r in runs]
    total = 1e3 * float(run["time_steps"]) / steps

    compute = get("refinement / shift / compute shift")
    shift = get("refinement / shift")
    segs = {"rhs": get("kick!") + get("drift!"), "shiftCompute": compute,
            "shiftApply": max(shift - compute, 0.0),
            "refineRest": max(get("refinement") - shift, 0.0),
            "update": get("update callback")}
    segs["other"] = max(total - sum(segs.values()), 0.0)

    n_rhs = int(run["rhs_evaluations"])
    t_end = float(run["t_end"])
    rhs_times = {path: t / n_rhs for path, t in ms.items()} if n_rhs else {}
    return {"segs": segs, "total": total, "min": step_ms[0], "max": step_ms[-1],
            "dots": step_ms, "runs": len(runs), "steps": steps, "n": int(run["n_startup"]),
            "nEnd": int(run["n_end"]), "rejected": int(run["rejected"]),
            "rhsPerStep": n_rhs / steps, "rhs": rhs_segments(rhs_times),
            "startup": ms.get("refinement startup", 0.0) / 1e3,
            "perTime": float(run["time_steps"]) / t_end if t_end > 0 else None}


def read_flat(file):
    if not file.is_file():
        return None
    frames = {}
    for line in file.read_text(errors="replace").splitlines():
        match = FLAT_LINE.match(line)
        if match is None:
            continue
        count, own, path, line_number, function = match.groups()
        frames[path, line_number, function] = (int(count), int(own))
    # The flat profile omits the frames with few samples, so own samples are only
    # a lower bound of the total
    package = lambda path: path[1:].split("/")[0] if path.startswith("@") else "other"  # noqa: E731
    return [{"file": path, "line": line_number, "function": function.strip(),
             "package": package(path), "count": count, "own": own}
            for (path, line_number, function), (count, own) in frames.items()]


def read_shift(directory):
    systems = {}
    for row in read_csv(directory / "shift_history.csv"):
        systems.setdefault(row["system"], []).append(
            {"i": int(row["iteration"]), "max": number(row["max"]),
             "p99": number(row["p99"]), "median": number(row["median"]),
             "above": int(row["above"]), "total": number(row["max_total_shift"])})
    return systems


def read_distribution(directory):
    systems = {}
    for row in read_csv(directory / "distribution.csv"):
        key = f"{row['system']}, x{row['dim']}"
        systems.setdefault(key, []).append(
            {"x": (float(row["lower"]) + float(row["upper"])) / 2, "n": int(row["n"]),
             "actual": number(row["mean_level"]),
             "target": number(row.get("mean_target_level"))})
    return systems


def read_pairs(directory):
    rows = []
    for row in read_csv(directory / "pairs.csv"):
        # The fluid only, the other searches are small
        if row["system"] != row["neighbor"]:
            continue
        uniform, variable = number(row["query_uniform_ms"]), number(row["query_variable_ms"])
        ms, n = (uniform if variable is None else variable), int(row["points"])
        if ms is not None and n > 0:
            rows.append({"system": row["system"], "n": n, "ms": ms, "us": 1e3 * ms / n,
                         "neighbors": number(row["in_support_per_particle"]),
                         "candidates": number(row["uniform_per_particle"]),
                         "nhs": row["nhs"]})
    return rows


def read_result(directory):
    meta = read_meta(directory)
    rhs_rows = read_csv(directory / "rhs_timers.csv")
    rhs = rhs_segments({r["path"]: float(r["per_call_ms"]) for r in rhs_rows})
    # `ab_interleaved.py` has one series of RHS evaluations per block
    blocks = {}
    for row in read_csv(directory / "rhs_samples.csv"):
        blocks.setdefault(row["block"], []).append(float(row["ms"]))
    rhs["dots"] = [statistics.median(values) for values in blocks.values()]
    merge = None
    summary = directory / "summary.txt"
    if summary.is_file():
        match = re.search(r"merge level ([\d.]+)", summary.read_text(errors="replace"))
        merge = float(match.group(1)) if match else None
    return {"meta": meta, "step": read_step(directory), "rhs": rhs if rhs_rows else None,
            "query": read_pairs(directory), "shift": read_shift(directory),
            "dist": read_distribution(directory), "merge": merge,
            "profile": {"rhs": read_flat(directory / "profile_rhs_flat.txt"),
                        "shift": read_flat(directory / "profile_shift_flat.txt")}}


def find_results(paths):
    found = []
    for path in paths:
        if not path.exists():
            sys.exit(f"{path} does not exist")
        candidates = [path, *sorted(p for p in path.rglob("*") if p.is_dir())]
        results = [d.resolve() for d in candidates if (d / "meta.toml").is_file()
                   and any((d / f).is_file() for f in DATA_FILES)]
        if not results:
            print(f"No results in {path}", file=sys.stderr)
        found += [d for d in results if d not in found]
    return found


def names_of(directories):
    """The shortest trailing parts of the paths that are unique."""
    for n in range(1, 10):
        names = ["/".join(d.parts[-n:]) for d in directories]
        if len(set(names)) == len(names):
            break
    return names


class Handler(http.server.BaseHTTPRequestHandler):
    """Serves the dashboard and nothing else."""

    def __init__(self, page, *args, **kwargs):
        self.page = page
        super().__init__(*args, **kwargs)

    def do_GET(self):
        found = self.path.split("?")[0] == "/"
        self.send_response(200 if found else 404)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(self.page) if found else 0))
        self.end_headers()
        if found:
            self.wfile.write(self.page)

    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directories", nargs="+", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--no-open", action="store_true")
    args = parser.parse_args()

    directories = find_results(args.directories)
    if not directories:
        sys.exit("No results found")
    data = [{"name": name, "path": str(d), **read_result(d)}
            for name, d in zip(names_of(directories), directories)]

    # `<` must not end the script element
    text = json.dumps(data, allow_nan=False).replace("<", "\\u003c")
    page = TEMPLATE.read_text().replace("__DATA__", text)
    first = args.directories[0]
    out = args.out or (first if first.is_dir() else first.parent) / "dashboard.html"
    out.write_text(page)
    print(f"{len(data)} result(s), saved {out}")
    if args.no_open:
        return

    handler = functools.partial(Handler, page.encode())
    with http.server.ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        url = f"http://localhost:{server.server_address[1]}/"
        print(f"Dashboard: {url} (Ctrl-C to stop)", flush=True)
        webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print()


if __name__ == "__main__":
    main()
