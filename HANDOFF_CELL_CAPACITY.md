# Handoff: cell capacity of neighborhood searches that store fine walls

Status 2026-11-24: a fix exists on `refinement/cell-capacity`, not merged. For now, the
benchmarks and experiments run without it, so the failing cases need a larger
`max_points_per_cell`. The values to use are in "Capacities to use without the fix"; they
replace the recommendations of 2026-11-23 (310 and 1210 for the cylinder).
The sections above "Measured capacities" are from before the fix.

## Goal

Refined simulations must not run out of cell capacity when
1. the stored particles belong to a wall that is finer than the coarse fluid (required), or
2. `max_spacing / min_spacing` is 8 (second commit; a TODO in `PLAN.md`).

This unblocks the vortex street at spacing ratio 4, the case where refinement is expected
to pay off (the uniform fine run has 156k particles and takes 314 ms per step).

## Problem 1: fine walls

The vortex street with ratio 4 stops in `initialize_neighborhood_search!`, called from
`semidiscretize`, with `cell list is full`, for the pair (fluid, cylinder). Full trace:
`benchmarks/results/phase3/r4/full_on_ratio4.log`.

- The cylinder has spacing `max_spacing / 4`, the channel walls `max_spacing`.
- The cell size is the search radius, the compact support of the coarsest fluid
  (`search_smoothing_length`). A cell then holds about 150 cylinder particles.
- The default capacity is 100. `ensure_refinement_cell_capacity` in
  `src/refinement/refinement.jl` raises it only if `refinement_points_per_cell(neighbor, ...)`
  is large enough, and that returns 0 unless `neighbor` is an `AbstractFluidSystem` with
  refinement.

It is not specific to the tree: the grid has the same problem, but see "Traps" for how it
shows up there.

Both search handlers call the function in `src/general/neighborhood_search.jl`
(`create_neighborhood_search` and the `SharedNHSHandler` constructor).

## Problem 2: ratio 8

`REFINEMENT_POINTS_PER_CELL_FACTOR = 4` is fixed. At ratio 8 the peak right after splitting
is 4.61 times the uniform count. The plan in `PLAN.md` is to derive the factor from
`max_spacing / min_spacing`. The peaks known so far: at most 3.1 in the 2D examples
(source comment) and 4.61 at ratio 8. Measure more ratios before choosing the rule.

## Suggested fix

Make `refinement_points_per_cell` return a count for other neighbor systems too, from
their particle spacing and the cell size. The grid and tree methods both call it, so
neither needs a separate change.

- Take the spacing from `particle_spacing(system, particle)` or
  `initial_condition.particle_spacing`. `RigidBodySystem` stores its own.
- Walls don't split, so the factor 4 may be more than needed. But the cell grid isn't
  aligned with the particles, and a `RoundSphere` isn't a lattice, so a factor of 1 is
  too small. Choose from the measured fullest cell, and keep some margin.
- The capacity costs memory: about `capacity * n_cells` entries in a grid. Don't raise it
  where the default of 100 is enough.
- Decide what happens without refinement. The test "Without Refinement" requires 100 there.
- Keep: zero search radius returns 0, capacities only grow, a larger user value is kept,
  and `resize_systems!` preserves them.
- Check open boundary systems too: they can be a neighbor and don't count as refined fluid
  here. I haven't checked whether their cells can overflow.

Update the comments and the docstring of `ParticleRefinement`, which say that only searches
storing refined fluid are enlarged.

## Measured capacities (2026-11-23)

Nothing in the code was changed. Measured with PointNeighbors 3bef14f, TrixiParticles
c4b66ab (benchmark) and 0f6ef96 (experiments), 8 threads. "Fullest" is the largest number of
particles that any cell held, including the startup after splitting, measured with a
capacity large enough not to overflow. "Now" is the capacity that is used now.
A fix for both problems exists on `refinement/cell-capacity` (d79e10c, 83e8632). It is in
neither branch, and merging it into `refinement/benchmark` conflicts in
`src/refinement/refinement.jl` and `test/refinement/cell_capacity.jl`.

