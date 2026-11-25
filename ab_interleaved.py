#!/usr/bin/env python3
"""Compare commits with interleaved measurements in warm processes.

Run from the worktree root with
    python3 benchmarks/ab_interleaved.py base=5b73bd7 final=655fd1b
The first label is the reference. A label is `name=commit`, or `name=.` for the current
state of `src/` (a snapshot is taken). Settings of a label follow the commit, in any order and
separated by colons, for example `tree=655fd1b:ratio4` or `fine=655fd1b:min:ratio4`:
- `min`, `max`: the uniform runs without refinement at the minimum and maximum spacing
- `grid`, `tree_uniform`, `tree_variable`: the neighborhood search. The default is
  `tree_variable` with refinement and `grid` for the uniform runs.
- `ratioN`: the spacing ratio of the vortex street (default: that of `setups.jl`). It has no
  effect on the other cases. A uniform run at `min` needs the ratio of the refined run.
- `default`, `fast`, `fast_pst`: the shifting of the refinement (default `fast`)

One Julia process per label and case is started and compiles once. Then the processes take
turns, in alternating order (A B, B A, ...), while the others wait. In its turn, a process
measures one full run (like `run_full.jl`) and a series of isolated RHS evaluations.
Comparing within a block cancels slow changes of the machine. `compare_interleaved.py`
turns the files into ratios with intervals, and this script prints its report at the end.

Rules, fixed before measuring:
- Block 0 is discarded (the first run of a process is often slower). It is kept in the
  files with the prefix `block0_`.
- A block is noisy if a step time or median RHS time is more than 5% above the smallest one
  of its label. As long as a case has fewer than `--blocks` clean blocks, whole blocks are
  repeated, at most `--max-extra`. No run is ever deleted.

Sources are exported with `git archive` to `.ab_src` (not in git), so `src/` and
PointNeighbors.jl can change while the measurement runs.

Options:
    --cases A,B      default `taylor_green,pipe_flow`
    --size S         default `small`
    --blocks N       measured blocks, default 5
    --max-extra N    blocks repeated because of noise, default 3
    --mode M         `full` (full runs and RHS, default) or `rhs` (RHS only)
    --aa             also run the reference commit a second time (label `<ref>_again`)
    --threads N      default 8
    --cpus LIST      `auto` (default: the quietest 8 neighboring cores), `none`,
                     or a list such as `48-55`
    --pn COMMIT      PointNeighbors commit, default `4842a89`. The Phase 2 and Phase 3 results
                     use `7aeb2f0`, where the grid doesn't report a cell overflow.
    --steps N        steps per full run, default 100
    --rhs-calls N    RHS evaluations per turn, default 100
    --name NAME      name of the output directory in `results/interleaved`
"""

import argparse
import csv
import ctypes
import fcntl
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

BENCH = Path(__file__).resolve().parent
REPO = BENCH.parent
PN_REPO = (REPO / "../PointNeighbors.jl").resolve()
SOURCES = BENCH / ".ab_src"
TICKS = os.sysconf("SC_CLK_TCK")

sys.path.insert(0, str(BENCH))
import compare_interleaved  # noqa: E402


# ==========================================================================================
# ==== Sources
def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def export(repo, commit, target):
    """Export a commit to `target`, once."""
    if not (target / ".exported").exists():
        shutil.rmtree(target, ignore_errors=True)
        target.mkdir(parents=True)
        archive = subprocess.run(["git", "-C", str(repo), "archive", commit],
                                 check=True, capture_output=True).stdout
        subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
        (target / ".exported").write_text(commit + "\n")


def pn_version(source):
    for line in (source / "Project.toml").read_text().splitlines():
        if line.startswith("version"):
            return line.split('"')[1]
    sys.exit(f"no version in {source}/Project.toml")


def environment(source, pn_source):
    """A `run/` project for `source` like `run/` of this worktree, with a fixed PointNeighbors."""
    run = source / "run"
    run.mkdir(exist_ok=True)
    text = (REPO / "run/Project.toml").read_text()
    text = text.replace('"../../PointNeighbors.jl"', f'"{pn_source}"')
    (run / "Project.toml").write_text(text)

    manifest = (REPO / "run/Manifest.toml").read_text()
    manifest = manifest.replace('"../../PointNeighbors.jl"', f'"{pn_source}"')
    # The manifest has the version of the checkout that `run/` points to
    parts = manifest.split("[[deps.PointNeighbors]]")
    head, tail = parts[0], parts[1]
    tail = re.sub(r'(\nversion = )"[^"]*"', f'\\1"{pn_version(pn_source)}"', tail, count=1)
    (run / "Manifest.toml").write_text(head + "[[deps.PointNeighbors]]" + tail)
    return run


