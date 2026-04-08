# GP Resolution Benchmark — Processing Workflow

## Overview

This experiment measures the tradeoff between GP grid resolution (`sback`), computational cost, and ecological inference in the LGCP+SE model. It runs 8 configurations (2 `rho` values × 4 `sback` levels) and compares timing and posterior parameter estimates.

### Experiment Grid

| Combo | rho (min) | sback (min) | Eff. range | ~Knots (7-mo) |
|-------|-----------|-------------|------------|----------------|
| 1     | 60        | 30          | 180 min    | ~6,133         |
| 2     | 60        | 60          | 180 min    | ~3,067         |
| 3     | 60        | 120         | 180 min    | ~1,533         |
| 4     | 60        | 180         | 180 min    | ~1,022         |
| 5     | 30        | 15          | 90 min     | ~12,267        |
| 6     | 30        | 30          | 90 min     | ~6,133         |
| 7     | 30        | 60          | 90 min     | ~3,067         |
| 8     | 30        | 90          | 90 min     | ~2,044         |

Harmonics adapt to the analysis window length (minimum 3 full cycles required):
- **Full 7 months** (cluster): daily, weekly, biweekly, monthly, bimonthly
- **3 months** (laptop): daily, weekly, biweekly, monthly
- **1 month** (laptop): daily, weekly

---

## Step 0: Prepare Data (local)

The data file `data/nopp.RData` should already exist. If not, regenerate it:

```bash
Rscript data.R
```

Verify:
```r
load('data/nopp.RData')
ls()            # should show: data, noise
length(data$ts) # number of whale calls
range(data$ts)  # time span in minutes
```

This single data file is used for all runs. The `--months` flag subsets it by adjusting the analysis window — no separate data files are needed.

---

## Step 1: Harmonic Diagnostic Plots (local, no fitting)

Before running anything on the cluster, verify that the harmonic design matrix is well-resolved at each `sback` level.

```bash
Rscript src/benchmark_diagnostics.R
```

**Outputs** (in `fig/benchmark/`):
- `harmonic_resolution_short.pdf` — daily and weekly harmonics overlaid at each sback vs. 1-min reference
- `harmonic_daily_zoom.pdf` — 48-hour zoom on the daily cycle with knot points marked
- `harmonic_all_grid.pdf` — full facet grid (harmonics × sback values)
- `grid_resolution_summary.csv` — table of knot counts and whether daily is resolved

**What to check:** The daily harmonic needs ~6+ points per cycle to be faithfully represented. At `sback=180` you get 8 points per daily cycle (adequate). At `sback=90` you get 16 (comfortable).

---

## Step 2: Laptop Benchmark (local)

Run a quick timing test locally with a 1-month subset to sanity-check everything before going to the cluster.

```bash
# Phase 1 timing, 1-month subset, single combo
Rscript src/benchmark_fit.R --combo=2 --months=1

# Try a few combos to see local scaling
Rscript src/benchmark_fit.R --combo=3 --months=1
Rscript src/benchmark_fit.R --combo=7 --months=1
```

