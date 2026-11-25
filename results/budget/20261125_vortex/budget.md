
### ratio2_grid, early

- vortex_street small, grid, tspan=(0.0, 9.0) spacing_ratio=2, shifting fast, refinement/benchmark 92fef57, PointNeighbors ef/tree-parallel 4842a89, 8 threads
- 3 clean of 3 runs, other load 0.0, 0.0, 0.0 cores, t = 0.000 to 0.089
- 10561 to 10754 fluid particles, 6.19 RHS/step, RHS 8.51 ms, 0.791 us per fluid particle, 81 s per simulated time
- step time: median 72.12 ms, minimum 72.10 ms
- startup: 1.05 s, of which shifting 0.79 s

| section | ms per step | % of step |
|---|---|---|
| **RHS** | **52.51** | **72.8** |
| &nbsp; interaction fluid-fluid | 19.58 | 27.1 |
| &nbsp; interaction other pairs | 3.11 | 4.3 |
| &nbsp; density | 9.89 | 13.7 |
| &nbsp; avg. pressure + beta | 13.08 | 18.1 |
| &nbsp; update nhs | 2.78 | 3.9 |
| &nbsp; boundary pressure | 0.42 | 0.6 |
| &nbsp; characteristics | 2.96 | 4.1 |
| &nbsp; rest | 0.70 | 1.0 |
| **refinement** | **9.43** | **13.1** |
| &nbsp; shift: compute shift | 5.35 | 7.4 |
| &nbsp; shift: apply shift | 0.95 | 1.3 |
| &nbsp; shift: rest | 0.65 | 0.9 |
| &nbsp; merge | 0.52 | 0.7 |
| &nbsp; split | 0.06 | 0.1 |
| &nbsp; criteria + target spacing | 0.61 | 0.8 |
| &nbsp; update systems before/after | 0.94 | 1.3 |
| &nbsp; rest | 0.36 | 0.5 |
| **update callback** | **8.83** | **12.2** |
| &nbsp; PST (update shifting) | 3.09 | 4.3 |
| &nbsp; update systems and nhs | 4.78 | 6.6 |
| &nbsp; open boundary | 0.96 | 1.3 |
| &nbsp; rest | 0.00 | 0.0 |
| **drift** | **0.10** | **0.1** |
| **time integration and rest** | **1.25** | **1.7** |

### ratio2_grid, developed

- vortex_street small, grid, tspan=(0.0, 9.0) spacing_ratio=2, shifting fast, refinement/benchmark 92fef57, PointNeighbors ef/tree-parallel 4842a89, 8 threads
- 3 clean of 3 runs, other load 0.0, 0.0, 0.0 cores, t = 4.001 to 4.105
- 14996 to 14942 fluid particles, 6.55 RHS/step, RHS 16.86 ms, 1.128 us per fluid particle, 143 s per simulated time
- step time: median 147.56 ms, minimum 146.15 ms

| section | ms per step | % of step |
|---|---|---|
| **RHS** | **110.49** | **74.9** |
| &nbsp; interaction fluid-fluid | 44.65 | 30.3 |
| &nbsp; interaction other pairs | 3.26 | 2.2 |
| &nbsp; density | 22.57 | 15.3 |
| &nbsp; avg. pressure + beta | 30.05 | 20.4 |
| &nbsp; update nhs | 3.70 | 2.5 |
| &nbsp; boundary pressure | 0.62 | 0.4 |
| &nbsp; characteristics | 4.43 | 3.0 |
| &nbsp; rest | 1.21 | 0.8 |
| **refinement** | **18.70** | **12.7** |
| &nbsp; shift: compute shift | 11.23 | 7.6 |
| &nbsp; shift: apply shift | 1.16 | 0.8 |
| &nbsp; shift: rest | 1.41 | 1.0 |
| &nbsp; merge | 1.01 | 0.7 |
| &nbsp; split | 0.07 | 0.0 |
| &nbsp; criteria + target spacing | 1.27 | 0.9 |
| &nbsp; update systems before/after | 1.85 | 1.3 |
| &nbsp; rest | 0.70 | 0.5 |
| **update callback** | **16.74** | **11.3** |
| &nbsp; PST (update shifting) | 6.46 | 4.4 |
| &nbsp; update systems and nhs | 9.41 | 6.4 |
| &nbsp; open boundary | 0.87 | 0.6 |
| &nbsp; rest | 0.00 | 0.0 |
| **drift** | **0.16** | **0.1** |
| **time integration and rest** | **1.47** | **1.0** |