def prepare(spec, pn_source):
    """Name, commit text, source directory and settings of a label."""
    name, _, what = spec.partition("=")
    what, *tokens = what.split(":")
    settings = {}
    for token in tokens:
        if token in ("on", "min", "max"):
            key, value = "refinement", token
        elif token in ("grid", "tree_uniform", "tree_variable"):
            key, value = "nhs", token
        elif token in ("default", "fast", "fast_pst"):
            key, value = "shifting", token
        elif re.fullmatch(r"ratio\d+", token):
            key, value = "ratio", token.removeprefix("ratio")
        else:
            sys.exit(f"`{spec}`: unknown setting `{token}`")
        if key in settings:
            sys.exit(f"`{spec}`: `{key}` is set twice")
        settings[key] = value
    settings.setdefault("refinement", "on")
    settings.setdefault("nhs", "tree_variable" if settings["refinement"] == "on" else "grid")
    settings.setdefault("shifting", "fast")
    settings.setdefault("ratio", "")
    if not re.fullmatch(r"\w[\w.-]*", name) or not what:
        sys.exit(f"`{spec}` is not `name=commit`")
    if what == ".":
        commit = git(REPO, "rev-parse", "--short", "HEAD")
        dirty = git(REPO, "status", "--porcelain", "--untracked-files=no")
        source = SOURCES / f"work_{name}"
        shutil.rmtree(source, ignore_errors=True)
        source.mkdir(parents=True)
        # Tracked files as they are now, and untracked ones that aren't ignored
        files = git(REPO, "ls-files", "-co", "--exclude-standard", "src", "ext", "examples",
                    "Project.toml", "NEWS.md").splitlines()
        for file in files:
            if (REPO / file).is_file():
                (source / file).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(REPO / file, source / file)
        text = f"{commit}-dirty" if dirty else commit
        (source / ".exported").write_text((f"{commit}-dirty" if dirty else commit) + "\n")
        (source / "changes.diff").write_text(git(REPO, "diff", "HEAD"))
    else:
        commit = git(REPO, "rev-parse", "--short", f"{what}^{{commit}}")
        source = SOURCES / commit
        export(REPO, commit, source)
        text = commit
    environment(source, pn_source)
    return name, text, source, settings


# ==========================================================================================
# ==== The machine
def cpu_busy():
    """CPU time that is not idle, per CPU in ticks."""
    busy = {}
    with open("/proc/stat") as io:
        for line in io:
            fields = line.split()
            if re.fullmatch(r"cpu\d+", fields[0]):
                times = [int(f) for f in fields[1:9]]
                busy[int(fields[0][3:])] = sum(times) - times[3] - times[4]
    return busy


def process_cpu(pid):
    """CPU time of a process in seconds."""
    fields = Path(f"/proc/{pid}/stat").read_text().rpartition(")")[2].split()
    return (int(fields[11]) + int(fields[12])) / TICKS


def parse_cpus(text):
    cpus = []
    for part in text.split(","):
        first, _, last = part.partition("-")
        cpus += range(int(first), int(last or first) + 1)
    return cpus


def siblings(cpu):
    path = Path(f"/sys/devices/system/cpu/cpu{cpu}/topology/thread_siblings_list")
    return parse_cpus(path.read_text().strip())


def choose_cpus(option, threads):
    if option == "none":
        return None
    if option != "auto":
        return parse_cpus(option)
    before = cpu_busy()
    time.sleep(3)
    after = cpu_busy()
    load = {c: (after[c] - before[c]) / TICKS / 3 for c in after}
    n_cores = len(load) // 2
    best = None
    for start in range(0, n_cores - threads + 1, 8):
        cores = range(start, start + threads)
        used = set(cores) | {s for c in cores for s in siblings(c)}
        total = sum(load[c] for c in used)
        if best is None or total < best[0]:
            best = (total, list(cores))
    print(f"CPUs {best[1][0]}-{best[1][-1]}, other load there {best[0]:.2f} cores")
    return best[1]


def frequency_mhz(cpus):
    values = []
    for cpu in cpus:
        try:
            values.append(int(Path(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq/"
                                   "scaling_cur_freq").read_text()) / 1e3)
        except OSError:
            pass
    return sum(values) / len(values) if values else float("nan")