### Scripts that fail

"Rule" is the capacity that `refinement/cell-capacity` sets, rounded up. Without the fix, use
the values in "Capacities to use without the fix" instead.

| Script | Case | Stored system | Fullest | Now | Rule |
|---|---|---|---|---|---|
| `run_full.jl`, `profile.jl` | vortex street `small`, ratio 4, `grid` and `tree_variable` | cylinder | 152 | 100 | 310 |
| `run_full.jl`, `profile.jl` | vortex street `small`, ratio 8, all three searches | cylinder | 607 | 100 (`tree_uniform`: 400) | 1210 |
| E3 `run.jl`, `gate` and `full` | `refined_D40_ratio4_*` | cylinder | 151 | 100 | 310 |
| E3 `run.jl`, `gate` and `full` | `refined_D40_ratio8_*` | cylinder | 596 | 100 | 1210 |
| E1 `run.jl`, `full` | `refined_max0.05_min0.00625` (ratio 8) | refined fluid | 3754 | 2845 | 5000 |

The error was seen with unmodified code for `run_full.jl` ratio 4 (grid and
`tree_variable`), `profile.jl` ratio 4 (`tree_variable`), `tree_uniform` at ratio 8 (through
`setups.jl`) and E1 (time span shortened, fails in the startup). The other rows follow from
the fullest cell. `profile.jl` uses the same setups as `run_full.jl`.

### Capacities to use without the fix

Updated 2026-11-24, measured with c4b66ab and PointNeighbors 4842a89 (`leaves.jl` and `e1.jl`,
not in the repository), 21 steps after the startup. Not set in any script yet.

| Run | What overflows | Fullest | `max_points_per_cell` |
|---|---|---|---|
| Vortex street and E3, ratio 4 | cylinder | 152 | **200** |
| Vortex street and E3, ratio 8 | cylinder | 607 | **700** |
| E1, ratio 8 | refined fluid | 3754 | **5000** |

- **Cylinder.** It is static and its spacing doesn't change, so the count is geometry: at
  ratio 4 a cell is about 12.3 `min_spacing` wide, and 12.3² ≈ 151. The factor of 2 of the
  rule isn't needed. The fullest cell holds 152 in both the grid and the tree (ratio 8: 605
  and 604 here, 607 on 2026-11-23). The tree doesn't help, since the cylinder is stored
  with the uniform radius `R` and its leaves are all at the root level.
- **E1.** Keep 5000. The peak varies between runs (3571 to 3754, uniform count 711). It is a
  short peak of the startup, not a steady state: the third split overshoots the target
  spacing 0.00625 to about 0.0027, then merging brings the fullest cell down to about 970.
  7 * 711 = 4978 is the limit of one complete split.
- **Memory** isn't a problem: the E1 grid has about 64 cells.
- Pass the value in the template cell list of only these cases. A larger automatic
  capacity of the fluid search is kept.
- A wake that refines later isn't covered, see "Not covered".

The tree doesn't keep the number of particles per leaf constant. A cell is only split if
every particle in its 3x3 block has a radius that fits the children, so one coarse particle
keeps the whole block at the root size. `max_points_per_cell` only sizes the storage.

| Case | Peak, grid | Peak, tree | Fullest after 21 steps, grid / tree | Fluid particles in root leaves |
|---|---|---|---|---|
| E1 ratio 8 | 3571 | 3233 | 979 / 227 | 28% |
| Vortex street ratio 4 | 375 | 375 | 152 / 146 | 98% |
| Vortex street ratio 8 | 1259 | 1262 | 443 / 406 | 83% |

Choosing the NHS per neighbor system (tree for the fluid, grid for the walls) isn't supported:
the handlers copy one template to all searches. It wouldn't reduce the count in the
cylinder cells either.

