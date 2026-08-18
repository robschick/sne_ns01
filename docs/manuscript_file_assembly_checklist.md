# Manuscript file assembly & preservation checklist

**Date:** 2026-07-24 · **Decision leaning:** 7-month primary + 5-month
sensitivity (see "Window decision" below).

Verifies what's needed to write the paper, what's safely preserved, and what's
still missing. `$CLUSTER = rss10@dcc-login.oit.duke.edu`.

## Path map (they differ!)

| content | location | dir name | persistence |
|---|---|---|---|
| production **fits** | `/work/rss10/sne_ns01/fit/` | `sne_ns01` | **scratch — 75-day wipe** |
| fit **mirror** | `/hpc/group/schicklab/sne_ns01/fit/` | `sne_ns01` | persistent lab share |
| rtct/loglik/lam/num/fig | `/hpc/group/schicklab/sne_dev/` | `sne_dev` | persistent lab share |

`config.R` `fit_base` falls back `/work` → `/hpc/.../sne_ns01` → local, so after
the scratch wipe `load_fit.R` silently uses the `/hpc` mirror — no breakage.

## Window decision context

**CORRECTION (2026-07-25):** an earlier version of this doc claimed 5-month
requires re-fitting all three buoys. That is **wrong**. Neither window needs a
re-fit. The distinction is *re-run summaries* (cheap) vs *re-run fits*
(expensive) — and the summaries are what's at issue, not the fits.

Key fact: the **5-month parameter outputs already exist as files** in `fig/`,
dated Jun 22, all three buoys — generated from the 5-month fits *before* the
7-month re-fits (Jun 27 / Jul 2 / Jul 12) overwrote them. Verified 5-month by the
`ts` axis in `fig/<buoy>/xb.RData` (max ≈ 217k min = Mar-1 boundary, not the
305k = Apr-30 7-month end) and `DIC.RData` `fit = LGCPSE`.

| window | fits | parameter outputs (DIC/XB/coeffs/Lam/Num/CI) | re-fit? |
|---|---|---|---|
| **5-month** | gone (overwritten) | **exist** (`fig/`, Jun 22, 5-mo) + cox01 QQ in `cmp_old/` | **no** — assemble from saved files |
| **7-month** | exist (mirrored) | **stale** (`fig/` is 5-mo) → regen via `05_*` on cluster | **no** — re-run summaries only |

So:
- **5-month primary** — mostly *already assembled*. Gaps: no 5-month ns02 rtct
  anywhere; cox01's 5-month QQ is in `cmp_old/` (the live `fig/cox01` QQ is Jul-24
  7-month/spline — do not mix). Downside: fits are gone, so you cannot generate
  any *new* fit-derived output or revise (a reviewer asking for a new diagnostic
  ⇒ re-fit).
- **7-month primary** — fits kept (full flexibility), but the `fig/` parameter
  tables are stale 5-month and must be **regenerated** from the 7-month fits
  (`05_sumEstM4/XB/DIC/Lam/Num` on the cluster — cheap, no re-fit).

**⚠️ WINDOW-MIX HAZARD.** `fig/` (and `fig/combined/`) currently holds BOTH
windows: Jun-22/26 outputs are 5-month; Jul-24 cox01 QQ + `qq_dispersion` are
7-month/spline. Assembling a paper straight from `fig/` as-is silently combines
5-month parameter estimates with 7-month diagnostics. **Before building tables,
make `fig/` uniformly one window.**

## Preservation status — FITS ARE SAFE ✅

All four production fits are mirrored to the persistent share (verified
2026-07-24, sizes identical, `/hpc` mtime just after `/work` = auto-mirror):

| fit | size | mirrored |
|---|---|---|
| cox01 LGCPSE (non-spline, 7mo) | 9.6G | ✅ |
| cox01 LGCPSEspl (spline, 7mo) | 24G | ✅ |
| ns01 LGCPSE (7mo) | 13G | ✅ |
| ns02 LGCPSE (7mo) | 13G | ✅ |

The `/work` 75-day wipe (fits dated Jun 27 – Jul 13 → wipe ≈ mid-to-late Sept)
is **no longer a data-loss risk**.

**Still advisable:** a *second* durable copy — the mirror is a single point of
failure. Pull the three non-spline 7-month fits (~36G) to laptop/external:

```bash
for b in cox01 ns01 ns02; do
  rsync -avz $CLUSTER:/hpc/group/schicklab/sne_ns01/fit/$b/${b}LGCPSE.RData ./fit/$b/
done
# integrity spot-check: compare an md5 on both sides for one file
```

## Local inventory (2026-07-24)

