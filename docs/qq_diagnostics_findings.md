# RTC Q–Q diagnostics: upper-tail findings

What the random-time-change (RTC) Q–Q plots tell us about the LGCPSE fit at the
three buoys (NS01, NS02, COX01), and what explains the upper-tail departures.

Investigation date: 2026-06-22. Reproduce with `06_qqOutliers.R` and
`07_gapVsCoverage.R` (both loop all three buoys; run **without** `--buoy`).
Analysis window: 2021-10-01 → 2022-03-01 (5 months).

---

## TL;DR

- The fit is **well calibrated through the bulk** of the inter-call interval
  distribution at all three buoys.
- Upper-tail departures are **not recording gaps** — acoustic coverage is
  ~99.9% everywhere (see below).
- They are **genuine**, and split into two mechanisms:
  1. **Extended biological silences** (days to ~3 weeks) where the recorder was
     on, calling ceased, and the model's intensity stayed too high.
  2. **A diel calling rhythm** the harmonic basis cannot represent — silences
     consistently resume near **dawn (~05:00 EST)**. The design resolves only
     periods of one week and longer.
- A few short-interval departures are **mild self-excitement overshoot** during
  dense call clusters. Minor.

---

## How to read these plots

Each point is a per-event compensator increment `dᵢ = ∫ λ(t) dt` over an
inter-call interval, sorted ascending (y = Sample) against the Exp(1) quantile
at plotting position `(i − 0.5)/n` (x = Theoretical). If the model is correct,
the `dᵢ` are i.i.d. Exp(1) and lie on the 45° line. A point **above** the line
means the model integrated more intensity over that interval than the single
observed gap implies — i.e. it expected calls during a stretch that was quiet.

Source: `05_sumRTCT.R` (plot `fig/<buoy>/QQband.pdf`, MSD `fig/<buoy>/QQmsd.tex`).

---

## Per-buoy summary

| Buoy  | QQ MSD | frac above diagonal | Character |
|-------|-------:|--------------------:|-----------|
| NS02  | 0.033  | 0.149 | Tightest fit; mild systematic upper tail |
| NS01  | 0.181  | 0.163 | Same shape, slightly heavier tail |
| COX01 | 15.099 | 0.001 above / 0.138 below | Bulk slightly under-dispersed; MSD driven by ~4 late-Feb points |

`frac above diagonal` = fraction of events whose per-event posterior band lies
entirely above the line (from `07`'s calibration summary). NS01/NS02 lean
systematically high; COX01 leans low in the bulk but has a handful of extreme
high outliers. COX01's MSD of 15.1 is dominated by ~4 intervals in the final
week (Feb 22–27 2022) where modeled intensity vastly exceeded observed calling —
an **end-of-window seasonal decline** (the Mar 1 cut is a modeling choice; raw
COX01 data runs to mid-May 2022).

---

## Recording gaps are ruled out

`07_gapVsCoverage.R` treats a minute with no raw RMS observation as recorder
downtime (the same gaps `01_data.R` interpolates over) and tests each
upper-tail interval against it.

| Buoy  | Window (hr) | Covered | Missing (hr) |
|-------|------------:|--------:|-------------:|
| NS01  | 3623.8 | 0.9993 | 2.7 |
| NS02  | 3599.9 | 0.9992 | 2.8 |
| COX01 | 3586.9 | 0.9993 | 2.6 |

Coverage ~99.9% at every buoy, and **every** long-gap outlier had
`noise_missing ≈ 0.000`. So the departures reflect model behavior, not data
outages.

---

## The diel signature

Among the long `true silence` gaps, the events that *end* the gap cluster hard
around **~05:00 EST** (timestamps are labeled UTC but are actually EST):

- NS01: ranks 3,4,5,14 at 04:59; rank 6 05:04; rank 9 05:05
- NS02: rank 1 05:01, rank 3 05:14, rank 8 05:42, rank 9 05:02, rank 14 05:04
- COX01: rank 5 05:12, rank 12 05:17

i.e. calling consistently resumes at dawn after multi-day quiets. This is a
**diel (24-h) rhythm**. The model's harmonic periods (`harm_periods_lgcp` in
`src/config.R`) are 1 wk, 2 wk, 1 mo, 2 mo — the shortest is one week, so a
daily cycle cannot be represented. During each nightly lull the model keeps
predicting calls; over a multi-day silence those expectations accumulate into a
large compensator increment that "cashes out" when calling restarts at dawn —
exactly the observed upper-tail signature, and consistent with the systematic
~15% above-diagonal at NS01/NS02.

---

## Why the diel term was left out (deliberate)

Excluding sub-daily harmonics was a **scoping decision**, not an oversight:

1. **Fit cost.** The LGCPSE MCMC is expensive; each added harmonic pair widens
   the design matrix and lengthens already-long cluster fits.
2. **Scientific focus.** The manuscript's question is the **seasonal** story.
   The weekly-to-bimonthly harmonic basis was chosen to resolve that, and a
   diel term is orthogonal to the seasonal narrative.

So the upper-tail misfit is the expected, understood cost of that choice — worth
**reporting as a limitation** rather than treating as a defect.

---

## Recommendation / future work

If a future iteration wants to flatten the upper tail, add a **24-h** (and
likely **12-h**) harmonic to `harm_periods_lgcp` and refit (full
`02 → 04 → 05` pipeline). A 24-h period over the 5-month window gives ~150
cycles, very well resolved. This directly targets the dominant misfit but is a
substantial recompute, so it is optional and out of scope for the current
seasonal analysis.

---

## Suggested manuscript text

> Acoustic coverage exceeded 99.9% at all three buoys, so the upper-tail
> departures in the RTC Q–Q diagnostics do not reflect recording gaps. They
> instead correspond to (i) extended quiescent periods of several days to ~3
> weeks during which calling ceased while the model retained nonzero intensity,
> and (ii) a consistent resumption of calling near dawn, indicating a diel
> calling rhythm not captured by the harmonic basis, which by design resolves
> periods of one week and longer (the analysis targets seasonal structure). A
> small number of short-interval departures reflect mild over-prediction by the
> self-excitement term during dense call clusters.
