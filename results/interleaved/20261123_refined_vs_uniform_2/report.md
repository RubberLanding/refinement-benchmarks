# Interleaved A/B: 20261123_refined_vs_uniform_2

- 2026-11-23T15:42:16, full measurement, size small, 8 threads, CPUs [16, 17, 18, 19, 20, 21, 22, 23], PointNeighbors 7aeb2f0
- Labels: `uniform_fine` = c4b66ab uniform at min. spacing, `refined_base` = 5b73bd7, `refined_final` = c4b66ab, `uniform_coarse` = c4b66ab uniform at max. spacing, `uniform_fine_again` = c4b66ab uniform at min. spacing
- 5 blocks planned, startup 145 s, total 11.6 min
- Other load on our cores and their siblings: median 0.01, max 0.15 cores. Whole machine: 24 to 25 cores busy, load average 24 to 26. Waiting workers used at most 0.175 cores together.

## taylor_green

step time [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 54.17 | 197.68 | 131.60 | 14.48 | 54.40 |  |
| 2 | 56.36 | 197.88 | 132.77 | 14.45 | 54.66 |  |
| 3 | 54.44 | 198.44 | 132.53 | 14.45 | 54.79 |  |
| 4 | 54.44 | 197.60 | 132.01 | 14.46 | 54.62 |  |
| 5 | 54.42 | 197.25 | 132.33 | 14.43 | 54.39 |  |
| **minimum** | 54.17 | 197.25 | 131.60 | 14.43 | 54.39 | |
| **median** | 54.44 | 197.68 | 132.33 | 14.45 | 54.62 | |

isolated RHS, median of the calls [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 5.65 | 18.84 | 12.24 | 1.36 | 5.66 |  |
| 2 | 5.64 | 18.92 | 12.22 | 1.36 | 5.65 |  |
| 3 | 5.64 | 18.91 | 12.23 | 1.36 | 5.66 |  |
| 4 | 5.65 | 18.89 | 12.25 | 1.36 | 5.67 |  |
| 5 | 5.64 | 18.81 | 12.19 | 1.36 | 5.66 |  |
| **minimum** | 5.64 | 18.81 | 12.19 | 1.36 | 5.65 | |
| **median** | 5.64 | 18.89 | 12.23 | 1.36 | 5.66 | |

Work and time per label, median over the blocks:

| label | fluid particles after startup | at the end | steps | RHS/step | rejected | mean dt | startup [s] | step [ms] | RHS [ms] | RHS per particle [µs] | refinement call [ms] | wall time per simulated time [s] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform_fine | 16384 | 16384 | 100 | 9.03 | 0 | 1.776e-04 | 0.00 | 54.44 | 5.57 | 0.340 | 0.0 | 306.6 |
| refined_base | 10746 | 10789 | 100 | 9.12 | 0 | 3.519e-04 | 4.31 | 197.68 | 18.92 | 1.757 | 127.9 | 561.7 |
| refined_final | 10746 | 10754 | 100 | 9.12 | 0 | 3.519e-04 | 4.35 | 132.33 | 12.38 | 1.152 | 119.4 | 376.0 |
| uniform_coarse | 4096 | 4096 | 100 | 9.03 | 0 | 3.551e-04 | 0.00 | 14.45 | 1.47 | 0.359 | 0.0 | 40.7 |
| uniform_fine_again | 16384 | 16384 | 100 | 9.03 | 0 | 1.776e-04 | 0.00 | 54.62 | 5.59 | 0.341 | 0.0 | 307.6 |

Clean blocks: 5 of 5 (0 extra).

Ratio to `uniform_fine` (median of the ratios per block, 95% bootstrap interval, ratio of the minima):

| label | metric | median | interval | ratio of minima | verdict |
|---|---|---|---|---|---|
| refined_base | step time [ms] | +263.0% | +251.1% to +264.9% | +264.1% | slower |
| refined_base | RHS in the steps [ms] | +239.6% | +232.3% to +242.0% | +240.7% | slower |
| refined_base | isolated RHS, median of the calls [ms] | +234.3% | +233.2% to +235.3% | +233.4% | slower |
| refined_base | isolated RHS, minimum of the calls [ms] | +236.6% | +235.3% to +238.0% | +236.5% | slower |
| refined_base | RHS in the steps per fluid particle [µs] | +416.7% | +405.6% to +420.4% | +418.4% | slower |
| refined_base | wall time per unit of simulated time [s] | +83.1% | +77.1% to +84.1% | +83.7% | slower |
| refined_final | step time [ms] | +142.9% | +135.6% to +143.5% | +142.9% | slower |
| refined_final | RHS in the steps [ms] | +121.8% | +117.7% to +123.0% | +121.8% | slower |
| refined_final | isolated RHS, median of the calls [ms] | +116.5% | +116.0% to +116.8% | +116.1% | slower |
| refined_final | isolated RHS, minimum of the calls [ms] | +118.2% | +117.4% to +118.6% | +117.9% | slower |
| refined_final | RHS in the steps per fluid particle [µs] | +238.0% | +231.8% to +239.9% | +238.0% | slower |
| refined_final | wall time per unit of simulated time [s] | +22.6% | +18.9% to +22.8% | +22.6% | slower |
| uniform_coarse | step time [ms] | -73.5% | -74.4% to -73.3% | -73.4% | faster |
| uniform_coarse | RHS in the steps [ms] | -73.6% | -74.2% to -73.4% | -73.5% | faster |
| uniform_coarse | isolated RHS, median of the calls [ms] | -75.9% | -75.9% to -75.9% | -75.9% | faster |
| uniform_coarse | isolated RHS, minimum of the calls [ms] | -76.0% | -76.0% to -75.9% | -76.0% | faster |
| uniform_coarse | RHS in the steps per fluid particle [µs] | +5.5% | +3.2% to +6.3% | +5.9% | slower |
| uniform_coarse | wall time per unit of simulated time [s] | -86.7% | -87.2% to -86.6% | -86.7% | faster |
| uniform_fine_again | step time [ms] | +0.3% | -3.0% to +0.7% | +0.4% | A/A |
| uniform_fine_again | RHS in the steps [ms] | -0.1% | -2.0% to +1.6% | +0.2% | A/A |
| uniform_fine_again | isolated RHS, median of the calls [ms] | +0.3% | +0.1% to +0.4% | +0.2% | A/A |
| uniform_fine_again | isolated RHS, minimum of the calls [ms] | +0.3% | -0.1% to +0.5% | +0.3% | A/A |
| uniform_fine_again | RHS in the steps per fluid particle [µs] | -0.1% | -2.0% to +1.6% | +0.2% | A/A |
| uniform_fine_again | wall time per unit of simulated time [s] | +0.3% | -3.0% to +0.7% | +0.4% | A/A |

A/A noise (the largest deviation of the A/A interval from 1): step time 3.0%, RHS in the steps 2.0%, isolated RHS, median of the calls 0.4%, isolated RHS, minimum of the calls 0.5%, RHS in the steps per fluid particle 2.0%, wall time per unit of simulated time 3.0%.

Isolated RHS by section, median over the blocks [ms]:

| label | interaction | update shifting | avg. pressure | beta | avg. pressure + beta | update nhs |
|---|---|---|---|---|---|---|
| uniform_fine | 2.345 | 1.758 | 1.030 | – | – | 0.480 |
| refined_base | 6.993 | 5.181 | 3.473 | 2.611 | – | 0.564 |
| refined_final | 5.271 | 3.498 | – | – | 2.850 | 0.568 |
| uniform_coarse | 0.562 | 0.415 | 0.239 | – | – | 0.135 |
| uniform_fine_again | 2.341 | 1.806 | 1.034 | – | – | 0.449 |

**Check: the labels don't do exactly the same work:**

- refined_base and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 912, 0, 10746, 10789, '0.035192479120508345') vs. (100, 903, 0, 16384, 16384, '0.017755681818181827')
- refined_final and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 912, 0, 10746, 10754, '0.03519134600019317') vs. (100, 903, 0, 16384, 16384, '0.017755681818181827')
- uniform_coarse and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 903, 0, 4096, 4096, '0.03551136363636365') vs. (100, 903, 0, 16384, 16384, '0.017755681818181827')
- refined_base and uniform_fine differ in the particles of the isolated RHS state: {10739} vs. {16384}
- refined_final and uniform_fine differ in the particles of the isolated RHS state: {10740} vs. {16384}
- uniform_coarse and uniform_fine differ in the particles of the isolated RHS state: {4096} vs. {16384}