### ratio2_tree_pruned, early

- vortex_street small, tree_pruned, tspan=(0.0, 9.0) spacing_ratio=2, shifting fast, refinement/benchmark 92fef57, PointNeighbors ef/tree-parallel 4842a89, 8 threads
- 3 clean of 3 runs, other load 0.0, 0.0, 0.0 cores, t = 0.000 to 0.090
- 10559 to 10751 fluid particles, 6.19 RHS/step, RHS 8.48 ms, 0.788 us per fluid particle, 79 s per simulated time
- step time: median 71.14 ms, minimum 70.96 ms
- startup: 0.89 s, of which shifting 0.71 s

| section | ms per step | % of step |
|---|---|---|
| **RHS** | **52.31** | **73.5** |
| &nbsp; interaction fluid-fluid | 15.43 | 21.7 |
| &nbsp; interaction other pairs | 5.20 | 7.3 |
| &nbsp; density | 11.70 | 16.5 |
| &nbsp; avg. pressure + beta | 11.74 | 16.5 |
| &nbsp; update nhs | 4.13 | 5.8 |
| &nbsp; boundary pressure | 0.54 | 0.8 |
| &nbsp; characteristics | 2.94 | 4.1 |
| &nbsp; rest | 0.62 | 0.9 |
| **refinement** | **8.82** | **12.4** |
| &nbsp; shift: compute shift | 4.41 | 6.2 |
| &nbsp; shift: apply shift | 1.14 | 1.6 |
| &nbsp; shift: rest | 0.60 | 0.8 |
| &nbsp; merge | 0.68 | 1.0 |
| &nbsp; split | 0.12 | 0.2 |
| &nbsp; criteria + target spacing | 0.52 | 0.7 |
| &nbsp; update systems before/after | 1.03 | 1.4 |
| &nbsp; rest | 0.32 | 0.4 |
| **update callback** | **8.50** | **12.0** |
| &nbsp; PST (update shifting) | 2.46 | 3.5 |
| &nbsp; update systems and nhs | 5.10 | 7.2 |
| &nbsp; open boundary | 0.94 | 1.3 |
| &nbsp; rest | 0.00 | 0.0 |
| **drift** | **0.09** | **0.1** |
| **time integration and rest** | **1.41** | **2.0** |

### ratio2_tree_pruned, developed

- vortex_street small, tree_pruned, tspan=(0.0, 9.0) spacing_ratio=2, shifting fast, refinement/benchmark 92fef57, PointNeighbors ef/tree-parallel 4842a89, 8 threads
- 3 clean of 3 runs, other load 0.0, 0.0, 0.0 cores, t = 4.000 to 4.102
- 15150 to 14734 fluid particles, 6.55 RHS/step, RHS 14.41 ms, 0.978 us per fluid particle, 121 s per simulated time
- step time: median 123.92 ms, minimum 123.74 ms

| section | ms per step | % of step |
|---|---|---|
| **RHS** | **94.06** | **75.9** |
| &nbsp; interaction fluid-fluid | 31.12 | 25.1 |
| &nbsp; interaction other pairs | 7.44 | 6.0 |
| &nbsp; density | 20.61 | 16.6 |
| &nbsp; avg. pressure + beta | 22.01 | 17.8 |
| &nbsp; update nhs | 5.82 | 4.7 |
| &nbsp; boundary pressure | 1.00 | 0.8 |
| &nbsp; characteristics | 4.82 | 3.9 |
| &nbsp; rest | 1.24 | 1.0 |
| **refinement** | **14.12** | **11.4** |
| &nbsp; shift: compute shift | 7.36 | 5.9 |
| &nbsp; shift: apply shift | 1.52 | 1.2 |
| &nbsp; shift: rest | 0.99 | 0.8 |
| &nbsp; merge | 1.11 | 0.9 |
| &nbsp; split | 0.14 | 0.1 |
| &nbsp; criteria + target spacing | 0.91 | 0.7 |
| &nbsp; update systems before/after | 1.61 | 1.3 |
| &nbsp; rest | 0.48 | 0.4 |
| **update callback** | **13.20** | **10.6** |
| &nbsp; PST (update shifting) | 4.03 | 3.3 |
| &nbsp; update systems and nhs | 8.02 | 6.5 |
| &nbsp; open boundary | 1.14 | 0.9 |
| &nbsp; rest | 0.00 | 0.0 |
| **drift** | **0.35** | **0.3** |
| **time integration and rest** | **2.19** | **1.8** |

