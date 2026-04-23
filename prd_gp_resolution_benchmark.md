# PRD: GP Grid Resolution Benchmarking Experiment

## Problem Statement

When fitting an LGCP + self-exciting point process model to whale call data, the choice of GP grid resolution (`sback`) and range parameter (`rho`) directly affects both computational cost and ecological inference. If the GP background rate is too coarse, it cannot capture rapid temporal variation in calling behavior (e.g., diel patterns), and that unmodeled variation leaks into the self-exciting component — inflating the branching ratio `alpha` and creating the appearance of social excitation that may be a model artifact. Conversely, an overly fine GP can absorb genuine excitation signal into the background, masking real communication.

Previous runs on a full year of data (~36,000 calls) took weeks on a cluster, which is infeasible for practical use. The current 6-month dataset (~half the calls) is more tractable, but the relationship between grid resolution, computational time, and parameter recovery is unknown. This is a methods paper, so characterizing these tradeoffs — and establishing what is feasible on a laptop vs. a cluster — is central to the contribution.

## Solution

Design and run a systematic benchmarking experiment that varies `sback` and `rho` across a structured grid, measuring:

1. **Computational cost**: Wall-clock time per MCMC iteration at each configuration.
2. **Ecological inference**: How posterior estimates of key parameters (`alpha`, `eta`, `delta`, `beta`) shift across grid resolutions — specifically, where background signal migrates into the excitation component and vice versa.
3. **Feasibility boundaries**: Which configurations are feasible within a 3-5 day fitting budget on a cluster, and which (if any) are feasible on a laptop with a temporal subset of data.

The experiment uses a 2-arm design with fixed `rho` per arm:

**Arm 1: `rho = 60` min (effective range = 180 min)**

| Level | `sback` (min) | ~Knots (6-month) |
|-------|---------------|-------------------|
| Fine | 30 | ~6,133 |
| Medium | 60 | ~3,067 |
| Coarse | 120 | ~1,533 |
| Very coarse | 180 | ~1,022 |

**Arm 2: `rho = 30` min (effective range = 90 min)**

| Level | `sback` (min) | ~Knots (6-month) |
|-------|---------------|-------------------|
| Fine | 15 | ~12,267 |
| Medium | 30 | ~6,133 |
| Coarse | 60 | ~3,067 |
| Very coarse | 90 | ~2,044 |

All runs share the same harmonic structure (daily, weekly, biweekly, monthly, bimonthly), priors, MCMC settings, and initial values.

## User Stories

1. As a researcher, I want to run a single script that fits the LGCP model at a specified `(rho, sback)` combination, so that I can benchmark different configurations independently.
2. As a researcher, I want Phase 1 (timing-only, ~1000 iterations) to complete quickly, so that I can assess feasibility before committing to a full run.
3. As a researcher, I want Phase 2 (full MCMC chain) to run conditionally after Phase 1, so that I can get posterior estimates within my 3-5 day time budget.
4. As a researcher, I want to submit all 8 configurations as a SLURM array job, so that they run in parallel on the cluster without manual intervention.
5. As a researcher, I want structured output directories (e.g., `fit/benchmark/rho60_sback120/`), so that results from different configurations are organized and easy to compare.
6. As a researcher, I want diagnostic plots of the harmonic design matrix at each `sback` resolution, so that I can visually verify where the daily cycle degrades due to insufficient grid resolution.
7. As a researcher, I want a summary script that loads results from all configurations and produces comparison tables and plots, so that I can assess the tradeoff between computational cost and parameter recovery.
8. As a researcher, I want to see how posterior `alpha` (branching ratio) changes across grid resolutions, so that I can identify where unmodeled background variation leaks into the excitation component.
9. As a researcher, I want to see how posterior `delta` (GP variance) changes across grid resolutions, so that I can understand how much flexibility the GP is given at each resolution.
10. As a researcher, I want to see how posterior `eta` (decay rate) and `beta` (harmonic coefficients) change across resolutions, so that I have a complete picture of parameter sensitivity.
11. As a researcher, I want the benchmarking script to support a laptop mode with temporal subsets (e.g., 1 month, 3 months), so that I can characterize what is feasible without a cluster.
12. As a researcher, I want timing results reported as time-per-iteration and projected total time for a target iteration count, so that I can plan runs within my 3-5 day budget.
13. As a researcher, I want to run multiple chains in production (after benchmarking identifies the best configuration), so that I can assess convergence with independent chains.
14. As a researcher preparing a methods paper, I want to present clear figures showing computational cost vs. ecological inference quality, so that readers can make informed choices about grid resolution for their own datasets.
15. As a researcher preparing a methods paper, I want to include a "laptop feasibility" analysis, so that readers without cluster access understand what subset sizes and resolutions are accessible to them.

## Implementation Decisions

### Module structure

Five new modules will be added to the project:

1. **Experiment configuration module** (`src/benchmark_config.R`): Defines the 2x4 grid of `(rho, sback)` combinations. Maps SLURM array task IDs (1-8) to specific combos. Sets the shared harmonic periods (daily=1440, weekly=10080, biweekly=20160, monthly=43200, bimonthly=86400 minutes). Imports shared constants from `src/config.R` (priors, MCMC settings, data paths, analysis window) rather than duplicating them.

