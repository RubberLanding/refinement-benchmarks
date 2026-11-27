# Provenance of the draft chapter "Computational cost of the particle refinement"

Draft of 2026-11-27, stage 1 data. For the reproducibility chapter later: every number in
`chapter_performance.tex` carries a key in `\src{...}`, listed here with its data, script and
code version. The final thesis numbers will come from one frozen commit (PLAN.md, "Stage 2").
At that point, replace this file with one that only has that commit.

## Rebuild the draft

From the worktree root (`/mnt/ssd/home/nschum25/benchmark`):

    python3 benchmarks/thesis_draft/make_figures.py      # figures/*.pdf, generated/*.tex
    cd benchmarks/thesis_draft && latexmk -pdf main.tex

`make_figures.py` parses the time budgets (B1, B2) directly; `results/` is git-ignored, so
`figures/` and `generated/` are tracked as well. The numbers of C1 and L1 that
it plots are written into the script, with the key next to them.

## Common to all measurements

- Machine pcm016, AMD Ryzen Threadripper 3990X (64 cores, SMT), 251 GB, 8 Julia threads
  pinned to quiet cores. Julia 1.13.4, Polyester threading backend.
- PointNeighbors.jl `ef/tree-parallel` 4842a89 (dev'd from `../PointNeighbors.jl`).
- Julia environment `run/` (Project.toml and Manifest.toml in the snapshot).
- Vortex street of `setups.jl`, `size=small` (`max_spacing = 1/70`), `shifting=fast`
  (`ShiftingHaftu(theta=1, max_iterations=20)`), refinement interval 10, `SerialUpdate()`.

## Sources

"Scripts" is the commit of this repository (`benchmarks/`, remote `refinement-benchmarks`) as
recorded by the run itself (`benchmarks = ...` in `meta.toml` or `session.json`). `-dirty`
means the run used uncommitted script changes; for both such sources below, the change is the
stall filter of `time_budget.py`, committed afterwards in this repository (see the log).

| key | what | data (under `benchmarks/results/`) | script | scripts commit | TrixiParticles |
|---|---|---|---|---|---|
| B1 | refined time budget, r2 grid, r2 pruned tree, r4 pruned tree, early and developed (t = 4), 3 runs each | `budget/20261125_vortex/budget.md` and subdirectories | `time_budget.jl` (runs), `time_budget.py` (summary) | 833c782 | 92fef57 |
| B2 | uniform time budget, coarse (1/70) and fine (1/140), grid | `budget/20261126_vortex_uniform/budget.md` | as B1 | 1e8425a-dirty | 92fef57 |
| C1 | decomposition of the RHS cost per particle (Fig. rhs_decomposition): 0.25 vs 0.81 us, shares 43/31/18/5/3 % | `interleaved/20261125_cost_per_particle/` and PLAN.md "Cost per particle of the refined RHS" | `ab_interleaved.py` (ladder coarse/fine/r1/r2) plus `scratch/cost_test.jl`, `balance_test.jl`, `developed_test.jl` (functions overridden in the session, not in `src/`) | 5becb23 (the scratch scripts are tracked since 2026-11-27) | b8a4e7f (5819670 in the session labels, the same change before a rebase) |
| I1 | `@inline` fix: single RHS and interleaved whole runs | `interleaved/20261125_inline/`, `scratch/inline_check*.jl` of C1 | `ab_interleaved.py`, `inline_check.jl` | 5becb23 | 5819670 vs 9b02352 (= 92fef57 after the rebase) |
| L1 | block sizes 0/16/64/256 of the load balancing, early and developed, 6 turns in one process | `interleaved/20261126_balancing/blocks_summary.md`, `blocks_*` | `scratch/blocks.jl`, `scratch/analyse_blocks.py`, `scratch/identical.jl` (bitwise check) | not recorded (the scratch script writes no metadata; 1e8425a plus the scratch scripts) | 92fef57 + the uncommitted balancing |
| L2 | A/B of the balancing, early state, 5 blocks with A/A | `interleaved/20261126_balancing_ab_grid/`, `_ab_tree_pruned/` | `ab_interleaved.py`, `ab_worker.jl` | 1e8425a-dirty | `base` = 92fef57, `balanced` = 92fef57-dirty |
| N1 | ratio 4 and 8, grid / tree / pruned tree; candidates per particle; fluid-cylinder pair | `interleaved/20261125_search_ratio4/`, `_ratio8/`, PLAN.md "Ratio 4 and 8, with pruning" | `ab_interleaved.py`, `profile.jl` | 423ab45 | 92fef57 |
| P1 | particle count over time, ratio 2, to t = 8 | `pilot/20261125_vortex_ratio2/` | `pilot.jl`, `plot_pilot.py` | 82ad27d | 5819670 |
| V1 | tree with per-particle radii finds the same pairs as the grid (TGV, pipe) | PLAN.md "Phase 1" | `check_variable_radii.jl` | not recorded (2026-11-22) | 5b73bd7, PointNeighbors 7aeb2f0 |

## Code that is not in a commit

- **The load balancing** (L1, L2) is uncommitted on `refinement/benchmark`. `ab_interleaved.py`
  saved the source of the `balanced` label with its diff
  (`.ab_src/work_balanced/changes.diff`, git-ignored); its `src/` part is identical to
  `provenance/snapshot_20261127/balancing_uncommitted.patch` (checked 2026-11-27). Once the
  balancing is committed, replace "92fef57 + patch" by that commit here.
- **The Julia environment** `run/` (Project.toml, Manifest.toml) is excluded from the
  TrixiParticles repository. The copy in `provenance/snapshot_20261127/` is the state of
  2026-11-27; the runs don't record it. TrixiParticles and PointNeighbors are dev'd by path,
  so their versions are the commits above.
- `provenance/snapshot_20261127/*_head.txt`: commits and dirty files of both packages on
  2026-11-27.

## For the reproducibility chapter (to do)

- Record a hash of `run/Manifest.toml` with every run, and refuse or save the diff when the
  scripts are dirty (the TrixiParticles source is already saved by `ab_interleaved.py`, but
  not by `time_budget.jl`, `pilot.jl` or the scratch scripts).
- Decide which result files to keep: `results/` is git-ignored (16 MB). At least the files
  behind the cited numbers of stage 2 (`budget.md`, `report.md`, `meta.toml`,
  `session.json`, the CSV files).
- The stage 2 measurements: one commit of TrixiParticles, PointNeighbors and the scripts,
  one Manifest, and this table with a single row per figure or table.
