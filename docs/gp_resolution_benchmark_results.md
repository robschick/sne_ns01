# GP Grid Resolution Benchmark — Results Summary (NS01)

How coarsening the LGCP Gaussian-process grid (`sback`) and changing its range
(`rho`) affect run time and inference in the LGCP + self-exciting (Hawkes) model.

## Where the experiment lives

| What | File |
|---|---|
| Design / PRD | `prd_gp_resolution_benchmark.md` |
| Experiment grid + adaptive harmonics | `src/benchmark_config.R` |
| Fitting driver (Phase 1 timing, Phase 2 full chain) | `src/benchmark_fit.R`, `aci_benchmark.sh` (SLURM array 1–8) |
| How-to-run | `benchmark_workflow.md` |
| Results (CSVs + figures) | `fig/ns01/benchmark/` (`timing_summary.csv`, `posterior_summary.csv`, `convergence_diagnostics.csv`, `*.pdf`) |
| Original write-up | `benchmark_report.Rmd` / `.pdf` (see caveat below) |
| Laptop timing (subsets, per buoy) | `benchmark_laptop_results_{ns01,ns02,cox01}.md` |

## Design

Two arms with `rho` held fixed in each; `sback` varied over four levels. Effective
GP range = 3·`rho`. Constraints: `sback` ≤ 3·`rho`, and 3·`rho` < 1,440 min (the
GP range stays below the daily harmonic period so the GP cannot absorb the diel cycle).

| Arm | `rho` (min) | Eff. range (min) | `sback` levels (min), fine → coarse |
|---|---|---|---|
| 1 | 60 | 180 | 30, 60, 120, 180 |
| 2 | 30 | 90 | 15, 30, 60, 90 |

- **Data:** NS01, 5-month window (Oct 1 2021 → Mar 1 2022, 151 days), 13,017 calls.
- **Phase 1:** 1,000 MCMC iterations per configuration → per-iteration time and
  one-time covariance-matrix setup time.
- **Phase 2:** 101,000-iteration chain per configuration; first 1/3 discarded as
  burn-in (67,334 retained samples).
