# Startup with background particles in Haftu et al.

2026-11-17. From reading the reference code (`asph_motion`), not from running it.

The paper presents a method without background particles. That holds for the simulation
run. The initial graded distribution is still built with background particles, in a
startup step the paper does not describe. The startup runs once, before the first time
step; during the simulation, only the regular refinement calls run. Our code builds it
without background particles, also once before the first time step.

## Paper vs. code

- Paper (Sec. "Removal of background particles"): the spacing and reference mass of
  Muta et al. move from background particles onto the fluid particles.
- Code, run: only `AdaptiveResolutionVacondioNoBG`. `--use-bg` "retains the use of
  background particles while the simulation is running".
- Code, startup: `initialize_fluid` (adapt.py:1325) always uses them ("We are still using
  AdaptiveResolutionVacondio to initialize the particles").
- The paper's comparison with and without background particles (`FPCNoBG`) starts both
  runs from the same background startup.

## Reference startup

$n_\text{iters} = \operatorname{round}\big(\ln(\Delta s_{\max}/\Delta s_{\min}) / \ln C_r + 0.5\big)$,
63 for the cylinder case ($\Delta s_{\max}/\Delta s_{\min} = 125$, $C_r = 1.08$).
Everything starts uniform at $\Delta s_{\max}$, except the solid at $\Delta s_{\min}$.

1. Background field, $3 n_\text{iters}$ rounds: background particles near the solid get
   $\Delta s_{\min}$, the rest are graded by Alg. 1, then split/merged and shifted.
2. Fluid, $3 n_\text{iters}$ rounds: target spacing from the nearby background particles,
   split/merge, 3 shift iterations. Only boundary: an outer box; the solid is not a source.
3. Remove fluid overlapping the solid, then $5 n_\text{iters}$ shift iterations with the
   solid as a source.
4. Discard the background particles, set velocity and pressure, start the run.

## Why a startup at all

The startup and the runtime refinement do different jobs. The startup does the one-time
transition from the uniform coarse distribution to the graded one, before there is a flow
to disturb. The runtime refinement keeps the distribution graded while the fluid flows
through the band: particles approaching the body are split, particles leaving it are
merged, in every call and for the whole run (with a solution-based criterion or a moving
body, the band itself moves too).

Alg. 1 updates the spacing from the neighbors' spacing of the previous call and spreads
it by one neighborhood per call. A settled field is kept by the runtime update. Without a
startup, the band alone needs at least 63 calls to reach full width, about 315 steps with
one call every 5 steps, with the flow near the body at coarse resolution and most splits
happening during the run. The reference uses $3 n_\text{iters}$ rounds; the factor 3 is
not explained and looks like a safety margin (see "Why the factor 3" below).

## Why the factor 3

"Settled" means: the target spacing no longer changes between calls, and no particle is
split or merged anymore. Reasons why this can take more than $n_\text{iters}$ calls (not
measured):
- Next to the refined region, the neighbor spacings differ by more than $C_r^3$, so Alg. 1
  takes the geometric mean instead of $C_r \cdot s_\text{min}$. The clean grading only
  forms after this averaging has smoothed the jump.
- The spacing is computed over the compact support of the current particles. Splitting
  shrinks the support, so a field computed with coarse neighborhoods is not yet the fixed
  point for the finer ones.
- The region fixed by the criterion is also defined via the compact support (fluid
  particles near boundaries), so it changes as the particles refine.

Measurable in our startup: per round, the number of particles whose target spacing
changes, and the number of splits and merges.

## Why background particles

Not stated anywhere. Likely:
- Legacy: the startup is the initializer of Muta et al., kept unchanged.
- In this code, only the background sees the solid during the startup (the initial fluid
  covers the cylinder and has only the box as a boundary).
- The spacing field settles before any fluid particle is split.

## Ours

`refinement_startup!` repeats the full runtime refinement on the fluid ($3 n_\text{levels}$
calls). Our fluid excludes walls and solids from the start, and the refinement criterion
reads the boundaries directly, so the geometry argument does not apply. Differences:
field and particles change together, Eq. 35 instead of Yang-Kong, up to 100 shift
iterations with Eq. 37 instead of 3 without correction, no final shifting.

Implications of computing the spacing on the fluid (not measured): the fluid already
splits while the field is still being averaged, so some splits are undone by later
merges. Without a flow this costs time, not accuracy. In return, the startup ends in a
steady state of the runtime update, while the reference switches from the background
field to Alg. 1 on the fluid at the start of the run, which can still split or merge
particles with the flow present.

## Proposal

1. Mirror the reference startup without background particles (same rounds and shift
   iterations, spacing from the fluid).
2. Compare with our current startup: cost, smallest pair distance / $\Delta s$,
   deviation of $\sum_b V_b W_{ab}$ from 1.
3. Add background particles only if 1 is clearly worse.

Decision (2026-11-19): we keep our startup (refinement rounds on the fluid before the
first time step). No good reason was found why the reference needs background particles
for the startup, so the proposal above is not carried out.
