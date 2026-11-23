# Phase 2 results

## Full runs, size small, 8 threads (2026-11-22, pcm016)

100 steps after the startup, 5 runs after one warm-up, medians. `SerialUpdate()` for
all NHS. Refinement every 10 steps. The machine was shared during all runs (load ~37
of 128 cores from other jobs), so the times are noisy; the spread of the step time is
small (0–7%) except for the pipe flow with the tree with variable radii (37%).
Produced with `python3 -I benchmarks/summarize.py`.

| case | size | NHS | refinement | threads | runs | n after startup | n end | startup [s] | shift in startup | step [ms] | spread | RHS [ms] | RHS/step | refinement/call [ms] | refinement in steps | shift in refinement | update cb [ms] | load |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| taylor_green | small | tree_variable | on | 8 | 5 | 10775 | 10789 | 17.65 | 95% | 239.95 | 1% | 19.665 | 9.1 | 467.9 | 20% | 91% | 12.24 | 38.9 37.8 35.2 |
| taylor_green | small | tree_uniform | on | 8 | 5 | 10784 | 10832 | 30.80 | 97% | 380.82 | 2% | 30.063 | 9.1 | 843.8 | 22% | 93% | 21.18 | 39.6 39.0 36.7 |
| taylor_green | small | grid | on | 8 | 5 | 10805 | 10833 | 29.16 | 98% | 367.23 | 0% | 29.222 | 9.1 | 790.1 | 21% | 93% | 20.62 | 39.7 39.2 37.6 |
| taylor_green | small | grid | min | 8 | 5 | 16384 | 16384 | 0.00 | 0% | 57.82 | 0% | 5.896 | 9.0 | 0.0 | 0% | 0% | 3.53 | 37.9 38.6 37.4 |
| taylor_green | small | grid | max | 8 | 5 | 4096 | 4096 | 0.00 | 0% | 15.07 | 3% | 1.522 | 9.0 | 0.0 | 0% | 0% | 0.90 | 38.2 38.6 37.5 |
| pipe_flow | small | tree_variable | on | 8 | 5 | 10578 | 9748 | 4.63 | 95% | 201.17 | 37% | 20.326 | 6.1 | 531.7 | 26% | 90% | 21.33 | 38.5 37.6 37.2 |
| pipe_flow | small | grid | on | 8 | 5 | 10562 | 9763 | 9.86 | 98% | 258.35 | 1% | 22.782 | 6.2 | 848.2 | 33% | 93% | 29.11 | 39.8 37.8 37.2 |
| pipe_flow | small | grid | min | 8 | 5 | 11560 | 11660 | 0.00 | 0% | 21.46 | 0% | 2.802 | 6.1 | 0.0 | 0% | 0% | 3.61 | 36.9 37.2 37.0 |
| pipe_flow | small | grid | max | 8 | 5 | 2890 | 2904 | 0.00 | 0% | 6.64 | 7% | 0.850 | 6.2 | 0.0 | 0% | 0% | 1.07 | 35.0 36.6 36.8 |
| pipe_flow | small | tree_uniform | on | 8 | 5 | 10556 | 9771 | 8.14 | 97% | 194.31 | 2% | 16.325 | 6.1 | 689.7 | 35% | 93% | 24.61 | 39.8 37.4 37.0 |

"RHS" is `kick!` + `drift!` per RHS evaluation. "refinement in steps" is the share of the
refinement callback in the wall time of the 100 steps.

### Findings

1. **With refinement, a time step is 4–10 times slower than the uniform baseline at the
   minimum spacing, which has more particles.** Taylor-Green: 240 ms (10.8k particles,
   tree with variable radii) vs. 58 ms (16.4k, uniform at `min_spacing`). Pipe flow:
   ~200 ms (10.6k) vs. 21 ms (11.6k). The refinement callback is only 20–35% of the step
   time, so most of the difference is in the RHS.
