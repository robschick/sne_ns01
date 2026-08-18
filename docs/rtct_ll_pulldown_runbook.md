# RTC-time + log-likelihood pull-down & summarize runbook

Bringing stage-4 derived quantities down from the cluster and summarizing them
on the laptop. Written for the current state:

- **COX01 rtct** — finished on the node.
- **NS02 ll** (`03_loglikLGCPSE.R`, job 49745854) — finished.
- **NS02 rtct** (`04_rtctLGCPSE.R`, job 49745856) — still running.

`$CLUSTER` is `rss10@dcc-login.oit.duke.edu`. Set it once per terminal with
`export CLUSTER=rss10@dcc-login.oit.duke.edu`.

The cluster repo lives at `/hpc/group/schicklab/sne_dev/`, and the "always
local" outputs (`rtct/`, `loglik/`, `lam/`, `num/`, `fig/`) are written into
that repo dir by each job (`$SLURM_SUBMIT_DIR`). So the pull source is
`/hpc/group/schicklab/sne_dev/<fold>/`, **not** `/work/rss10/sne_ns01/`.
Dry-run any pull first (`rsync -avzn …`) to confirm the file list before
committing.

## 1. rsync down

```bash
# COX01 rtct (both LGCPSE + LGCPSEspl files) and ns01 — but NOT ns02 yet.
# ns02's rtct job (49745856) is still running, so the remote ns02 file is stale
# and your local ns02 rtct has no backup; exclude it until the job finishes.
rsync -avz --exclude='ns02/' $CLUSTER:/hpc/group/schicklab/sne_dev/rtct/ ./rtct/

# NS02's log-likelihood trace (from the ll job that finished)
rsync -avz $CLUSTER:/hpc/group/schicklab/sne_dev/loglik/ ./loglik/
```

The spline result lands as `cox01/cox01LGCPSEspl_rtct.RData` — a distinct name
from the production `cox01LGCPSE_rtct.RData`, so it never clobbers the
non-spline file. See §3 for pulling ns02 once its job finishes.

You do **not** need to pull the large `fit/` files for any of this:
`05_sumRTCT.R` reads only `rtct/<buoy>/…_rtct.RData` and `03_sumLoglik.R` reads
only `loglik/<buoy>/…_loglik.RData`. Neither sources `load_fit.R`.

## 2. Summarize locally

```bash
# NS02 burn-in traceplot → fig/ns02/NegTwoLogLikTrace.pdf
Rscript 03_sumLoglik.R --buoy=ns02

# COX01 rtct summary → fig/cox01/ (RTC compensator / Q-Q)
Rscript 05_sumRTCT.R --buoy=cox01
```

On the `seasonal-spline-phase3` branch COX01 is the spline buoy, so the
diagnostics this branch tracks are the zoom + dispersion ones:

```bash
Rscript 05b_sumRTCTzoom.R  --buoy=cox01   # single-buoy: --buoy REQUIRED
Rscript 08_qqDispersion.R                 # all-buoy loop: run with NO --buoy
```

**Footgun — `--buoy` on the all-buoy scripts.** `08_qqDispersion.R` and
`05c_sumRTCTzoomAll.R` loop internally and set the buoy via `Sys.setenv(BUOY=…)`.
But `resolve_buoy()` in `config.R` checks the command-line `--buoy` arg *first*
and only falls back to the env var — so passing `--buoy=cox01` pins **every**
iteration to cox01 and you get three identical rows. Symptom: the same
`n_events`/`mean_d` on all buoys, and `Buoy: cox01` printed three times. Run
these two scripts with **no** `--buoy`. (The single-buoy `05_*`/`05b` scripts
*do* want `--buoy`.)

Both all-buoy scripts **degrade gracefully** where an rtct file is missing — run
them before NS02 is down and they'll just skip ns02 with a warning. Cleanest to
hold them until you've pulled `rtct/ns02/`.

## 3. After NS02 rtct finishes

```bash
# Optional: keep the old ns02 rtct (it has no backup) before overwriting it.
cp rtct/ns02/ns02LGCPSE_rtct.RData rtct/ns02/ns02LGCPSE_rtct.bak.RData

rsync -avz $CLUSTER:/hpc/group/schicklab/sne_dev/rtct/ns02/ ./rtct/ns02/
Rscript 05_sumRTCT.R --buoy=ns02
Rscript 05c_sumRTCTzoomAll.R   # all-buoy — NO --buoy
Rscript 08_qqDispersion.R      # all-buoy — NO --buoy
```

## 4. Telling the non-spline and spline fits apart

The spline uses an **isolated namespace**: when it's on, `fiti` becomes
`LGCPSEspl` and every output (fit/loglik/lam/rtct/num/fig) carries the `spl`
tag, so it never collides with the production `LGCPSE` files. Ground-truth
rules, in order of certainty:

1. **Filename.** `…LGCPSE…` = non-spline; `…LGCPSEspl…` = spline. The pipeline
   physically cannot write a spline result to a non-`spl` name.
2. **Design width (definitive).** Load the *fit* and check `ncol(Xm)`:
   **13 = non-spline** (intercept + noise + sst + 5 harmonics×2);
   **17 = spline** (drops the 2-month harmonic's 2 cols, appends 6 spline df).

Do **not** use the file date to judge model type — it only says *when* it was
fit. Fits live on **`/work/rss10/sne_ns01/fit/`** (dir `sne_ns01`), a different
location *and* dir name than the rtct/loglik outputs on `.../sne_dev/`.

```r
# on a cluster COMPUTE node (fits are ~10-25 GB; use srun, not the login node)
e <- new.env()
load('/work/rss10/sne_ns01/fit/cox01/cox01LGCPSE.RData', envir = e)
ncol(e$Xm)   # 13 -> non-spline confirmed
```

## 5. Clean spline-vs-non-spline test (fixed 7-month window)

The analysis window is a single hard-coded line in `config.R`
(`analysis_end <- 2022-04-30`), **independent of the spline flag**. So the honest
test is spline vs non-spline on the *same* 7-month window (both ~8806 events for
COX01). Confirmed available fits:

- `cox01LGCPSE.RData` (non-spline, 13-col) and `cox01LGCPSEspl.RData` (spline)
  both exist — no new *fit* is needed.

The local non-spline rtct may be older than the current non-spline fit (check
dates). To compare against the *current* fit, regenerate its rtct with the
spline **off**, then rerun `08`:

```bash
# on the cluster. Flip the ONE line in config.R rather than switching branches
# (a checkout can be blocked by unrelated local edits to config.R/02_fit/aci_fit):
#   src/config.R ~line 135:  cox01 = TRUE  ->  cox01 = FALSE
sbatch --export=ALL,BUOY=cox01 aci_rtct.sh   # loads cox01LGCPSE.RData -> non-spline rtct
#   then set that line back to TRUE (edit by hand — do NOT `git checkout config.R`,
#   which would also wipe the other pending local edits)

# laptop, once it finishes:
rsync -avz $CLUSTER:/hpc/group/schicklab/sne_dev/rtct/cox01/ ./rtct/cox01/
Rscript 08_qqDispersion.R    # NO --buoy; compare the COX01 spline vs non-spline rows
```

Reading the result: `var_drop` (variance after dropping the top-5 increments) is
the key column — near 1 means the misfit is a few outlier silences; ≫1 means a
whole over-long tail the model isn't capturing. `acf1_U > 0` flags missing slow
(seasonal) structure. The spline earns its place only if it pulls these toward
the non-spline-short-window quality on the *matched* window.