### Rule of the fix

- Cylinder, walls, structures: `ceil(2 * (cell size / particle spacing)^2)`, with the spacing
  of the system. At ratio 4 this is 303, at ratio 8 it is 1210. The fullest cell was
  1.0 times the uniform count for the cylinder.
- Refined fluid: `ceil(7 * (cell size / min_spacing)^2)`, where 7 is the number of particles
  of `HexagonalSplitting`. This is 4978 for E1 at ratio 8, where the fullest cell is 5.3
  times the uniform count (3749 and 3754 in two runs). The factor of 4 in
  `REFINEMENT_POINTS_PER_CELL_FACTOR` gives 2845.

This is the rule of `refinement/cell-capacity`. With it, no script has to change. Without it,
pass the values above as `max_points_per_cell` in the template cell list (`FullGridCellList`,
`TreeCellList`) of only the failing cases, so that the other measurements stay comparable. In `setups.jl` that
is `template_nhs`; the template of `tree_uniform` has 400 already,
which is enough at ratio 4 (not run unmodified) but not at ratio 8.
The experiments use the `nhs` of the examples, which can be overridden. A template value
applies to the cells of all stored systems and is kept if it is larger, so the memory grows
for all of them.

### Cases that fit

| Case | Fullest fluid (now) | Fullest open boundary (100) | Fullest wall (100) |
|---|---|---|---|
| Vortex street `small`, ratio 2 | 85 (152) | 16 | 37 |
| Vortex street `small`, ratio 4 | 375 (605) | 16 | fails except `tree_uniform` |
| Vortex street `small`, ratio 8 | 1262 (2420) | 12 | fails, see above |
| Taylor-Green `small` | 84 (164) | | |
| Pipe flow `small` | 84 (152) | 49 | 21 |
| Uniform baselines (`min`, `max`) | 13 (100) | 10 | 12 |
| E1 refined, ratio 2 (debug, full) | 88 (178) | | |
| E1 refined, ratio 4 (debug, full) | 538 (712) | | |
| E2 refined (debug, full) | 106 (152) | 52 | 28 |
| E3 refined, D5 and D10 (debug) | 86 (152) | 12 | 37 |
| E3 `refined_D40_ratio2` (gate) | 104 (152) | 16 | 42 |
| E3 `refined_D40_ratio4` (gate) | 367 (605) | 16 | fails, see above |
| E3 `refined_D40_ratio8` (gate) | 932 (2420) | 16 | fails, see above |

The largest of the three searches is given. `check_variable_radii.jl` and `profile.jl` at
ratio 2 finish without an error, and so did `test_forces.jl`. `uniform_*` runs: at most 16.

### Not covered

- Only the startup and the first steps: 21 steps (benchmark), `tspan = (0, 5e-3)`
  (experiments). A wake that refines later is not included.
- E3 `full` at D20 and D80 (ratio 2). Expected to fit, since the fullest cell depends mainly
  on the ratio, but not measured. Uniform `gate` and `full` runs of E3 were not measured.
- Sizes `medium` and `large`. Size `tiny` ran without an error (Taylor-Green, pipe flow).
- `accuracy.jl` and `ab_worker.jl` (Taylor-Green and pipe flow at ratio 2, like the rows
  above) weren't part of these measurements. Their runs of 2026-11-23 use PointNeighbors
  7aeb2f0, where the grid doesn't report an overflow.
- The E1-E3 scripts stopped after their first run for another reason (world age, fixed in
  287dbcf on `refinement/experiments`). The measurement worked around it in a scratch copy.
- Old results of the failing cases on a grid with PointNeighbors 7aeb2f0 may be wrong:
  the ratio 4 vortex street ran through there without an error.

## Where to work

Both bugs are independent of the benchmark, so the recommended base is `refinement/main`.
`refinement/benchmark` is `refinement/main` plus 8 commits, and f9db5fa (tree capacity)
exists only there. `refinement/main` has no tree method, so the tree test belongs on
`refinement/benchmark`, after rebasing it onto the fix.

