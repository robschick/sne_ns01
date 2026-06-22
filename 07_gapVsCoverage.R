# =============================================================================
# 07_gapVsCoverage.R — Is each upper-tail Q-Q gap a recording outage or a real
# biological silence?
#
# 06_qqOutliers.R flags the intervals with the largest compensator increments.
# This script tests, for each one, whether the gap coincides with missing
# acoustic coverage. The raw noise (RMS) logger runs on a 1-minute grid; minutes
# with no raw observation are taken as recorder downtime (same gaps 01_data.R
# interpolates over). If a long call gap overlaps missing-noise minutes it is a
# recording gap; if noise is present throughout, it is a true silence the model
# failed to capture.
#
# Classification per interval:
#   excitement (short)  interval < 60 min  -> not a gap; self-excitement overshoot
#   recording gap       >= 50% of minutes have no noise observation
#   true silence        <= 10% missing (recorder on, whales quiet)
#   partial coverage    in between
#
# Reads Stage-4 rtct (rtct/<buoy>/) + raw noise rds (data/<buoy noise file>).
# Buoys missing either input are skipped with a warning.
#
# Usage:   Rscript 07_gapVsCoverage.R         <-- run WITHOUT --buoy; loops all.
# Env:     QQ_TOPN=<n>   intervals per buoy to test (default 15; matches 06).
#
# Outputs (fig/combined/):
#   gap_vs_coverage.csv / .tex      per-interval verdict
#   coverage_summary.csv            per-buoy window coverage
# =============================================================================

rm(list = ls())
library(tidyverse); library(xtable)

source('src/RFtns.R')   # config sourced per-buoy in the loop

buoys       <- c('ns01', 'ns02', 'cox01')
buoy_labels <- c(ns01 = 'NS01', ns02 = 'NS02', cox01 = 'COX01')
topn        <- as.integer(Sys.getenv('QQ_TOPN', unset = '15'))

classify <- function(interval_min, missing_frac) {
  dplyr::case_when(
    interval_min < 60      ~ 'excitement (short)',
    missing_frac >= 0.50   ~ 'recording gap',
    missing_frac <= 0.10   ~ 'true silence',
    TRUE                   ~ 'partial coverage'
  )
}

gap_list      <- list()
coverage_list <- list()

for (b in buoys) {
  Sys.setenv(BUOY = b)
  source('src/config.R')   # std, path.rtct, datai, fiti_lgcp, buoy_cfg
  fiti <- fiti_lgcp

  rtctfile  <- paste0(path.rtct, datai, fiti, '_rtct.RData')
  noisefile <- file.path('data', buoy_cfg$noise_file)
  if (!file.exists(rtctfile) || !file.exists(noisefile)) {
    warning(sprintf('%s skipped: missing %s', b,
                    if (!file.exists(rtctfile)) rtctfile else noisefile))
    next
  }

  load(rtctfile)                 # ts (minutes from std), postCompen
  noise_raw <- readRDS(noisefile)  # raw RMS logger; UTC column

  # ── Noise-coverage mask over the analysis window (minutes from std) ─────────
  # present[k+1] == TRUE  <=>  a raw noise observation exists at minute-offset k.
  maxoff  <- ceiling(max(ts))
  present <- logical(maxoff + 1)
  off     <- round((as.numeric(noise_raw$UTC) - as.numeric(std)) / 60)
  off     <- off[off >= 0 & off <= maxoff]
  present[off + 1] <- TRUE

  coverage_list[[b]] <- tibble(
    Buoy            = buoy_labels[[b]],
    window_hr       = round(maxoff / 60, 1),
    covered_frac    = round(mean(present), 4),
    missing_hr      = round(sum(!present) / 60, 1)
  )

  # ── Per-event intervals; the increment integrates [prev event, this event] ──
  start_ts <- dplyr::lag(ts, default = 0)   # first event's predecessor = window start
  miss_frac <- vapply(seq_along(ts), function(i) {
    mins <- seq(floor(start_ts[i]), ceiling(ts[i]))
    mins <- mins[mins >= 0 & mins <= maxoff]
    if (!length(mins)) return(NA_real_)
    mean(!present[mins + 1])
  }, numeric(1))

  qq <- tibble(
    d         = postCompen[, 5],
    when      = std + ts * 60,
    interval_min = ts - start_ts,
    miss_frac = miss_frac
  ) %>%
    slice_max(d, n = topn) %>%
    transmute(
      Buoy = buoy_labels[[b]],
      rank = row_number(),
      when = format(when, '%Y-%m-%d %H:%M'),
      gap_hr        = round(interval_min / 60, 2),
      d             = round(d, 2),
      noise_missing = round(miss_frac, 3),
      verdict       = classify(interval_min, miss_frac)
    )
  gap_list[[b]] <- qq
}

# ── Write & print ─────────────────────────────────────────────────────────────
out_dir <- file.path('fig', 'combined')
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

if (length(coverage_list)) {
  coverage_tbl <- bind_rows(coverage_list)
  cat('\n=== Acoustic coverage over the analysis window ===\n')
  print(as.data.frame(coverage_tbl), row.names = FALSE)
  write_csv(coverage_tbl, file.path(out_dir, 'coverage_summary.csv'))
}

if (length(gap_list)) {
  gap_tbl <- bind_rows(gap_list)
  cat(sprintf('\n=== Top-%d gaps: recording outage vs. true silence ===\n', topn))
  print(as.data.frame(gap_tbl), row.names = FALSE)
  cat('\n--- verdict tally ---\n')
  print(gap_tbl %>% count(Buoy, verdict))

  write_csv(gap_tbl, file.path(out_dir, 'gap_vs_coverage.csv'))
  print(xtable(gap_tbl, caption = 'Upper-tail Q-Q gaps vs. acoustic coverage.'),
        booktabs = FALSE, include.rownames = FALSE,
        file = file.path(out_dir, 'gap_vs_coverage.tex'))
  cat(sprintf('\nWrote tables to %s/\n', out_dir))
} else {
  cat('\n[no inputs found — nothing written]\n')
}
