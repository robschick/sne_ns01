# 5-month manuscript assembly — status

**Date:** 2026-08-06 · **Window:** Oct 1 2021 → ~Mar 1 2022 (5 months)

Supersedes the "7-month primary + 5-month sensitivity" lean in
`manuscript_file_assembly_checklist.md` (2026-07-24). That lean rested on a
factual error — see the correction in `local_disk_inventory.md`.

## Decision: 5-month is primary

Two things flipped the call.

**1. The blocking gap was never real.** Every doc said "no 5-month ns02 rtct
anywhere." Wrong — the laptop's ns02 data + rtct are 5-month (33,611 events,
`ts`max day 150). 33,611 vs the cluster's 36,481 is a *window* difference, not a
stale-vintage difference. All three buoys are fully covered at 5 months.

**2. At 5 months the model passes the RTC gate on all three buoys — with no
seasonal correction at all.** Uniform 5-month `fig/combined/qq_dispersion.csv`:

| Buoy | n | var_d | var_drop | bulk_slope | acf1_U | lb_p | ks_D |
|---|---|---|---|---|---|---|---|
| NS01 | 13,017 | 1.159 | **0.860** | 0.920 | −0.025 | **0.289** | 0.030 |
| NS02 | 33,611 | 0.982 | **0.913** | 0.946 | −0.029 | 1.9e−11 | 0.018 |
| COX01 | 6,098 | 17.309 | **0.877** | 0.871 | 0.189 | 0 | 0.075 |

Compare the 7-month COX01 spline fit: `var_drop` **18.6**, `acf1_U` 0.49,
`ks_D` 0.356 — the gate you spent two 250k-iteration chains failing to clear.

COX01's full-range `var_d` 17.3 is the known outlier meter, not a bulk problem:
dropping the top 5 increments takes it to 0.877. NS01's Ljung-Box `lb_p` = 0.29
means no detectable serial structure at all — the cleanest of the three.

**Framing consequence.** `manuscript_and_window_decisions.md` §1a argues the
seasonal correction is load-bearing and can't be dropped. That argument only
bites for the 7-month window, which *imports* the end-of-season silence. At 5
months the non-stationarity isn't in the window, so there is nothing to correct
and no misfit for a reviewer to run into. The 5→7 comparison then becomes a
*reportable finding* — extending into the decline breaks compensator calibration,
and a 6-df natural spline does not repair it — rather than an unresolved
methodological debt. That is a stronger, more honest paper than shipping a
7-month fit whose own diagnostics flag it.

## State of the tree

`data/`, `rtct/`, `fig/` are **uniformly 5-month** as of 2026-08-06. Both windows
are retained under window-suffixed names so an rsync from the node cannot
silently clobber the other window. `src/config.R` has
`seasonal_spline_by_buoy['cox01'] = FALSE`. Full map in `local_disk_inventory.md`.

## What is assembled

Per buoy (ns01 / ns02 / cox01), all present and window-uniform:

| output | file | status |
|---|---|---|
| background decomposition | `fig/<b>/XB_<BUOY>.pdf`, `xb.RData` | ✅ Jun 22 |
| posterior intervals | `fig/<b>/CI.pdf` | ✅ Jun 22 |
| coefficient table | `fig/<b>/background_excitement_coeffs_table.tex` | ✅ Jun 22 |
| DIC | `fig/<b>/DIC.{tex,RData}` | ✅ Jun 22 |
| intensity summaries | `fig/<b>/Lam.pdf`, `LamTotalRug_<BUOY>.pdf` | ✅ Jun 22 |
| counts | `fig/<b>/Num.tex` | ✅ Jun 22 |
| RTC Q-Q | `fig/<b>/QQband.pdf`, `QQmsd.tex` | ✅ (cox01 restored 08-06) |

Cross-buoy: `fig/combined/combined_coeffs.*`, `combined_counts.*` (Jun 22),
`QQband_allbuoys.pdf` (regenerated 08-06, byte-size identical to the Jun-26
render — confirming that one was already 5-month), `qq_dispersion.*` (08-06).

Sensitivity material: `fig/ns01/QQband_windowCompare*.pdf` (5 vs 7 month),
`cmp_old/` (5-mo cox01 reference incl. gap-vs-coverage), `cmp_new/` (7-mo spline
cox01 reference).

## Open gaps

1. **Burn-in traceplots are unrecoverable.** `03_sumLoglik.R` needs `loglik/`
   from the 5-month fits. Absent locally; the node's `loglik/` is all 7-month;
   the 5-month fits were overwritten by the Jun-27/Jul-2/Jul-12 re-fits. Decide
   how to evidence convergence — parked, not blocking.
2. **No new fit-derived output without a re-fit.** The 5-month fits are gone, so
   any reviewer request for a novel fit-derived diagnostic costs a re-fit
   (~1 fit-cycle/buoy). Everything currently needed is already rendered.
3. **`analysis_end` in `src/config.R` is still 2022-04-30.** Harmless — it only
   affects `01_data.R`, and re-running that implies a re-fit. Change it only if
   a 5-month re-fit is ever commissioned.
4. **Second durable copy of the node's 7-month fits** — still only on the `/hpc`
   mirror. Unchanged from the 07-24 checklist; not on the 5-month critical path.

## Related docs

- `local_disk_inventory.md` — corrected census + the window-suffix map.
- `manuscript_file_assembly_checklist.md` — node paths, preservation, `aci_sum.sh`
  (its *window decision* section is superseded by this doc).
- `manuscript_and_window_decisions.md` — two-paper split; §1a framing now applies
  only to the 7-month alternative.
- `rtct_ns02_resume_postmortem.md` — the 33,611/36,481 confusion originates here.
