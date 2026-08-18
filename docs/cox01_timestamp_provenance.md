# COX01 timestamp provenance: forensic record

**Finding:** 3,175 of the 10,377 COX01 detections (31%) — everything after
2022-02-16 — carry timestamps destroyed by an Excel re-save of one delivered
CSV, which collapsed full-precision times to 3 significant figures
(100,000-second ≈ 27.8-hour bins). These corrupted events are inside the
5-month fit window's final week and are the direct cause of COX01's Q–Q
catastrophe (MSD 15.1). The ingestion code is not at fault. NS01 and NS02 are
clean.

Investigation date: 2026-08-18. All row counts and timestamps below were
verified against the files on that date. Companion docs:
`docs/qq_diagnostics_findings.md` (the diagnostics this explains, including
the 2026-08-18 clock-boundary correction that started this chain).

---

## Executive summary

| Question | Answer |
|---|---|
| What is corrupt? | All COX01 detection times from 2022-02-22 19:46:40 through 2022-05-14 20:13:20 (3,175 events) |
| What broke them? | `NEFSC_MA-RI_202202_COX01_narwlog_ST.csv` was opened and re-saved in Excel before delivery; `start_time`/`end_time` were written back in scientific notation at 3 significant figures |
| Effective resolution | 0.01 × 10⁷ s = 100,000 s ≈ 27.8 hours per bin |
| Is our code at fault? | No — `2025-05-05_Wrangle-NEFSC-Call-Data.R` parsed every file correctly per its documented header |
| Are NS01/NS02 affected? | No — their 202202 `_ST` files are full precision (NS01: 2 duplicate-stamp rows in 29,663; NS02: 6 in 38,324; both are benign rounding pairs) |
| Is it in the fitted data? | Yes — `data/cox01.RData` (n = 6,098, window Oct 1 → Mar 1) contains 457 duplicated event times: bursts of 243, 80, 75, 63 on Feb 22/25/26/27 |
| Recoverable? | Not from anything on this machine. Requires a full-precision re-export of the 202202 COX01 file from NEFSC (Gen Davis / Hanna Kolipali) |
| Interim fix | Truncate COX01 at 2022-02-16 18:48:24 (end of clean data) and refit |

---

## Discovery timeline

1. **2026-06-22** — RTC Q–Q diagnostics flag COX01: MSD 15.1 vs 0.03–0.18 at
   NS01/NS02, driven by "~4 intervals in the final week (Feb 22–27)"
   (`docs/qq_diagnostics_findings.md`). Attributed at the time to an
   end-of-window seasonal decline.
2. **2026-06-27** — Dispersion decomposition (`08_qqDispersion.R`): COX01
   `var_d` = 17.31 collapsing to 0.877 without the top-5 outliers;
   `acf1_U` = +0.189. Attributed to missing slow structure (diel + seasonal
   decline).
3. **2026-07-02** — Apr-30-window refit makes COX01 *worse* (`var_drop` 21.9,
   `ks_D` 0.356, `acf1_U` 0.507). Attributed to the seasonal end-of-calling
   decline; leads to the spline experiments, eventually shelved (5-month
   window made primary 2026-08-06).
4. **2026-08-18 (a)** — Solar-curve test (`RScripts/plot_suntimes.R`) kills
   the "calls resume at dawn" reading of the ~05:00 gap-end cluster: dawn
   drifts >1 h across the season, the gap-ends don't. Verdict: fixed clock
   boundary. This prompts a hunt for processing boundaries.
5. **2026-08-18 (b)** — All-detections minute histogram
   (`RScripts/minute_histogram.R`) finds no 05:00 spike but exposes massive
   single-minute spikes at *irregular* clock times in COX01 only.
6. **2026-08-18 (c)** — Duplicate-stamp analysis: the spikes are bursts of up
   to 418 detections sharing one exact-to-the-second timestamp; bursts
   contain *distinct* calls (distinct frequencies), so times were collapsed,
   not rows duplicated.
