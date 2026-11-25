# Benchmarking particle refinement

Branch `refinement/benchmark` (worktree `../benchmark`), based on `refinement/main`.
Originally created from `refinement/integration` (db093f603); that branch is retired
(2026-11-22) and `refinement/main` is the trunk of the refinement work.
Results go to `benchmarks/results/`.

Goal: find where refinement spends its time, directly (refinement call) and indirectly (more
expensive RHS), and fix what is easy (see "Phase 4"). Uniform runs are only a reference;
comparing wall times with them is a possible experiment, not part of benchmarking.
The neighborhood search is the `TreeNeighborhoodSearch` of PointNeighbors.jl
`ef/tree-parallel` (originally 1e65a4a, 4842a89 since 2026-11-23), dev'd in `run/` as
`../../PointNeighbors.jl`, with one search radius per particle.

## Decisions

- The tree NHS is used with per-particle search radii, not as a drop-in with the largest
  radius for all particles.
- BenchmarkTools is added to `run/` by the user.
- New work starts from `refinement/main`, not from `refinement/integration` (retired).
- The benchmark scripts are not published in TrixiParticles. They may later go into a
  separate repository for reproducibility.
- The `@trixi_timeit` sections are developed here and go upstream later in a small PR
  (TODO, not now). They are only on `refinement/benchmark`, not on `refinement/main`
  (2026-11-22).
- The variable search radii stay on this branch; no PR yet.
- Shifting is investigated in `SHIFTING.md` (since 2026-11-17). The first timings show
  it as ~90% of the refinement time with ~98 of at most 100 iterations per call.
- Measurements on the CPU only (2026-11-24). The GPU is out of scope, see "GPU preparation".
- Thesis scope (2026-11-24): the thesis implements refinement in TrixiParticles. It doesn't
  have to be optimized; showing a faster run than the uniform fine one at the same error
  would be nice, but isn't required. The benchmarks show the cost and where the time goes.
  The tree NHS (splitting rule and query, item 7) is named as future work.
- Fixes and features that `refinement/experiments` needs for correctness usually also go to
  `refinement/benchmark` (2026-11-25), so that both measure the same method.
- Item 5 (ee083ac, average pressure over the pairs in support) stays on `refinement/benchmark`
  and doesn't go into the experiments for now (2026-11-25). Until then, the benchmarked
  pressure term differs from the one of the experiments.
- 327b648 (interpolation) stays off this branch: it only affects evaluation, not the
  simulation, and the benchmarks don't interpolate (2026-11-25).
- No work in the pressure loop until the momentum drift is settled (2026-11-25).
- Shifting: the experiments use the same setting as the benchmarks, θ = 1 with 20 iterations
  (`shifting=fast`, 2026-11-25). Not changed in the experiments yet, see "Phase 4".
- Broad guideline for "easy" optimizations (2026-11-25): estimated gain of at least about 5% of
  the step or 20% of the startup, at most about a day of work, in TrixiParticles or a setting,
  results unchanged up to rounding or re-checked. Estimate the gain first (share of the
  section times plausible reduction). Stop when no easy item reaches about 5%.
- Order for accuracy against speed (2026-11-25): (1) a bug or instability is fixed at any cost;
  (2) does it matter for what is reported, over the longest run needed; (3) does it vanish with
  resolution (only a floor needs the fix); (4) is the fix cheaper than finer spacing for the
  same error (cost scales with Δx⁻³ in 2D); (5) if still unclear, an option that is off by
  default, with its price and the limitation in the thesis.
- `refinement/cell-capacity` isn't merged for now. Cases that overflow get a larger
  `max_points_per_cell`: 200 for the vortex street at ratio 4, see
  `HANDOFF_CELL_CAPACITY.md`.
- Timings that decide something or are reported are interleaved (`ab_interleaved.py`, two
  sessions plus `--aa`). Separate sessions are not comparable on pcm016.
- The GPU compatibility (81e7dd9) is not ready for upstream. It stays on its own branch
  `refinement/gpu-compat` (based on 6a1ed36) and is neither on `refinement/main` nor on
  `refinement/benchmark` (2026-11-22). Phase 1 does not depend on it.

## Branches (2026-11-22)

`refinement/benchmark` = `refinement/main` + the commits below, rebased whenever
`refinement/main` moves.

| Where | What |
|---|---|
| `refinement/main` | Bugs regardless of the benchmark (type stability, cell capacity, `dt_max`). The benchmark branch picks them up by rebasing. Changed defaults (e.g. of `ShiftingHaftu`) only after the variant comparison in `SHIFTING.md` step 4. |
| `refinement/benchmark` | Code in `src/` that the measurements need but that isn't ready for the trunk: the timers (Phase 0), the variable search radii with the tree NHS (Phase 1), the reference shifting variant (`SHIFTING.md` step 3), candidate fixes until the data decides (Phase 3, `SHIFTING.md` step 5). |
| not in TrixiParticles | Scripts, `run/`, results and these notes. |

The commit messages of the unpushed commits were reworded on 2026-11-25. Only the hashes changed, the
contents are the same. Recorded results, `run_accuracy.sh` and the folders in `.ab_src` use the old
hashes; this file uses the new ones.

