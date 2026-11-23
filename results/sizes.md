# Sizes of the Phase 2 cases

Fluid particles after the refinement startup (`run_full.jl steps=0`, tree NHS with
variable radii, `SerialUpdate()`, 8 threads, pcm016, 2026-11-22). The spacings are in
`SPACINGS` in `setups.jl`.

| case | size | max spacing | initial | after startup | ratio |
|---|---|---|---|---|---|
| Taylor-Green | tiny | 1/20 | 400 | 1,531 | 3.83 |
| Taylor-Green | small | 1/64 | 4,096 | 10,775 | 2.63 |
| Taylor-Green | (1/88) | 1/88 | 7,744 | 17,481 | 2.26 |
| Taylor-Green | medium | 1/138 | 19,044 | 37,112 | 1.95 |
| Taylor-Green | large | 1/288 | 82,944 | not measured (~160k) | |
| Pipe flow | tiny | 0.4/20 | 1,000 | 4,132 | 4.13 |
| Pipe flow | small | 0.4/34 | 2,890 | 10,578 | 3.66 |
| Pipe flow | (0.4/46) | 0.4/46 | 5,290 | 18,140 | 3.43 |
| Pipe flow | medium | 0.4/70 | 12,250 | 39,572 | 3.23 |
| Pipe flow | large | 0.4/144 | 51,840 | not measured (~160k) | |

The ratio decreases with the resolution, since the refinement grades over a fixed number
of particle spacings (Taylor-Green: `spacing_ratio=1.05`, about 14 neighborhoods from
`min_spacing` to `max_spacing`).

The pipe flow with refinement has almost as many fluid particles as the uniform baseline
at `min_spacing` (4 times the initial particles): more at tiny (4,132 vs. 4,000), 81% at
medium (39,572 vs. 49,000). The spatial criterion refines near the walls, and the pipe is
only 0.4 high, so most of the pipe is at or near the minimum spacing. The refinement saves
little in this case. To be kept in mind when the pipe flow numbers are interpreted.

With the tree NHS, the grid NHS and the uniform tree, the counts after the startup differ
by a few particles (tiny Taylor-Green: 1,531, 1,521, 1,532), from the different summation
order.
