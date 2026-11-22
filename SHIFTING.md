# Shifting after particle refinement

Part of the refinement benchmark (see `PLAN.md`). Shifting is the largest cost of
refinement, so it gets its own investigation.

Goal: understand why shifting takes most of the refinement time and almost never
converges, decide between the convergence-based scheme and fixed iterations as in the
reference, and remove the cheap bottlenecks.

## Findings so far (2026-11-17)

Smoke test, Taylor-Green with refinement (`particle_spacing=0.05`, ~2k particles,
8 threads, grid NHS, first call includes compilation):
- Shifting is ~90% of the startup (45 calls) and of each runtime call.
- ~98 iterations per call on average, with `max_iterations=100`: the tolerance is
  almost never reached.
- "apply shift" 16.4 ms and 805 KiB per iteration, "compute shift" 5.9 ms and 1 KiB.
  The rest of the shift section (Eq. 35 twice, Eq. 37) 167 ms and 51 MiB per call.

Our `ShiftingHaftu`: θ = 0.5, at most 0.05 h per iteration, stops when the largest
`|δr_Eq15| / h` is below 2e-3 or after 100 iterations. All systems are sources. The
self-interaction NHS is updated in every iteration. Eq. 35 before and after shifting,
Eq. 37 at the end with the accumulated shift.

Reference code (`asph_motion/code`). "The reference" means the code that was executed
for the paper results: the cases of `automate.py`, which all inherit
`fpc_auto.WindTunnel` (`moving_square.py` too). Traced by reading, not by running.

- `SmoothPositionShift` (adapt.py:114): full Eq. 15 (θ = 1), at most
  `0.25 * 0.025 * h = 0.00625 h` per iteration, `W(Δp)` with `Δp = get_deltap() * h_ij`,
  `V_j = m_j / ρ0`.
- **The runtime smoother does run.** `AdaptiveResolution.run` only builds it if
  `_orig_nnps` is set (adapt.py:1044), and `WindTunnel.create_tools`
  (fpc_auto.py:597, "Awful Hack!") sets `_orig_nnps` to the solver NNPS and builds the
  smoother with `iters=3`. (Corrects an earlier note here that said it never runs; I
  had missed `create_tools`.)
- Smoother per refinement call (every 5 steps, `freq=5`): one NNPS update
  (`smoother.update()`), `InitializeShift` (x0 = x), 3 iterations of
  `SmoothPositionShift` without NNPS updates, then `CorrectProperties` (p and u, not ρ,
  with `x - x0`, gradients at the shifted positions with `V_j = m_j / ρ_j`). Sources:
  `shift_sources` = fluid, inlet, outlet, solid, wall (not only the fluid). No h update
  after the smoother; h comes from `OptimizeH` in the next RHS.
- **Shifting in every RHS.** `AdaptiveEDACScheme` always has `ShiftForceLind`
  (edac.py:1021, all arrays as sources) and uses TVF (`EDACTVFStep`:
  `x = x0 + dt (u + dt a_hat)`, A-tensor terms in momentum and EDAC). The shift per
  step is `dt² a_hat` = Eq. 15 with `0.5 h_min² (c0 / (c0 + umax))²` instead of
  `0.5 h_i²` (fixed `dt = CFL h_min / (c0 + umax)`, factor `0.5 (c0 / CFL)²`), capped
  at 0.00625 h_i. So coarse particles get a much weaker shift than fine ones. The paper
  states a limit of 0.25 h; the code uses 0.00625 h.
- h at runtime: `update_h='optimize'` (`OptimizeH`, edac.py:1420) is Eq. 35 in every
  RHS evaluation with all arrays as sources (solids included). Ours: after refinement
  only, same system only.
- The paper (Alg. "Adaptive particle refinement procedure", paper.tex:878) shifts
  3 times, corrects (Eq. 37), then updates h (Eq. 35). The code matches up to the h
  update, which happens in the next RHS.
- Startup: see "Reference startup" below.

Our examples also shift every step (`ConsistentShiftingSun2019` in Taylor-Green,
`ParticleShiftingTechnique` in pipe flow), but with a different formula than the
reference.

## Decisions (2026-11-17)

1. Keep `ShiftingHaftu` as the working baseline. Mirror the executed reference shifting
   (runtime smoother) and check whether it works for us. Then combine the best of both
   and optimize.
