---

editor_options: 
  markdown: 
    wrap: 72
---

# Harmonic EDA checklist — deciding which periodic terms to fit over a longer deployment

A standalone, runnable checklist for the exploratory data analysis to do *before* choosing `harm_periods_lgcp` (and the analysis window) in `src/config.R`. It consolidates guidance previously scattered across [`docs/modeling_domain_guidance.md`](modeling_domain_guidance.md) §2 and the diel / dispersion reasoning in [`docs/qq_diagnostics_findings.md`](qq_diagnostics_findings.md).

**The core idea.** A harmonic can only *help* if the signal it targets is (a) really present in the raw data and (b) reasonably stable over the span you fit. The plots below answer "present?" and "stable?" for each candidate period, so you add terms on evidence rather than reflex. The paired model-side diagnostic (§5, the sign of `acf1_U`) tells you *after* a fit whether a period is still missing.

Every snippet is self-contained and uses this repo's raw files:

- **calls:** `data/<buoy>_all.rds` — has `ts` (minutes from the deployment origin) and `start_datetime` (POSIXct, **labeled UTC but actually EST**);
- **noise:** `data/<buoy>_rms_data.rds` — has `UTC` (minute grid) and `RMS`;
- **window constants:** `std`, `analysis_end` from `src/config.R`.

> Reminder from the code: timestamps are labeled UTC but are **EST**. "Dawn \~05:00" below is EST. Don't apply a tz shift when reading hour-of-day.

------------------------------------------------------------------------

## 0. Setup — load the raw calls on a real clock

``` r
library(tidyverse)
source("src/config.R")   # gives std, analysis_end, buoy, buoy_cfg

calls <- readRDS(file.path("data", buoy_cfg$call_file)) %>%
  # start_datetime is labeled UTC but is actually EST; treat the clock as-is.
  transmute(
    dt   = start_datetime,
    date = as.Date(start_datetime),
    hour = as.numeric(format(start_datetime, "%H")) +
           as.numeric(format(start_datetime, "%M")) / 60   # fractional hour 0–24
  )

# Full available record (NOT yet cut to the analysis window) — EDA should look
# at everything the recorder captured, then decide where to cut.
range(calls$dt)
```

Keep two versions in mind: the **full record** (for the window decision) and the **windowed** subset `filter(dt >= std, dt <= analysis_end)` (for what the current fit actually sees). Look at both.

------------------------------------------------------------------------

## 1. Phenological envelope — daily counts with a smoother

*Question: where does the rate rise out of, and decay back toward, baseline?* This drives the **window** decision and whether you need a seasonal spline vs. just harmonics.

``` r
daily <- calls %>% count(date, name = "n")

ggplot(daily, aes(date, n)) +
  geom_col(width = 1, colour = NA, fill = "grey70") +
  geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), se = TRUE) +
  geom_vline(xintercept = as.Date(c(std, analysis_end)),
             linetype = 2, colour = "steelblue") +
  labs(title = paste(toupper(buoy), "— daily call counts (full record)"),
       subtitle = "dashed = current analysis window; look at the on-ramp AND off-ramp",
       x = NULL, y = "calls / day") +
  theme_bw()
```

What to read off it:

- **On-ramp / plateau / off-ramp.** If the rate decays smoothly toward \~0 inside the record (a *soft biological decline*), periodic harmonics **cannot** follow it — that's the seasonal-spline case (see `seasonal_spline` in `config.R`), not a harmonic you can add.
- **Where to cut.** The window boundary should sit where your basis can still represent the rate. Extending into a long silence the basis can't follow is what inflates the RTC compensator (the Apr-30 lesson).

------------------------------------------------------------------------

## 2. Rate vs. the detector noise floor — is the tail real signal?

*Question: past what point are "calls" mostly detector artifacts?* Including that tail injects **structured noise** the point process will try to explain — often the real reason to truncate rather than extend.