# ==========================================================================================
# ==== Workers
def die_with_parent():
    # SIGKILL the worker when this script dies, so no processes are left behind
    ctypes.CDLL(None).prctl(1, signal.SIGKILL)


class Worker:
    def __init__(self, label, case, source, commit, settings, pn_commit, out, options):
        self.label, self.case = label, case
        self.out = out / label / case
        self.out.mkdir(parents=True)
        self.log = open(self.out / "worker.log", "w")
        command = ["julia", f"--project={source / 'run'}", "-t", str(options.threads),
                   str(BENCH / "ab_worker.jl"), f"case={case}", f"size={options.size}",
                   *(f"{key}={value}" for key, value in settings.items()
                     if key != "ratio" or case == "vortex_street"),
                   f"steps={options.steps}", f"rhs_calls={options.rhs_calls}",
                   f"commit={commit}", f"pn_commit={pn_commit}", f"out={self.out}"]
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=self.log,
                                        text=True, bufsize=1, cwd=REPO,
                                        preexec_fn=die_with_parent)

    def wait(self):
        """Wait for the next line starting with `@@ ` and return the rest of it."""
        for line in self.process.stdout:
            self.log.write(line)
            self.log.flush()
            if line.startswith("@@ "):
                return line[3:].strip()
        sys.exit(f"{self.label} {self.case} stopped, see {self.out / 'worker.log'}")

    def pin(self, cpus):
        """Pin all threads. Only after compiling: many workers on few cores compile slowly."""
        subprocess.run(["taskset", "-acp", ",".join(map(str, cpus)),
                        str(self.process.pid)], check=True, stdout=subprocess.DEVNULL)

    def ask(self, command):
        self.process.stdin.write(command + "\n")
        self.process.stdin.flush()
        return self.wait()

    def close(self):
        try:
            self.process.stdin.write("quit\n")
            self.process.stdin.flush()
            self.process.stdin.close()
            self.process.wait(timeout=30)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            self.process.kill()


def precompile(source):
    # One after the other, so the processes don't do it at the same time
    subprocess.run(["julia", f"--project={source / 'run'}", "-e",
                    "using TrixiParticles, PointNeighbors, OrdinaryDiffEqLowStorageRK; "
                    "println(pkgdir(TrixiParticles), \" \", pkgdir(PointNeighbors))"],
                   check=True, cwd=REPO, stdout=subprocess.DEVNULL)


