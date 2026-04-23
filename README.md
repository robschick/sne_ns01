# sne_ns01 — LGCPSE pipeline for SNE buoys

End-to-end workflow for fitting a log-Gaussian Cox process with self-excitement
(LGCPSE) to NARW upcall time series from the three SNE buoys: **NS01, NS02,
COX01**. Buoy is the parallel axis throughout — every script accepts
`--buoy=<ns01|ns02|cox01>` or `BUOY=<...>` in the environment.

All model constants live in `src/config.R`. Shared post-processing helpers
(batch-means mean, HPD intervals, harmonic-period label formatting, etc.) live
in `src/RFtns.R`. Fit loading is factored through `src/load_fit.R`.

---

## Prerequisite files

Per buoy, under `data/`:

| Buoy  | Call file          | Noise file              |
|-------|--------------------|-------------------------|
| NS01  | `ns_01_all.rds`    | `ns01_rms_data.rds`     |
| NS02  | `ns_02_all.rds`    | `ns02_rms_data.rds`     |
| COX01 | `cox_01_all.rds`   | `cox01_rms_data.rds`    |

Plus, shared across buoys:

- `data/sst/2025-11-20_SNE_buoys_sst-data.csv` (SST per buoy column).

`data/` is gitignored — these files live outside the repo. The exact filenames
and the SST column per buoy are pinned in `buoy_settings` (`src/config.R`).

---

## Pipeline stages

Each stage runs once per buoy. The cluster stages are one `sbatch` per buoy
(no SLURM arrays — buoy is the parallelism axis).

### 1. Build `data/<buoy>.RData` (local)

```bash
Rscript 01_data.R --buoy=ns01
Rscript 01_data.R --buoy=ns02
Rscript 01_data.R --buoy=cox01
```

Produces `data/ns01.RData`, etc. — these feed every downstream stage.

### 2. Fit + log-likelihood (cluster)

```bash
sbatch --export=ALL,BUOY=ns01  aci_fit.sh   # MCMC fit (02_fitLGCPSE.R)
sbatch --export=ALL,BUOY=ns01  aci_ll.sh    # posterior -2logL (03_loglikLGCPSE.R)
```

`aci_fit.sh` writes `/work/rss10/sne_ns01/fit/<buoy>/<buoy>LGCPSE.RData` and
auto-copies it to `/hpc/group/schicklab/sne_ns01/fit/<buoy>/` (persistent
share — see HPC storage notes below). `aci_ll.sh` writes
`loglik/<buoy>/<buoy>LGCPSE_loglik.RData`.

Repeat for `ns02` and `cox01`.

### 3. Burn-in diagnostic (local, interactive)

Pull the loglik trace back to the laptop (see rsync below), then:

```bash
Rscript 03_sumLoglik.R --buoy=ns01
```

Inspect `fig/ns01/NegTwoLogLikTrace.pdf`. If the trace is still trending,
increase `buoy_settings$ns01$burn` in `src/config.R`, commit the change, and
re-run `aci_ll.sh` on the cluster. Otherwise proceed.

Repeat per buoy.

### 4. Posterior summaries on the cluster

Once burn is locked in, run the three derived-quantity jobs. They all read
the fit via `src/load_fit.R` and apply `buoy_cfg$burn`:

```bash
sbatch --export=ALL,BUOY=ns01 aci_rtct.sh   # 04_rtctLGCPSE.R
sbatch --export=ALL,BUOY=ns01 aci_lam.sh    # 04_lamLGCPSE.R
sbatch --export=ALL,BUOY=ns01 aci_num.sh    # 04_numLGCPSE.R
```

Outputs land in `rtct/<buoy>/`, `lam/<buoy>/`, `num/<buoy>/`.

### 5. Figures + LaTeX tables (local)

Rsync `loglik/ rtct/ lam/ num/ fit/` down to the laptop (see below), then:

```bash
for buoy in ns01 ns02 cox01; do
  Rscript 05_sumDIC.R   --buoy=$buoy
  Rscript 05_sumEstM4.R --buoy=$buoy
  Rscript 05_sumRTCT.R  --buoy=$buoy
  Rscript 05_sumXB.R    --buoy=$buoy
  Rscript 05_sumNum.R   --buoy=$buoy
  Rscript 05_sumLam.R   --buoy=$buoy
done
```

Outputs (PDFs + `.tex` tables) land in `fig/<buoy>/`.

---

## HPC storage: the 75-day wipe

`/work/rss10/sne_ns01/` is cluster scratch and is **wiped after 75 days**.
`02_fitLGCPSE.R` mirrors every completed fit to the persistent share at
`/hpc/group/schicklab/sne_ns01/fit/<buoy>/` at the end of the MCMC loop (this
is a no-op on laptop runs where the share is not mounted). That copy survives
the scratch wipe, but is not off-site — move fits to the laptop for long-term
safekeeping.

`src/config.R` resolves `path.fit` with a three-tier fallback:

1. `/work/rss10/sne_ns01/fit/<buoy>/` — cluster scratch (fastest)
2. `/hpc/group/schicklab/sne_ns01/fit/<buoy>/` — persistent share (post-wipe)
3. `./fit/<buoy>/` — laptop after rsync

Every other output (`loglik/ lam/ rtct/ num/ fig/`) is always read/written
locally — rsync them down after each cluster stage.

### Rsync from cluster to laptop

From the laptop, in the repo root:

```bash
CLUSTER=rss10@dcc-login.oit.duke.edu

# Per-buoy fits (persistent share survives the wipe, so pull from there)
rsync -avz $CLUSTER:/hpc/group/schicklab/sne_ns01/fit/ ./fit/

# Derived quantities (always under /work/rss10 — pull before the wipe)
rsync -avz $CLUSTER:/work/rss10/sne_ns01/loglik/ ./loglik/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/rtct/   ./rtct/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/lam/    ./lam/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/num/    ./num/
```

---

## Where outputs go

- `data/<buoy>.RData` — stage 1 output. Gitignored.
- `fit/<buoy>/<buoy>LGCPSE.RData` — MCMC fit. Gitignored; treat as the canonical
  analytic artifact and keep at least one copy off-cluster.
- `loglik/<buoy>/`, `rtct/<buoy>/`, `lam/<buoy>/`, `num/<buoy>/` — derived
  posterior quantities. Gitignored; regenerate from the fit if needed.
- `fig/<buoy>/` — all figures (PDF) and LaTeX tables (`.tex`) from the `05_*`
  scripts. **Gitignored** — treat as a build product. Regenerate by re-running
  the `05_*` scripts.

---

## Script naming

Numeric prefixes indicate pipeline stage; scripts with the same prefix can
(and usually should) be run in any order within the stage.

| Prefix | Where it runs     | What                                             |
|--------|-------------------|--------------------------------------------------|
| `01_`  | local             | Build per-buoy `.RData` from raw rds + SST CSV   |
| `02_`  | cluster (sbatch)  | MCMC fit                                         |
| `03_`  | cluster + local   | Posterior -2logL and burn-in traceplot           |
| `04_`  | cluster (sbatch)  | Derived quantities: rtct, lam, num               |
| `05_`  | local             | Figures and LaTeX tables                         |

`archive/` contains the retired NHPPSE pipeline and sweep-era duplicates;
`archive/README.md` explains what and why.