| old | new |
|---|---|
| 6b5500a | 265dcd5 |
| f9db5fa | b7d0949 |
| 7acd1aa | ca4d0cb |
| 65d0799 | ee083ac |
| 21c205b | eeda08f |
| c4b66ab | 655fd1b |
| 251bba0 | ecee413 |
| 5819670 | b8a4e7f |
| 9b02352 | 92fef57 |

Current state:
- `refinement/main`: the PR stack (00–11), the vorticity criterion, the Eq. 37 free-slip
  fix, no shifting into OB zones (6a1ed36), the cell capacity (8dd9fab), the type
  stability of the shifting loops (540c784).
- `refinement/benchmark`: + the timers (6863f05) + the variable search radii with the
  tree NHS (5b73bd7, Phase 1), pushed. On top, not to be pushed (decided 2026-11-25):
  265dcd5, b7d0949, ca4d0cb, ee083ac, eeda08f, 655fd1b (Phase 3, 2026-11-23), and from
  `refinement/experiments` (2026-11-25): ecee413 (`SummationDensity` in the pipe and
  Taylor-Green examples, 960af49 there) and b8a4e7f (`pst_equilibrium`, b689757 there).
- Worktree `../benchmark-measure` (detached) with its own `run/`, for measurements of
  a given commit while `src/` is edited (`MEASURE=../benchmark-measure benchmarks/ab.sh`).
  `runtest/` in this worktree is the environment for the tests.
- `refinement/gpu-compat`: 6a1ed36 + the GPU compatibility (81e7dd9). To be rebased onto
  `refinement/main` when it is picked up again.
- Phases 0 and 1 are done. Phase 2 has started (see the status in "Phase 2").
- Open on `refinement/main` before the Phase 2 timings: the `dt_max` fix in the TGV
  examples (still `h / 4 * (c + U)`), and the cell capacity factor from
  `max_spacing / min_spacing` (needed for ratio 8).

## Fixes and findings from the server (2026-11-19/20)

From `dev/refinement_diagnostics/README.md` on `server/refinement-diagnostics`, which also
has the study scripts.

- **Type stability (540c784, on `refinement/main`).** `Val(NDIMS)` in the `@threaded`
  closures was dynamic, so `extract_svector_flat` allocated per particle. This was the
  805 KiB per "apply shift" iteration and the 51 MiB per "correct properties" call
  (`SHIFTING.md` step 1). TGV startup, 8 threads: 7.76 s / 5.9 GiB → 4.24 s / 37 MiB.
  Measurements before this fix measure the allocations.
- **Cell capacity (8dd9fab, on `refinement/main`).** Without it, a resolution ratio ≥ 4
  stops in the startup with `list is full`. Still too small at ratio 8: the peak right
  after splitting is 4.61 × `n_uniform`, the factor is 4. TODO on `refinement/main`:
  derive it from `max_spacing / min_spacing`.
- **Reproducibility.** With `ParallelUpdate()` and several threads, identical runs differ
  in the particle count from the 2nd refinement call on (TGV 1516–1544). The cause is the
  summation order in the NHS update, not the refinement code. With `SerialUpdate()`, or
  1 thread, all runs are identical. Use `SerialUpdate()` for every comparison.
- **`dt_max` bug in the TGV examples** (also upstream `main`): `h / 4 * (c + U)` instead of
  `h / (4 (c + U))`, so only the viscous limit applies. TODO on `refinement/main` before the
  TGV timings, otherwise the time per step is not representative.
- **Shifting convergence.** Not an oscillation, but a slow collective drift. θ = 1 with
  20 iterations has the quality of the default (θ = 0.5, 100 iterations) at about a third
  of the startup time. Details and tables in the server README; to be merged into
  `SHIFTING.md`.
- **Density instability.** `ShiftingHaftu` together with the shifting of the time
  integration and `ContinuityDensity` lets the density of single particles drift
  exponentially (TGV to t = 5). θ = 1 with the RMS criterion goes unstable at t ≈ 4.68.
  Without either shifting it stays bounded. Next step: rebase `pst_equilibrium`
  (`server/pst-equilibrium`) and repeat. Relevant for the variant comparison in
  `SHIFTING.md` step 4.

## Layout

```
benchmarks/
  PLAN.md
  SHIFTING.md
  BACKGROUND_STARTUP.md
  setups.jl        # cases with a size parameter, NHS choice and backend
  run_full.jl      # phase 2: full runs, TimerOutputs per phase
  run_matrix.sh    # phase 2: all full-run configurations of one size and thread count
  summarize.py     # phase 2: table of medians of the full runs
  ab.sh            # phase 3, superseded by ab_interleaved.py: measure one state under a label
  compare_ab.py    # phase 3: compare the labels of ab.sh
  ab_interleaved.py      # compare commits: warm processes that take turns (replaces ab.sh)
  ab_worker.jl           # the Julia process of one commit and case for ab_interleaved.py
  compare_interleaved.py # report of ab_interleaved.py (ratios per block with intervals)
  run_isolated.jl  # phase 2: BenchmarkTools on single refinement calls and kernels
  profile.jl       # phase 2: Profile and Profile.Allocs on the slowest phases
  results/         # CSV per run + summary.md, with commit hashes, threads and machine
```

## Phase 0: Instrumentation (benchmark branch only)