``` r
noise <- readRDS(file.path("data", buoy_cfg$noise_file)) %>%
  transmute(date = as.Date(UTC), RMS) %>%
  group_by(date) %>% summarise(rms = mean(RMS, na.rm = TRUE), .groups = "drop")

daily %>%
  left_join(noise, by = "date") %>%
  pivot_longer(c(n, rms)) %>%
  ggplot(aes(date, value)) +
  geom_line() +
  facet_wrap(~ name, ncol = 1, scales = "free_y",
             labeller = as_labeller(c(n = "calls / day", rms = "mean RMS noise"))) +
  geom_vline(xintercept = as.Date(c(std, analysis_end)),
             linetype = 2, colour = "steelblue") +
  labs(title = paste(toupper(buoy), "— call rate vs. noise floor"), x = NULL, y = NULL) +
  theme_bw()
```

If the call rate collapses toward the level where RMS noise (false positives) dominates, that span is not carrying biological signal — truncate before it rather than asking a harmonic to fit noise.

------------------------------------------------------------------------

## 3. Hour-of-day — does a diel rhythm exist, and is it stable?

*This is the direct harmonic-selection tool.* It answers all three questions for the 24-h term: **does a diel cycle exist, is it stable across the deployment, and over what span is a 24-h harmonic warranted?**

### 3a. Aggregate diel cycle

``` r
ggplot(calls, aes(hour)) +
  geom_histogram(breaks = 0:24, fill = "grey60", colour = "white") +
  scale_x_continuous(breaks = seq(0, 24, 3)) +
  geom_vline(xintercept = 5, linetype = 2, colour = "firebrick") +  # dawn ~05:00 EST
  labs(title = paste(toupper(buoy), "— calls by hour of day (all seasons)"),
       subtitle = "red = ~05:00 EST dawn resumption seen in the gap-ending events",
       x = "hour of day (EST)", y = "calls") +
  theme_bw()
```

A clear peak/trough here = a real 24-h signal → a 24-h harmonic is justified. A secondary structure (e.g. a dusk shoulder) hints you may also want the **12-h** term.

### 3b. Stability across sub-seasons (the "is it stable?" check)

A harmonic assumes a *fixed* phase/amplitude over the whole window. Facet by month to check that assumption before you commit to it:

``` r
calls %>%
  mutate(mon = factor(format(dt, "%Y-%m"))) %>%
  count(mon, hour = floor(hour)) %>%
  group_by(mon) %>% mutate(frac = n / sum(n)) %>%      # normalize: shape, not volume
  ggplot(aes(hour, frac)) +
  geom_col(fill = "grey60") +
  geom_vline(xintercept = 5, linetype = 2, colour = "firebrick") +
  facet_wrap(~ mon) +
  labs(title = paste(toupper(buoy), "— diel shape by month"),
       subtitle = "same dawn peak every month → one stable 24-h harmonic is enough",
       x = "hour of day (EST)", y = "fraction of that month's calls") +
  theme_bw()
```

- **Same shape every month** → one stationary 24-h (and maybe 12-h) harmonic covers the whole window.
- **Phase or amplitude drifts** (e.g. dawn peak migrates, or diel structure only appears mid-season) → a single global harmonic will be misspecified. Consider a shorter window, a season×hour interaction, or letting the GP absorb it — a single sinusoid won't.

------------------------------------------------------------------------

## 4. Spectral view — let the data rank the candidate periods

Rather than guessing periods, bin the calls to a regular series and look at where the power actually concentrates. Peaks tell you which harmonics to include; the absence of a peak at a candidate period tells you to leave it out.