7. **2026-08-18 (d)** — Raw-file reconciliation: the three raw narwlog CSVs in
   `data/raw_calls/` are clean and end 2022-02-16; the burst rows exist in
   none of them. The burst stamps are exact multiples of 100,000 s since
   2021-01-01 → 3-significant-figure rounding identified.
8. **2026-08-18 (e)** — Ingestion audit against
   `~/Documents/_research/rrr/hawkes_kp/src/2025-05-05_Wrangle-NEFSC-Call-Data.R`
   reveals the fourth source file (`..._202202_COX01_narwlog_ST.csv`, never
   copied into this repo). Direct inspection shows the mangled values are
   literal in the delivered file. Root cause closed.

---

## The defect, quantified

`data/cox_01_all.rds` (10,377 rows) decomposes exactly as:

| Component | Rows | Time span | Source |
|---|---:|---|---|
| Clean | 7,202 | 2021-02-26 21:03:38 → 2022-02-16 18:48:24 | three raw narwlog CSVs (post `species == 7 & call_type == 1` filter) |
| Mangled | 3,175 | 2022-02-22 19:46:40 → 2022-05-14 20:13:20 | `NEFSC_MA-RI_202202_COX01_narwlog_ST.csv` (3,317 data rows → 3,175 after the same filter) |

The mangled rows occupy only **33 distinct timestamps** (mean 96 events per
stamp, max 418). There is **no overlap** between the two components: clean
data stops Feb 16, mangled data starts Feb 22. Deduplication is therefore
both wrong (the calls are real and distinct — e.g. the 243-event burst holds
218 distinct rows with 45 distinct `start_freq` values) and insufficient
(there is no clean copy of those calls anywhere on this machine). Across all
bursts, ~326 rows are additionally *fully* identical (every column), i.e.
some calls became indistinguishable after their times and rounded frequencies
collided.

### Complete burst table (all 21 stamps with > 20 events)

`sec2021` = seconds since 2021-01-01 00:00:00 in the file's native base;
`sci` = that value at 3 significant figures, exactly as it appears in the
delivered CSV. Every stamp is an exact multiple of 100,000.

| start_datetime (as stored) | n | sec2021 | sci |
|---|---:|---:|---|
| 2022-03-16 19:33:20 | 418 | 38,000,000 | 3.80E+07 |
| 2022-04-07 19:20:00 | 353 | 39,900,000 | 3.99E+07 |
| 2022-03-24 22:00:00 | 326 | 38,700,000 | 3.87E+07 |
| 2022-03-23 18:13:20 | 290 | 38,600,000 | 3.86E+07 |
| 2022-02-25 03:20:00 | 243 | 36,300,000 | 3.63E+07 |
| 2022-04-06 15:33:20 | 198 | 39,800,000 | 3.98E+07 |
| 2022-04-02 00:26:40 | 197 | 39,400,000 | 3.94E+07 |
| 2022-03-15 15:46:40 | 169 | 37,900,000 | 3.79E+07 |
| 2022-03-04 02:00:00 | 133 | 36,900,000 | 3.69E+07 |
| 2022-03-11 00:40:00 | 129 | 37,500,000 | 3.75E+07 |
| 2022-03-05 05:46:40 | 90 | 37,000,000 | 3.70E+07 |
| 2022-02-27 10:53:20 | 80 | 36,500,000 | 3.65E+07 |
| 2022-03-01 18:26:40 | 77 | 36,700,000 | 3.67E+07 |
| 2022-02-26 07:06:40 | 75 | 36,400,000 | 3.64E+07 |
| 2022-03-02 22:13:20 | 70 | 36,800,000 | 3.68E+07 |
| 2022-02-22 19:46:40 | 63 | 36,100,000 | 3.61E+07 |
| 2022-03-19 03:06:40 | 57 | 38,200,000 | 3.82E+07 |
| 2022-03-31 20:40:00 | 36 | 39,300,000 | 3.93E+07 |
| 2022-03-21 10:40:00 | 31 | 38,400,000 | 3.84E+07 |
| 2022-04-04 08:00:00 | 23 | 39,600,000 | 3.96E+07 |
| 2022-04-03 04:13:20 | 22 | 39,500,000 | 3.95E+07 |

