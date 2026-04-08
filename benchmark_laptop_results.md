# Laptop Benchmark Results (1-month subset)

**Date:** 2026-04-08
**Data:** 6733 events, 27.7 days
**Harmonics:** 2 (daily, weekly)

## Timing Summary

| Combo | rho (min) | sback (min) | Knots | Cov matrix (sec) | Time/iter (sec) | Iters/hour | Iters in 3 days | Iters in 5 days |
|-------|-----------|-------------|-------|------------------|-----------------|------------|-----------------|-----------------|
| 1 | 60 | 30 | 1331 | 1.5 | 0.1275 | 28,237 | 2,033,037 | 3,388,395 |
| 2 | 60 | 60 | 666 | 0.2 | 0.1288 | 27,942 | 2,011,798 | 3,352,996 |
| 3 | 60 | 120 | 333 | 0.1 | 0.1299 | 27,704 | 1,994,721 | 3,324,535 |
| 4 | 60 | 180 | 222 | 0.1 | 0.1289 | 27,936 | 2,011,360 | 3,352,267 |
| 5 | 30 | 15 | 2662 | 10.5 | 0.1411 | 25,508 | 1,836,552 | 3,060,921 |
| 6 | 30 | 30 | 1331 | 1.4 | 0.1350 | 26,665 | 1,919,886 | 3,199,810 |
| 7 | 30 | 60 | 666 | 0.2 | 0.1257 | 28,651 | 2,062,873 | 3,438,122 |
| 8 | 30 | 90 | 444 | 0.1 | 0.1248 | 28,835 | 2,076,091 | 3,460,152 |

## Observations

- Covariance matrix setup scales with knot count (O(m³)), but is a one-time cost.
- Per-iteration cost is dominated by the event likelihood, not grid resolution.
- All combos are laptop-feasible for 1-month data.