``` r
# Regular hourly count series across the window (fill empty hours with 0).
win <- calls %>% filter(dt >= std, dt <= analysis_end)
grid <- tibble(h = seq(floor_date(min(win$dt), "hour"),
                       ceiling_date(max(win$dt), "hour"), by = "hour"))
series <- grid %>%
  left_join(count(mutate(win, h = floor_date(dt, "hour")), h, name = "n"), by = "h") %>%
  mutate(n = replace_na(n, 0))

# Periodogram; convert cycles/hour to a period in DAYS for readability.
sp <- spectrum(series$n, log = "no", plot = FALSE, detrend = TRUE, taper = 0.1)
tibble(period_days = 1 / sp$freq / 24, power = sp$spec) %>%
  filter(period_days <= 40) %>%
  ggplot(aes(period_days, power)) +
  geom_line() +
  geom_vline(xintercept = c(0.5, 1, 7, 14, 30),  # 12h, 1d, 1wk, 2wk, 1mo
             linetype = 3, colour = "firebrick") +
  scale_x_log10(breaks = c(0.5, 1, 7, 14, 30)) +
  labs(title = paste(toupper(buoy), "— periodogram of hourly call counts"),
       subtitle = "vertical lines = candidate harmonic periods; keep the ones under a peak",
       x = "period (days, log scale)", y = "spectral power") +
  theme_bw()
```

Read it as a menu: a peak at **1 day** confirms the diel term, a peak at **0.5 day** confirms 12-h, peaks at 7/14/30-day confirm the weekly-to-monthly set already in `harm_periods_lgcp`. A candidate period with **no** peak is a term you can drop to save MCMC cost. (Cross-check §3 before trusting a diel peak — a periodogram can be fooled by an uneven duty cycle.)

------------------------------------------------------------------------

## 5. The paired model-side diagnostic — did a harmonic go missing?

EDA proposes; the fit disposes. After a fit, `08_qqDispersion.R` reports `acf1_U` (lag-1 autocorrelation of the PIT residual `U = 1 − exp(−d)` in event order). Its **sign** is the tell:

| `acf1_U` | Meaning | Action |
|----------------------------:|----------------------|----------------------|
| **\> 0** | residual has runs → **missing slow/low-frequency structure** (a diel cycle or seasonal decline the basis can't represent) | add the harmonic (or spline) that §1/§3/§4 flagged, refit |
| **≈ 0** | serial structure absorbed | basis is adequate at this timescale |
| **\< 0** | over-adaptive GP/Hawkes overshoot | *don't* add harmonics — that's the wrong fix |

This is how you close the loop: EDA says "there's a 24-h signal," you add the term, and a positive `acf1_U` collapsing toward 0 is the evidence it worked. Whether a period cures the RTC over-dispersion is gated on this + `var_drop → ~1`, not on the periodogram alone.

------------------------------------------------------------------------

## Decision summary

1.  **Plot the envelope (§1).** Smooth decline toward 0 inside the record → seasonal *spline*, not a harmonic. Set the window where the basis can still follow.
2.  **Check the noise floor (§2).** Truncate before "calls" become detector artifacts; don't ask a harmonic to fit false positives.
3.  **Plot hour-of-day, aggregate and by month (§3).** Peak present + stable across months → add the 24-h (and 12-h if there's a second peak) harmonic. Drifting phase → a global sinusoid is misspecified.
4.  **Periodogram (§4).** Keep candidate periods that sit under a peak; drop the rest to save MCMC cost.
5.  **Refit and read `acf1_U` (§5).** Positive → still missing slow structure, keep going. Negative → stop adding harmonics.

### Caveats carried over from the diagnostics work

- The diel harmonic and the Apr-30 window were changed in the **same commit**, so the diel term's effect is currently *unattributable* — the clean test is diel on/off at a **fixed** window.
- Each harmonic pair (`sin` + `cos`) widens the expensive LGCPSE MCMC; add on evidence, not reflex.
- Low-frequency harmonics (1–2 month) **overlap a seasonal spline**; if you run the spline, watch identifiability (the code drops the 2-month term when the spline is on — see `seasonal_spline_drop_period` in `config.R`).
- Give the **window start** the same scrutiny as the end: the on-ramp has the identical problem, and for harmonic models the phase anchor (`harm_start_time`) interacts with the start.
