# Interleaved A/B: 20261123_base_vs_final

- 2026-11-23T14:23:09, full measurement, size small, 8 threads, CPUs [56, 57, 58, 59, 60, 61, 62, 63], PointNeighbors 7aeb2f0
- Labels: `base` = 5b73bd7, `final` = c4b66ab, `base_again` = 5b73bd7
- 5 blocks planned, startup 444 s, total 18.9 min
- Other load on our cores and their siblings: median 0.01, max 0.06 cores. Whole machine: 39 to 41 cores busy, load average 37 to 44. Waiting workers used at most 0.013 cores together.

## taylor_green

step time [ms], every block:

| block | base | final | base_again | noisy? |
|---|---|---|---|---|
| 1 | 205.91 | 134.41 | 204.69 |  |
| 2 | 204.37 | 132.58 | 203.71 |  |
| 3 | 204.31 | 131.77 | 203.95 |  |
| 4 | 204.15 | 131.91 | 204.37 |  |
| 5 | 204.19 | 133.03 | 204.11 |  |
| **minimum** | 204.15 | 131.77 | 203.71 | |
| **median** | 204.31 | 132.58 | 204.11 | |

isolated RHS, median of the calls [ms], every block:

| block | base | final | base_again | noisy? |
|---|---|---|---|---|
| 1 | 19.53 | 12.51 | 19.54 |  |
| 2 | 19.40 | 12.32 | 19.41 |  |
| 3 | 19.38 | 12.29 | 19.41 |  |
| 4 | 19.35 | 12.44 | 19.47 |  |
| 5 | 19.39 | 12.33 | 19.37 |  |
| **minimum** | 19.35 | 12.29 | 19.37 | |
| **median** | 19.39 | 12.33 | 19.41 | |

Work and time per label, median over the blocks:

| label | fluid particles after startup | at the end | steps | RHS/step | rejected | mean dt | startup [s] | step [ms] | RHS [ms] | RHS per particle [µs] | refinement call [ms] | wall time per simulated time [s] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| base | 10746 | 10789 | 100 | 9.12 | 0 | 3.519e-04 | 4.45 | 204.31 | 19.56 | 1.817 | 131.9 | 580.5 |
| final | 10746 | 10754 | 100 | 9.12 | 0 | 3.519e-04 | 4.43 | 132.58 | 12.37 | 1.151 | 121.7 | 376.7 |
| base_again | 10746 | 10789 | 100 | 9.12 | 0 | 3.519e-04 | 4.51 | 204.11 | 19.53 | 1.814 | 132.7 | 580.0 |

Clean blocks: 5 of 5 (0 extra).

Ratio to `base` (median of the ratios per block, 95% bootstrap interval, ratio of the minima):

| label | metric | median | interval | ratio of minima | verdict |
|---|---|---|---|---|---|
| final | step time [ms] | -35.1% | -35.5% to -34.7% | -35.5% | faster |
| final | RHS in the steps [ms] | -36.7% | -37.0% to -36.3% | -37.0% | faster |
| final | isolated RHS, median of the calls [ms] | -36.4% | -36.6% to -35.7% | -36.5% | faster |
| final | isolated RHS, minimum of the calls [ms] | -36.6% | -37.0% to -36.1% | -36.8% | faster |
| final | RHS in the steps per fluid particle [µs] | -36.6% | -36.9% to -36.2% | -36.9% | faster |
| final | refinement call [ms] | -7.8% | -9.0% to -7.0% | -8.3% | faster |
| final | wall time per unit of simulated time [s] | -35.1% | -35.5% to -34.7% | -35.5% | faster |
| base_again | step time [ms] | -0.2% | -0.6% to +0.1% | -0.2% | A/A |
| base_again | RHS in the steps [ms] | -0.3% | -0.5% to -0.0% | -0.3% | A/A |
| base_again | isolated RHS, median of the calls [ms] | +0.1% | -0.1% to +0.6% | +0.1% | A/A |
| base_again | isolated RHS, minimum of the calls [ms] | +0.1% | -0.0% to +0.8% | +0.1% | A/A |
| base_again | RHS in the steps per fluid particle [µs] | -0.3% | -0.5% to -0.0% | -0.3% | A/A |
| base_again | refinement call [ms] | +0.9% | -2.0% to +1.9% | +1.1% | A/A |
| base_again | wall time per unit of simulated time [s] | -0.2% | -0.6% to +0.1% | -0.2% | A/A |

A/A noise (the largest deviation of the A/A interval from 1): step time 0.6%, RHS in the steps 0.5%, isolated RHS, median of the calls 0.6%, isolated RHS, minimum of the calls 0.8%, RHS in the steps per fluid particle 0.5%, refinement call 2.0%, wall time per unit of simulated time 0.6%.

Isolated RHS by section, median over the blocks [ms]:

| label | interaction | update shifting | avg. pressure | beta | avg. pressure + beta | update nhs |
|---|---|---|---|---|---|---|
| base | 7.170 | 5.385 | 3.612 | 2.679 | – | 0.586 |
| final | 5.415 | 3.518 | – | – | 2.816 | 0.590 |
| base_again | 7.234 | 5.390 | 3.592 | 2.686 | – | 0.584 |

**Check: the labels don't do exactly the same work:**