Note: with `--months=1`, only daily and weekly harmonics are included (longer periods don't have enough cycles). This means laptop and cluster results aren't directly comparable on parameter estimates — but timing-per-iteration is still informative for the feasibility story.

To run a full laptop chain (if timing looks reasonable):

```bash
Rscript src/benchmark_fit.R --combo=3 --months=1 --full
```

---

## Step 3: Move to Cluster

Copy the repo to the cluster:

```bash
rsync -avz --exclude='fit/' --exclude='fig/' \
  /path/to/sne_ns01/ rss10@dcc-login.oit.duke.edu:/work/rss10/sne_ns01/
```

(Exclude `fit/` and `fig/` if you don't want to transfer large local outputs. The cluster will generate its own in `/work/rss10/sne_ns01/fit/benchmark/`.)

Make sure `data/nopp.RData` is included in the transfer.

---

## Step 4: Phase 1 — Timing Characterization (cluster)

Run 1000 iterations at each of the 8 configurations:

```bash
sbatch aci_benchmark.sh
```

This submits an 8-task array job. Each task runs 1000 MCMC iterations and saves timing. Should complete in minutes to hours depending on the combo.

**Outputs** (in `fit/benchmark/rho*_sback*/`):
- `phase1_timing.RData` — time per iteration, projected iterations within 3- and 5-day budgets

**Monitor:**
```bash
sacct -j <JOBID> --format=JobID,Elapsed,State
cat out/bench_<JOBID>-<ARRAYID>.log
```

---

## Step 5: Review Phase 1 Results

Pull timing results back locally (or run summary on the cluster):

```bash
Rscript src/benchmark_summary.R
```

At this stage only timing outputs are produced:

- `fig/benchmark/timing_summary.csv` — raw timing data
- `fig/benchmark/timing_comparison.pdf` — time/iteration vs. knot count (log-log)
- `fig/benchmark/budget_feasibility.pdf` — max iterations in 3/5-day budgets vs. 150k target

**Decision point:** If a combo can't reach ~100k iterations in 5 days, it's probably not worth running Phase 2 for. If it hits 150k+ in 3 days, it's comfortably within budget.

---

## Step 6: Phase 2 — Full MCMC Chains (cluster)

Run full chains for all combos (or a subset based on Phase 1):

```bash
# All 8 combos
sbatch aci_benchmark.sh --full

# Or skip infeasible combos
sbatch --array=2,3,4,6,7,8 aci_benchmark.sh --full
```

Each job calculates its iteration count to fill a 3-day wall-clock budget (floored to nearest 1000, minimum 10,000). The 5-day SLURM limit provides headroom.

Phase 2 picks up from Phase 1 state — nothing is wasted. Checkpoints save every 1000 iterations.

**Outputs** (in `fit/benchmark/rho*_sback*/`):
- `phase2_fit.RData` — full posterior samples, branching structure, GP values, acceptance rates

---

## Step 7: Full Summary and Comparison

Once Phase 2 jobs complete, pull results locally and run:

```bash
Rscript src/benchmark_summary.R
```

**All outputs** (in `fig/benchmark/`):

| File | Description |
|------|-------------|
| `timing_summary.csv` | Raw timing data for all combos |
| `timing_comparison.pdf` | Log-log: time/iteration vs. knots |
| `budget_feasibility.pdf` | Bar chart: max iterations in 3/5-day budgets |
| `posterior_summary.csv` | Posterior summaries across all combos |
| `parameter_comparison.pdf` | Forest plot: alpha, eta, delta across resolutions |
| `covariate_comparison.pdf` | Forest plot: all beta coefficients |
| `signal_leakage.pdf` | Alpha vs. delta scatterplot |

---

## Key Figures for the Paper

1. **`harmonic_daily_zoom.pdf`** — motivates the need for fine grids to resolve diel patterns
2. **`timing_comparison.pdf`** — shows computational scaling with grid resolution
3. **`budget_feasibility.pdf`** — which configs are practical within a time budget
4. **`parameter_comparison.pdf`** — how alpha/eta/delta shift with resolution
5. **`signal_leakage.pdf`** — the central result: signal transfer between GP background and excitation as resolution changes

---

## File Inventory

```
src/
  config.R                # Production config (datai='nopp', 4 harmonics)
  benchmark_config.R      # Experiment grid, CLI parsing, adaptive harmonics
  benchmark_fit.R         # Phase 1 + Phase 2 fitting driver
  benchmark_diagnostics.R # Harmonic resolution verification plots
  benchmark_summary.R     # Cross-configuration comparison and plots

aci_benchmark.sh          # SLURM array job (8 combos)

data/
  nopp.RData              # Full 7-month dataset (used by all runs)

fit/benchmark/            # Fitting outputs
  rho60_sback030/
    phase1_timing.RData
    phase2_fit.RData
  rho60_sback060/
  ...

fig/benchmark/            # Figures and tables
  harmonic_*.pdf
  timing_*.pdf / *.csv
  budget_feasibility.pdf
  parameter_comparison.pdf
  covariate_comparison.pdf
  signal_leakage.pdf
  posterior_summary.csv
```

---

## Troubleshooting

**Phase 1 is very slow for fine grids (combo 1 or 5):**
The covariance matrix operations (`solve()`, `chol()`) scale as O(m³). Combo 5 (sback=15, ~12k knots) may take several minutes just for the matrix setup. This is expected and is itself a useful data point.

**Phase 2 runs out of time:**
The 5-day SLURM limit should accommodate the 3-day MCMC budget plus overhead. If a job is killed, the last checkpoint is in `phase2_fit.RData` — it's saved every 1000 iterations.

**Missing noise data at knot locations:**
The fitting script joins noise data to knot times via `left_join`. If `sback` is very fine, some knot times may not have exact matches. Check for NAs in the log output.

**Laptop harmonics differ from cluster harmonics:**
This is expected. With `--months=1`, only daily and weekly harmonics are included (monthly/bimonthly need ≥3 cycles). The design matrix will have fewer columns, so posterior parameter vectors are not directly comparable across different window lengths. Timing comparisons are still valid.

**Running on a different cluster:**
Edit `aci_benchmark.sh` to match your cluster's module system and partition names. The R scripts are cluster-agnostic.
