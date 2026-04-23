# Laptop Benchmark Results — NS01 (1-month subset)

**Date:** 2026-04-14
**Data:** 871 events, 75.2 days
**Harmonics:** 2 (daily, weekly)

## Timing Summary

| Combo | rho (min) | sback (min) | Knots | Cov matrix (sec) | Time/iter (sec) | Iters/hour | Iters in 3 days | Iters in 5 days |
|-------|-----------|-------------|-------|------------------|-----------------|------------|-----------------|-----------------|
| 1 | 60 | 30 | 3608 | 23.7 | 0.0267 | 134,771 | 9,703,504 | 16,172,507 |
| 2 | 60 | 60 | 1804 | 3.0 | 0.0074 | 487,475 | 35,098,172 | 58,496,953 |
| 3 | 60 | 120 | 902 | 0.4 | 0.0041 | 875,486 | 63,035,019 | 105,058,366 |
| 4 | 60 | 180 | 602 | 0.1 | 0.0031 | 1,162,040 | 83,666,882 | 139,444,803 |
| 5 | 30 | 15 | 7216 | 162.8 | 0.1383 | 26,025 | 1,873,821 | 3,123,035 |
| 6 | 30 | 30 | 3608 | 19.9 | 0.0276 | 130,563 | 9,400,500 | 15,667,501 |
| 7 | 30 | 60 | 1804 | 2.6 | 0.0075 | 482,833 | 34,763,948 | 57,939,914 |
| 8 | 30 | 90 | 1203 | 0.8 | 0.0045 | 792,952 | 57,092,511 | 95,154,185 |

## Observations

- Covariance matrix setup scales with knot count (O(m³)), but is a one-time cost.
- Per-iteration cost is dominated by the event likelihood, not grid resolution.
- All combos are laptop-feasible for 1-month data.