2. **One RHS evaluation is 3–7 times more expensive per particle with refinement.**
   Taylor-Green, tree with variable radii vs. uniform at `min_spacing`, per RHS:
   fluid-fluid interaction 7.2 vs. 2.3 ms, `update systems and nhs` 12.3 vs. 3.5 ms
   (update shifting 5.3 vs. 1.8, average pressure 3.6 vs. 1.1, EDAC beta 2.7 vs. none).
   Pipe flow: fluid-fluid 9.6 vs. 1.0 ms, average pressure 4.2 vs. 0.5 ms, EDAC beta
   3.4 ms. The loops in `update systems and nhs` cost as much as the interaction itself.
   Candidates: the loops that are not opted in to the variable radii (average pressure,
   the `ConsistentShiftingSun2019` update in Taylor-Green) query with the uniform radius
   `R`; the per-pair cost with variable h; the tree query itself. To be profiled.
3. **The tree with variable radii helps the startup most.** Taylor-Green: 17.7 s vs.
   29.2 s (grid) and 30.8 s (uniform tree); pipe flow: 4.6 s vs. 9.9 s (grid) and 8.1 s
   (uniform tree). In the time steps, it is 35% faster than the grid for Taylor-Green
   (240 vs. 367 ms), but not faster than the uniform tree for the pipe flow (RHS 20.3 vs.
   16.3 ms).
4. **Shifting is 90–98% of the startup and 90–93% of each refinement call**, as in
   `SHIFTING.md`.
5. **The `update callback` costs 3–6 times more with refinement** (12–29 ms vs. 3.5 ms
   per call), from the same loops as in 2.
6. **The pipe flow gains nothing from the refinement.** The refined run has 91% of the
   particles of the uniform run at `min_spacing` (see `sizes.md`) and is 10 times
   slower per step.

## Profile, size small, 8 threads (2026-11-22, pcm016)

`profile.jl` on the state after the startup and 20 steps. Results in
`results/profile/20261122-22*` (refined with the tree with variable radii, and the uniform
baselines at `min_spacing` with the grid NHS). The target spacing levels are from a
second run of the `distribution` section with the same setup.

### 1. Why is the RHS more expensive?

Not mainly because of the loops with the uniform radius, but because of the tree query.

| | particles | neighbors in support / particle | query, per-particle radii [ms] | query, uniform R [ms] | query per particle [µs] | RHS [ms] |
|---|---|---|---|---|---|---|
| TGV refined (tree) | 10,743 | 29.8 | 2.29 | 3.00 (105 candidates) | 0.21 | 19.5 |
| TGV uniform min (grid) | 16,384 | 27.0 | | 0.93 | 0.057 | 5.9 |
| Pipe refined (tree) | 10,599 | 28.7 | 1.61 | 2.40 (141 candidates) | 0.15 | 13.7 |
| Pipe uniform min (grid) | 11,562 | 25.8 | | 0.18 | 0.016 | 2.7 |

Query times with an empty loop body. With the same number of neighbors, one tree query
per particle costs 3.7 (TGV, periodic) to 9.5 (pipe) times the grid query. Every neighbor
loop pays it: with refinement there are 4 loops per RHS (interaction, average pressure,
EDAC beta, shifting update; beta only with refinement), so about half of the RHS is the
tree query alone (TGV: ~9.5 of 19.5 ms).

- With the per-particle radii, the tree returns only pairs in support (100% useful), so
  the `pair_in_support` check in `skip_unsupported_pairs` is redundant there. It has 7.5%
  of the samples of the neighbor loops as own time (TGV).
- In the profile of the neighbor loops (TGV), about 40% of the samples are in
  `mapreduce_points` outside of the loop body (distance checks of the points in a leaf),
  26% in the traversal of the tree, 29% in the loop body. The leaves hold up to
  `max_points_per_cell=100` points and can be larger than the search radius, so many more
  points are checked than returned. Candidate: smaller leaves (`max_points_per_cell`,
  Phase 3 item 5).