- `@trixi_timeit timer()` sections in `refinement!`: criteria (Alg. 4), target spacing
  (Alg. 1), merge before splitting, split (candidates, `resize_systems!`, apply, NHS
  update), merge after splitting (per round), shift ("compute shift" and "apply shift"
  per iteration; more timers in `SHIFTING.md`) and the final `update_nhs!`.
- No counter hook in `src/`. Counts come from the `ncalls` of the timers:
  refinement calls ("refinement", startup rounds from its sub-sections), full
  `update_nhs!(semi)` calls ("update nhs" under merge/split/shift), merge rounds
  ("apply merging"), resizes ("recreate nhs"), shifting iterations ("compute shift").
  Shifting gets the two timers "compute shift" and "apply shift" in its loop for this.
- Amounts (merged pairs, split particles) are not counted in full runs. The scripts read
  the active particle count from the buffer before and after each call (net change).
  The isolated benchmarks call `count_merge_pairs` and `collect_split_candidates!`
  directly on the snapshot.
- Status: done (2026-11-17), smoke-tested with the TGV example. Rebased onto
  `refinement/main` (6863f05, 2026-11-22, without the GPU compatibility); the refinement
  tests pass (2010/2010, also on `refinement/main`).
- Benchmarks use `ParticleRefinementCallback`, not the manual callback of the examples
  (it bypasses the timer).

## Phase 1: Variable search radii with the tree NHS

Needed before the measurements, since the uniform radius is the expected main cost.
PointNeighbors already supports it: `initialize_tree!`/`update_tree!` take one radius per
neighbor point, and `foreach_point_neighbor`/`foreach_neighbor`/`mapreduce_neighbor`
take a query `search_radius` (a function `point -> radius` for `foreach_point_neighbor`).

Status: implemented and checked 2026-11-19, checks in `check_variable_radii.jl`.
Committed on the laptop (2026-11-22) on top of cc44f48, not pushed yet. Rebase it onto
`refinement/benchmark` (6863f05). Expect textual conflicts in the loops that the GPU
compatibility had rewritten (merge partners, target spacing, Eq. 35, shift) and in
`src/general/neighborhood_search.jl` (also changed by the cell capacity, 8dd9fab).
Repeat the checks after the rebase.
The checks need PointNeighbors 1e65a4a, which is not on the upstream repository (the tip
of `ef/tree-parallel` there is 7aeb2f0). Push it from the laptop.

Rebased and pushed as 5b73bd7 (on 6863f05). Checks repeated on the server (2026-11-22,
Julia 1.13.4, 8 threads, PointNeighbors 7aeb2f0 instead of 1e65a4a): all passed.

| case | pairs equal | tree / uniform pairs | max rel. difference (dv, shift) |
|---|---|---|---|
| TGV, continuity | yes | 0.25 | 2.4e-13 |
| TGV, summation | yes | 0.25 | 1.5e-13 |
| pipe, continuity | yes (fluid-fluid, fluid-OB, OB-fluid) | 0.22 / 0.12 | 1.8e-14 |
| pipe, summation | yes | 0.22 / 0.12 | 2.1e-14 |

Two script fixes were needed on Julia 1.13 and the current package versions: the
example globals are read with `invokelatest(getglobal, ...)` (world age), and `dv` is
copied element-wise, since `wrap_v(...)[:, active]` fails for the `PtrArray` of
StrideArraysCore.

Implementation (`src/general/neighborhood_search.jl`, section "Variable search radii"):
- Only with `TreeNeighborhoodSearch` and `MaximumRadius()`. Each particle of a system
  with variable h gets `r = min(compact_support(kernel, h), R)`, `R` the NHS radius.
  The tree finds `max(r_a, r_b) = min(max(cs_a, cs_b), R)`, so every loop that skips
  pairs outside of the support of the larger h (`pair_in_support`), of the average h or
  of its own h sees exactly the pairs of the grid NHS with radius `R`.
- Tree radii (`initialize_nhs!`, `set_search_radii!`): per particle for neighbors with
  variable h, `R` for all others (a uniform tree, not zero: with an explicit `max_level`,
  zero radii would split every cell down to `max_level`). All NHS updates and
  initializations go through `update_neighborhood_search!(nhs, neighbor, ...)` and
  `initialize_nhs!`, including resize and restart.
- Queries use `r_a` only when both systems have variable h (fluid-fluid, fluid-OB,
  OB-fluid). Pairs with walls stay uniform: the wall h is not in the tree, and a coarse
  wall (vortex street) needs its own support.
- Opt-in per loop, not automatic: the OB sample-point interpolation, the average pressure
  (neighbor count), the method of characteristics and the mirroring rely on `R`.
  Opted in: `foreach_symmetric_point_neighbor`, `mapreduce_symmetric_neighbor` (EDAC/WCSPH
  RHS, walls, dummy particles, refinement criterion), summation density, EDAC beta,
  `ParticleShiftingTechnique` with variable h, OB `interact!`, refinement shift
  (Eq. 15), Eq. 37 correction, Eq. 35, target spacing, merge partners.
- Stale radii: the tree copies the radii when it is built. `update_smoothing_lengths!`
  before the shifting loop changes h without an NHS update, so `update_search_radii!`
  rebuilds the self tree there (tree only, timer "update search radii"). All other h
  changes are followed by an NHS update before a loop that uses the neighbor h.