- final and base differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 912, 0, 10746, 10754, '0.03519134600019317') vs. (100, 912, 0, 10746, 10789, '0.035192479120508345')
- final and base differ in the particles of the isolated RHS state: {10740} vs. {10739}

For labels that differ, use the wall time per unit of simulated time instead of the step time. If the particle counts differ a lot, divide the RHS times by them.


## pipe_flow

step time [ms], every block:

| block | base | final | base_again | noisy? |
|---|---|---|---|---|
| 1 | 112.98 | 73.56 | 113.30 |  |
| 2 | 112.17 | 73.08 | 112.82 |  |
| 3 | 112.20 | 72.94 | 112.38 |  |
| 4 | 112.12 | 72.82 | 112.45 |  |
| 5 | 112.41 | 72.96 | 112.59 |  |
| **minimum** | 112.12 | 72.82 | 112.38 | |
| **median** | 112.20 | 72.96 | 112.59 | |

isolated RHS, median of the calls [ms], every block:

| block | base | final | base_again | noisy? |
|---|---|---|---|---|
| 1 | 13.71 | 8.34 | 13.77 |  |
| 2 | 13.63 | 8.24 | 13.70 |  |
| 3 | 13.62 | 8.27 | 13.62 |  |
| 4 | 13.62 | 8.23 | 13.64 |  |
| 5 | 13.62 | 8.28 | 13.65 |  |
| **minimum** | 13.62 | 8.23 | 13.62 | |
| **median** | 13.62 | 8.27 | 13.65 | |

Work and time per label, median over the blocks:

| label | fluid particles after startup | at the end | steps | RHS/step | rejected | mean dt | startup [s] | step [ms] | RHS [ms] | RHS per particle [µs] | refinement call [ms] | wall time per simulated time [s] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| base | 10551 | 9755 | 100 | 6.12 | 2 | 7.439e-04 | 1.15 | 112.20 | 13.64 | 1.344 | 116.2 | 150.8 |
| final | 10551 | 9780 | 100 | 6.27 | 5 | 7.361e-04 | 1.09 | 72.96 | 8.46 | 0.832 | 102.5 | 99.1 |
| base_again | 10551 | 9755 | 100 | 6.12 | 2 | 7.439e-04 | 1.14 | 112.59 | 13.71 | 1.350 | 115.9 | 151.4 |

Clean blocks: 5 of 5 (0 extra).

Ratio to `base` (median of the ratios per block, 95% bootstrap interval, ratio of the minima):

| label | metric | median | interval | ratio of minima | verdict |
|---|---|---|---|---|---|
| final | step time [ms] | -35.0% | -35.1% to -34.9% | -35.0% | faster |
| final | RHS in the steps [ms] | -38.1% | -38.2% to -37.8% | -38.1% | faster |
| final | isolated RHS, median of the calls [ms] | -39.3% | -39.6% to -39.2% | -39.5% | faster |
| final | isolated RHS, minimum of the calls [ms] | -39.7% | -40.0% to -39.3% | -39.8% | faster |
| final | RHS in the steps per fluid particle [µs] | -38.2% | -38.2% to -37.9% | -38.2% | faster |
| final | refinement call [ms] | -12.2% | -12.6% to -10.4% | -12.5% | faster |
| final | wall time per unit of simulated time [s] | -34.3% | -34.4% to -34.2% | -34.4% | faster |
| base_again | step time [ms] | +0.3% | +0.2% to +0.6% | +0.2% | A/A |
| base_again | RHS in the steps [ms] | +0.3% | -0.0% to +0.7% | +0.3% | A/A |
| base_again | isolated RHS, median of the calls [ms] | +0.2% | +0.0% to +0.6% | +0.1% | A/A |
| base_again | isolated RHS, minimum of the calls [ms] | +0.2% | -0.4% to +1.1% | +0.1% | A/A |
| base_again | RHS in the steps per fluid particle [µs] | +0.3% | -0.0% to +0.7% | +0.3% | A/A |
| base_again | refinement call [ms] | -0.5% | -0.7% to +1.9% | -0.4% | A/A |
| base_again | wall time per unit of simulated time [s] | +0.3% | +0.2% to +0.6% | +0.2% | A/A |

A/A noise (the largest deviation of the A/A interval from 1): step time 0.6%, RHS in the steps 0.7%, isolated RHS, median of the calls 0.6%, isolated RHS, minimum of the calls 1.1%, RHS in the steps per fluid particle 0.7%, refinement call 1.9%, wall time per unit of simulated time 0.6%.

Isolated RHS by section, median over the blocks [ms]:

| label | interaction | avg. pressure | beta | avg. pressure + beta | update nhs |
|---|---|---|---|---|---|
| base | 6.010 | 3.388 | 2.497 | – | 1.359 |
| final | 4.540 | – | – | 2.772 | 0.535 |
| base_again | 5.963 | 3.450 | 2.498 | – | 1.355 |

**Check: the labels don't do exactly the same work:**

- final and base differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 627, 5, 10551, 9780, '0.07361347991840166') vs. (100, 612, 2, 10551, 9755, '0.07438794619466285')

For labels that differ, use the wall time per unit of simulated time instead of the step time. If the particle counts differ a lot, divide the RHS times by them.