2. **Benchmarking driver** (`src/benchmark_fit.R`): The main fitting script, parameterized by `(rho, sback)` via SLURM array index or command-line argument. Phase 1: runs 1000 MCMC iterations, records wall-clock time per iteration, saves timing results, and exits. Phase 2: if invoked with a flag (e.g., `--full`), runs a full MCMC chain (iteration count derived from the Phase 1 timing estimate and the 3-5 day budget). Saves posteriors in structured output directories. Reuses the existing `fitLGCPSE` C++ function — no changes to the MCMC sampler itself.

3. **Harmonic diagnostic plots** (`src/benchmark_diagnostics.R`): For each `sback` in the experiment grid, constructs the design matrix at that resolution and plots all 5 harmonic components over time. Produces a multi-panel figure showing where the daily cycle becomes under-resolved. This is a standalone script that does not require fitting.

4. **Cross-configuration summary** (`src/benchmark_summary.R`): Loads Phase 1 timing results and Phase 2 posteriors from all 8 configurations. Produces: (a) timing table and plot (time/iteration vs. `sback`, faceted by `rho`); (b) parameter forest plots showing posterior credible intervals for `alpha`, `eta`, `delta`, and each `beta` coefficient across all configurations; (c) signal leakage analysis — ratio of estimated background vs. excitation event counts across resolutions.

5. **SLURM submission script** (`aci_benchmark.sh`): Array job (1-8) dispatching all configurations. Same resource allocation as existing `aci_com.sh` (128GB, 21-day limit). Each array task sources `benchmark_config.R` to look up its `(rho, sback)` combo.

### Laptop mode

The benchmarking driver will accept an optional temporal subset parameter (e.g., `--months 1` or `--months 3`) that truncates the analysis window accordingly. This allows running the same experiment grid on a laptop with smaller data. The subset is applied by adjusting `analysis_end` relative to `std` — no separate data files needed.

### Harmonics

All runs use the same 5 harmonic periods regardless of `sback` and `rho`:
- Daily (1,440 min)
- Weekly (10,080 min)
- Biweekly (20,160 min)
- Monthly (43,200 min)
- Bimonthly (86,400 min)

This is an expansion from the current 4-harmonic set (weekly, biweekly, monthly, bimonthly). The daily harmonic is new and ecologically important for capturing diel calling patterns.

### Constraints enforced

The configuration module will validate that each `(rho, sback)` combo satisfies:
- `sback < rho * 3` (GP must correlate across at least one grid cell)
- `rho * 3 < 1440` (effective range smaller than shortest harmonic period = daily)

### Output structure

```
fit/benchmark/
  rho60_sback030/
    phase1_timing.RData
    phase2_fit.RData
  rho60_sback060/
    ...
  rho30_sback015/
    ...
fig/benchmark/
  harmonic_resolution.pdf
  timing_comparison.pdf
  parameter_comparison.pdf
  signal_leakage.pdf
```

### What is NOT changed

- The C++ MCMC sampler (`RcppFtns.cpp`) is not modified
- The existing `02_fitLGCPSE.R` and `config.R` are not modified
- Priors, adaptive MCMC settings, and initial value strategy remain identical across all runs

## Testing Decisions

No formal automated tests for this experiment. Validation is through:
- Harmonic diagnostic plots (visual verification that the design matrix faithfully represents each harmonic at a given `sback`)
- Phase 1 timing sanity checks (time/iteration should scale roughly as O(m^3) with knot count)
- Phase 2 posterior trace plots (standard MCMC diagnostics)
- Cross-configuration parameter comparisons (the primary scientific output)

## Out of Scope

- Modifications to the C++ MCMC sampler (e.g., sparse matrix approximations, parallelization of the LGCP sampler)
- Model selection or DIC comparison across configurations (this is about characterizing sensitivity, not picking a winner)
- Formal convergence diagnostics (e.g., Gelman-Rubin across multiple chains) — one chain per configuration is sufficient for benchmarking; multi-chain production runs are a follow-up
- Varying other model parameters (priors, `adaptInterval`, initial values) across configurations
- NHPP model benchmarking (this experiment is LGCP-only)

## Further Notes

- The key scientific insight motivating this work: at coarse GP resolutions, the model may misattribute background heterogeneity as social excitation (inflated `alpha`). This is not just a computational concern — it affects ecological conclusions about whale communication behavior.
- The constraint that `rho * 3` must be less than the shortest harmonic period (1440 min = daily) means `rho` is capped at ~480 min. The two arms (`rho = 30`, `rho = 60`) are well within this.
- Previous experience with the full-year dataset (~36,000 calls) showed that fitting took weeks. The 6-month dataset should be roughly half the cost per iteration (fewer events in the likelihood), but the matrix operations scale with knot count, not event count.
- The "laptop feasibility" story is important for the methods paper audience. The message: you can fit this on a laptop for a small temporal subset, but 6-month datasets require a cluster. The experiment quantifies exactly where that boundary lies.