2. ~~The reference variant also covers the reference startup procedure.~~ Revised
   2026-11-19: we keep our startup, the reference variant mirrors only the runtime
   smoother (see `BACKGROUND_STARTUP.md`).
3. The shifting timers go into the timer commit. New code only after that commit.

Open:
- Whether the mirror also includes the per-step Lind shift with TVF (`ShiftForceLind`),
  or keeps our per-step shifting techniques. Without it, the 3-iteration smoother has
  to do work that the reference spreads over every step.
- Startup with background particles: decided 2026-11-19, we keep our startup.

## Reference startup

`UpdateBackground` in the case file (`_create_bg`, fpc_auto.py:449), then
`initialize_fluid` (adapt.py:1316). `n_iters = round(ln(ds_max / ds_min) / ln(cr) + 0.5)`
is the number of resolution levels (18 for `ds_max / ds_min = 20`, `cr = 2^(1/4)`).
Fluid, walls, inlet and outlet start uniform at `ds_max`, the solid at `ds_min`.

1. Background particles (`set_initial_bg`): a separate uniform particle set at
   `ds_max` over the fluid bounding box, outer ring fixed. `3 n_iters` rounds of:
   `MarkBoundary` (background particles near solids get `ds_min`), `UpdateSpacing`
   (each takes `cr` × the smallest neighbor spacing, or the geometric mean if the
   neighbor spacings differ by more than `cr³`), split/merge of the background
   particles by their spacing, and 5 iterations of Yang-Kong h + a weak shift. Result:
   a graded spacing field `ds` carried by the background particles.
2. Fluid rounds: an outer `box` of `ds_max` particles around the fluid acts as a
   boundary. `3 n_iters` rounds of:
   - `set_mref`: each fluid particle takes the smallest `ds` of the nearby background
     particles, so `m_max = 1.05 ρ ds²`, `m_min = 0.5 ρ ds²`.
   - split (Vacondio, 7 particles) and iterative merging (up to 3 iterations), not near
     the box. No smoother here.
   - one NNPS update, then 3 iterations of [Yang-Kong h update (`Nr = 28`) +
     `SmoothPositionShift`], sources fluid + box.
3. Remove fluid particles that overlap solids, then `n_iters` × [NNPS update +
   5 iterations of `SmoothPositionShift`] with fluid, box and solids as sources, no h
   update (90 iterations, at most ≈ 0.56 h in total).
4. Switch to `AdaptiveResolutionVacondioNoBG` for the run (no background particles,
   spacing from the fluid itself). Velocity and pressure are set from potential flow
   after the startup, so nothing is corrected during the startup.

Ours (`refinement_startup!`): `n_startup_rounds` full `refinement!` calls, each with
target spacing on the fluid itself (as in the reference runtime), merging, splitting,
`ShiftingHaftu` with up to 100 iterations and Eq. 37, and Eq. 35 instead of Yang-Kong.

## Step 1: Timers and allocations

First run with the new timers (Taylor-Green, `particle_spacing=0.05`, 8 threads,
startup incl. compilation): per iteration "apply" 4.8 ms and 807 KiB (the trivial
threaded loop allocates, likely a boxed capture), "update self nhs" 6.2 ms,
"compute shift" 4.7 ms, "max shift" 11 μs. "correct properties" 133 ms and 51 MiB per
call. Smoothing lengths ~5 ms per call.

Timers (upstream style, in the timer commit):
- `apply_shift!`: "apply" (the threaded loop), "update self nhs", "max shift"
  (`maximum(relative_shift)`).
- `correct_properties!`: "correct properties" at the call site.
- `update_smoothing_lengths!`: "smoothing lengths before" and "smoothing lengths after"
  at the two call sites in `apply_refinement_shifting!`.

Allocations: `Profile.Allocs` (`sample_rate=1`) on one shift call from a snapshot, to
find the 805 KiB per iteration and the 51 MiB per call. These are bugs regardless of the
scheme, so fix them first and measure before/after.

## Step 2: Does the convergence check behave as expected?

Diagnostics in the scripts, not in `src/`: run the loop of `apply_refinement_shifting!`
with `compute_shift!`/`apply_shift!` on a snapshot and record per iteration:
- `r_k = max |δr_Eq15| / h` (the current criterion), median and 99th percentile,
  number of particles above the tolerance,