- `/mnt/ssd/home/nschum25/TrixiParticles.jl` is the checkout of `refinement/main` and may be
  used by others. Create a new worktree and branch from `refinement/main`.
- `../benchmark-measure` is for measurements. Don't edit it.
- Six commits on `refinement/benchmark` (6b5500a to c4b66ab) are unpushed (2026-11-24) and
  the user hasn't decided whether to push them. Don't push, and ask the user before rebasing.
- `git stash` is shared between all worktrees. Use WIP commits instead.

## Traps

- **Silent overflow.** PointNeighbors `ef/tree-parallel` (7aeb2f0) and the registered
  versions up to 0.6.7 guard the capacity check of the grid cell lists with `@boundscheck`,
  so under `@inbounds` an overflow writes into the next cell without an error. A grid run
  that doesn't stop proves nothing with these versions. Fixed in the registered 0.6.8
  (762efa1, #194), the first registered version that always checks, and in the local branch
  `local/tree-parallel-overflow-fix` (3bef14f). The local checkout, which `run/` and `runtest/`
  use, is now on the rebased `ef/tree-parallel` (4842a89), with the same code as 3bef14f.
  `benchmarks/.ab_src` still has its own copy of 7aeb2f0, which is also the default `--pn` of `ab_interleaved.py`. Check which version is loaded with
  `pathof(PointNeighbors)`. `Pkg.test` runs with `--check-bounds=yes`, which hides the bug.
- **Reproducibility.** Use `SerialUpdate()`. With `ParallelUpdate()` and several threads,
  identical runs differ in their particle counts.
- **Noise.** pcm016 is shared (load about 32 of 128 cores). Timings are not needed for this
  fix. If you report any, say what else was running.
- **Commands.** Run them from the worktree root; don't `cd` into `benchmarks/`, which is a
  separate git repository.

## Tests

Extend `test/refinement/cell_capacity.jl`. It covers grid (both handlers) and tree, and
its wall has the coarse spacing 0.1, so `fluid_boundary == 100` should stay as it is.
Add:
- a wall at `min_spacing`, with a ratio where the default is too small: capacity raised for
  the search that stores it, for both handlers (and for the tree on the benchmark branch);
- the fullest cell fits with a round (not lattice) wall;
- a coarse wall and a run without refinement keep 100.

Confirm that the new tests fail without the fix.

## Done when

- Both of these get past the startup and finish on `refinement/benchmark` with the fix:

  ```
  julia --project=run -t 8 benchmarks/run_full.jl case=vortex_street size=small ratio=4 \
      nhs=tree_variable refinement=on shifting=fast steps=100 runs=1 out=<dir>
  julia --project=run -t 8 benchmarks/run_full.jl case=vortex_street size=small ratio=4 \
      nhs=grid refinement=on shifting=fast steps=100 runs=1 out=<dir>
  ```

  Ratio 2 completed before the fix with `tree_variable`; it should still do so.
- The grid at ratio 4 was also checked with the registered PointNeighbors (0.6.8 or later).
- For problem 2: a ratio 8 startup without overflow. If it needs more than a factor change,
  report that instead of widening the scope.
- The refinement tests pass (2019 on `refinement/benchmark` before; about 14 minutes), and
  the general tests (2773). `runtest/` is the test environment, excluded from git like `run/`.
  A new worktree needs its own copies; their `[sources]` use relative paths.

Out of scope: the tree's split rule, the performance work, and the item 5 decision
(65d0799).

Report back: the rule you chose for the capacity and the measured fullest cells, the
commits, the test results, and whether the ratio 4 run completed. The ratio 4 benchmark
itself follows separately.

## Further reading

`PLAN.md` (branches, Phase 3) and `results/summary.md`, "Phase 3, R2–R4".