(The remaining 12 mangled stamps hold 1–20 events each; total mangled rows
3,175.)

### Fingerprints of the Excel re-save

Head of the delivered `NEFSC_MA-RI_202202_COX01_narwlog_ST.csv`:

```
# start_time.units: seconds since start date,,,,,
# start_time.start_date: 01/01/21 00:00:00,,,,,
...
3.61E+07,3.61E+07,116.586,186.093,999,0
3.61E+07,3.61E+07,143.492,286.989,7,1
```

Three independent tells:

1.  **`3.61E+07`** — Excel's General-format scientific display for large
    numbers, written back at display precision. Both `start_time` and
    `end_time` are affected (call durations are destroyed too).
2.  **Trailing `,,,,,` on every comment line** — Excel pads short rows out to
    the sheet's column count on save. The pristine files have bare comment
    lines.
3.  **Small-magnitude columns survived** — `start_freq`/`end_freq` (2–3
    digit values) kept ~6 significant figures, exactly what display-precision
    truncation predicts (small numbers don't trigger scientific display).

Contrast with the clean NS01 counterpart, same delivery, same date:

```
# start_time.units: seconds since start date
# start_time.start_date: 01/01/06 00:00:00
5.08233285462627E+08,5.08233286851516E+08,119.432,234.186,7,1
```

Full 15-significant-digit precision, no comma padding. **The corruption
happened to exactly one file of the delivery, before or during its export —
not on this machine and not in our code.**

### Verifying the arithmetic (spot checks)

- 2022-02-25 03:20:00 − 2021-01-01 00:00:00 = 420 d 3 h 20 min
  = 420×86,400 + 12,000 = **36,300,000 s** = 3.63E+07 ✓
- 2022-03-16 19:33:20 → 439 d + 70,400 s = **38,000,000 s** = 3.80E+07 ✓
- 2022-04-07 19:20:00 → 461 d + 69,600 s = **39,900,000 s** = 3.99E+07 ✓
- Bin width: adjacent representable values differ by 0.01E+07 = 100,000 s
  = 27 h 46 min 40 s. Burst stamps' seconds always end :00/:20/:40 because
  100,000 mod 60 = 40.

---

## File inventory

### This repo (`sne_ns01`)

| File | Rows/size | Status |
|---|---|---|
| `data/raw_calls/NEFSC_MA-RI_202102_COX01_narwlog.csv` | 1,666 lines (1,620 data) | clean; `start_date 01/01/21` |
| `data/raw_calls/NEFSC_MA-RI_202107_COX01_narwlog.csv` | 59 lines (13 data) | clean; `start_date 01/01/21` |
| `data/raw_calls/NEFSC_MA-RI_202111_COX01_narwlog.csv` | 5,932 lines (5,886 data) | clean; **`start_date 01/01/70` (Unix epoch — different base!)**; calls 2021-11-06 05:07:55 → 2022-02-16 18:48:24; max duplicate stamp count 2 (benign second-rounding pairs) |
| `data/raw_calls/NEFSC_MA-RI_202202_COX01_narwlog_ST.csv` | **absent** | the corrupted fourth source was never copied into this repo — that's why the burst rows initially appeared to come from nowhere |
| `data/cox_01_all.rds` | 10,377 rows | CONTAMINATED (3,175 mangled rows, Feb 22 → May 14) |
| `data/cox01.RData` | n = 6,098 events | CONTAMINATED (5,641 unique `ts`; 457 duplicated; four bursts Feb 22–27 inside the Oct 1 → Mar 1 window) |
| `data/ns_01_all.rds` | 29,663 rows | clean (2 duplicate-stamp rows) |
| `data/ns_02_all.rds` | 38,324 rows | clean (6 duplicate-stamp rows) |

Raw CSV layout (all narwlog files): 43 `#` comment lines; line 44 = header;
line 45 = column descriptions; line 46 = units; data from line 47.

### Origin repo (`~/Documents/_research/rrr/hawkes_kp`)

Delivery directory `data/2025-05-05_CCB_acoustic_data/` (13 files):
deployment metadata + 12 narwlog CSVs (4 per buoy). The 202202 files carry an
`_ST` suffix. Only the COX01 `_ST` file is mangled.

Ingestion script: `src/2025-05-05_Wrangle-NEFSC-Call-Data.R` (header credits
the delivery to Gen Davis and Hanna Kolipali, NEFSC).

### Time-base zoo (for anyone touching these files again)

| File group | `start_time.start_date` | Parsed with origin |
|---|---|---|
| 202102/202103/202107 (all buoys) | 01/01/21 | 2021-01-01 ✓ |
| 202110/202111 (all buoys) | 01/01/70 | 1970-01-01 ✓ |
| 202202 `_ST` COX01 | 01/01/21 | 2021-01-01 ✓ |
| 202202 `_ST` NS01/NS02 | 01/01/06 | 2006-01-01 ✓ |

Every file was parsed per its own documented header. The wrangle script's
comment ("these have different origin times; not sure why") flagged the
inconsistency without reaching the precision defect — which is invisible at
that stage because the mangled values parse into perfectly plausible
Feb–May 2022 datetimes.

**Why timestamps look "labeled UTC but actually EST":** all origins were
applied with `tz = 'UTC'`, so the stored datetimes inherit whatever clock the
analyst logs used. This is the separate, still-open clock-provenance question
(see below).

---

## Ingestion audit: the wrangle script is exonerated

Checked line by line (2026-08-18):

- Each of the four COX01 files is read with `skip = 45`, columns renamed,
  filtered to `species == 7 & call_type == 1`, and timestamped with the
  origin from its own header. Correct in every case.
- 202202 `_ST` row accounting: 3,317 data rows → 3,175 after the
  species/call-type filter → exactly the 3,175 mangled rows in the RDS. ✓
- `ts` is the midpoint of `BeginTimes`/`EndTimes` in minutes, measured from
  the earliest 202102 call (2021-02-26 21:03:38); all four deployments use
  that same reference. ✓ (This is why mangled `ts` values like 211,879.36
  aren't obviously round — the roundness lives in the 2021-01-01 base, not
  the `ts` base.)
- Soft spots noted, none causal: `skip = 45` silently consumes the units row
  as the header row (fragile if NEFSC changes the comment-block length); no
  uniqueness assertion on timestamps (would have caught this at ingestion);
  the fourth COX01 raw file was not propagated into `sne_ns01/data/raw_calls`.

---

## Downstream contamination map

Everything COX01-specific that consumed events after 2022-02-16 is suspect:

| Artifact | Impact |
|---|---|
| 5-month fits (`LGCPSE`, window Oct 1 → Mar 1) | Final week (Feb 22–28) consists of 4 instantaneous bursts (243/80/75/63 events). The Hawkes term sees 243 simultaneous events; the following near-silence yields the giant compensator increments previously read as "end-of-window seasonal decline". |
| Q–Q diagnostics (`05_sumRTCT.R`) | COX01 MSD 15.099 and the "~4 late-Feb outliers" are artifacts of the bursts, not biology. |
| Dispersion table (`08_qqDispersion.R`, 2026-06-27) | COX01 `var_d` 17.31, `acf1_U` +0.189, LB Q 4,834 — all confounded. NS01/NS02 rows unaffected. |
| Apr-30-window experiments (2026-07-02) & spline program | Mar–Apr events were **entirely** 27.8-h-binned: 100% of COX01's added data was corrupt. The "seasonal decline can't be represented" diagnosis and the spline gate result at COX01 are built on this. |
| Gap/coverage verdicts (`07_gapVsCoverage.R`) | COX01's late-Feb "true silence" intervals are inter-burst artifacts. NS01/NS02 verdicts stand. |
| Anything reading `data/cox_01_all.rds` or `data/cox01.RData` directly | Same contamination. |

**What survives:** all NS01/NS02 results; COX01 results through 2022-02-16;
the compensator-budget/under-dispersion *mechanics* in the Q–Q doc (the math
is sound, the attribution isn't); and coarse seasonal statements about
Mar–May COX01 calling (the mangled rows still count calls correctly at
~daily resolution — they must simply never enter a point-process likelihood).

**Still open, and *not* explained by this defect:** the ~05:00 gap-end
clustering at NS01/NS02 (clean files) from the clock-boundary correction in
`docs/qq_diagnostics_findings.md`. The minute histogram shows no dataset-wide
05:00 stamp spike, so that remains an unexplained boundary phenomenon —
separate investigation.

---

## Recovery plan

1.  **Request a re-export** of `NEFSC_MA-RI_202202_COX01_narwlog_ST.csv`
    from Gen Davis / Hanna Kolipali (NEFSC), explicitly asking that it not
    pass through Excel (or be exported as text with full numeric precision).
    The underlying log almost certainly retains full precision, since the
    NS01/NS02 `_ST` exports from the same delivery do.
2.  **Acceptance checks for the replacement file** (all must pass):
    - comment lines have no trailing `,,,,,` padding;
    - `start_time` values carry ≥ 10 significant digits (e.g.
      `3.6300123456E+07`, not `3.63E+07`);
    - ~3,317 data rows; calls spanning late Feb → mid-May 2022 under
      `origin = start_date` from its own header;
    - zero exact-duplicate `start_time` values beyond occasional benign
      pairs;
    - after the `species == 7 & call_type == 1` filter, per-day call counts
      match the mangled file's per-bin counts when both are aggregated to
      the 100,000-s bins (the mangled file is a valid coarse histogram of
      the truth — use it as the cross-check).
3.  **Rebuild** `cox_01_all.rds` via the wrangle script with the new file,
    adding `stopifnot(!any(duplicated(start_datetime)))` per deployment; copy
    the fourth raw file into `sne_ns01/data/raw_calls/` this time.
4.  **Add a guard in `01_data.R`**: assert `ts` uniqueness (or a hard error
    if any timestamp carries more than a handful of events) so corrupt
    deliveries can never reach a fit again.
5.  **Refit COX01** (full `02 → 04 → 05` pipeline) and re-run `05–08`
    diagnostics; update the tables in `docs/qq_diagnostics_findings.md`,
    which currently carry pre-discovery COX01 numbers flagged as baseline.
6.  **Interim** (if the re-export is slow): truncate COX01's window at
    2022-02-16 18:48:24 and refit — expected outcome is COX01 diagnostics
    falling in line with NS01/NS02.

---

## Reproduction commands

Duplicate-stamp census (any buoy):

``` r
x <- readRDS('data/cox_01_all.rds')
sum(duplicated(x$start_datetime) | duplicated(x$start_datetime, fromLast = TRUE))
head(dplyr::count(x, start_datetime, sort = TRUE))
```

Mangled-row isolation (the 100,000-s signature):

``` r
sec2021 <- as.numeric(x$start_datetime) -
  as.numeric(as.POSIXct('2021-01-01', tz = attr(x$start_datetime, 'tzone')))
mangled <- x[sec2021 > 3e7 & sec2021 %% 1e5 == 0, ]
range(mangled$start_datetime)   # 2022-02-22 19:46:40 -> 2022-05-14 20:13:20
```

Raw-file precision check (no R needed):

``` sh
awk -F, 'NR>46 {print $1}' NEFSC_MA-RI_202202_COX01_narwlog_ST.csv | sort -u | head
# clean file -> 15-digit mantissas; mangled -> 3-digit (X.XXE+07)
```

Fitted-data check:

``` r
load('data/cox01.RData')            # objects: data, noise
length(data$ts); length(unique(data$ts))   # 6098 vs 5641
head(sort(table(data$ts), decreasing = TRUE))  # 243, 80, 75, 63, ...
```

Detection scripts (this repo): `RScripts/minute_histogram.R` (the check that
exposed the bursts), `RScripts/plot_suntimes.R` (the solar-curve test that
prompted it).
