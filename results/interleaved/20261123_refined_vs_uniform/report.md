# Interleaved A/B: 20261123_refined_vs_uniform

- 2026-11-23T15:22:48, full measurement, size small, 8 threads, CPUs [8, 9, 10, 11, 12, 13, 14, 15], PointNeighbors 7aeb2f0
- Labels: `uniform_fine` = c4b66ab uniform at min. spacing, `refined_base` = 5b73bd7, `refined_final` = c4b66ab, `uniform_coarse` = c4b66ab uniform at max. spacing, `uniform_fine_again` = c4b66ab uniform at min. spacing
- 5 blocks planned, startup 212 s, total 19.1 min
- Other load on our cores and their siblings: median 0.03, max 2.04 cores. Whole machine: 26 to 64 cores busy, load average 30 to 53. Waiting workers used at most 0.160 cores together.

## taylor_green

step time [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 56.48 | 206.33 | 133.50 | 14.91 | 55.90 |  |
| 2 | 71.67 | 209.61 | 136.69 | 16.89 | 74.09 | uniform_fine step +28%; uniform_fine RHS +27%; uniform_coarse step +15%; uniform_coarse RHS +41%; uniform_fine_again step +33%; uniform_fine_again RHS +33% |
| 3 | 56.39 | 211.33 | 137.18 | 15.34 | 57.61 | uniform_coarse RHS +6% |
| 4 | 56.13 | 210.06 | 137.03 | 15.31 | 57.31 | uniform_coarse RHS +5% |
| 5 | 61.72 | 206.96 | 174.54 | 18.68 | 75.25 | uniform_fine step +10%; uniform_fine RHS +30%; refined_final step +31%; refined_final RHS +29%; uniform_coarse step +27%; uniform_coarse RHS +35%; uniform_fine_again step +35%; uniform_fine_again RHS +33% |
| 6 | 74.24 | 226.76 | 160.06 | 22.05 | 74.77 | uniform_fine step +32%; uniform_fine RHS +30%; refined_base step +12%; refined_base RHS +12%; refined_final step +20%; refined_final RHS +19%; uniform_coarse step +50%; uniform_coarse RHS +35%; uniform_fine_again step +34%; uniform_fine_again RHS +27% |
| 7 | 72.74 | 227.59 | 160.48 | 20.05 | 77.72 | uniform_fine step +30%; uniform_fine RHS +30%; refined_base step +12%; refined_base RHS +12%; refined_final step +21%; refined_final RHS +18%; uniform_coarse step +37%; uniform_coarse RHS +39%; uniform_fine_again step +39%; uniform_fine_again RHS +29% |
| 8 | 69.87 | 202.47 | 132.90 | 14.66 | 74.64 | uniform_fine step +24%; uniform_fine RHS +27%; uniform_fine_again step +34%; uniform_fine_again RHS +28% |
| **minimum** | 56.13 | 202.47 | 132.90 | 14.66 | 55.90 | |
| **median** | 65.79 | 209.83 | 137.11 | 16.11 | 74.37 | |

isolated RHS, median of the calls [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 5.76 | 19.73 | 12.51 | 1.41 | 5.85 |  |
| 2 | 7.33 | 19.63 | 12.50 | 1.94 | 7.75 | uniform_fine step +28%; uniform_fine RHS +27%; uniform_coarse step +15%; uniform_coarse RHS +41%; uniform_fine_again step +33%; uniform_fine_again RHS +33% |
| 3 | 5.89 | 20.21 | 12.82 | 1.45 | 6.00 | uniform_coarse RHS +6% |
| 4 | 5.89 | 20.17 | 12.74 | 1.45 | 5.97 | uniform_coarse RHS +5% |
| 5 | 7.51 | 19.53 | 15.87 | 1.86 | 7.78 | uniform_fine step +10%; uniform_fine RHS +30%; refined_final step +31%; refined_final RHS +29%; uniform_coarse step +27%; uniform_coarse RHS +35%; uniform_fine_again step +35%; uniform_fine_again RHS +33% |
| 6 | 7.49 | 21.58 | 14.63 | 1.86 | 7.43 | uniform_fine step +32%; uniform_fine RHS +30%; refined_base step +12%; refined_base RHS +12%; refined_final step +20%; refined_final RHS +19%; uniform_coarse step +50%; uniform_coarse RHS +35%; uniform_fine_again step +34%; uniform_fine_again RHS +27% |
| 7 | 7.50 | 21.63 | 14.54 | 1.91 | 7.56 | uniform_fine step +30%; uniform_fine RHS +30%; refined_base step +12%; refined_base RHS +12%; refined_final step +21%; refined_final RHS +18%; uniform_coarse step +37%; uniform_coarse RHS +39%; uniform_fine_again step +39%; uniform_fine_again RHS +29% |
| 8 | 7.30 | 19.34 | 12.31 | 1.37 | 7.45 | uniform_fine step +24%; uniform_fine RHS +27%; uniform_fine_again step +34%; uniform_fine_again RHS +28% |
| **minimum** | 5.76 | 19.34 | 12.31 | 1.37 | 5.85 | |
| **median** | 7.32 | 19.95 | 12.78 | 1.66 | 7.44 | |

Work and time per label, median over the blocks:

| label | fluid particles after startup | at the end | steps | RHS/step | rejected | mean dt | startup [s] | step [ms] | RHS [ms] | RHS per particle [µs] | refinement call [ms] | wall time per simulated time [s] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform_fine | 16384 | 16384 | 100 | 9.03 | 0 | 1.776e-04 | 0.00 | 65.79 | 6.75 | 0.412 | 0.0 | 370.6 |
| refined_base | 10746 | 10789 | 100 | 9.12 | 0 | 3.519e-04 | 4.59 | 209.83 | 20.09 | 1.866 | 135.3 | 596.2 |
| refined_final | 10746 | 10754 | 100 | 9.12 | 0 | 3.519e-04 | 4.73 | 137.11 | 12.82 | 1.192 | 125.5 | 389.6 |
| uniform_coarse | 4096 | 4096 | 100 | 9.03 | 0 | 3.551e-04 | 0.00 | 16.11 | 1.64 | 0.400 | 0.0 | 45.4 |
| uniform_fine_again | 16384 | 16384 | 100 | 9.03 | 0 | 1.776e-04 | 0.00 | 74.37 | 7.63 | 0.466 | 0.0 | 418.8 |

Clean blocks: 1 of 8 (3 extra).

Ratio to `uniform_fine` (median of the ratios per block, 95% bootstrap interval, ratio of the minima):

| label | metric | median | interval | ratio of minima | verdict |
|---|---|---|---|---|---|
| refined_base | step time [ms] | +224.1% | +192.4% to +274.2% | +260.7% | slower, size uncertain |
| refined_base | RHS in the steps [ms] | +202.9% | +172.1% to +249.7% | +239.1% | slower, size uncertain |
| refined_base | isolated RHS, median of the calls [ms] | +188.3% | +164.9% to +242.7% | +235.7% | slower, size uncertain |
| refined_base | isolated RHS, minimum of the calls [ms] | +221.4% | +188.8% to +249.5% | +244.5% | slower, size uncertain |
| refined_base | RHS in the steps per fluid particle [µs] | +360.9% | +314.1% to +432.1% | +415.9% | slower, size uncertain |
| refined_base | wall time per unit of simulated time [s] | +63.5% | +47.5% to +88.8% | +82.0% | slower, size uncertain |
| refined_final | step time [ms] | +128.5% | +90.7% to +144.1% | +136.8% | slower, size uncertain |
| refined_final | RHS in the steps [ms] | +110.3% | +73.4% to +122.8% | +117.5% | slower, size uncertain |
| refined_final | isolated RHS, median of the calls [ms] | +103.3% | +70.5% to +117.2% | +113.7% | slower, size uncertain |
| refined_final | isolated RHS, minimum of the calls [ms] | +112.8% | +94.2% to +119.1% | +118.5% | slower, size uncertain |
| refined_final | RHS in the steps per fluid particle [µs] | +220.5% | +164.3% to +239.5% | +231.5% | slower, size uncertain |
| refined_final | wall time per unit of simulated time [s] | +15.3% | -3.8% to +23.2% | +19.5% | inconclusive (noisy) |
| uniform_coarse | step time [ms] | -72.8% | -76.4% to -70.3% | -73.9% | faster, size uncertain |
| uniform_coarse | RHS in the steps [ms] | -72.9% | -76.7% to -70.7% | -73.8% | faster, size uncertain |
| uniform_coarse | isolated RHS, median of the calls [ms] | -75.3% | -75.5% to -74.6% | -76.2% | faster, size uncertain |
| uniform_coarse | isolated RHS, minimum of the calls [ms] | -75.6% | -75.8% to -74.3% | -75.8% | faster, size uncertain |
| uniform_coarse | RHS in the steps per fluid particle [µs] | +8.2% | -6.7% to +17.1% | +4.6% | inconclusive (noisy) |
| uniform_coarse | wall time per unit of simulated time [s] | -86.4% | -88.2% to -85.1% | -86.9% | faster, size uncertain |
| uniform_fine_again | step time [ms] | +2.8% | +0.7% to +6.8% | -0.4% | A/A |
| uniform_fine_again | RHS in the steps [ms] | +2.9% | +1.5% to +6.8% | -0.0% | A/A |
| uniform_fine_again | isolated RHS, median of the calls [ms] | +1.7% | +0.9% to +3.6% | +1.5% | A/A |
| uniform_fine_again | isolated RHS, minimum of the calls [ms] | +2.2% | +1.3% to +3.1% | +1.8% | A/A |
| uniform_fine_again | RHS in the steps per fluid particle [µs] | +2.9% | +1.5% to +6.8% | -0.0% | A/A |
| uniform_fine_again | wall time per unit of simulated time [s] | +2.8% | +0.7% to +6.8% | -0.4% | A/A |

A/A noise (the largest deviation of the A/A interval from 1): step time 6.8%, RHS in the steps 6.8%, isolated RHS, median of the calls 3.6%, isolated RHS, minimum of the calls 3.1%, RHS in the steps per fluid particle 6.8%, wall time per unit of simulated time 6.8%.

Isolated RHS by section, median over the blocks [ms]:

| label | interaction | update shifting | avg. pressure | beta | avg. pressure + beta | update nhs |
|---|---|---|---|---|---|---|
| uniform_fine | 3.234 | 2.162 | 1.274 | – | – | 0.459 |
| refined_base | 7.353 | 5.554 | 3.677 | 2.786 | – | 0.590 |
| refined_final | 5.588 | 3.652 | – | – | 2.914 | 0.595 |
| uniform_coarse | 0.729 | 0.495 | 0.270 | – | – | 0.155 |
| uniform_fine_again | 3.403 | 2.221 | 1.253 | – | – | 0.510 |

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
| 1 | 17.64 | 112.61 | 79.16 | 5.34 | 18.28 | uniform_fine step +10%; uniform_fine RHS +11%; refined_final step +10%; uniform_fine_again step +9% |
| 2 | 17.46 | 131.07 | 84.90 | 6.96 | 23.50 | uniform_fine step +8%; uniform_fine RHS +8%; refined_base step +18%; refined_base RHS +21%; refined_final step +18%; refined_final RHS +7%; uniform_coarse step +34%; uniform_fine_again step +40%; uniform_fine_again RHS +32% |
| 3 | 17.40 | 116.22 | 75.72 | 5.43 | 17.64 | uniform_fine step +8%; uniform_fine RHS +8%; uniform_fine_again RHS +6% |
| 4 | 16.99 | 116.07 | 75.32 | 5.40 | 17.49 | uniform_fine step +6%; uniform_fine RHS +5%; uniform_coarse RHS +5%; uniform_fine_again RHS +5% |
| 5 | 21.76 | 140.34 | 90.53 | 6.60 | 25.19 | uniform_fine step +35%; uniform_fine RHS +36%; refined_base step +26%; refined_base RHS +26%; refined_final step +26%; refined_final RHS +23%; uniform_coarse step +27%; uniform_coarse RHS +34%; uniform_fine_again step +50%; uniform_fine_again RHS +47% |
| 6 | 16.10 | 110.98 | 72.36 | 6.87 | 16.84 | uniform_coarse step +32% |
| 7 | 16.15 | 111.44 | 72.12 | 5.19 | 16.84 |  |
| 8 | 16.42 | 112.47 | 72.38 | 5.22 | 16.84 |  |
| **minimum** | 16.10 | 110.98 | 72.12 | 5.19 | 16.84 | |
| **median** | 17.20 | 114.34 | 75.52 | 5.41 | 17.56 | |

isolated RHS, median of the calls [ms], every block:

| block | uniform_fine | refined_base | refined_final | uniform_coarse | uniform_fine_again | noisy? |
|---|---|---|---|---|---|---|
| 1 | 2.25 | 13.82 | 8.35 | 0.62 | 2.19 | uniform_fine step +10%; uniform_fine RHS +11%; refined_final step +10%; uniform_fine_again step +9% |
| 2 | 2.19 | 16.59 | 8.81 | 0.63 | 2.76 | uniform_fine step +8%; uniform_fine RHS +8%; refined_base step +18%; refined_base RHS +21%; refined_final step +18%; refined_final RHS +7%; uniform_coarse step +34%; uniform_fine_again step +40%; uniform_fine_again RHS +32% |
| 3 | 2.18 | 14.34 | 8.60 | 0.63 | 2.20 | uniform_fine step +8%; uniform_fine RHS +8%; uniform_fine_again RHS +6% |
| 4 | 2.13 | 14.28 | 8.53 | 0.63 | 2.20 | uniform_fine step +6%; uniform_fine RHS +5%; uniform_coarse RHS +5%; uniform_fine_again RHS +5% |
| 5 | 2.76 | 17.30 | 10.11 | 0.81 | 3.06 | uniform_fine step +35%; uniform_fine RHS +36%; refined_base step +26%; refined_base RHS +26%; refined_final step +26%; refined_final RHS +23%; uniform_coarse step +27%; uniform_coarse RHS +34%; uniform_fine_again step +50%; uniform_fine_again RHS +47% |
| 6 | 2.03 | 13.69 | 8.26 | 0.60 | 2.09 | uniform_coarse step +32% |
| 7 | 2.02 | 13.69 | 8.24 | 0.61 | 2.09 |  |
| 8 | 2.03 | 13.69 | 8.23 | 0.61 | 2.10 |  |
| **minimum** | 2.02 | 13.69 | 8.23 | 0.60 | 2.09 | |
| **median** | 2.16 | 14.05 | 8.44 | 0.62 | 2.19 | |

Work and time per label, median over the blocks:

| label | fluid particles after startup | at the end | steps | RHS/step | rejected | mean dt | startup [s] | step [ms] | RHS [ms] | RHS per particle [µs] | refinement call [ms] | wall time per simulated time [s] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform_fine | 11560 | 11660 | 100 | 6.12 | 2 | 1.176e-03 | 0.00 | 17.20 | 2.34 | 0.201 | 0.0 | 14.6 |
| refined_base | 10551 | 9755 | 100 | 6.12 | 2 | 7.439e-04 | 1.22 | 114.34 | 13.93 | 1.372 | 117.6 | 153.7 |
| refined_final | 10551 | 9780 | 100 | 6.27 | 5 | 7.361e-04 | 1.19 | 75.52 | 8.78 | 0.864 | 103.9 | 102.6 |
| uniform_coarse | 2890 | 2904 | 100 | 6.22 | 4 | 2.308e-03 | 0.00 | 5.41 | 0.71 | 0.243 | 0.0 | 2.3 |
| uniform_fine_again | 11560 | 11660 | 100 | 6.12 | 2 | 1.176e-03 | 0.00 | 17.56 | 2.34 | 0.202 | 0.0 | 14.9 |

Clean blocks: 2 of 8 (3 extra).

Ratio to `uniform_fine` (median of the ratios per block, 95% bootstrap interval, ratio of the minima):

| label | metric | median | interval | ratio of minima | verdict |
|---|---|---|---|---|---|
| refined_base | step time [ms] | +584.2% | +544.9% to +590.0% | +589.2% | slower, size uncertain |
| refined_base | RHS in the steps [ms] | +507.8% | +481.8% to +526.0% | +526.0% | slower, size uncertain |
| refined_base | isolated RHS, median of the calls [ms] | +571.7% | +527.3% to +576.2% | +575.9% | slower, size uncertain |
| refined_base | isolated RHS, minimum of the calls [ms] | +576.6% | +541.6% to +584.6% | +584.3% | slower, size uncertain |
| refined_base | RHS in the steps per fluid particle [µs] | +595.1% | +565.3% to +615.8% | +615.8% | slower, size uncertain |
| refined_base | wall time per unit of simulated time [s] | +981.3% | +919.3% to +990.5% | +989.2% | slower, size uncertain |
| refined_final | step time [ms] | +345.0% | +335.1% to +349.3% | +347.9% | slower, size uncertain |
| refined_final | RHS in the steps [ms] | +281.2% | +261.4% to +289.3% | +288.2% | slower, size uncertain |
| refined_final | isolated RHS, median of the calls [ms] | +301.8% | +270.9% to +305.9% | +306.7% | slower, size uncertain |
| refined_final | isolated RHS, minimum of the calls [ms] | +302.2% | +277.9% to +307.9% | +307.7% | slower, size uncertain |
| refined_final | RHS in the steps per fluid particle [µs] | +335.4% | +312.7% to +344.7% | +343.3% | slower, size uncertain |
| refined_final | wall time per unit of simulated time [s] | +610.7% | +594.9% to +617.7% | +615.3% | slower, size uncertain |
| uniform_coarse | step time [ms] | -68.2% | -69.7% to -62.6% | -67.8% | faster, size uncertain |
| uniform_coarse | RHS in the steps [ms] | -69.7% | -70.3% to -62.9% | -68.7% | faster, size uncertain |
| uniform_coarse | isolated RHS, median of the calls [ms] | -70.6% | -71.3% to -70.1% | -70.3% | faster, size uncertain |
| uniform_coarse | isolated RHS, minimum of the calls [ms] | -70.8% | -71.8% to -70.6% | -70.6% | faster, size uncertain |
| uniform_coarse | RHS in the steps per fluid particle [µs] | +21.4% | +19.0% to +48.7% | +25.4% | inconclusive (noisy) |
| uniform_coarse | wall time per unit of simulated time [s] | -83.8% | -84.5% to -81.0% | -83.6% | faster, size uncertain |
| uniform_fine_again | step time [ms] | +3.9% | +2.6% to +15.7% | +4.5% | A/A |
| uniform_fine_again | RHS in the steps [ms] | +3.1% | -0.3% to +20.5% | +3.8% | A/A |
| uniform_fine_again | isolated RHS, median of the calls [ms] | +3.1% | +1.0% to +10.8% | +3.0% | A/A |
| uniform_fine_again | isolated RHS, minimum of the calls [ms] | +2.3% | +1.6% to +3.4% | +3.4% | A/A |
| uniform_fine_again | RHS in the steps per fluid particle [µs] | +3.1% | -0.3% to +20.5% | +3.8% | A/A |
| uniform_fine_again | wall time per unit of simulated time [s] | +3.9% | +2.6% to +15.7% | +4.5% | A/A |

A/A noise (the largest deviation of the A/A interval from 1): step time 15.7%, RHS in the steps 20.5%, isolated RHS, median of the calls 10.8%, isolated RHS, minimum of the calls 3.4%, RHS in the steps per fluid particle 20.5%, wall time per unit of simulated time 15.7%.

Isolated RHS by section, median over the blocks [ms]:

| label | interaction | avg. pressure | beta | avg. pressure + beta | update nhs |
|---|---|---|---|---|---|
| uniform_fine | 1.206 | 0.398 | – | – | 0.438 |
| refined_base | 6.255 | 3.486 | 2.535 | – | 1.372 |
| refined_final | 4.649 | – | – | 2.835 | 0.544 |
| uniform_coarse | 0.334 | 0.112 | – | – | 0.136 |
| uniform_fine_again | 1.208 | 0.413 | – | – | 0.478 |

**Check: the labels don't do exactly the same work:**

- refined_base and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 612, 2, 10551, 9755, '0.07438794619466285') vs. (100, 612, 2, 11560, 11660, '0.11756897949212002')
- refined_final and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 627, 5, 10551, 9780, '0.07361347991840166') vs. (100, 612, 2, 11560, 11660, '0.11756897949212002')
- uniform_coarse and uniform_fine differ in (steps, RHS evaluations, rejected, particles after the startup, particles at the end, t_end): (100, 622, 4, 2890, 2904, '0.23083540782141132') vs. (100, 612, 2, 11560, 11660, '0.11756897949212002')
- refined_base and uniform_fine differ in the particles of the isolated RHS state: {13767} vs. {13834}
- refined_final and uniform_fine differ in the particles of the isolated RHS state: {13767} vs. {13834}
- uniform_coarse and uniform_fine differ in the particles of the isolated RHS state: {4076} vs. {13834}

For labels that differ, use the wall time per unit of simulated time instead of the step time. If the particle counts differ a lot, divide the RHS times by them.