- `check_configuration`: all variable-h systems must have the same compact support per h
  (the tree uses the neighbor kernel, `pair_in_support` the query kernel).
- `max_level` of the template `TreeCellList` must be set, otherwise `copy_cell_list`
  picks it from `R` and the tree is never finer than `R`. Setups use
  `floor(log2(R / cs(h(min_spacing))))`.

- Tree NHS with search radius 0 (pairs that never interact, e.g. OB-OB) are not built
  (`copy_neighborhood_search` returns an empty template), `initialize_nhs!` skips them.

Checks (`check_variable_radii.jl`), on the state after the startup, for Taylor-Green
(spacing 0.05) and pipe flow (0.02), each with continuity and summation density:
1. Pairs in support of the larger h found by the tree with variable radii vs. a Trivial
   NHS with `R`: equal for fluid-fluid, fluid-OB and OB-fluid in all 4 cases. The tree
   returns 25% (TGV), 22% (pipe fluid-fluid) and 12% (fluid-OB) of the uniform pairs.
2. One RHS (`kick!`) and one Eq. 15 shift with grid, tree uniform and tree variable
   on the same state: max relative difference 3.9e-13 (dv ~1e-15). The OB has `dv = 0`
   in the pipe flow, so the OB `interact!` is only covered by check 1.
Result 2026-11-19: all passed.

Whole runs cannot be compared: with the grid NHS alone, two runs end the startup with
different particle counts (1537 vs. 1535 for TGV at 0.05). Rounding from the parallel
NHS update flips split/merge decisions. Phase 2 must therefore record the particle count
of each run, and the refinement time varies with it.
Solved (2026-11-20, server): with `SerialUpdate()` in the grid NHS, or with 1 thread, runs
are identical. The grid comparisons use `SerialUpdate()`. For the tree NHS, check whether
its parallel update has the same effect.

## Phase 2: Measurements

Cases (`setups.jl`), each at about 10k, 40k and 160k particles via `particle_spacing`,
fixed number of steps, no saving:
- Taylor-Green with refinement (periodic, EDAC, no walls)
- Pipe flow with refinement (walls, open boundaries)

Runs: 1 and 8 threads, one warm-up run per session, median of at least 5 runs.
Grid NHS with `SerialUpdate()` for comparisons, `ParallelUpdate()` only when timing the
NHS update itself. Only on commits with the type stability fix (540c784). The TGV only after
the `dt_max` fix.

Full runs (`run_full.jl`): time per step for RHS, refinement callback and startup.
Baselines: the same case without refinement at `min_spacing` and `max_spacing`; Grid NHS
(`FullGridCellList`, `ParallelUpdate`) with the largest radius vs. the tree NHS with
uniform radius vs. the tree NHS with variable radii.

Isolated (`run_isolated.jl`): snapshot after `refinement_startup!`, then `refinement!` on a
`deepcopy` per sample (`@benchmark ... setup=(...) evals=1`). Kernels (shifting kernels
are covered in `SHIFTING.md`):
`update_nhs!`, `collect_merge_partners!`, `update_target_spacing!`,
`apply_refinement_criteria!`, one RHS evaluation.

Profiling (`profile.jl`): `Profile.print(format=:flat, sortedby=:count)` and
`Profile.Allocs` for the slowest phases.

Status (2026-11-22):
- `run/` created in the worktree (TrixiParticles `..`, PointNeighbors `../../PointNeighbors.jl`
  at 7aeb2f0, OrdinaryDiffEqLowStorageRK), excluded in `.git/info/exclude`. BenchmarkTools
  is not added yet (needed for `run_isolated.jl`).
- `setups.jl` and `run_full.jl` written and smoke-tested at `tiny` for all NHS kinds and
  baselines. `run_matrix.sh <size> <threads>` runs all configurations of one size.
- The TGV `dt_max` is computed correctly in `setups.jl` (`h / (4 (c + U))`), so the TGV
  timings don't wait for the fix in the example.
- The example is included once per configuration, and each run starts from a `deepcopy`.
  Including it again creates new types for its anonymous functions (the refinement
  criteria are part of the system type), so every run would compile everything again
  (startup 31 s instead of 2.4 s at tiny).
- Sizes calibrated for small and medium, see `results/sizes.md`. Large is not measured yet.
- pcm016 is shared (load ~32 of 128 cores from other jobs at the time of the first runs).
  `meta.toml` records the load average. Timings from pcm016 are noisy until the machine
  is free or the threads are pinned.
- The small matrix at 8 threads (100 steps, 5 runs) is done, see `results/summary.md`.
  Main finding: with refinement, the RHS is 3–7 times more expensive per particle than the
  uniform baseline at `min_spacing`, so the steps are 4–10 times slower although the
  refinement callback is only 20–35% of the step time.
- `profile.jl` written (sections distribution, pairs, rhs, profile_rhs, shift,
  profile_shift) and run at size small, see `results/summary.md`. Findings: the tree query
  costs 3.7–9.5 times the grid query per particle and is about half of the RHS; the
  shifting always runs 100 iterations because of a tail of particles; the target spacing of
  the pipe flow stays fine, since the grading needs ~25–30 `max_spacing` and the pipe is
  34 high.
