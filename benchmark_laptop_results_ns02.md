# Laptop Benchmark Results — NS02 (1-month subset)

**Date:** 2026-04-08
**Data:** 239 events, 29.8 days
**Harmonics:** 2 (daily, weekly)

## Timing Summary

| Combo | rho (min) | sback (min) | Knots | Cov matrix (sec) | Time/iter (sec) | Iters/hour | Iters in 3 days | Iters in 5 days |
|-------|-----------|-------------|-------|------------------|-----------------|------------|-----------------|-----------------|
| 1 | 60 | 30 | 1432 | 1.8 | 0.0033 | 1,078,490 | 77,651,288 | 129,418,814 |
| 2 | 60 | 60 | 716 | 0.2 | 0.0011 | 3,299,725 | 237,580,202 | 395,967,003 |
| 3 | 60 | 120 | 358 | 0.0 | 0.0005 | 6,581,353 | 473,857,404 | 789,762,340 |
| 4 | 60 | 180 | 239 | 0.0 | 0.0003 | 11,842,105 | 852,631,579 | 1,421,052,632 |
| 5 | 30 | 15 | 2863 | 12.8 | 0.0143 | 251,678 | 18,120,805 | 30,201,342 |
| 6 | 30 | 30 | 1432 | 1.7 | 0.0032 | 1,122,544 | 80,823,199 | 134,705,332 |
| 7 | 30 | 60 | 716 | 0.2 | 0.0010 | 3,464,870 | 249,470,645 | 415,784,408 |
| 8 | 30 | 90 | 478 | 0.1 | 0.0007 | 4,986,150 | 359,002,770 | 598,337,950 |

## Observations

- Covariance matrix setup scales with knot count (O(m³)), but is a one-time cost.
- Per-iteration cost is dominated by the event likelihood, not grid resolution.
- All combos are laptop-feasible for 1-month data.

