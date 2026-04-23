# LGCPSE pipeline refactor

Goal: complete the partial refactor so the LGCPSE end-to-end workflow runs cleanly
for all three buoys (NS01, NS02, COX01) with minimal tribal knowledge. Reached via
a grill-me session — decisions captured below.

## How to use this plan

- Work top-to-bottom; each numbered section = one focused commit (grouping a
  handful of tiny changes into one commit is fine).
- Precondition for Section 1: baseline commit of current WIP must be in place.
- Check off items as they complete. If assumptions here stop matching reality,
  update this file before writing code.

## Decisions locked in (from grill-me)

- Fit-file naming: drop the `_5c4h` suffix entirely. `fitLGCPSE.R` already writes
  `{buoy}LGCPSE.RData`; downstream must match.
- Run locations: `rtct/lam/num` are cluster-only; `sum*` run either side but
  canonical run is local after rsync (`path_base` auto-switch handles both).
- Burn-in: per-buoy, stored inside `buoy_settings` in `config.R`. Chains mix
  differently across buoys so a single global burn is wrong.
- Canonical scripts: keep the `_harmonics_rho` variants, drop the plain-name
  duplicates (they're sweep-era legacy).
- Harmonic labels: auto-derive from `harm_periods_lgcp` via a `fmt_period()`
  helper (silent mislabel bug otherwise).
- Sweep scaffolding: remove `comb` / `runID` / `SLURM_ARRAY_TASK_ID` from all
  cluster scripts. Buoy is the new parallel axis — one sbatch per buoy.
- Scope: LGCPSE only. Archive NHPPSE entirely (it didn't fit the data as well).
- Archive target: `archive/` at repo root, preserving subpath structure, with a
  README explaining why.
- Output organization: figs and LaTeX tables → `fig/{buoy}/...`. `fig/` stays
  gitignored (treat as build product).
- Orchestration: README + numbered script prefixes (`01_`, `02_`, ...). No
  Makefile — the interactive burn-in step fights automation.
- Fit archive: auto-copy to `/hpc/group/schicklab/sne_ns01/fit/{buoy}/` after
  fit finishes (persistent lab share; `/work/rss10/` wipes after 75 days).
  README reminds user to also move off cluster to laptop.
- Shared helpers: consolidate `get_legend`, `hpd*`, `bmmean`, `lb/ub` variants,
  new `fmt_period()` into `src/RFtns.R`.
- Commits: focused per-section commits, not one giant squash.

## Scope — what's in, what's archived

**In scope (refactor to use `config.R` + `load_fit.R` + `src/RFtns.R`):**
- Cluster: `fitLGCPSE.R` ✅, `loglikLGCPSE.R` ✅, `lamLGCPSE.R` ✅,
  `rtctLGCPSE.R`, `numLGCPSE.R`
- Local: `sumLoglik.R` (burn-in trace — critical), `sumDIC_harmonics_rho.R`,
  `sumEstM4_harmonics_rho.R`, `sumRTCT_harmonics_rho.R`,
  `sumXB_harmonics_rho.R`, `sumNum.R`, `sumLam.R`

**Archive (`archive/`):**
- NHPPSE pipeline: `fitNHPPSE_parallel.R`, `loglikNHPPSE.R`, `rtctNHPPSE.R`,
  `numNHPPSE.R`, `src/RcppFtns_parallel.cpp`
- Sweep-era duplicates: `sumRTCT.R`, `sumEst.R`, `sumEstM4.R`, `sumXB.R`,
  `sumDIC.R`
- Unrelated/legacy: `sumData.R` (2009 Cape Cod manuscript fig — doesn't ingest
  cluster output), `sumPlot.R` (NHPPSE/`nopp2/` legacy), `check.R`,
  `src/test.cpp`

## Work plan (one commit per section unless noted)

### 0. Pre-flight
- [ ] Add `.DS_Store`, `.Rhistory` to `.gitignore`.
- [ ] Baseline commit: `"checkpoint before LGCPSE refactor"`.

### 1. Archive retirements
- [ ] `mkdir -p archive/src`.
- [ ] `git mv` each archived file to `archive/<same-subpath>/`.
- [ ] Write `archive/README.md` — one paragraph: "NHPPSE investigation retired
      YYYY-MM (didn't fit data as well as LGCPSE); sweep-era `sum*` duplicates
      superseded by config-driven `_harmonics_rho` variants; `sumData.R` is a
      2009 Cape Cod manuscript figure unrelated to the SNE buoy pipeline."
- [ ] Commit: `"archive NHPPSE pipeline and sweep-era duplicates"`.

### 2. Strip NHPPSE from shared code
- [ ] `config.R`: remove `fiti_nhpp`, `burn_nhpp`, `sback_nhpp`, `rho_nhpp`.
- [ ] `src/load_fit.R`: remove the `model_has_gp == FALSE` branch; GP path only.
- [ ] Commit: `"remove NHPPSE support from config and load_fit"`.

### 3. Rename pipeline scripts
Drop `_harmonics_rho` suffix (no sweep → no disambiguation); add stage prefix.

- [ ] `git mv data.R 01_data.R`
- [ ] `git mv fitLGCPSE.R 02_fitLGCPSE.R`
- [ ] `git mv loglikLGCPSE.R 03_loglikLGCPSE.R`
- [ ] `git mv sumLoglik.R 03_sumLoglik.R`
- [ ] `git mv rtctLGCPSE.R 04_rtctLGCPSE.R`
- [ ] `git mv lamLGCPSE.R 04_lamLGCPSE.R`
- [ ] `git mv numLGCPSE.R 04_numLGCPSE.R`
- [ ] `git mv sumDIC_harmonics_rho.R 05_sumDIC.R`
- [ ] `git mv sumEstM4_harmonics_rho.R 05_sumEstM4.R`
- [ ] `git mv sumRTCT_harmonics_rho.R 05_sumRTCT.R`
- [ ] `git mv sumXB_harmonics_rho.R 05_sumXB.R`
- [ ] `git mv sumNum.R 05_sumNum.R`
- [ ] `git mv sumLam.R 05_sumLam.R`
- [ ] Update any cross-references in `aci_*.sh` / docs / comments.
- [ ] Commit: `"rename pipeline scripts with stage prefixes, drop sweep-era suffix"`.

### 4. Config + shared helpers
- [ ] `config.R`:
  - [ ] Add `burn = 50000` (or per-buoy values from traceplot inspection) inside
        each entry of `buoy_settings`.
  - [ ] Add `path.fig <- file.path(local_base, 'fig', buoy, '')`.
  - [ ] Add `hpc_archive_base <- '/hpc/group/schicklab/sne_ns01'`.
  - [ ] Update `path_base` logic so `path.fit` falls through
        `/work/rss10/ → /hpc/group/schicklab/ → local`.
  - [ ] Ensure `fiti_lgcp <- 'LGCPSE'` (no `_5c4h`).
- [ ] `src/RFtns.R`: move in `get_legend`, `hpd`, `hpd1`, `hpd2`, `bmmean`,
      `lb90`, `ub90`, `lb95`, `ub95`. Add `fmt_period(minutes)` returning
      `"1 wk"` / `"2 wk"` / `"1 mo"` / `"2 mo"` / etc. from a period in minutes.
- [ ] `src/load_fit.R`: pull `burn` from `buoy_cfg$burn`.
- [ ] Commit: `"per-buoy burn, path.fig, fit-archive fallback, consolidated helpers"`.

### 5. Cluster script refactors (rtct, num)
(`lamLGCPSE.R` already uses `config.R` + `load_fit.R` — just rename in §3.)

- [ ] `04_rtctLGCPSE.R`:
  - [ ] Remove `comb`, `runID`, `SLURM_ARRAY_TASK_ID`, hardcoded
        `datai = 'nopp'`, hardcoded `burn = 50000`, hardcoded
        `LGCPSE_5c4h` fiti, hardcoded `/work/rss10/` and `'rtct/'` paths.
  - [ ] `source('src/config.R'); source('src/RFtns.R')`.
  - [ ] `fiti <- fiti_lgcp; burn <- buoy_cfg$burn; source('src/load_fit.R')`.
  - [ ] Outputs to `path.rtct`.
- [ ] `04_numLGCPSE.R`: same treatment; outputs to `path.num`.
- [ ] `aci_*.sh` cluster scripts: pass `--export=BUOY=ns01` (or equivalent) so
      `config.R` resolves the buoy. Submit one job per buoy; drop SLURM array
      indices.
- [ ] Commit: `"refactor cluster rtct/num to config-driven, drop sweep scaffolding"`.

### 6. Fit archive auto-copy
- [ ] At end of `02_fitLGCPSE.R`, after final `save(...)`:
      `dir.create(archive_path, recursive = TRUE, showWarnings = FALSE)` then
      `file.copy(filename, archive_path, overwrite = TRUE)` where
      `archive_path <- file.path(hpc_archive_base, 'fit', buoy)`.
- [ ] Commit: `"auto-copy completed fits to persistent schicklab share"`.

### 7. Sum-script refactors (group by 2–3 per commit, or one per)
For each of `03_sumLoglik.R`, `05_sumDIC.R`, `05_sumEstM4.R`, `05_sumRTCT.R`,
`05_sumXB.R`, `05_sumNum.R`, `05_sumLam.R`:

- [ ] Replace preamble with `source('src/config.R'); source('src/RFtns.R')`.
- [ ] `fiti <- fiti_lgcp; burn <- buoy_cfg$burn; source('src/load_fit.R')`
      (skip `load_fit.R` for scripts that don't need fit data — e.g.,
      `sumNum.R` just reads `path.num`, `sumRTCT.R` just reads `path.rtct`).
- [ ] Remove all `datai = 'nopp'`, hardcoded `/work/rss10/`,
      `/hpc/group/schicklab/`, `nopp/fig/`, hardcoded `burn = 50000`,
      `LGCPSE_5c4h` strings.
- [ ] Outputs (figures + LaTeX tables) to `path.fig` with filenames that drop
      the `{datai}` prefix (folder already conveys buoy).
- [ ] Drop multi-model `fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')` loops —
      single-model (LGCPSE) only.
- [ ] Drop `comb`/`runID` loops — single (fixed) config only.

Script-specific:
- [ ] `05_sumEstM4.R`: derive `Predictors` from `harm_periods_lgcp` using
      `fmt_period()` — silent mislabel bug fix.
- [ ] `05_sumLam.R`: origin for UTC reconstruction = `std` (from `config.R`),
      not the hardcoded NS01 deploy time at line 63.
- [ ] `03_sumLoglik.R`: single-model traceplot. This is the script whose output
      you use to set `buoy_cfg$burn` — document that in its header comment.
- [ ] `05_sumDIC.R`: one DIC row for the single fit (drop `for(runID ...)`).

Commits: one per script, or grouped by 2–3 where they're straightforward.

### 8. README.md at repo root
Sections:
- [ ] Prerequisite files in `data/` per buoy (`{buoy}_rms_data.rds`,
      `{buoy}_all.rds`, SST CSV under `data/sst/`).
- [ ] Pipeline stages:
  1. Local: `Rscript 01_data.R --buoy=ns01`.
  2. Cluster: `sbatch --export=ALL,BUOY=ns01 aci_fit.sh` (and loglik).
  3. Local interactive: `Rscript 03_sumLoglik.R --buoy=ns01` → inspect
     `fig/ns01/NegTwoLogLikTrace.pdf` → set `buoy_settings$ns01$burn` in
     `config.R` → commit.
  4. Cluster: submit `04_rtctLGCPSE.R`, `04_lamLGCPSE.R`, `04_numLGCPSE.R`.
  5. Local: run all `05_sum*.R` scripts after rsyncing outputs from cluster.
- [ ] Explicit note on `/work/rss10/` 75-day wipe, the auto-copy to
      `/hpc/group/schicklab/sne_ns01/fit/{buoy}/`, and the recommended
      `rsync` command to pull fits down to laptop.
- [ ] Where outputs land: `fig/{buoy}/` (gitignored; regenerate from fits).
- [ ] Commit: `"add README with end-to-end workflow and HPC wipe caveat"`.

### 9. Final sweep commit
- [ ] `"complete LGCPSE pipeline refactor"` — summary commit message
      enumerating the overall before/after.

## Open items / future passes (out of scope for this refactor)

- Study-region descriptive figure for the SNE buoys (would replace archived
  `sumData.R` — needs a new figure, not a port).
- `sumXB.R` harmonic-effect plot block commented out in `sumEstM4`; can be
  revived once the refactor lands.
- Automated rsync helper `rsync_fits.sh` for pulling fits to laptop (README
  covers the command; scripting it is optional).
- Benchmark workflow (`benchmark_*.R`, `aci_benchmark.sh`,
  `benchmark_report.Rmd`) left alone — separate concern.
