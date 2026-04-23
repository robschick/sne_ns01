# Laptop Benchmark Results — COX01 (1-month subset)

**Date:** 2026-04-08
**Data:** 100 events, 87.6 days
**Harmonics:** 2 (daily, weekly)

## Timing Summary

| Combo | rho (min) | sback (min) | Knots | Cov matrix (sec) | Time/iter (sec) | Iters/hour | Iters in 3 days | Iters in 5 days |
|-------|-----------|-------------|-------|------------------|-----------------|------------|-----------------|-----------------|
| 1 | 60 | 30 | 4207 | 36.8 | 0.0356 | 101,087 | 7,278,241 | 12,130,402 |
| 2 | 60 | 60 | 2104 | 4.6 | 0.0072 | 499,861 | 35,990,003 | 59,983,338 |
| 3 | 60 | 120 | 1052 | 0.6 | 0.0018 | 1,974,767 | 142,183,214 | 236,972,024 |
| 4 | 60 | 180 | 702 | 0.2 | 0.0009 | 4,114,286 | 296,228,571 | 493,714,286 |
| 5 | 30 | 15 | 8414 | 260.1 | 0.1989 | 18,096 | 1,302,879 | 2,171,465 |
| 6 | 30 | 30 | 4207 | 30.2 | 0.0358 | 100,469 | 7,233,758 | 12,056,263 |
| 7 | 30 | 60 | 2104 | 3.9 | 0.0073 | 495,186 | 35,653,370 | 59,422,283 |
| 8 | 30 | 90 | 1403 | 1.2 | 0.0031 | 1,153,107 | 83,023,703 | 138,372,838 |

## Observations

- Covariance matrix setup scales with knot count (O(m³)), but is a one-time cost.
- Per-iteration cost is dominated by the event likelihood, not grid resolution.
- All combos are laptop-feasible for 1-month data.

