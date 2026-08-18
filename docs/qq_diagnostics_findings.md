# RTC Q–Q diagnostics: upper-tail findings

What the random-time-change (RTC) Q–Q plots tell us about the LGCPSE fit at the three buoys (NS01, NS02, COX01), and what explains the upper-tail departures.

Investigation date: 2026-06-22. Reproduce with `06_qqOutliers.R` and `07_gapVsCoverage.R` (both loop all three buoys; run **without** `--buoy`). Analysis window: 2021-10-01 → 2022-03-01 (5 months). **Corrected 2026-08-18**: the diel/dawn interpretation of the \~05:00 gap-end cluster is withdrawn — it is a fixed clock boundary (solar-curve test: `RScripts/calc_suntimes.R`, `RScripts/plot_suntimes.R`).

**⚠ 2026-08-18, COX01 data-integrity finding:** every COX01-specific number in this document (MSD 15.099, the "\~4 late-Feb outliers", `var_d` 17.31, `acf1_U` +0.189, LB Q 4834, and the end-of-window-decline attribution) is contaminated by Excel-mangled timestamps in the final week of the fit window — 3,175 detections after 2022-02-16 were collapsed into \~27.8-hour bins in the delivered `NEFSC_MA-RI_202202_COX01_narwlog_ST.csv`, four of those bursts (243/80/75/63 simultaneous events, Feb 22–27) sit inside the window, and they *are* the late-Feb outliers. NS01/NS02 are clean and their conclusions stand. Full forensic record, contamination map, and recovery plan: `docs/cox01_timestamp_provenance.md`.

------------------------------------------------------------------------

## TL;DR

- The fit is **well calibrated through the bulk** of the inter-call interval distribution at all three buoys.
- Upper-tail departures are **not recording gaps** — acoustic coverage is \~99.9% everywhere (see below).
- They are **genuine**, and split into two mechanisms:
  1.  **Extended biological silences** (days to \~3 weeks) where the recorder was on, calling ceased, and the model's intensity stayed too high.
  2.  ~~A diel calling rhythm the harmonic basis cannot represent~~ **CORRECTED 2026-08-18:** the \~05:00 resumption cluster is a **fixed clock boundary, not dawn** — gap-end times stay pinned at 04:59–05:42 all season while actual dawn drifts by more than an hour. See "The \~05:00 signature" below. The silences themselves remain genuine; only the dawn interpretation of when they end is withdrawn.
- A few short-interval departures are **mild self-excitement overshoot** during dense call clusters. Minor.

------------------------------------------------------------------------

## How to read these plots

Each point is a per-event compensator increment `dᵢ = ∫ λ(t) dt` over an inter-call interval, sorted ascending (y = Sample) against the Exp(1) quantile at plotting position `(i − 0.5)/n` (x = Theoretical). If the model is correct, the `dᵢ` are i.i.d. Exp(1) and lie on the 45° line. A point **above** the line means the model integrated more intensity over that interval than the single observed gap implies — i.e. it expected calls during a stretch that was quiet.

Source: `05_sumRTCT.R` (plot `fig/<buoy>/QQband.pdf`, MSD `fig/<buoy>/QQmsd.tex`).

------------------------------------------------------------------------

## Per-buoy summary

| Buoy | QQ MSD | frac above diagonal | Character |
|----|---:|---:|----|
| NS02 | 0.033 | 0.149 | Tightest fit; mild systematic upper tail |
| NS01 | 0.181 | 0.163 | Same shape, slightly heavier tail |
| COX01 | 15.099 | 0.001 above / 0.138 below | Bulk slightly under-dispersed; MSD driven by \~4 late-Feb points |