### ratio4_tree_pruned, early

- vortex_street small, tree_pruned, tspan=(0.0, 9.0) spacing_ratio=4, shifting fast, refinement/benchmark 92fef57, PointNeighbors ef/tree-parallel 4842a89, 8 threads
- 3 clean of 3 runs, other load 0.0, 0.0, 0.0 cores, t = 0.000 to 0.054
- 12421 to 12750 fluid particles, 6.34 RHS/step, RHS 15.92 ms, 1.249 us per fluid particle, 258 s per simulated time
- step time: median 139.51 ms, minimum 137.59 ms
- startup: 3.70 s, of which shifting 2.98 s

| section | ms per step | % of step |
|---|---|---|
| **RHS** | **101.00** | **72.4** |
| &nbsp; interaction fluid-fluid | 27.23 | 19.5 |
| &nbsp; interaction other pairs | 9.94 | 7.1 |
| &nbsp; density | 25.47 | 18.3 |
| &nbsp; avg. pressure + beta | 24.57 | 17.6 |
| &nbsp; update nhs | 7.57 | 5.4 |
| &nbsp; boundary pressure | 2.35 | 1.7 |
| &nbsp; characteristics | 3.12 | 2.2 |
| &nbsp; rest | 0.77 | 0.5 |
| **refinement** | **18.13** | **13.0** |
| &nbsp; shift: compute shift | 9.94 | 7.1 |
| &nbsp; shift: apply shift | 1.76 | 1.3 |
| &nbsp; shift: rest | 1.18 | 0.8 |
| &nbsp; merge | 1.33 | 1.0 |
| &nbsp; split | 0.23 | 0.2 |
| &nbsp; criteria + target spacing | 1.02 | 0.7 |
| &nbsp; update systems before/after | 2.01 | 1.4 |
| &nbsp; rest | 0.67 | 0.5 |
| **update callback** | **17.25** | **12.4** |
| &nbsp; PST (update shifting) | 5.43 | 3.9 |
| &nbsp; update systems and nhs | 10.01 | 7.2 |
| &nbsp; open boundary | 1.81 | 1.3 |
| &nbsp; rest | 0.00 | 0.0 |
| **drift** | **0.12** | **0.1** |
| **time integration and rest** | **3.00** | **2.2** |

### ratio4_tree_pruned, developed

- vortex_street small, tree_pruned, tspan=(0.0, 9.0) spacing_ratio=4, shifting fast, refinement/benchmark 92fef57, PointNeighbors ef/tree-parallel 4842a89, 8 threads
- 3 clean of 3 runs, other load 0.0, 0.0, 0.0 cores, t = 4.001 to 4.060
- 21600 to 22573 fluid particles, 6.60 RHS/step, RHS 26.85 ms, 1.189 us per fluid particle, 397 s per simulated time
- step time: median 234.87 ms, minimum 230.93 ms

| section | ms per step | % of step |
|---|---|---|
| **RHS** | **176.79** | **75.3** |
| &nbsp; interaction fluid-fluid | 56.91 | 24.2 |
| &nbsp; interaction other pairs | 12.55 | 5.3 |
| &nbsp; density | 42.71 | 18.2 |
| &nbsp; avg. pressure + beta | 43.40 | 18.5 |
| &nbsp; update nhs | 10.95 | 4.7 |
| &nbsp; boundary pressure | 3.19 | 1.4 |
| &nbsp; characteristics | 5.29 | 2.3 |
| &nbsp; rest | 1.80 | 0.8 |
| **refinement** | **28.65** | **12.2** |
| &nbsp; shift: compute shift | 14.98 | 6.4 |
| &nbsp; shift: apply shift | 2.70 | 1.1 |
| &nbsp; shift: rest | 2.03 | 0.9 |
| &nbsp; merge | 2.85 | 1.2 |
| &nbsp; split | 0.28 | 0.1 |
| &nbsp; criteria + target spacing | 1.71 | 0.7 |
| &nbsp; update systems before/after | 3.13 | 1.3 |
| &nbsp; rest | 0.96 | 0.4 |
| **update callback** | **25.98** | **11.1** |
| &nbsp; PST (update shifting) | 8.06 | 3.4 |
| &nbsp; update systems and nhs | 15.62 | 6.6 |
| &nbsp; open boundary | 2.30 | 1.0 |
| &nbsp; rest | 0.01 | 0.0 |
| **drift** | **0.53** | **0.2** |
| **time integration and rest** | **2.91** | **1.2** |