- The uniform tree (`max_level=0`) needs `max_points_per_cell=400`, otherwise the pipe
  flow stops with `cell list is full`.

## Phase 3: Optimizations (plan of 2026-11-22, from the Phase 2 data)

Based on the small matrix and `profile.jl` (`results/summary.md`, overview in the artifact
"Refinement Cost Breakdown"). Reference: Taylor-Green refined with the tree and
per-particle radii, 240 ms per step (10.8k particles), and the pipe flow, 201 ms. The
uniform runs at `min_spacing` take 58 ms (16.4k) and 21 ms (11.6k).

Where the 240 ms go (TGV): RHS 179 ms (75%), of which ~47% is the tree query and ~29% the
loop bodies; refinement 47 ms (20%), of which compute shift 35 ms and apply shift 6.5 ms;
update callback 12 ms (5%). The tree query is also the main cost of `compute shift`.

Upper bound: even with no overhead, the refined TGV has 0.66 of the uniform particles,
so it can at best be ~1.5 times faster than the uniform run (pipe flow: 0.92, ~1.1 times).
The code optimizations below cannot change that; only the case can (see R4).

### Ranking

Gains are estimates per TGV step (240 ms) unless noted, to be measured.

| # | Optimization | Where | Expected gain | Effort | Risk |
|---|---|---|---|---|---|
| 1 | Shifting with θ = 1, 20 iterations | `setups.jl` (default later on `refinement/main`) | −34 ms (−14%), startup −75% | trivial | low: quality checked on the server |
| 2 | ~~Tree leaf size (`max_points_per_cell`, `max_level`)~~ No setting: see R1 | — | — | — | — |
| 3 | Skip `pair_in_support` with per-particle radii | `src/`, benchmark branch | −12 ms (−5%) | small | low: covered by `check_variable_radii.jl` |
| 4 | One neighbor loop for EDAC beta and the average pressure | `src/`, benchmark branch | −21 ms (−9%), also in the update callback | medium | medium: two quantities in one pass |
| 5 | Radius of the average pressure (per-particle support) | `refinement/main`, after a decision | −6 ms (−3%) | small | it changes the result, so a correctness question first |
| 6 | Per-pair cost with variable h (`pair_kernel_grads`, two kernel gradients) | `src/` | unknown, the loop bodies are ~29% of the RHS | medium–high | medium |
| 7 | Tree splitting and query in PointNeighbors | `ef/tree-parallel` | the tree–grid gap (3.7–9.5× per particle); most leaves are at the root size `R` (see R1) | high | separate repository |
| 8 | NHS rebuilds per `update_nhs!(semi)` (shared fluid NHS rebuilt per pair?) | `src/` | pipe: `update nhs` is 10% of the RHS (35% in the uniform run); TGV 3% | small to check | low |
| 9 | Two full system updates per refinement call ("update systems before" and "after" in `apply_refinement!`) | `src/` | 16–25 ms per call (12–18% of a fast call, ~2.5 ms per TGV step) | small to check | medium: "before" computes the quantities that merging and Eq. 37 use |

Deprioritized by the data: the serial parts and allocations of the refinement
(merging, splitting, resize: 4–6 ms per step, 2%), the resizes (none with the buffers of
`setups.jl`), the self NHS update per shift iteration (6 ms per step, shrinks 5 times with
item 1).

### R1: settings only (no code change), size small

1. Item 1: `ShiftingHaftu(theta=1, max_iterations=20)` as an option in `setups.jl`
   (`shifting=default|fast`). The default in `src/` stays until `SHIFTING.md` step 4.
2. Item 2 dropped (2026-11-22). `max_points_per_cell` only sizes the storage of the leaf
   lists; it doesn't decide the splitting. A cell is split if it is not empty, below
   `max_level`, and its children are at least as large as the largest search radius in
   the 3^d block around it (`split_cell!`, `can_split` in `src/cell_lists/tree.jl` of
   PointNeighbors). With `max_spacing / min_spacing = 2`, `max_level = 1` and the children
   are exactly the support of `min_spacing`, so a cell is only split where its whole
   block is at the smallest h. Since Eq. 35 makes h continuous, almost every block has a
   radius slightly above it: at size tiny, 77–81% of the fluid particles are in root
   leaves (size `R`), even in the pipe flow with 81% fine particles. There the tree checks
   the same points as a grid with `R`, plus its traversal. A higher `max_level` doesn't
   help either (no radius is below `R / 2`). `profile.jl` now prints the points per leaf
   level (`pairs` section). This moves the tree–grid gap to item 7.
3. Measure: `run_full.jl` with the tree and per-particle radii, `shifting=default` and
   `shifting=fast` in the same session, 5 runs, both cases. `profile.jl`
   `sections=distribution,pairs,rhs,shift` for both settings.
4. Keep: `shifting=fast` stays an option, since it is a change of the method; the
   default in `src/` changes only after `SHIFTING.md` step 4.

Done when: the step time, the startup time and the shift residuals are known for both
settings.