For labels that differ, use the wall time per unit of simulated time instead of the step time. If the particle counts differ a lot, divide the RHS times by them.


## pipe_flow

step time [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 16.24 | 108.83 | 70.98 | 5.11 | 16.25 |  |
| 2 | 16.05 | 109.12 | 70.95 | 5.14 | 16.22 |  |
| 3 | 16.11 | 109.17 | 71.00 | 5.11 | 16.28 |  |
| 4 | 16.34 | 109.07 | 71.00 | 5.08 | 16.26 |  |
| 5 | 16.41 | 108.61 | 70.75 | 5.07 | 16.19 |  |
| **minimum** | 16.05 | 108.61 | 70.75 | 5.07 | 16.19 | |
| **median** | 16.24 | 109.07 | 70.98 | 5.11 | 16.25 | |

isolated RHS, median of the calls [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 2.06 | 13.29 | 8.11 | 0.59 | 2.04 |  |
| 2 | 2.00 | 13.28 | 8.11 | 0.58 | 2.02 |  |
| 3 | 2.06 | 13.27 | 8.10 | 0.59 | 2.05 |  |
| 4 | 2.02 | 13.22 | 8.11 | 0.57 | 2.04 |  |
| 5 | 2.09 | 13.26 | 8.10 | 0.58 | 2.01 |  |
| **minimum** | 2.00 | 13.22 | 8.10 | 0.57 | 2.01 | |
| **median** | 2.06 | 13.27 | 8.11 | 0.58 | 2.04 | |

Work and time per label, median over the blocks:

| label | fluid particles after startup | at the end | steps | RHS/step | rejected | mean dt | startup [s] | step [ms] | RHS [ms] | RHS per particle [µs] | refinement call [ms] | wall time per simulated time [s] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform_fine | 11560 | 11660 | 100 | 6.12 | 2 | 1.176e-03 | 0.00 | 16.24 | 2.20 | 0.190 | 0.0 | 13.8 |
| refined_base | 10551 | 9755 | 100 | 6.12 | 2 | 7.439e-04 | 1.11 | 109.07 | 13.26 | 1.306 | 112.9 | 146.6 |
| refined_final | 10551 | 9780 | 100 | 6.27 | 5 | 7.361e-04 | 1.05 | 70.98 | 8.28 | 0.814 | 98.3 | 96.4 |
| uniform_coarse | 2890 | 2904 | 100 | 6.22 | 4 | 2.308e-03 | 0.00 | 5.11 | 0.66 | 0.229 | 0.0 | 2.2 |
| uniform_fine_again | 11560 | 11660 | 100 | 6.12 | 2 | 1.176e-03 | 0.00 | 16.25 | 2.17 | 0.187 | 0.0 | 13.8 |

Clean blocks: 5 of 5 (0 extra).

Ratio to `uniform_fine` (median of the ratios per block, 95% bootstrap interval, ratio of the minima):

| label | metric | median | interval | ratio of minima | verdict |
|---|---|---|---|---|---|
| refined_base | step time [ms] | +570.2% | +562.0% to +580.0% | +576.8% | slower |
| refined_base | RHS in the steps [ms] | +500.8% | +492.7% to +510.0% | +509.0% | slower |
| refined_base | isolated RHS, median of the calls [ms] | +546.6% | +534.1% to +564.5% | +561.6% | slower |
| refined_base | isolated RHS, minimum of the calls [ms] | +560.2% | +543.6% to +568.3% | +566.9% | slower |
| refined_base | RHS in the steps per fluid particle [µs] | +587.0% | +577.8% to +597.5% | +596.4% | slower |
| refined_base | wall time per unit of simulated time [s] | +959.2% | +946.3% to +974.7% | +969.6% | slower |
| refined_final | step time [ms] | +337.1% | +331.2% to +342.1% | +340.9% | slower |
| refined_final | RHS in the steps [ms] | +274.9% | +268.7% to +281.4% | +280.0% | slower |
| refined_final | isolated RHS, median of the calls [ms] | +294.5% | +287.5% to +305.7% | +305.1% | slower |
| refined_final | isolated RHS, minimum of the calls [ms] | +302.7% | +292.9% to +309.2% | +307.4% | slower |
| refined_final | RHS in the steps per fluid particle [µs] | +328.1% | +321.1% to +335.6% | +334.0% | slower |
| refined_final | wall time per unit of simulated time [s] | +598.1% | +588.7% to +606.1% | +604.1% | slower |
| uniform_coarse | step time [ms] | -68.5% | -69.1% to -68.0% | -68.4% | faster |
| uniform_coarse | RHS in the steps [ms] | -69.9% | -70.4% to -69.4% | -69.6% | faster |
| uniform_coarse | isolated RHS, median of the calls [ms] | -71.5% | -72.5% to -71.2% | -71.3% | faster |
| uniform_coarse | isolated RHS, minimum of the calls [ms] | -71.7% | -72.4% to -71.4% | -71.5% | faster |
| uniform_coarse | RHS in the steps per fluid particle [µs] | +20.7% | +18.6% to +22.8% | +21.8% | slower |
| uniform_coarse | wall time per unit of simulated time [s] | -84.0% | -84.3% to -83.7% | -83.9% | faster |
| uniform_fine_again | step time [ms] | +0.0% | -1.3% to +1.1% | +0.9% | A/A |
| uniform_fine_again | RHS in the steps [ms] | -0.2% | -2.6% to +0.3% | -0.4% | A/A |
| uniform_fine_again | isolated RHS, median of the calls [ms] | -0.2% | -3.8% to +1.2% | +0.6% | A/A |
| uniform_fine_again | isolated RHS, minimum of the calls [ms] | +0.1% | -2.7% to +1.1% | +0.9% | A/A |
| uniform_fine_again | RHS in the steps per fluid particle [µs] | -0.2% | -2.6% to +0.3% | -0.4% | A/A |
| uniform_fine_again | wall time per unit of simulated time [s] | +0.0% | -1.3% to +1.1% | +0.9% | A/A |

A/A noise (the largest deviation of the A/A interval from 1): step time 1.3%, RHS in the steps 2.6%, isolated RHS, median of the calls 3.8%, isolated RHS, minimum of the calls 2.7%, RHS in the steps per fluid particle 2.6%, wall time per unit of simulated time 1.3%.

Isolated RHS by section, median over the blocks [ms]:

| label | interaction | avg. pressure | beta | avg. pressure + beta | update nhs |
|---|---|---|---|---|---|
| uniform_fine | 1.148 | 0.406 | – | – | 0.406 |
| refined_base | 5.831 | 3.282 | 2.419 | – | 1.317 |
| refined_final | 4.436 | – | – | 2.730 | 0.521 |
| uniform_coarse | 0.316 | 0.104 | – | – | 0.121 |
| uniform_fine_again | 1.147 | 0.385 | – | – | 0.435 |

**Check: the labels don't do exactly the same work:**

- refined_base and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 612, 2, 10551, 9755, '0.07438794619466285') vs. (100, 612, 2, 11560, 11660, '0.11756897949212002')
- refined_final and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 627, 5, 10551, 9780, '0.07361347991840166') vs. (100, 612, 2, 11560, 11660, '0.11756897949212002')
- uniform_coarse and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 622, 4, 2890, 2904, '0.23083540782141132') vs. (100, 612, 2, 11560, 11660, '0.11756897949212002')
- refined_base and uniform_fine differ in the particles of the isolated RHS state: {13767} vs. {13834}
- refined_final and uniform_fine differ in the particles of the isolated RHS state: {13767} vs. {13834}
- uniform_coarse and uniform_fine differ in the particles of the isolated RHS state: {4076} vs. {13834}

For labels that differ, use the wall time per unit of simulated time instead of the step time. If the particle counts differ a lot, divide the RHS times by them.