`frac above diagonal` = fraction of events whose per-event posterior band lies entirely above the line (from `07`'s calibration summary). NS01/NS02 lean systematically high; COX01 leans low in the bulk but has a handful of extreme high outliers. COX01's MSD of 15.1 is dominated by \~4 intervals in the final week (Feb 22–27 2022) where modeled intensity vastly exceeded observed calling — an **end-of-window seasonal decline** (the Mar 1 cut is a modeling choice; raw COX01 data runs to mid-May 2022).

------------------------------------------------------------------------

## Recording gaps are ruled out

`07_gapVsCoverage.R` treats a minute with no raw RMS observation as recorder downtime (the same gaps `01_data.R` interpolates over) and tests each upper-tail interval against it.

| Buoy  | Window (hr) | Covered | Missing (hr) |
|-------|------------:|--------:|-------------:|
| NS01  |      3623.8 |  0.9993 |          2.7 |
| NS02  |      3599.9 |  0.9992 |          2.8 |
| COX01 |      3586.9 |  0.9993 |          2.6 |

Coverage \~99.9% at every buoy, and **every** long-gap outlier had `noise_missing ≈ 0.000`. So the departures reflect model behavior, not data outages.

------------------------------------------------------------------------

## The \~05:00 signature: a clock boundary, not dawn (corrected 2026-08-18)

**The original diel reading (2026-06-22) is withdrawn.** This section preserves the observation, documents the test that killed the interpretation, and lists what still needs to be run down.

### The original observation (still true as data)

Among the long `true silence` gaps, the events that *end* the gap cluster hard around **\~05:00** on the stored clock (timestamps are labeled UTC but were assumed to be EST):

- NS01: ranks 3,4,5,14 at 04:59; rank 6 05:04; rank 9 05:05
- NS02: rank 1 05:01, rank 3 05:14, rank 8 05:42, rank 9 05:02, rank 14 05:04
- COX01: rank 5 05:12, rank 12 05:17

The original inference: calling resumes at dawn after multi-day quiets, i.e. a diel (24-h) rhythm below the resolution of the harmonic basis (shortest period 1 week).

### The test

A genuine dawn signal must **drift with the season**. At \~41°N, sunrise (and civil/nautical dawn with it) moves by roughly an hour between early October and late February — so gap-end times that track dawn cannot sit at the same clock minute across the window. Crucially, this test is **immune to the timezone judgment call**: a wrong fixed offset (EST vs EDT vs true UTC) shifts the solar curves vertically but cannot change their seasonal slope. Points that track dawn slope with the curve under *any* offset; points on a flat line match none.

We computed sunrise, civil dawn, and nautical dawn at each buoy's position for every day of the window (`suncalc`, via `RScripts/calc_suntimes.R` for the gap dates and `RScripts/plot_suntimes.R` for the daily grid + figure), shifted them onto the data's nominal-EST clock (UTC−5), and plotted every gap-end event against them:

![Gap-end clock time vs date, with solar dawn curves per buoy](../fig/combined/gap_end_vs_dawn.png)

(Figure: `fig/combined/gap_end_vs_dawn.png`; `fig/` is gitignored — regenerate with `Rscript RScripts/plot_suntimes.R`.)

### The result: the cluster does not track dawn

All 18 gap-ends within ±45 min of 05:00, against dawn for that date and position (nominal EST):

| Buoy  | rank | date       | gap end | nautical dawn | sunrise |     d |
|-------|-----:|------------|--------:|--------------:|--------:|------:|
| NS02  |    1 | 2021-10-20 |   05:01 |         04:58 |   05:58 | 36.2  |
| NS02  |    8 | 2021-10-27 |   05:42 |         05:05 |   06:05 | 12.5  |
| NS02  |   14 | 2021-11-22 |   05:04 |         05:33 |   06:36 |  9.08 |
| NS02  |    9 | 2021-11-24 |   05:02 |         05:35 |   06:38 | 10.9  |
| NS02  |    3 | 2021-11-29 |   05:14 |         05:40 |   06:44 | 19.1  |
| NS01  |    1 | 2022-01-04 |   05:07 |         06:02 |   07:07 | 51.5  |
| COX01 |   11 | 2022-01-12 |   05:24 |         06:05 |   07:09 |  7.7  |
| NS01  |    4 | 2022-01-13 |   04:59 |         06:01 |   07:06 | 14.8  |
| COX01 |    6 | 2022-01-14 |   05:35 |         06:04 |   07:09 | 10.7  |
| NS01  |    6 | 2022-01-18 |   05:04 |         06:00 |   07:03 | 12.2  |
| NS01  |    3 | 2022-01-22 |   04:59 |         05:58 |   07:01 | 17.2  |
| COX01 |    5 | 2022-01-22 |   05:12 |         06:01 |   07:04 | 12.0  |
| COX01 |   12 | 2022-01-26 |   05:17 |         05:59 |   07:02 |  6.74 |
| NS01  |    5 | 2022-01-28 |   04:59 |         05:54 |   06:57 | 12.9  |
| NS01  |    9 | 2022-01-31 |   05:05 |         05:52 |   06:54 |  9.03 |
| NS02  |    4 | 2022-02-08 |   05:17 |         05:43 |   06:44 | 17.0  |
| COX01 |   15 | 2022-02-08 |   04:17 |         05:47 |   06:49 |  6.54 |
| NS01  |   14 | 2022-02-21 |   04:59 |         05:29 |   06:29 |  7.55 |

Three things kill the dawn interpretation:

1.  **No seasonal drift.** Nautical dawn moves \~04:58 (late Oct) → \~06:05 (mid-Jan) → \~05:29 (late Feb); the gap-ends stay pinned at 04:59–05:42 throughout. By mid-January the "dawn" resumptions are a **full hour before first light**.
2.  **Minute-level pinning.** NS01 lands on *exactly* 04:59 on four dates spanning Jan 13 → Feb 21, a stretch over which dawn moved \~30 minutes. Solar behavior cannot reproduce that; a fixed boundary trivially does.
3.  **The October coincidence explains the original error.** In late October nautical dawn really is \~05:00 on this clock — the earliest-dated outliers (NS02 ranks 1, 8) genuinely sit in the dawn window, which is what made the diel story look plausible when reading times off a table without the seasonal curve.

Conclusion: the \~05:00 cluster is a **fixed clock boundary** — a daily file rollover, detector batch start, or duty-cycle boundary — not a solar signal. Suggestively, if the stored timestamps are **true UTC** (i.e. the "actually EST" relabeling is wrong), then 05:00 stored = **midnight EST**, exactly where a daily processing boundary would sit.

What survives the correction: the extended silences themselves are real (coverage \~99.9%, `noise_missing ≈ 0` — the recorder was on and calling ceased). Only the interpretation of *when they end* is withdrawn. The compensator outliers, the budget decomposition, and the under-dispersed-bulk mechanics above are unaffected.

### What we still need to do

1.  **Trace the boundary in the processing chain.** Find what sits at 05:00 stored time: raw audio file rollover, detector batch restarts, duty cycle. Check raw file naming/start times and detector logs. The true-UTC/local-midnight hypothesis is the leading candidate.
2.  **A cheap decisive check:** histogram the clock minute of **all** detections (not just gap ends). A processing boundary that stamps or displaces detections will show as an excess at the boundary minute across the whole dataset; a biological signal will not produce a single-minute spike.
3.  **Pin down timestamp provenance** from deployment metadata, including handling of the 2021-11-07 DST transition. Note: a uniform clock offset is harmless to the *seasonal* analysis (all harmonics ≥ 1 week; the noise covariate shares the same clock), but it must be stated correctly in the data description.
4.  **Test for a genuine diel rhythm properly**, if we still care: hour-of-day distribution of all calls (`docs/harmonic_eda_checklist.md`, step 3), computed per month so a real dawn effect can show its seasonal drift. Gap-end times of 14 outliers were never the right evidence for this.
5.  **Hold the 24-h harmonic refit** until 1–4 resolve. The refit's motivating evidence was this signature; fitting a harmonic to a file boundary would launder an artifact into a biological claim.

------------------------------------------------------------------------

## Dispersion decomposition (what drives COX01's under-dispersed bulk)

Added 2026-06-27 via `08_qqDispersion.R` (loops all buoys; run **without** `--buoy`). **These are pre-refit baseline numbers** — read from the May backup `rtct/` (Oct 1 → Mar 1 window, no diel harmonic); re-run once the diel-harmonic / Apr-30 refit lands and update this table. If the LGCPSE compensator is correct the increments `dᵢ` are i.i.d. Exp(1) (mean = var = CV = 1).

| Buoy  |     n | mean_d | var_d | mean_drop | var_drop | bulk_slope | acf1_U | LB Q (20) |    LB p |
|-------|------:|-------:|------:|----------:|---------:|-----------:|-------:|----------:|--------:|
| NS01  | 13017 |  0.971 | 1.159 |     0.962 |    0.860 |      0.920 | −0.025 |      23.0 |    0.29 |
| NS02  | 33611 |  0.977 | 0.982 |     0.974 |    0.913 |      0.946 | −0.029 |      93.3 |   2e−11 |
| COX01 |  6098 |  0.963 | 17.31 |     0.872 |    0.877 |      0.871 | +0.189 |    4833.7 | \<1e−16 |

`mean_drop`/`var_drop` = mean and variance after removing the 5 largest `dᵢ`; `bulk_slope` = OLS slope of the central-95% Q–Q (\< 1 ⇒ under-dispersed bulk); `acf1_U` = lag-1 autocorrelation of `Uᵢ = 1 − exp(−dᵢ)` in **event order**; `LB Q (20)` / `LB p` = Ljung–Box omnibus statistic and p-value over lags 1–20 (H₀: no serial autocorrelation in `U`). See the next section for the full definition and interpretation of these last two columns.

Note the lag-1 vs omnibus contrast: **NS02's** lag-1 autocorrelation is negligible (−0.029) yet Ljung–Box rejects (Q = 93.3) — diffuse, low-level serial structure spread across many lags that a single lag misses but that n = 33,611 makes detectable. **NS01** does not reject (Q = 23.0, p = 0.29) — its residuals are serially clean. **COX01's** Q = 4834 is two orders of magnitude larger than NS02's, so the magnitude ordering still isolates COX01 as the dominant departure even though both reject. (As with KS, Ljung–Box rejects on practically negligible departures at these sample sizes; read Q magnitudes and `acf1_U`, not just whether p \< 0.05.)

Two mechanisms, and the numbers separate them:

1.  **Budget conservation drives the bulk under-dispersion.** Because `∑ᵢ dᵢ = ∫ λ ≈ n` is (nearly) pinned by the fit, `mean_d ≈ 1` even for COX01. COX01's full-sample `var_d = 17.3` is **over**-dispersion carried entirely by \~5 silence outliers: dropping them collapses the variance to 0.88 and pulls the mean to 0.872. Those few huge increments spend the compensator budget, so the remaining \~6090 events are deflated below 1 — *that* deflation is the under-dispersed bulk (`bulk_slope = 0.871`). The bulk under-dispersion and the upper-tail outliers are the **same events seen from opposite ends**, not two defects.

2.  **The residual is missing slow structure, not over-adaptive intensity.** COX01's `acf1_U = +0.189` is **positive** — the opposite sign from what an over-flexible GP / self-excitement term would produce (those chase each event and leave *negative* lag-1 correlation). Positive serial correlation means runs of small `dᵢ` then runs of large `dᵢ`, the fingerprint of low-frequency structure the model omits (the diel cycle and the end-of-window seasonal decline). NS01/NS02 sit near Exp(1) (NS02 almost textbook) with `acf1_U ≈ 0`.

**Prediction for the refit.** The 24-h harmonic should shrink the silence outliers → relax `var_d` and lift `mean_drop`/`bulk_slope` toward 1 via the budget, and pull COX01's `acf1_U` toward 0 by absorbing the diel run-structure. If `acf1_U` stays positive, the remaining slow term is the end-of-window seasonal decline at the Apr-30 cut. *(Superseded 2026-08-18: the dawn evidence motivating the 24-h harmonic did not survive the solar-curve test — see "The \~05:00 signature" below. The `acf1_U` sign logic itself stands: positive serial correlation still indicates missing slow structure; the diel cycle just drops off the candidate list unless the all-calls hour-of-day test revives it.)*

(KS-vs-Exp(1) is uninformative at n = 6k–34k — it rejects on any trivial departure; the effect sizes `ks_D = 0.018–0.075` are the honest read.)

------------------------------------------------------------------------

## The serial-correlation diagnostic (`acf1_U` and Ljung–Box), in detail

This section documents `acf1_U` and its omnibus companion for a statistical reader. Both are computed in `08_qqDispersion.R`.

### Construction

``` r
d    <- postCompen[, 5]                          # increments, EVENT (time) order
U    <- 1 - exp(-d)                              # probability-integral transform
acf1 <- acf(U, lag.max = 1, plot = FALSE)$acf[2] # lag-1 autocorrelation
lb   <- Box.test(U, lag = 20, type = 'Ljung-Box')
```

Three steps:

1.  **Keep `dᵢ` in chronological order.** `dᵢ = ∫_{t_{i-1}}^{t_i} λ` is the compensator increment over the *i*-th inter-call interval. The Q–Q plots sort the `dᵢ`; here we deliberately do **not** sort, because serial structure only exists in time order. (`postCompen`'s rows are stored in event order.)

2.  **Probability-integral transform, `Uᵢ = 1 − exp(−dᵢ)`.** This is the Exp(1) CDF, so under a correct compensator (`dᵢ ~ iid Exp(1)`) the `Uᵢ` are `iid Uniform(0,1)` — a Rosenblatt/PIT residual. Two reasons to work on `U` rather than `d` directly:

    - **Robustness.** Exp(1) is heavy-tailed and the silence outliers reach `d ≈ 10–17`; a Pearson autocorrelation on raw `d` would be dominated by a few giant products. `U ∈ [0,1]` is bounded, so the statistic reflects the *bulk's* serial structure, not the outliers.
    - **Known null.** Under H₀ the `Uᵢ` are uniform and independent, a clean reference for departures in mean, shape, or dependence.

3.  **Lag-1 autocorrelation.** `acf(...)$acf` returns lag 0 at index `[1]` (always

    1)  and lag 1 at index `[2]`:

    ```         
    acf1_U = Σ_{i=2}^{n} (Uᵢ − Ū)(U_{i−1} − Ū) / Σ_{i=1}^{n} (Uᵢ − Ū)²
    ```

    i.e. the sample correlation between each `Uᵢ` and its immediate predecessor.

### Interpretation

Under H₀ the `Uᵢ` are independent, so `acf1_U ≈ 0` with sampling SE ≈ `1/√n`. The **sign** discriminates the two candidate mechanisms:

| `acf1_U` | Temporal pattern | Implication |
|----|----|----|
| ≈ 0 | no runs | residuals look iid — modeled intensity captured the structure (NS01) |
| **\> 0** | large `d` follows large, small follows small (runs) | intensity biased **over stretches** — too low across some spans (calls faster than expected → repeated small `d`), too high across others (silences → repeated large `d`): **missing slow/low-frequency structure** (diel cycle, seasonal decline) |
| **\< 0** | large `d` followed by small `d` (alternation) | mean-reverting at lag 1: intensity **over-corrects after each event** — an **over-adaptive** GP / self-excitement term chasing the data |

For COX01, `acf1_U = +0.189` at n = 6098 (SE ≈ 0.013) is \~15 SE above zero — unambiguously positive. That **rules out** the over-adaptive-intensity hypothesis, which predicts the opposite sign, and points instead at omitted diel + end-of-window seasonal structure. NS01/NS02 sit at −0.025/−0.029 — within \~3 SE of zero.

### Why also Ljung–Box

`acf1_U` reads a single lag; genuine serial structure can spread across many. The **Ljung–Box** statistic pools the first *m* (= 20) autocorrelations into one omnibus test of H₀: no autocorrelation at any lag 1..*m*:

```         
Q = n(n+2) Σ_{k=1}^{m} ρ̂ₖ² / (n − k)   ~  χ²_m  under H₀
```

It is the principled back-up for the `acf1_U` headline. The lag-1 number and the omnibus can disagree, and here they do informatively: **NS02** has a negligible lag-1 (−0.029) yet Q = 93.3 (p = 2e−11), i.e. weak autocorrelation diffused over many lags that only the omnibus — powered by n = 33,611 — detects; **NS01** does not reject (Q = 23.0, p = 0.29). COX01's Q = 4834 remains two orders of magnitude larger than any other, so the magnitude ordering preserves the substantive conclusion.

### Caveats

- **Large-n significance.** At n = 6k–34k both Ljung–Box and KS reject on practically negligible departures. Report the **statistic magnitudes** (`Q`, `acf1_U`, `ks_D`), not just p \< 0.05.
- **Point-estimate read.** `dᵢ` is the posterior **median** increment (`postCompen[, 5]`); this ignores per-event posterior uncertainty in the compensator. Adequate for a diagnostic, but not a fully Bayesian residual.
- **`acf1_U` is one lag.** It is a sign-bearing summary, not a complete test — which is exactly why Ljung–Box accompanies it.

------------------------------------------------------------------------

## Why the diel term was left out (deliberate)

Excluding sub-daily harmonics was a **scoping decision**, not an oversight:

1.  **Fit cost.** The LGCPSE MCMC is expensive; each added harmonic pair widens the design matrix and lengthens already-long cluster fits.
2.  **Scientific focus.** The manuscript's question is the **seasonal** story. The weekly-to-bimonthly harmonic basis was chosen to resolve that, and a diel term is orthogonal to the seasonal narrative.

So the upper-tail misfit is the expected, understood cost of that choice — worth **reporting as a limitation** rather than treating as a defect.

*(2026-08-18: the correction above makes this scoping decision look even better in hindsight — the "diel rhythm" the basis supposedly couldn't capture appears not to exist in the gap-end evidence at all.)*

------------------------------------------------------------------------

## Recommendation / future work

*(Rewritten 2026-08-18 after the clock-boundary correction.)*

The 24-h/12-h harmonic refit previously recommended here is **on hold**: its motivating evidence (dawn-clustered gap ends) turned out to be a fixed clock boundary. Before any sub-daily term is considered, the boundary must be traced in the processing chain and a genuine diel rhythm demonstrated from the hour-of-day distribution of all calls (steps 1–4 in "What we still need to do" above).

Two further reasons the refit was always weaker than it looked:

1.  A 24-h harmonic cannot fix the dominant outliers anyway. Over a multi-day silence, a diel term modulates intensity *within* each day but the compensator still accumulates across days — the big `dᵢ` shrink only marginally.
2.  The one refit that did land (Apr-30 window + diel harmonic, 2026-07-02) made COX01 *worse*, because the window extension imported the end-of-season decline; the diel term's effect was unattributable. The 5-month window is now primary.

For the seasonal manuscript, the upper-tail misfit stays a **reported limitation**, per the section above.

------------------------------------------------------------------------

## Suggested manuscript text

*(Rewritten 2026-08-18 — the previous version claimed a dawn/diel rhythm from the gap-end times; that claim is withdrawn per the clock-boundary correction above. Do not resurrect clause (ii) from the old text.)*

> Acoustic coverage exceeded 99.9% at all three buoys, so the upper-tail departures in the RTC Q–Q diagnostics do not reflect recording gaps. They correspond to extended quiescent periods of several days to \~3 weeks during which calling ceased while the model retained nonzero intensity; the harmonic basis, which by design resolves periods of one week and longer (the analysis targets seasonal structure), cannot anticipate the onset or cessation of such episodes. A small number of short-interval departures reflect mild over-prediction by the self-excitement term during dense call clusters.
