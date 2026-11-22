# Benchmarking particle refinement

Branch `refinement/benchmark` (worktree `../benchmark`), based on `refinement/main`.
Originally created from `refinement/integration` (db093f603); that branch is retired
(2026-11-22) and `refinement/main` is the trunk of the refinement work.
Results go to `benchmarks/results/`.

Goal: find where refinement spends its time and fix the cheap bottlenecks.
The neighborhood search is the `TreeNeighborhoodSearch` of PointNeighbors.jl
`ef/tree-parallel` (1e65a4a), dev'd in `run/` as `../../PointNeighbors.jl`,
with one search radius per particle.

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
- Measurements on CPU first, then GPU. Scripts and code are prepared for the GPU from
  the start.
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

Current state:
- `refinement/main`: the PR stack (00–11), the vorticity criterion, the Eq. 37 free-slip
  fix, no shifting into OB zones (6a1ed36), the cell capacity (8dd9fab), the type
  stability of the shifting loops (540c784).
- `refinement/benchmark`: + the timers (6863f05).
- `refinement/gpu-compat`: 6a1ed36 + the GPU compatibility (81e7dd9). To be rebased onto
  `refinement/main` when it is picked up again.
- Phase 1 is committed on the laptop, on top of the old timer commit cc44f48 (which
  contained the GPU compatibility). Rebase it onto 6863f05 before pushing.

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
  run_full.jl      # phase 1: full runs, TimerOutputs per phase
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

## Phase 3: Candidate fixes (to be confirmed by the data)

1. NHS rebuilds per refinement call: full `update_nhs!(semi)` after merging before
   splitting, splitting, merging after splitting and shifting; self updates per merge
   round and per shifting iteration (up to 100); `update_systems_and_nhs` twice in the
   callback. The tree is always rebuilt from scratch.
   From the code (2026-11-19, to be confirmed by the timers): `update_nhs!(semi)` loops
   over all pairs, and with the `SharedNHSHandler` the pairs (fluid, fluid), (OB, fluid)
   and (wall, fluid) map to the same NHS (same radius `R`), so the fluid NHS of the pipe
   flow is rebuilt three times per `update_nhs!(semi)`, also in every RHS.
2. Shifting: see `SHIFTING.md` (convergence check, fixed iterations as in the
   reference, reference variant, allocations, NHS update per iteration). The allocations
   of "apply shift" and "correct properties" are fixed on `refinement/main` (540c784).
3. Serial parts and allocations: `resize_systems!`, `split_capacity`, `count_merge_pairs`,
   `maximum(relative_shift)`, `zeros(...)` in `split_particles!`, captured and reassigned
   variables in closures (`n_merged`, `n_rounds` → `Core.Box`).
4. Resizes: how often `resize_systems!` recreates the NHS; larger `buffer_size`.
5. Tree options: `pruning`, `max_points_per_cell`.

## GPU preparation

Needs `refinement/gpu-compat`, which is not on the benchmark branch. Before the GPU
measurements, rebase it onto `refinement/main` and decide whether the benchmark branch
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