- **Design matrix:** 11 columns: intercept, noise, SST, and sin/cos pairs for 4
  harmonics (daily, weekly, biweekly, monthly). The benchmark keeps a harmonic only
  if the window holds ≥ 3 full cycles. The bimonthly period (86,400 min) needs
  259,200 min but the 5-month window is 217,440 min, so the benchmark dropped it.
  See [Production harmonics](#production-harmonics) for how this differs from production.

## Timing results

| `rho` | `sback` | Knots (m) | Cov. setup (s, one-time) | s / iter | Iters / hr |
|---|---|---|---|---|---|
| 60 | **30** (finest) | 7,248 | 492.0 | 2.01 | 1,791 |
| 60 | 60 | 3,624 | 64.3 | 1.87 | 1,927 |
| 60 | 120 | 1,812 | 8.6 | 1.83 | 1,967 |
| 60 | **180** (coarsest) | 1,208 | 2.8 | 1.79 | 2,011 |
| 30 | **15** (finest) | 14,496 | 2,445.7 | 2.39 | 1,507 |
| 30 | 30 | 7,248 | 316.1 | 1.92 | 1,879 |
| 30 | 60 | 3,624 | 38.2 | 1.68 | 2,144 |
| 30 | **90** (coarsest) | 2,416 | 11.9 | 1.64 | 2,193 |

### Baseline vs. coarsened

Within each arm the baseline is the finest grid and the coarsened run is the
coarsest. Both arms span a 6× reduction in knot count.

| Arm | Baseline → coarsened | Knots | s / iter | Per-iter speed-up | Cov. setup | 100k iters (est.) |
|---|---|---|---|---|---|---|
| `rho` = 30 | `sback` 15 → 90 | 14,496 → 2,416 | 2.39 → 1.64 | **~31%** | 2,446 s → 12 s (~205× faster) | ~66 h → ~46 h |
| `rho` = 60 | `sback` 30 → 180 | 7,248 → 1,208 | 2.01 → 1.79 | ~11% | 492 s → 3 s (~178× faster) | ~56 h → ~50 h |

**Takeaways**

- Coarsening the grid by 6× reduced per-iteration time by **~31%** in the
  `rho` = 30 arm and ~11% in the `rho` = 60 arm. Per-iteration cost scales only
  weakly with knot count because the event likelihood dominates it, not the GP.
- The covariance-matrix setup scales roughly as O(m³) and shrinks by two orders
  of magnitude. It is a one-time cost per chain, so it has little effect on total
  run time.
- Overall, grid resolution is a modest lever on wall-clock time. Event count and
  chain length matter more.

## Inference results (posterior means, 95% interval)

| `rho` | `sback` | α (branching ratio) | η (decay) | δ (log GP var.) |
|---|---|---|---|---|
| 60 | 30 | 0.227 (0.212–0.241) | 0.366 | 0.631 |
| 60 | 60 | 0.237 (0.223–0.252) | 0.363 | 0.761 |
| 60 | 120 | 0.234 (0.221–0.248) | 0.327 | 0.838 |
| 60 | 180 | 0.235 (0.221–0.249) | 0.313 | 0.906 |
| 30 | 15 | 0.180 (0.169–0.191) | 0.206 | 0.418 |
| 30 | 30 | 0.206 (0.191–0.221) | 0.259 | 0.571 |
| 30 | 60 | 0.231 (0.217–0.246) | 0.336 | 0.813 |
| 30 | 90 | 0.233 (0.219–0.247) | 0.332 | 0.911 |

- **`rho` = 60:** α is essentially flat across `sback` (0.227–0.237, overlapping
  intervals).
- **`rho` = 30:** α rises from 0.180 to 0.233 as the grid coarsens. Fine-scale
  background structure that the coarser GP cannot resolve is absorbed by the Hawkes
  component (signal leakage). δ rises along with it, because a coarser GP needs
  more marginal variance to fit the same data.
- The ecological reading does not change: about 20–24% of calls are triggered by a
  preceding call.
- **Mixing:** α ESS is 399–1,008 (adequate). δ ESS is 19–123 (poor, a structural
  consequence of the single-site δ/W updates). η ESS is 100–637. See
  `convergence_diagnostics.csv`.

## Production harmonics

Production (`src/config.R`, `harm_periods_lgcp`) uses **5 harmonic periods**, each
contributing one sin and one cos column. With intercept, noise, and SST, the
design matrix has 13 columns. The seasonal spline is OFF for all three buoys.

| Harmonic | Period (min) | Cycles in 5-month window (151 d) |
|---|---|---|
| Daily | 1,440 | ~151 |
| Weekly | 10,080 | ~21.6 |
| Biweekly | 20,160 | ~10.8 |
| Monthly (30 d) | 43,200 | ~5.0 |
| Bimonthly (60 d) | 86,400 | ~2.5 |

Production differs from this benchmark in two ways: it keeps the bimonthly
harmonic (under 3 cycles at 5 months), and it uses `rho` = 60 with `sback` = 20.
That `sback` was not one of the benchmarked levels.
The cycle-count comments in `config.R` (e.g. "~212 cycles") still describe the old
7-month window.

## Caveats

- **The `benchmark_report.pdf` prose is out of date.** It was written for an
  earlier 7-month run: 22,787 events, 5.7–7.1 s/iter, chains cut off at
  58k–80k iterations, and α between 0.186 and 0.226. The CSVs in
  `fig/ns01/benchmark/` (dated 2026-06-24) are from the 5-month rerun summarized
  here. Re-knitting the Rmd refreshes its tables, but the numbers hard-coded in its
  text will still be the old ones.
- The timing CSV does not record whether Phase 1 ran on the laptop or on a cluster
  node. Use the relative speed-ups; treat absolute seconds per iteration as
  hardware-specific.
- The `benchmark_laptop_results_*.md` files are labelled "1-month subset", but their
  headers report spans of 30–88 days.