# ==========================================================================================
# ==== Measurement
class Session:
    def __init__(self, options, out, cpus):
        self.options, self.out, self.cpus = options, out, cpus
        # The hyperthread siblings are not used, so other load on them is foreign too
        self.watched = sorted({s for c in cpus for s in siblings(c)}) if cpus else \
            sorted(cpu_busy())
        self.workers = []
        self.turns = []

    def turn(self, worker, kind, block, prefix):
        others = [w for w in self.workers if w is not worker]
        busy, start = cpu_busy(), time.time()
        own = process_cpu(worker.process.pid)
        idle = {w: process_cpu(w.process.pid) for w in others}
        text = worker.ask(f"{kind} {block} {prefix}".strip())
        wall = time.time() - start
        own = process_cpu(worker.process.pid) - own
        idle = sum(process_cpu(w.process.pid) - t for w, t in idle.items())
        now = cpu_busy()
        # CPU time on the cores and their siblings that isn't ours, in cores
        foreign = (sum(now[c] - busy[c] for c in self.watched) / TICKS - own - idle) / wall
        machine = sum(now[c] - busy[c] for c in now) / TICKS / wall
        self.turns.append({
            "block": block, "case": worker.case, "label": worker.label, "kind": kind,
            "start": f"{start:.1f}", "wall_s": f"{wall:.2f}", "own_cores": f"{own / wall:.2f}",
            "foreign_cores": f"{max(foreign, 0):.2f}", "machine_cores": f"{machine:.1f}",
            "idle_workers_cores": f"{idle / wall:.3f}", "load1": f"{os.getloadavg()[0]:.1f}",
            "mhz": f"{frequency_mhz(self.cpus or self.watched):.0f}"})
        with open(self.out / "turns.csv", "w", newline="") as io:
            writer = csv.DictWriter(io, self.turns[0])
            writer.writeheader()
            writer.writerows(self.turns)
        print(f"  block {block} {worker.case} {worker.label} {kind}: {text} "
              f"[other load {max(foreign, 0):.1f} cores, machine {machine:.0f}, "
              f"idle workers {idle / wall:.2f}]", flush=True)

    def block(self, block, cases):
        prefix = "block0_" if block == 0 else ""
        for case in cases:
            workers = [w for w in self.workers if w.case == case]
            # Rotate the start and reverse every second block, so each label is equally
            # often first
            n = len(workers)
            shift = (block // 2) % n
            order = workers[shift:] + workers[:shift]
            if block % 2 == 1:
                order.reverse()
            for worker in order:
                if self.options.mode == "full":
                    self.turn(worker, "full", block, prefix)
                self.turn(worker, "rhs", block, prefix)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("labels", nargs="+", metavar="name=commit")
    parser.add_argument("--cases", default="taylor_green,pipe_flow")
    parser.add_argument("--size", default="small")
    parser.add_argument("--blocks", type=int, default=5)
    parser.add_argument("--max-extra", type=int, default=3)
    parser.add_argument("--mode", choices=("full", "rhs"), default="full")
    parser.add_argument("--aa", action="store_true")
    parser.add_argument("--threads", type=int, default=8)
    parser.add_argument("--cpus", default="auto")
    parser.add_argument("--pn", default="4842a89")
    parser.add_argument("--steps", type=int, default=100)
    parser.add_argument("--rhs-calls", type=int, default=100)
    parser.add_argument("--name")
    options = parser.parse_args()

    SOURCES.mkdir(exist_ok=True)
    lock = open(SOURCES / "lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit("Another `ab_interleaved.py` is running")

    started = time.time()
    pn_commit = git(PN_REPO, "rev-parse", "--short", f"{options.pn}^{{commit}}")
    pn_source = SOURCES / f"PointNeighbors_{pn_commit}"
    export(PN_REPO, pn_commit, pn_source)
    labels = [prepare(spec, pn_source) for spec in options.labels]
    if options.aa:
        labels.append((labels[0][0] + "_again", *labels[0][1:]))
    if len({label[0] for label in labels}) < len(labels):
        sys.exit("the label names must differ")
    cases = options.cases.split(",")

    out = BENCH / "results/interleaved" / \
        (options.name or datetime.now().strftime("%Y%m%d-%H%M%S"))
    out.mkdir(parents=True)
    for source in {label[2] for label in labels}:
        precompile(source)
    cpus = choose_cpus(options.cpus, options.threads)
    session = Session(options, out, cpus)

    info = {"date": datetime.now().isoformat(timespec="seconds"), "cases": cases,
            "labels": [{"name": n, "commit": c, **s} for n, c, _, s in labels],
            "reference": labels[0][0],
            "aa": labels[-1][0] if options.aa else None,
            "pointneighbors": pn_commit, "cpus": cpus, "size": options.size,
            "threads": options.threads, "blocks": options.blocks, "mode": options.mode,
            "steps": options.steps, "rhs_calls": options.rhs_calls, "extra": {}}
    write_info = lambda: (out / "session.json").write_text(json.dumps(info, indent=1))  # noqa: E731
    write_info()

    try:
        print(f"Starting {len(labels) * len(cases)} workers, output in {out}", flush=True)
        for case in cases:
            for name, commit, source, settings in labels:
                session.workers.append(Worker(name, case, source, commit, settings,
                                              pn_commit, out, options))
        for worker in session.workers:
            worker.wait()
        if cpus:
            for worker in session.workers:
                worker.pin(cpus)
        info["startup_s"] = round(time.time() - started, 1)
        write_info()
        print(f"All workers are warm after {info['startup_s']:.0f} s", flush=True)

        for block in range(options.blocks + 1):
            session.block(block, cases)

        for case in cases:
            extra = 0
            while (compare_interleaved.clean_blocks(out, case) < options.blocks
                   and extra < options.max_extra):
                extra += 1
                print(f"{case}: fewer than {options.blocks} clean blocks, "
                      f"repeating (extra block {extra})", flush=True)
                session.block(options.blocks + extra, [case])
            info["extra"][case] = extra
            write_info()
    finally:
        for worker in session.workers:
            worker.close()

    info["total_s"] = round(time.time() - started, 1)
    write_info()
    for worker in session.workers:
        compare_interleaved.write_rhs_timers(worker.out)
    report = compare_interleaved.report(out)
    (out / "report.md").write_text(report)
    print(report)


if __name__ == "__main__":
    main()