- The average pressure queries with the uniform radius `R` (105–141 candidates per
  particle instead of ~29). On the tree, this costs only 30–50% more than the per-particle
  query (3.0 vs. 2.3 ms), since the traversal dominates. It also averages over a larger
  neighborhood than in the uniform run, which changes the result.
- The per-pair work of the interaction is also more expensive with variable h
  (`pair_kernel_grads`: two kernel gradients per pair, `kernel_grad` in the profile).
  Interaction minus query: TGV refined 4.9 ms for 10.7k particles, uniform 1.4 ms for
  16.4k, about 5 times more per particle. This estimate is rough, since the query with an
  empty body may be optimized differently.

### 2. Why is the shifting so expensive?

One iteration is cheap (0.22 RHS evaluations in TGV, 0.27 in the pipe flow), but every
call runs all 100 iterations, so a refinement call costs 22–27 RHS evaluations.

| iteration | 1 | 10 | 20 | 40 | 60 | 100 |
|---|---|---|---|---|---|---|
| TGV max `\|δr\|/h` | 9.1e-2 | 2.2e-2 | 1.4e-2 | 1.0e-2 | 7.7e-3 | 2.9e-3 |
| TGV p99 | 2.3e-2 | 5.4e-3 | 3.4e-3 | 2.1e-3 | 1.7e-3 | 1.3e-3 |
| TGV median | 5.1e-4 | 2.5e-4 | 2.3e-4 | 2.2e-4 | 2.1e-4 | 2.0e-4 |
| TGV above tolerance | 1,543 | 515 | 330 | 127 | 58 | 14 |
| Pipe max | 1.4e-1 | 1.5e-2 | 1.2e-2 | 7.7e-3 | 5.4e-3 | 9.0e-3 |
| Pipe above tolerance | 2,460 | 668 | 430 | 197 | 112 | 42 |

Tolerance 2e-3, `θ = 0.5`, at most 0.05 h per iteration.

- The median is below the tolerance after the first iteration. The max norm is set by a
  tail of particles (H4 in `SHIFTING.md`): the 99th percentile reaches the tolerance after
  ~40 iterations in TGV, the maximum not within 100.
- In the pipe flow, the maximum stops decreasing after ~70 iterations and grows again
  (5.2e-3 → 9.0e-3), a floor or an oscillation of a few particles (H2/H3), probably near
  walls or open boundaries. To be located (step 2 of `SHIFTING.md`).
- The accumulated shift reaches 0.40 h (TGV) and 0.35 h (pipe), large for the first-order
  correction of Eq. 37.

### 3. Why does the pipe flow not benefit from the refinement?

| | at min_spacing | graded | at max_spacing | refined / uniform at min_spacing |
|---|---|---|---|---|
| Pipe, particles | 79% | 14% | 8% | 0.92 |
| Pipe, target spacing | 67% | 23% | 10% | |
| TGV, particles | 41% | 56% | 3% | 0.66 |
| TGV, target spacing | 28% | 62% | 10% | |

- The target spacing itself stays fine. Across the pipe, the mean target level peaks at
  0.29 (level 0 = `min_spacing`, 1 = `max_spacing`); along the pipe, it is 0.54 between
  the refined zones. In TGV, the target level grows from 0.2 to 0.93 over about 22
  `max_spacing`, so grading from 0 to 1 needs ~25–30 `max_spacing`. The pipe is only 34
  `max_spacing` high at size small and is graded from both walls
  (`SpatialRefinementCriterion`), and the refined zones at the inlet and outlet (30% of the
  length) are at `min_spacing` too.
- Merging adds to it: two particles at `min_spacing` only merge where the target level is
  above 0.46 (merged mass at most `max_mass_factor = 1.05` times the reference mass),
  so the particles lag behind the target (center of the pipe: 0.41 vs. 0.54).
- With a higher resolution, the pipe is more `max_spacing` high and the ratio improves
  (0.81 at medium, `sizes.md`), but the case is too small for a coarse core at these sizes.
  Even TGV has only 3% of the particles at `max_spacing`.

