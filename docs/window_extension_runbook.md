# Runbook — extend analysis window to Apr 30 2022 + add daily harmonic

Standalone procedure for re-processing the full LGCPSE pipeline after the
**2026-06-24** config change. Run start-to-finish on the Duke Compute Cluster
(DCC) for all three buoys (NS01, NS02, COX01).

## What changed (commit `04e95cb`)

Two edits in `src/config.R`, plus a cosmetic label helper in `src/RFtns.R`:

| File | Change |
|------|--------|
| `src/config.R` | `analysis_end`: `2022-03-01` → **`2022-04-30`** (~7 months / 211 days; NS01/NS02 raw-data limit) |
| `src/config.R` | `harm_periods_lgcp`: added **daily** term (`1 * harm_day_unit` = 1,440 min) as the first period; also added the `harm_day_unit` definition |
| `src/RFtns.R` | `fmt_period()` gains a `day` case so the new term labels as `"1 day"` (not `"1440 min"`) |

Harmonic set is now: **1 day, 1 wk, 2 wk, 1 mo, 2 mo** (5 periods → 10 design columns).

**Why the daily term is safe:** its period (1,440 min) exceeds the GP effective
range (`3 * rho = 180 min`), so the GP cannot absorb the diel signal. The term
targets the diel calling cycle flagged by the RTC Q-Q upper-tail diagnosis.

**Why `01_data.R` must re-run:** the analysis window is applied in `01_data.R`
(it filters raw events/noise to `[std, analysis_end]` and writes
`data/<buoy>.RData`). `02_fitLGCPSE.R` just loads that file, so the new window
only takes effect after `01_data.R` is re-run.

> This **overwrites** all existing `fit/`, `lam/`, `num/`, `rtct/`, and `fig/`
> outputs for the three buoys — intended. The GP-resolution benchmark outputs
> are produced from a separate config and are unaffected.

---

## Files to send to the cluster

The cluster code repo is `sne_dev` at `/hpc/group/schicklab/sne_dev`; fit
outputs go to the work dir `/work/rss10/sne_ns01/`.

**1. Code** — get the config change onto the cluster (preferred: via the
GitHub remote; see below):

```bash
# cluster
cd /hpc/group/schicklab/sne_dev && git pull
```

Changed files in the pull: `src/config.R`, `src/RFtns.R`,
`docs/manuscript_results_workflow.md`, `docs/window_extension_runbook.md`.

**2. Raw data inputs** — `01_data.R` reads these from the repo's `data/` dir.
They don't change with the window, but must be present on the cluster. Verify,
and push from the laptop only if missing:

```bash
# cluster — check
ls data/*_all.rds data/*_rms_data.rds data/sst/
```
```bash
# laptop — push if missing
rsync -avz data/*_all.rds data/*_rms_data.rds \
  rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/data/
rsync -avz data/sst/ \
  rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/data/sst/
```

---

## Run sequence (cluster)

> **Gotcha:** the cluster shell has `BUOY=cox01` exported. `unset BUOY` first,
> and always pass `BUOY=$b` / `--buoy=$b` explicitly.

### Stage 1–4 — rebuild data, fit, derived quantities (automated via SLURM deps)

```bash
cd /hpc/group/schicklab/sne_dev
unset BUOY
mkdir -p out
for b in ns01 ns02 cox01; do
  BUOY=$b Rscript 01_data.R                                       # rebuild data/<buoy>.RData
  fit=$(sbatch --parsable --export=ALL,BUOY=$b aci_fit.sh)        # 02_fitLGCPSE.R (long pole)
  echo "$b fit -> $fit"
  sbatch --dependency=afterok:$fit --export=ALL,BUOY=$b aci_ll.sh     # 03_loglikLGCPSE.R
  sbatch --dependency=afterok:$fit --export=ALL,BUOY=$b aci_lam.sh    # 04_lamLGCPSE.R
  sbatch --dependency=afterok:$fit --export=ALL,BUOY=$b aci_num.sh    # 04_numLGCPSE.R
  sbatch --dependency=afterok:$fit --export=ALL,BUOY=$b aci_rtct.sh   # 04_rtctLGCPSE.R
done
```

Monitor with `squeue -u rss10`. Fit jobs: 128 GB / 21-day walltime. The longer
window pushes the knot count to ~15k, so the one-time `O(m^3)` covariance setup
is a multi-hour cost before sampling starts. MCMC length / burn-in unchanged
(`niters_lgcp = 100000`).

### Stage 5 — tables and figures (after Stage 4 completes)

Run on a **≥64 GB** node — the fit-loading scripts OOM on NS02 otherwise
(`salloc --mem=64G --time=4:00:00`):

```bash
for b in ns01 ns02 cox01; do
  Rscript 03_sumLoglik.R --buoy=$b   # burn-in traceplot
  Rscript 05_sumEstM4.R  --buoy=$b   # coefficient table (incl. "1 day") + CI plot
  Rscript 05_sumLam.R    --buoy=$b   # intensity plots
  Rscript 05_sumNum.R    --buoy=$b   # total / background / counter counts
  Rscript 05_sumRTCT.R   --buoy=$b   # RTC Q-Q  <-- the payoff check for the diel term
  Rscript 05_sumDIC.R    --buoy=$b
  Rscript 05_sumXB.R     --buoy=$b   # ns02: THIN=2000 Rscript 05_sumXB.R --buoy=ns02
done
Rscript 05_sumCombined.R             # cross-buoy tables — NO --buoy
```

Pull figures down to the laptop for the manuscript:

```bash
# laptop
rsync -avz rss10@dcc-login.oit.duke.edu:/work/rss10/sne_ns01/lam/ ./lam/
rsync -avz rss10@dcc-login.oit.duke.edu:/work/rss10/sne_ns01/num/ ./num/
rsync -avz rss10@dcc-login.oit.duke.edu:/work/rss10/sne_ns01/fit/ ./fit/
rsync -avz rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/fig/ ./fig/
```

---

## Validation checks

- After `01_data.R`: console reports the window `2021-10-01 → 2022-04-30` and a
  higher in-window event count than the old 5-month run.
- After `05_sumEstM4.R`: coefficient table has a `1 day` harmonic row (sin+cos).
- After `05_sumRTCT.R`: the RTC Q-Q upper-tail misfit should be reduced relative
  to the pre-diel-harmonic fit (the reason for the change).
