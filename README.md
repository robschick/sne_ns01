# sne_ns01 — LGCPSE pipeline for SNE buoys

End-to-end workflow for fitting a log-Gaussian Cox process with
self-excitement (LGCPSE) to North Atlantic right whale upcall time series
from three buoys in the Southern New England area: **NS01**, **NS02**,
**COX01**. Buoy is the parallelism axis throughout — every script accepts
`--buoy=<ns01|ns02|cox01>` as a command-line argument or `BUOY=<...>` as
an environment variable.

Model constants live in `src/config.R`. Shared post-processing helpers
(batch-means means, HPD intervals, harmonic-period label formatting, etc.)
live in `src/RFtns.R`. Fit loading is factored through `src/load_fit.R`.

---

## Prerequisites

### Raw data files (`data/`, gitignored)

| Buoy  | Call file          | Noise file              |
|-------|--------------------|-------------------------|
| NS01  | `ns_01_all.rds`    | `ns01_rms_data.rds`     |
| NS02  | `ns_02_all.rds`    | `ns02_rms_data.rds`     |
| COX01 | `cox_01_all.rds`   | `cox01_rms_data.rds`    |

Plus, shared across buoys: `data/sst/2025-11-20_SNE_buoys_sst-data.csv`
(one column per buoy).

Exact filenames and per-buoy SST columns are pinned in `buoy_settings` in
`src/config.R`.

### Software

- **R ≥ 4.1** with `coda`, `tidyverse`, `batchmeans`, `xtable`, `Rcpp`,
  `RcppArmadillo`, `spgs`, `foreach`, `doParallel`, `suncalc`.
- A **C++ compiler** (macOS: Xcode Command Line Tools; Linux: gcc
  toolchain).
- A **SLURM cluster** for stages 2 and 4. The `aci_*.sh` scripts assume
  the Duke Computing Cluster module environment (`R/4.1.1-rhel8`,
  `Boost`, `PROJ`, etc.); adapt for other clusters as needed.

---

## Pipeline overview

| Stage | Runs on  | Scripts                           | Produces                       |
|-------|----------|-----------------------------------|--------------------------------|
| 1     | laptop   | `01_data.R`                       | `data/<buoy>.RData`            |
| 2     | cluster  | `02_fitLGCPSE.R`, `03_loglikLGCPSE.R` | fit + post-burn −2 log L   |
| 3     | laptop   | `03_sumLoglik.R`                  | burn-in traceplot              |
| 4     | cluster  | `04_rtctLGCPSE.R`, `04_lamLGCPSE.R`, `04_numLGCPSE.R` | derived posterior quantities |
| 5     | laptop   | `05_sum*.R`                       | figures (PDF) + LaTeX tables   |

Stages 1 and 5 are fast; stages 2 and 4 are MCMC-heavy. Between them,
stage 3 is an interactive human-in-the-loop step: a traceplot tells you
whether the MCMC has burned in enough, and you edit the per-buoy burn
value in `src/config.R` accordingly before proceeding to stage 4. That
feedback loop is why the workflow is split rather than a single
end-to-end `sbatch`.

---

## Getting the code onto the cluster

No git remote is configured out of the box. Either add one and
`git pull` on the cluster, or rsync the tree from the laptop:

```bash
CLUSTER=user@cluster.example.edu   # adjust for your site

rsync -avz --exclude='.git' --exclude='data/' --exclude='fit/' \
      --exclude='loglik/' --exclude='rtct/' --exclude='lam/' \
      --exclude='num/' --exclude='fig/' --exclude='out/' \
      ./ $CLUSTER:sne_ns01/
```

Re-run after every `src/config.R` edit (notably the per-buoy burn values
set in stage 3) so the cluster picks them up.

---

## Stage 1 — build per-buoy input (laptop)

```bash
Rscript 01_data.R --buoy=ns01
Rscript 01_data.R --buoy=ns02
Rscript 01_data.R --buoy=cox01
```

Reads the raw rds + SST files, filters to the analysis window
(Oct 2021 – Apr 2022), writes `data/<buoy>.RData`. Push the results up:

```bash
rsync -avz data/*.RData $CLUSTER:sne_ns01/data/
```

(Alternatively, run `01_data.R` directly on the cluster if the raw rds
files + SST CSV already live there.)

---

## Stage 2 — fit + log-likelihood (cluster)

Two jobs per buoy: the MCMC fit and the posterior −2 log L trace. The
loglik job reads the fit, so chain them with a SLURM `afterok`
dependency:

```bash
for b in ns01 ns02 cox01; do
  fid=$(sbatch --parsable --export=ALL,BUOY=$b aci_fit.sh)
  sbatch --dependency=afterok:$fid --export=ALL,BUOY=$b aci_ll.sh
done
```

That queues three fits (each ~days at `niters_lgcp = 100000`) and three
loglik jobs that fire automatically after their paired fit exits
cleanly.

**Outputs:**

- `fit/<buoy>/<buoy>LGCPSE.RData` on `/work/rss10/sne_ns01/` (scratch),
  auto-mirrored to `/hpc/group/schicklab/sne_ns01/fit/<buoy>/`
  (persistent share).
