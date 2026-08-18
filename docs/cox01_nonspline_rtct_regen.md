# COX01 non-spline rtct regen — matched spline-vs-not comparison

**Date:** 2026-07-24 · **Branch:** `seasonal-spline-phase3` (cluster) ·
**Status:** rtct job submitted, awaiting completion.

## Why

The COX01 `08_qqDispersion.R` numbers looked alarming with the spline on:

| metric (Exp(1) target = 1) | non-spline (cmp_old) | spline (current) |
|---|---|---|
| n_events | 6098 | 8806 |
| var_d | 17.3 | 82.2 |
| var_drop (top-5 removed) | **0.88** | 18.6 |
| acf1_U | 0.19 | 0.49 |
| ks_D | 0.075 | 0.356 |

But this is **confounded**: the event count jumps 6098→8806, which is *more
data*, not a modeling change. The spline run extends the window into the
seasonal-decline tail. `cmp_old` was fit on a shorter window, so it's
spline-off-short-window vs spline-on-long-window — two changes at once.

The analysis window (`analysis_end <- 2022-04-30` in `config.R`) is a single
hard-coded line, **independent of the spline flag**. So the honest test is
spline vs non-spline on the *same* 7-month window (~8806 events both).

## What we established

- Two separate fits exist on the cluster (isolated namespaces):
  - `/work/rss10/sne_ns01/fit/cox01/cox01LGCPSE.RData`  — non-spline, Jun 27
  - `/work/rss10/sne_ns01/fit/cox01/cox01LGCPSEspl.RData` — spline, Jul 13
- Confirmed the non-spline fit is genuinely non-spline: `ncol(Xm) == 13`
  (13 = non-spline; 17 = spline). So **no new fit is needed** — only its rtct,
  regenerated from the current (Jun 27) fit so vintages match.
- Fits live on `/work/rss10/sne_ns01/fit/` (dir `sne_ns01`); rtct/loglik
  outputs live on `/hpc/group/schicklab/sne_dev/` (dir `sne_dev`). Different
  location *and* dir name.

## What we did (cluster, on `seasonal-spline-phase3`)

Did **not** switch to master (a `git checkout master` was blocked by unrelated
local edits to `config.R`/`02_fitLGCPSE.R`/`aci_*.sh`). Instead flipped one line
in the working-tree `config.R`:

```r
seasonal_spline_by_buoy <- c(
  ns01  = FALSE,
  ns02  = FALSE,
  cox01 = FALSE      # was TRUE — temporary, for this non-spline rtct run
)
```

Then submitted:

```bash
sbatch --export=ALL,BUOY=cox01 aci_rtct.sh
```

With `cox01 = FALSE`, `fiti` resolves to `LGCPSE`, so the job loads
`cox01LGCPSE.RData` and writes `cox01LGCPSE_rtct.RData` (~8806 events).

**Sanity check:** the job log should print `Seasonal spline for cox01: FALSE`.
If it says `TRUE`, the edit didn't take — kill it and re-check.

## TODO when the job finishes

1. **Restore the flag** — set `cox01` back to `TRUE` in `config.R` **by hand**.
   Do NOT `git checkout`/`git restore src/config.R` — that would also wipe the
   staged config.R blob and the other local edits.

2. **Pull the new non-spline rtct down (laptop):**
   ```bash
   rsync -avz $CLUSTER:/hpc/group/schicklab/sne_dev/rtct/cox01/ ./rtct/cox01/
   ```

3. **Rerun the dispersion table** (all-buoy loop — **no `--buoy`**, or every row
   pins to one buoy):
   ```bash
   Rscript 08_qqDispersion.R
   ```

4. **Read the result.** `var_drop` is the key column: near 1 = misfit is a few
   outlier silences; ≫1 = a whole over-long tail the model isn't capturing.
   `acf1_U > 0` = missing slow (seasonal) structure. The spline earns its place
   only if, on the *matched* 7-month window, it pulls these toward the
   non-spline quality.

## Deferred (not now): laptop↔cluster sync

The cluster branch has **diverged** from origin (1 local commit vs 3 on origin).
The 3 origin commits (per-buoy spline scoping, niters→250k, burn→130k) are the
*same content* the cluster has **staged** in `config.R` — duplicate work, not a
real conflict. Reconcile deliberately after this run: `git fetch`, confirm
origin's 3 == the staged blob, then likely drop the staged config.R in favor of
origin's committed version and triage the cluster-local `aci_*.sh` path edits
(keep those out of the shared branch). Inspect the one cluster-only commit with
`git log origin/seasonal-spline-phase3..HEAD` before discarding anything.