- **fit/** — only April *benchmark* runs. **No production fits local.**
- **rtct/** — cox01 (8806, both spline/non-spline), ns01 (`.5mo`=13017,
  `.7mo`/base=22784), ns02 (33611). All 7-month except ns01 `.5mo`.
- **loglik/, lam/, num/** — **absent locally.**

## What each manuscript output needs (per buoy)

| output | script | reads |
|---|---|---|
| burn-in traceplot | `03_sumLoglik.R` | `loglik/` |
| RTC Q-Q / compensator | `05_sumRTCT.R` | `rtct/` |
| dispersion table | `08_qqDispersion.R` (NO `--buoy`) | `rtct/` |
| parameter estimates | `05_sumEstM4.R`, `05_sumXB.R` | **fit** |
| DIC | `05_sumDIC.R` | **fit** |
| lambda summaries | `05_sumLam.R` | `lam/` |
| numeric summaries | `05_sumNum.R`, `05_sumCombined.R` | `num/` |

Fit-reading tables (est/DIC): run **on the cluster** (fits live there), pull the
small `fig/` outputs — don't download 10–25 GB objects to the laptop.

## Derived outputs — CONFIRMED present on the node (2026-07-25)

All 7-month derived outputs (loglik, lam, num, rtct) exist on the node for every
buoy, cox01 in both non-spline + spline (verified — see
`docs/local_disk_inventory.md`). So **no `aci_lam`/`aci_num`/`aci_ll` re-runs are
needed** — only the summary scripts remain. Caveat: **ns02 rtct (49745856) is
still running** (12+ days as of 07-25); its on-disk file is a partial checkpoint,
not final. Don't summarize ns02 until it finishes.

## Render all summaries — `aci_sum.sh` (batch job)

`aci_sum.sh` runs every `05_*`/`08`/`03_sumLoglik` script for all buoys from the
existing fits + derived outputs (no re-fit, no re-derive). Run it as a **SLURM
job**, not on the login node — `05_sumEstM4`/`05_sumXB` load the full fits
(cox01 spline = 24 GB) into RAM.

```bash
# ship the one file to the node (sidesteps the branch-divergence tangle)
rsync -avz aci_sum.sh $CLUSTER:/hpc/group/schicklab/sne_dev/

# on the node: syntax check + ensure log dir, then submit GATED on the ns02 rtct
bash -n aci_sum.sh && mkdir -p out
sbatch --dependency=afterok:49745856 aci_sum.sh   # self-fires when ns02 rtct done
# (drop --dependency once 49745856 is gone; subset with --export=ALL,BUOYS="cox01 ns01")

# when it finishes, pull the rendered figures/tables down
rsync -avz $CLUSTER:/hpc/group/schicklab/sne_dev/fig/ ./fig/
```

Decisions/gotchas baked into the script's header comment:
- **COX01 spline flag** — branch default `cox01 = TRUE` renders the *spline* fit
  (`LGCPSEspl` outputs). For non-spline *primary* tables set `cox01 = FALSE`
  first; isolated tags let you run it both ways without collision.
- **`--dependency=afterok:49745856`** — holds the job until the ns02 rtct exits
  cleanly. If that job hits walltime and is killed, `afterok` won't fire.
- **`--mem=192GB`** — generous vs. OOM history; lower only if placement is slow.

## RTC compensator gotcha — NS02 walltime + resume/thin knobs

`04_rtctLGCPSE.R` is single-threaded and its cost is O(`n_events` × `niters`).
NS02 (33,611 events, ~4× cox01) **timed out at the 14-day walltime — 31,290 of
33,611 events done (93%)** on job 49745856 (2026-07-27). The file it left is a
partial checkpoint (the loop `save()`s postCompen + intlami every 10 events).

`04_rtctLGCPSE.R` now has two env knobs (added 2026-07-27) to handle this:

- **`RTCT_RESUME=true`** — reload the checkpoint and continue where it stopped.
  Full posterior only (the checkpoint isn't thinned; a guard blocks resume+thin).
  This is the fix for the NS02 timeout — only ~7% of events remain (~1 day), and
  it keeps NS02 consistent with the un-thinned cox01/ns01 rtcts.
  ```bash
  rsync -avz 04_rtctLGCPSE.R $CLUSTER:/hpc/group/schicklab/sne_dev/
  sbatch --export=ALL,BUOY=ns02,RTCT_RESUME=true aci_rtct.sh
  # log should print: "Resuming rtct from 31290 of 33611 events (aaa idx 3130)"
  ```
- **`RTCT_THIN=<#draws>`** — subsample the posterior (via `load_fit.R`'s thinning
  branch) for a *fresh* run; ~10× faster at 25k draws, quantiles unchanged. Use
  only when starting from scratch on a high-event buoy — NOT with resume.

**Branch note:** these `04_rtctLGCPSE.R` edits are **committed on the laptop
`seasonal-spline-phase3` branch**, but on the node they arrive via the `rsync`
above as an uncommitted local edit (like the `aci_*.sh` tweaks) — fold into the
branch reconciliation when syncing the node.

## Remaining gaps — TODO

1. **Decide the COX01 primary model** (spline vs non-spline) → set the flag before
   `aci_sum.sh`.
2. **Let ns02 rtct (49745856) finish**, then submit `aci_sum.sh` (or submit now
   with the `afterok` gate). Watch its walltime — 12+ days in.
3. **Make `fig/` uniform to one window** — the rendered outputs replace the stale
   5-month `fig/` in place; pull them down after the job.
4. **(Optional) second durable copy of the three non-spline fits** — see
   Preservation section.

## Related docs

- `docs/local_disk_inventory.md` — full local + node census, window-tagged.
- `docs/rtct_ll_pulldown_runbook.md` — rsync pull-down + summarize, footgun notes.
- `docs/cox01_nonspline_rtct_regen.md` — the matched non-spline rtct run.