## Phase 3, R1: fast shifting (2026-11-22, pcm016, size small, 8 threads)

`shifting=fast` = `ShiftingHaftu(theta=1, max_iterations=20)`, against the default
(θ = 0.5, 100 iterations, max criterion), tree with per-particle radii, both settings in
the same session, 5 runs each. Results in `results/full/20261122-23*` and
`results/profile/2026112[23]-*` with `default` or `fast` in the name.

| case | shifting | startup [s] | step [ms] | refinement / call [ms] | refinement in steps | RHS [ms] |
|---|---|---|---|---|---|---|
| Taylor-Green | default | 17.96 | 242.8 | 480.2 | 20% | 19.9 |
| Taylor-Green | fast | 4.53 | 206.2 | 135.3 | 7% | 19.7 |
| Pipe flow | default | 4.53 | 143.8 | 402.0 | 28% | 14.1 |
| Pipe flow | fast | 1.18 | 121.5 | 121.8 | 10% | 14.5 |

- Startup −75%, refinement call −70% (−72% TGV), step −15% (TGV) and −16% (pipe). The RHS
  is unchanged, as expected.
- In this session the pipe flow with the default takes 143.8 ms per step, not 201 ms as in
  the first small matrix. That run had a spread of 37% between its runs (RHS 20.3 vs.
  14.1 ms now), so its numbers are not reliable. The pipe flow tree-variable row of the
  first table should be read with this in mind.
- Residuals (Eq. 15, `|δr|/h` before limiting) after the last iteration of one replayed
  call:

  | case | setting | iterations | max | p99 | median | above tolerance | max total shift / h |
  |---|---|---|---|---|---|---|---|
  | TGV | default | 100 | 2.9e-3 | 1.3e-3 | 2.0e-4 | 14 | 0.40 |
  | TGV | default after 20 | 20 | 1.4e-2 | 3.4e-3 | 2.3e-4 | 330 | 0.23 |
  | TGV | fast | 20 | 1.2e-2 | 2.7e-3 | 4.0e-4 | 260 | 0.29 |
  | Pipe | default | 100 | 9.0e-3 | 1.6e-3 | 2.1e-4 | 42 | 0.35 |
  | Pipe | fast | 20 | 8.9e-3 | 2.9e-3 | 4.3e-4 | 322 | 0.29 |

  The fast setting leaves the median and the 99th percentile about twice as high as 100
  default iterations; in the pipe flow the maximum is the same. The server study found
  no measurable difference in the flow fields and the TGV error against the exact
  solution, so this residual difference does not show in the solution. Each row comes from
  its own startup, so the states differ slightly.
- What is left of a fast refinement call (TGV, 134 ms): shift 92 ms (20 iterations of
  ~4.1 ms, Eq. 35 and Eq. 37), "update systems before" + "after" 25 ms (two full updates of
  the systems, each as expensive as the update callback), merging 12 ms, target spacing
  3.5 ms. Pipe flow (122 ms): shift 82 ms, the two updates 16 ms, merging 12 ms.
- Tree leaves at size small: 78% of the fluid particles in TGV and 54–56% in the pipe flow
  are in leaves of the root size `R` (see `PLAN.md`, R1 item 2). The fraction in the
  finer leaves grows with the resolution (pipe: 23% at tiny, 45% at small).

## Phase 3, R2–R4 (2026-11-23, pcm016, size small, 8 threads)

Commits on `refinement/benchmark` (on 5b73bd7, not pushed):

| commit | item | change |
|---|---|---|
| 6b5500a | 3 | Skip the support check of pairs found with per-particle search radii |
| f9db5fa | — | Increase the cell capacity of tree neighborhood searches with refinement (bug fix, see below) |
| 7acd1aa | 8 | Update a shared neighborhood search of a fluid only once |
| 65d0799 | 5 | Average the EDAC pressure over the pairs in support with variable smoothing lengths |
| 21c205b | 4 | Compute the EDAC average pressure and beta in one neighbor loop |
| c4b66ab | 6 | Compute the particle spacing from the mass with sqrt and cbrt |

