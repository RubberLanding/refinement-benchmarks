### taylor_green

| run | steps to t_end | dtmax | particles min..max | L2 error at t=0.5 | L2 error at t_end | L1 error at t_end | max error / U at t_end | energy / exact at t_end | L2 error in refined box at t_end | failed |
|---|---|---|---|---|---|---|---|---|---|---|
| refined_base | 2817 | 3.55e-04 | 10721..10872 | 1.34% | 3.30% | 3.26% | 0.039 | 1.0663 | 3.92% |  |
| refined_final | 2817 | 3.55e-04 | 10719..10872 | 1.39% | 3.39% | 3.34% | 0.053 | 1.0679 | 4.00% |  |
| refined_final_half_dt | 5633 | 1.78e-04 | 10717..10852 | 1.39% | 3.36% | 3.28% | 0.127 | 1.0667 | 4.43% |  |
| uniform_coarse | 2817 | 3.55e-04 | 4096..4096 | 0.89% | 1.01% | 0.98% | 0.023 | 0.9833 | 0.82% |  |
| uniform_fine | 5633 | 1.78e-04 | 16384..16384 | 0.40% | 0.41% | 0.40% | 0.007 | 0.9928 | 0.35% |  |
| uniform_fine_double_dt | 2816 | 3.55e-04 | 16384..16384 | 0.40% | 0.41% | 0.40% | 0.008 | 0.9928 | 0.35% |  |
| uniform_same_n | 4576 | 2.19e-04 | 10816..10816 | 0.48% | 0.52% | 0.51% | 0.011 | 0.9906 | 0.47% |  |

### pipe_flow

| run | steps to t_end | particles min..max | rejected | difference to reference | x=0.25 | x=0.5 | x=0.75 | centerline u at x=0.75 | failed |
|---|---|---|---|---|---|---|---|---|---|
| reference | 2515 | 45606..46698 | 87 | 0.00% | 0.00% | 0.00% | 0.00% | 1.3841 |  |
| refined_base | no result |
| refined_final | no result |
| uniform_coarse | 776 | 2821..2930 | 43 | 0.38% | 0.47% | 0.29% | 0.35% | 1.3888 |  |
| uniform_fine | 1418 | 11356..11688 | 69 | 0.21% | 0.19% | 0.22% | 0.23% | 1.3876 |  |
| uniform_same_n | 1307 | 9434..9724 | 74 | 0.21% | 0.19% | 0.21% | 0.22% | 1.3872 |  |