Status: done (2026-11-23), see `results/summary.md`, "Phase 3, R1". Fast shifting: startup
−75%, refinement call −70%, step −15% (TGV 242.8 → 206.2 ms, pipe 143.8 → 121.5 ms), RHS
unchanged. Next in the refinement call: the two full system updates ("update systems
before" and "after", 16–25 ms per call, item 9). Use `shifting=fast` for all further
Phase 3 measurements, and the default only as the reference.

### R2: small code changes on `refinement/benchmark`, one commit each

1. Item 3: in `skip_unsupported_pairs`, skip the check when the query used the
   per-particle radius (dispatch on `VariableRadiusTreeNHS` and both systems with
   variable h). Verify with `check_variable_radii.jl` (pairs and results unchanged).
2. Item 8: count the tree rebuilds per `update_nhs!(semi)` in the pipe flow (the
   `SharedNHSHandler` maps (fluid, fluid), (OB, fluid) and (wall, fluid) to one NHS).
   Fix only if the fluid NHS is rebuilt more than once.
3. Item 4: compute beta and the average pressure in one neighbor loop of the EDAC
   system. Verify: beta and the average pressure equal before/after on a snapshot
   (bitwise or up to rounding), and the refinement tests.
4. After each: small matrix, tree only, `SerialUpdate()`, same session as a re-run of the
   previous state (the machine is shared, so compare within a session).

### R3: open questions, before more code

- Item 5: which neighborhood the average pressure should use with variable h (the
  support of the particle, as in the uniform run, or `R`). Decide on `refinement/main`,
  since it changes results.
- Item 6: profile the interaction body at line level (`profile.jl` tree output,
  `pair_kernel_grads`, `kernel_grad`, `smoothing_length`), and compare with the uniform
  run per pair. Candidates: compute the kernel normalization per particle once, avoid the
  second gradient where `h_a = h_b`.
- Item 7: only if the tree–grid gap stays large after R1. Then it is work for
  PointNeighbors, with the query benchmark of `profile.jl` (`pairs`) as the test.

Status R2 and R3 (2026-11-23): done, see `results/summary.md`, "Phase 3, R2–R4". Commits
265dcd5 (item 3), b7d0949 (tree capacity fix), ca4d0cb (item 8), ee083ac (item 5),
eeda08f (item 4), 655fd1b (item 6) on `refinement/benchmark`, not pushed. RHS −35% (TGV)
and −39% (pipe), step −37% and −35%. Item 5 changes results and needs a decision for
`refinement/main`. Item 7 stays open (PointNeighbors).
New open item: the capacity of searches that store walls finer than the coarse fluid
(vortex street with ratio 4 stops with `cell list is full`).

### R4: a case where the refinement should pay off

The pipe flow keeps 92% of the fine particles (target spacing fine almost everywhere,
`results/summary.md` section 3), so it only shows overhead. Before the medium and large
sizes: a longer or wider channel, or the vortex street with a larger spacing ratio, with
the ratio refined / uniform particles measured first (`profile.jl sections=distribution`).
Keep Taylor-Green as the periodic case.

Status R4 (2026-11-23): vortex street added (`case=vortex_street`, `ratio=`). At ratio 2,
size small: 0.27 of the uniform fine particles, step 80.1 ms vs. 80.7 ms uniform at
`min_spacing`, break-even. Ratio 4 blocked by the wall capacity bug.

### Interleaved measurements and accuracy (2026-11-23)

Size small, 8 threads, `ContinuityDensity`, PointNeighbors 7aeb2f0, base 5b73bd7, final
655fd1b, uniform runs with the final code. `results/interleaved/` and `results/accuracy/`.
`20261123_refined_vs_uniform` was disturbed by other jobs and repeated as
`20261123_refined_vs_uniform_2`, which is the one to cite.

| | step, uniform fine | step, refined final | wall time per simulated time vs. uniform fine |
|---|---|---|---|
| Taylor-Green | 54.4 ms | 132.3 ms | 1.23 |
| pipe flow | 16.2 ms | 71.0 ms | 7.0 (first 100 steps) |

- Taylor-Green's 1.23 depends on the refined `dtmax`, which comes from the coarse h. Uniform
  fine with twice its `dtmax` has the same error, which makes the refined run about 2.4
  times slower.
- Base to final: the step time drops by 33% (Taylor-Green) and 35% (pipe).
- An RHS costs 3.4 (Taylor-Green) and 4.3 times (pipe) as much per particle as a uniform one.
- The profiles suggest that the tree query is 58% (Taylor-Green) and 41% (pipe) of the RHS
  (estimates from single runs).
- Refined Taylor-Green had 3.4% L2 velocity error at t = 1 (uniform coarse 1.0%, fine 0.4%),
  and the refined pipe blew up at t = 1.63–1.71. `SummationDensity` fixes the blow-up but
  not the Taylor-Green error.
- The Taylor-Green error has several causes, investigated on `refinement/debug-tgv`:
  `ViscosityAdami` with unequal masses, the PST term of the momentum equation without
  `pst_equilibrium`, and the viscosity `epsilon = 0.01`. Grading is still open.

These timings use `ContinuityDensity` and the older setup, so they don't describe the
thesis setup. They must not be cited as a speedup of a working refined run.

## Phase 4: Where refinement spends its time (rewritten 2026-11-25)

Replaces the plan of 2026-11-24. Two stages, since the experiments still change `src/`.

### Stage 1: now

Code: `refinement/benchmark`, PointNeighbors 4842a89. One rough time budget. The exact
numbers get stale when `src/` changes, the structure (which loops, search cost, shifting
iterations) mostly doesn't.

1. Prepare the scripts (no timings, independent of the open investigations):
   - `setups.jl`: capacity 200 for the vortex street at ratio 4 (700 at ratio 8), and a
     shifting option with `pst_equilibrium=true`.
   - `ab_interleaved.py`, `ab_worker.jl`: pass `ratio` to the vortex street, choose the NHS
     per label, default `--pn` 4842a89.
   - `run_full.jl`, `profile.jl`: ratio 1 (refinement on, nothing to refine), and a developed
     state (simulate, then copy; `restart_with` isn't supported with refinement).
   - The size of the search structures once per run.
2. Pilot: particle count over time in the vortex street, to find when it levels off.
3. Time budget: vortex street, size small, ratio 2, early state (after 20 steps), 8 threads,
   `SerialUpdate()`, `shifting=fast`, 100 steps, 3 runs. All sections in ms and percent, the
   startup separately. Report per step, per simulated time, and the startup.
4. Fastest setup with refinement: the same refined case with the grid and the tree (and other
   settings of the setup), with `ab_interleaved.py` and the wall time per simulated time. The
   tree is being developed and the grid is a backup, so this is not a benchmark of the
   searches. It only matters whether the grid is faster for some setup (2026-11-25).
5. Tree settings on that state (`pruning`, `capacity`, `max_level`), with identical pairs
   required. Optimizing the tree itself is out of scope.
6. `profile.jl` on the three largest sections. Rank candidates by the guideline. The pressure
   loop isn't touched.

### Pilot (2026-11-25)

Vortex street, small, ratio 2, tree, `shifting=fast`, 8 threads, to t = 8
(`results/pilot/20261125_vortex_ratio2`, `pilot.jl`). No overflow or failure. 10,559 fluid
particles after the startup, a peak of 15,731 at t = 2.9, then 14,600 to 15,250 (mean about
14,950) from t = 3.5 to 8. Judged by the particle count, the state is developed from t of 3.5 to 4
(3,440 steps to t = 4, 10 minutes of stepping on a loaded machine). The periodicity of the shedding
wasn't checked. The developed state has 42% more particles than the state after the startup.

### Candidate: fluid neighbors of density, beta and average pressure in one loop

Not implemented: it changes the average pressure loop, which isn't touched until the momentum
drift is settled. One RHS searches the fluid neighbors three times (density; average pressure and
beta; interaction), and the first two could share one search.
- Order in the RHS: density (`update_quantities!`), wall pressure (`update_boundary_interpolation!`,
  needs the fluid density), average pressure and beta (`update_final!`, needs the wall pressure).
- The density loop could also sum beta (needs only distance, `h_a` and mass; the division by the
  density comes in `finalize_beta!`) and the pressure of fluid neighbors (an integrated quantity).
  The wall part of the average pressure stays in a later loop over the wall neighbors only.
- Open: whether the pressure of the open boundary is known before the density loop.
- Estimated gain: one fluid search is about 15% of the RHS in a tiny profile (0.93 of 6.1 ms, one
  noisy run), so at most about 11% of the step; a guess is 7 to 10%. Uniform runs could gain too.
- Must keep the average pressure bitwise or up to rounding, and the pairs that it counts.

### Cost per particle of the refined RHS (2026-11-25)

Vortex street, small, ratio 2, 20 steps, 8 threads, quiet machine. Session
`results/interleaved/20261125_cost_per_particle` (with scratch scripts; old hashes).
- RHS per fluid particle: uniform fine 0.25 us, refined with the tree 0.81 us. Of the excess of
  0.56 us, about 43% is thread imbalance (Polyester gives each thread an equal contiguous share of
  the particles), 31% the code for variable smoothing lengths, 18% the grading (twice the search
  work for the same neighbors), 5% the problem size, 3% the call overhead (single runs).
- Developed state (t = 4, 47% fine particles): imbalance 1.5 instead of 2.8 times the mean.
- `skip_unsupported_pairs` called the interaction without inlining. Fixed in 92fef57. Interleaved
  before/after (`20261125_inline`, only 1 of 8 blocks clean, load 42 to 74): grid step time
  -23% (RHS -27%), tree -3%. These sizes are uncertain, the direction is not.
  Grid and tree with the fix: the grid was faster in every block (median -6% step, -9% RHS).
- Rounding: 92fef57 isn't bitwise neutral in whole runs. The first difference is one value in its last
  digit (tree: step 35, grid: step 2). It flips some merge decisions later (10,744 and 10,754
  particles after 100 steps with the grid).
- Balancing is not implemented. Dealing blocks of particles to the threads (early state, single run)
  took the RHS from 8.6 to 6.0 ms with the tree and from 7.6 to 5.2 ms with the grid with the `@inline`.
  Developed state (with the `@inline`, single calls, load rising to 36): tree 19.5 ms, with blocks of
  16 / 64 / 256 14.8 / 18.9 / 14.6 ms; grid 17.1 ms, with blocks 17.4 / 13.3 / 13.6 ms. The gain is uncertain.

### Ratio 4 and 8, with pruning (2026-11-25)

Interleaved sessions `20261125_search_ratio4` and `_ratio8` (92fef57, PointNeighbors 4842a89, size small, early
state: 100 steps after the startup, 8 threads), plus `profile.jl` for each search. Tree and pruned tree do the same work (same
steps, RHS evaluations and particle counts); the grid takes slightly different steps, so compare with it by the
wall time per simulated time. Compared with the grid:

| | ratio 4, 8 blocks (1 clean) | ratio 8, 5 blocks (all clean) |
|---|---|---|
| step time grid / tree / pruned [ms] (median) | 214 / 196 / 153 | 666 / 486 / 385 |
| wall time per simulated time: tree / pruned | -12% / -30% | -30% / -44% |
| refinement call: tree / pruned | -16% / -35% | -36% / -49% |

In the only clean block of ratio 4 the step time is 202 / 180 / 138 ms. A/A noise 0.8% and 1.1%. Ratio 2 with
pruning is not measured; without pruning the grid was about 6% faster per step there.

Fluid-fluid neighbors per particle within the largest radius: 81 (ratio 4) and 308 (ratio 8), of which 27 and 28
are in support. Empty search (grid / tree / pruned): ratio 8 10.0 / 8.1 / 3.9 ms, ratio 4 3.0 / 4.0 / 2.1 ms
(the tree profile at ratio 4 was disturbed). Fluid particles in root-size tree cells: 96% and 85%.

**Fluid-cylinder pair:** it does not use the radii (`uses_variable_search_radius` needs both systems variable,
the cylinder has a constant smoothing length), so every fluid particle searches it with the largest radius,
whichever search is used. Ratio 8: 109 cylinder particles per fluid particle, 0.3 in support; the pair is
5.5 ms of 13.7 ms of the interaction with pruning (density and average pressure may have the same problem, not
split). Reason: the search radius
is that of the coarse fluid. Idea, not implemented: a query radius per particle for walls with a small constant
smoothing length (not checked whether the pairs need the larger support). Changing the cylinder itself (hollow)
is dropped (user, 2026-11-25).

### While the experiments run

For every fix in `src/`, an interleaved before/after run of only that fix (about 15 minutes).

### Stage 2: after the code freeze

When E1 and E2 are done, E3 passes its gate and no `src/` change is open:

1. Freeze one commit with the thesis setup. It also needs the viscosity settings
   (`ViscosityMorris`, `epsilon=1e-6`) and the splitting pattern, if the settled setup uses
   them, and a decision on ee083ac.
2. Time budget: vortex street, ratios 2 and 4, early and developed state.
3. Ladder on frozen states, time per particle and RHS, A and C at the finest spacing:
   A uniform with the grid, C refinement on at ratio 1 with grid and tree (the refinement
   code), D ratios 2 and 4 with grid and tree (the grading). B (uniform with the tree) was
   dropped, since it only compares the searches (2026-11-25).
4. Fastest setup (as in stage 1), profiles, and the final candidates, each accepted by an interleaved
   comparison and an accuracy check if results change beyond rounding.
5. Scaling (1, 8, 32 threads; small and medium), interval and `ParallelUpdate()` checks if
   time remains.
6. Numbers for the thesis and hand-off notes in `results/summary.md`. Pipe flow and
   Taylor-Green only as checks that the findings aren't specific to one case.

Dropped: the medium and large Taylor-Green and pipe runs, the GPU.

Things to watch:
- ecee413 changes the density calculator of the pipe and Taylor-Green cases, so timings
  across it compare a different method, not the code. Override the calculator
  (`density_calculator`, `fluid_density_calculator` in the pipe) to compare the code.
- `profile.jl sections=shift,profile_shift` needs the `compute_shift!` signature of b8a4e7f,
  so use the scripts of b540def for older commits.
- `profile.jl` and `check_variable_radii.jl` take `pst_equilibrium` from the refinement.

Open:
- The experiments don't have the shifting setting yet. They aren't touched from here until the
  user says so (2026-11-25).
- Whether d67a555 (`ParticleRefinementCallback` in the vortex street example) from
  `refinement/experiments` also goes to this branch. It replaces the manual callback of the
  example, which the benchmark overrides already.
- Whether the 1-thread runs and `run_isolated.jl` are still wanted.
- The startup and shifting notes in `SHIFTING.md` are not revisited.

## GPU preparation

Out of scope since 2026-11-24, kept for later. Needs `refinement/gpu-compat`, which is not
on the benchmark branch. Before the GPU measurements, rebase it onto `refinement/main` and decide whether the benchmark branch
takes it.

- Scripts take the backend as a parameter (`PolyesterBackend()` now, `CUDABackend()` later)
  and move the semidiscretization with `Semidiscretization(...; parallelization_backend)`.
- The tree NHS on the GPU is on PointNeighbors `ef/tree-gpu`, not on `ef/tree-parallel`.
- Code audit for scalar indexing and CPU-only constructs in `src/refinement/` and the
  refinement callback (e.g. loops over new particles in `resize_systems!`, `deepcopy`,
  `maximum`/`sum` on views, `zeros(Bool, n)` caches), listed in `results/gpu_audit.md`.

## Report

`results/summary.md`: time per phase and case, top hotspots with profile excerpts,
fixes ranked by expected gain vs. effort, before/after numbers for each applied fix.