All with fast shifting (`shifting=fast`), tree with per-particle radii. Measured with
`ab.sh` (full runs, 3 runs, and `profile.jl` `sections=pairs,rhs` with 100 RHS
evaluations), results in `results/phase3/`. Compare with `compare_ab.py <labels>`.

### Isolated RHS per evaluation [ms]

Each state measured once after its commit (`r2_*`, `r3_1`). The isolated RHS timers are
stable between sessions (base: 19.2–19.8 ms in five measurements); the full runs were not
(see "Noise").

| state | TGV RHS | TGV interaction | TGV update shifting | TGV avg. p (+ beta) | Pipe RHS | Pipe interaction | Pipe avg. p (+ beta) | Pipe update nhs |
|---|---|---|---|---|---|---|---|---|
| base (5b73bd7) | 19.74 | 7.29 | 5.37 | 3.69 + 2.72 | 13.60 | 5.91 | 3.44 + 2.45 | 1.35 |
| + item 3 (6b5500a) | 17.71 | 5.49 | 5.30 | 3.58 + 2.68 | 12.28 | 4.52 | 3.46 + 2.46 | 1.36 |
| + item 8 (7acd1aa) | 17.74 | 5.45 | 5.31 | 3.65 + 2.70 | 11.62 | 4.56 | 3.55 + 2.49 | 0.56 |
| + item 5 (65d0799) | 16.58 | 5.35 | 5.33 | 2.58 + 2.65 | 10.43 | 4.54 | 2.43 + 2.47 | 0.53 |
| + item 4 (21c205b) | 14.61 | 5.68 | 5.33 | 2.94 | 8.18 | 4.47 | 2.73 | 0.54 |
| + item 6 (c4b66ab) | 12.80 | 5.61 | 3.53 | 2.99 | 8.27 | 4.51 | 2.75 | 0.55 |

RHS −35% (TGV) and −39% (pipe flow). Per item (TGV / pipe): item 3 −2.0 / −1.3 ms,
item 8 — / −0.7 ms (the pipe flow rebuilt the fluid tree three times per
`update_nhs!(semi)`: fluid, open boundary and wall share it), item 5 −1.2 / −1.2 ms,
item 4 −2.0 / −2.2 ms, item 6 −1.8 / — ms (the generic power `^(1 / ndims)` per pair in
the per-step shifting of TGV; the pipe flow updates its shifting in the callback).

### Step time

| case | base | final | change | from R1 default shifting |
|---|---|---|---|---|
| Taylor-Green | 208.6 ms (`r2_0_base`, spread 1%) | 131.6 ms (pinned, 2 sessions: 131.9 and 131.4, spread 1%) | −37% | 242.8 → 131.6 ms, −46% |
| Pipe flow | 115.2 ms (`r2_0_base`, spread 0%) | 75.4 ms (`final_r3`, spread 6%) | −35% | 143.8 → 75.4 ms, −48% |

The update callback is also halved (TGV 12.3 → 6.9 ms), since it runs the same loops.
The refinement call shrinks a little (TGV 137 → 120 ms) and is now 9–14% of a step.

Against the uniform runs at `min_spacing` (Phase 2): TGV 131.6 vs. 57.8 ms (was 4.2 times,
now 2.3 times slower with 0.66 of the particles), pipe flow 75.4 vs. 21.5 ms (was 9.4,
now 3.5 times slower with 0.92 of the particles).

### Noise

The full runs of the TGV were disturbed in several sessions (spread up to 51%, e.g.
`final_base`, `final_r3`, `r2_2`, `r2_3`), also with the threads pinned to fixed cores
(`taskset -c 48-55`: base 405 and 252 ms in two sessions, final 131.9 and 131.4 ms). The
other jobs on pcm016 (two 16-thread Julia processes, load ~35) are the likely cause; in
`r2_2` and `r2_3`, my own test runs on 2 threads added to it. Only runs with a spread of at
most 6% are used above. The isolated RHS timers (100 evaluations) were not affected by
this, except in `final_r3` (TGV interaction 10.3 ms instead of 5.6 ms).