- the largest applied shift / h and, at the end, the largest total shift / h,
- for the particle with the largest shift: distance to the resolution interface, to
  walls and open boundaries, whether it was just split or merged.

Cases:
- a. Perturbed uniform lattice, one resolution, periodic, no refinement. This must
  converge geometrically; if not, the implementation is wrong.
- b. Graded distribution after the startup, shifted repeatedly without time stepping.
- c. The state of a runtime call (Taylor-Green and pipe flow after some steps).

Hypotheses:
- H1 slow convergence: with θ = 0.5 and the 0.05 h limit, the decay per iteration is
  too slow for 2e-3 within 100 iterations (geometric decay of `r_k`).
- H2 floor: `r_k` stays at a level above the tolerance, because Eq. 15 is not zero for
  the graded distribution (resolution interface, mass-based `V_b`, `h_ab`) or near
  walls (all systems are sources).
- H3 oscillation: `r_k` is not monotonic (pairs that overshoot, limit cycles).
- H4 outliers: the maximum comes from a few particles (e.g. just split, `ε h` apart),
  while the median converged. Then the max norm is too strict.

The total shift matters on its own: up to 100 × 0.05 h = 5 h per call, while Eq. 37 is a
first-order Taylor correction that is only valid for small shifts. The reference moves a
particle by at most 3 × 0.00625 h ≈ 0.019 h per call.

## Step 3: Reference variant

A second shifting technique (e.g. `ShiftingHaftuReference`) that follows the
reference as closely as possible. Every deviation is listed below with the reason, and
a deviation is only allowed if the reference does not work in our setup.

| Reference | Variant | Deviation and reason |
|---|---|---|
| 3 fixed iterations, θ = 1 | same | |
| at most 0.00625 h per iteration | same | |
| Eq. 15 with `W(Δp)`, `Δp = get_deltap() h_ij` | `kernel_inflection_point`, same values for the quintic and cubic spline | |
| sources: fluid, inlet, outlet, solid, wall (`shift_sources`) | all systems | |
| `V_j = m_j / ρ0` in Eq. 15, `m_j / ρ_j` in Eq. 37 | same | |
| one NHS update before, none between the iterations and before Eq. 37 | same | |
| no Eq. 35 before shifting | same (ours updates h before shifting) | |
| Eq. 37 for p and v with `x - x0` | p and v with the accumulated shift | `x - x0` is wrong for particles that crossed a periodic boundary |
| no density correction (summation density) | none with `SummationDensity`; with `ContinuityDensity` to be decided | the reference has no continuity density |
| Eq. 35 in every RHS (`OptimizeH`) | to be decided | ours has no per-RHS h update |
| Lind shift via TVF in every RHS | to be decided (see Open) | |
| refinement every 5 steps | same in the comparison runs | |
| startup: background particles, Yang-Kong h, 3 + 5 shift iterations | see "Reference startup" | |

## Step 4: Compare the variants

Variants:
- A. Current `ShiftingHaftu` (tolerance 2e-3, at most 100 iterations).
- B. `ShiftingHaftu` with 3 fixed iterations (our θ and limit), to separate the
  iteration count from the parameters.
- C. Reference variant (step 3).
- D. `shifting_technique=nothing` (only the per-step shifting regularizes).

Metrics:
- Cost: time per refinement call and of the startup, iterations per call.
- Particle distribution after shifting: `r_k` after the last iteration, smallest pair
  distance / Δs, deviation of `Σ_b V_b W_ab` from 1.
- Solution: Taylor-Green kinetic energy decay and velocity error against the analytical
  solution, pressure noise; pipe flow velocity profile against Poiseuille; stability
  until the end time; total shift per call.

Cases: Taylor-Green and pipe flow, small size first, then the Phase 2 sizes.

## Step 5: Performance fixes

After the scheme is chosen:
- the allocations from step 1,
- the self NHS update per iteration (the reference does not update),
- fusing `compute_shift!` and `apply_shift!` and the serial `maximum`,
- GPU: `maximum` on the device, no scalar indexing.

## Results

`results/shifting/`: residual histories (CSV and plots), timing per variant, the
comparison table, and a short decision note for the thesis.