- `loglik/<buoy>/<buoy>LGCPSE_loglik.RData` on `/work/rss10/sne_ns01/`.

---

## Stage 3 — burn-in feedback loop (laptop)

Pull the fit and loglik files down:

```bash
rsync -avz $CLUSTER:/hpc/group/schicklab/sne_ns01/fit/ ./fit/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/loglik/       ./loglik/
```

Generate the traceplot per buoy and inspect:

```bash
Rscript 03_sumLoglik.R --buoy=ns01   # writes fig/ns01/NegTwoLogLikTrace.pdf
```

If the retained (post-burn) chain is still trending:

1. Raise `buoy_settings$<buoy>$burn` in `src/config.R`.
2. Commit the change.
3. Re-sync the repo to the cluster.
4. Re-run **only `aci_ll.sh`** for the affected buoys — the fit itself
   isn't affected by a burn change, just the post-burn slice.

Repeat until every buoy's traceplot looks stationary.

---

## Stage 4 — derived posterior quantities (cluster)

Three jobs per buoy with no inter-dependencies, so submit them all at
once:

```bash
for b in ns01 ns02 cox01; do
  for s in aci_rtct.sh aci_lam.sh aci_num.sh; do
    sbatch --export=ALL,BUOY=$b $s
  done
done
```

**Outputs:** `rtct/<buoy>/`, `lam/<buoy>/`, `num/<buoy>/` on
`/work/rss10/sne_ns01/`.

---

## Stage 5 — figures and tables (laptop)

Pull stage-4 outputs down, then render everything locally:

```bash
rsync -avz $CLUSTER:/work/rss10/sne_ns01/rtct/ ./rtct/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/lam/  ./lam/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/num/  ./num/

for b in ns01 ns02 cox01; do
  Rscript 05_sumDIC.R   --buoy=$b
  Rscript 05_sumEstM4.R --buoy=$b
  Rscript 05_sumRTCT.R  --buoy=$b
  Rscript 05_sumXB.R    --buoy=$b
  Rscript 05_sumNum.R   --buoy=$b
  Rscript 05_sumLam.R   --buoy=$b
done
```

Outputs (PDFs + `.tex` tables) land in `fig/<buoy>/`.

---

## Storage layout and the 75-day wipe

`/work/rss10/sne_ns01/` is cluster scratch and is **wiped after 75 days**.
`02_fitLGCPSE.R` mirrors each completed fit to
`/hpc/group/schicklab/sne_ns01/fit/<buoy>/` at the end of the MCMC loop
(silent no-op on laptop runs where the share isn't mounted). The
schicklab share is persistent but not off-site — always move fits to the
laptop for long-term safekeeping.

`src/config.R` resolves `path.fit` with a three-tier fallback so the
same code works everywhere:

1. `/work/rss10/sne_ns01/fit/<buoy>/` — cluster scratch (fastest)
2. `/hpc/group/schicklab/sne_ns01/fit/<buoy>/` — persistent share (post-wipe)
3. `./fit/<buoy>/` — laptop after rsync

Every other path (`loglik/`, `lam/`, `rtct/`, `num/`, `fig/`, `data/`) is
always read from and written to the *local* working directory. Rsync
them between laptop and cluster as each stage completes.

---

## Output locations

| Path                            | What it contains                          | Notes                       |
|---------------------------------|-------------------------------------------|-----------------------------|
| `data/<buoy>.RData`             | stage 1 output (calls + noise + SST)      | gitignored                  |
| `fit/<buoy>/<buoy>LGCPSE.RData` | MCMC fit — canonical artifact             | gitignored; preserve off-cluster |
| `loglik/<buoy>/`                | posterior −2 log L trace                  | gitignored; regenerable     |
| `rtct/<buoy>/`                  | random-time-change compensator            | gitignored; regenerable     |
| `lam/<buoy>/`                   | posterior intensity (background/SE/total) | gitignored; regenerable     |
| `num/<buoy>/`                   | posterior expected event counts           | gitignored; regenerable     |
| `fig/<buoy>/`                   | figures (PDF) + LaTeX tables              | gitignored; build product   |

---

## Script naming

Numeric prefixes mark the pipeline stage; scripts with the same prefix
can be run in any order within that stage.

| Prefix | Where            | What                                                    |
|--------|------------------|---------------------------------------------------------|
| `01_`  | laptop           | Build per-buoy `.RData` from raw rds + SST CSV          |
| `02_`  | cluster          | MCMC fit                                                |
| `03_`  | cluster + laptop | Posterior −2 log L (cluster) + burn-in traceplot (laptop) |
| `04_`  | cluster          | Derived posterior quantities: rtct, lam, num            |
| `05_`  | laptop           | Figures and LaTeX tables                                |

`aci_*.sh` are the SLURM wrappers for the cluster-side scripts
(`aci_fit`, `aci_ll`, `aci_rtct`, `aci_lam`, `aci_num`).

`archive/` contains the retired NHPPSE pipeline and sweep-era script
duplicates; `archive/README.md` explains what and why.