### Bugs found

- **Tree capacity (fixed in f9db5fa).** `ensure_refinement_cell_capacity` only increased the
  cell capacity of grids. The tree keeps many leaves at the root size `R` (see R1), so the
  pipe flow stopped with `cell list is full` (`r2_1`, also `tree_uniform` in Phase 2). Now
  the tree gets the same capacity (four times a uniform cell at `min_spacing`, ~150 at
  size small). Test in `test/refinement/cell_capacity.jl`.
- **Capacity of searches that store walls finer than the coarse fluid (not fixed).** The
  vortex street with `spacing_ratio=4` stops in `initialize_neighborhood_search!` for the
  pair (fluid, cylinder): the cylinder is at `max_spacing / 4`, the search radius is the
  support of the coarse fluid, so a cell holds ~150 cylinder particles (capacity 100).
  `ensure_refinement_cell_capacity` only looks at fluids with refinement as neighbors.
  This also applies to the grid. A fix would compute the capacity from the spacing of any
  neighbor system and the cell size.

### Correctness

- `check_variable_radii.jl` on c4b66ab: neighbors equal in all four cases, largest
  relative difference grid vs. tree 3.7e-13 (Phase 1: 2.4e-13).
- Refinement tests 2019/2019 (2010 before, plus the new tests), general tests 2773/2773.
- New tests: tree capacity, the shared fluid NHS is updated once and finds the moved fluid,
  the average pressure only averages pairs in support, average pressure and beta in one
  loop equal the separate loops bitwise.
- Results change with item 5 (the average pressure with refinement averages over the
  pairs in support instead of all pairs within `R`) and at rounding level with item 6.
  Items 3, 4 and 8 don't change results.

### R3: the remaining per-pair cost and the tree

- Item 6, the per-pair cost with variable h: the profile showed `particle_spacing`
  (`(m / ρ₀)^(1 / ndims)` per pair in the per-step shifting) at 9% of the neighbor-loop
  samples, now `sqrt`/`cbrt` (c4b66ab). The other part is the two kernel gradients per pair
  of Eq. 8 (`pair_kernel_grads`), which the formulation needs. With continuous h from Eq. 35,
  `h_a = h_b` almost never holds, so the shortcut for equal h does not help.
- Item 7, the tree: unchanged, see R1 item 2. With `max_spacing / min_spacing = 2`, most
  leaves stay at the root size (TGV 78%, pipe 56%, vortex street 100% at size small),
  so the tree checks the same points as a grid with `R`. This is the main remaining gap to
  the uniform runs and has to be solved in PointNeighbors (the split criterion of
  `can_split`), not in TrixiParticles.

### R4: a case where the refinement should pay off

Vortex street (`case=vortex_street` in `setups.jl`), size small (max spacing 1/70),
spacing ratio 2, fast shifting, c4b66ab:

| run | fluid particles | step [ms] | RHS [ms] | refinement in steps |
|---|---|---|---|---|
| refined (tree, per-particle radii) | 10,556 | 80.1 | 9.39 | 12% |
| uniform at `min_spacing` (grid) | 39,038 | 80.7 | 10.98 | — |
| uniform at `max_spacing` (grid) | 9,756 | 23.9 | 3.22 | — |

- 89% of the particles are at `max_spacing`, refined / uniform at `min_spacing` = 0.27
  (the wake is not refined yet in the first 120 steps).
- The refined run needs as long as the uniform fine run, with 3.7 times fewer particles:
  break-even. One RHS costs 3.2 times more per particle (9.39 ms / 10.6k vs.
  10.98 ms / 39k). All tree leaves are at the root size here.
- With `spacing_ratio=4`, the uniform fine run has 156k particles and takes 314 ms per step,
  but the refined run stops (wall capacity bug above). This is the case where the
  refinement should clearly pay off.
