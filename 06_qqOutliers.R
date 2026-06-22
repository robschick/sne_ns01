# =============================================================================
# 06_qqOutliers.R — Localize the upper-tail departures in the RTC Q-Q plots.
#
# The random-time-change Q-Q diagnostic (05_sumRTCT.R) shows the per-event
# compensator increments d_i sitting on the 45-deg line when the model is
# correct (d_i ~ Exp(1)). Departures are confined to the extreme upper tail —
# a few intervals where the model integrated more intensity than the single
# observed gap implies (the model expected calls but a long quiet gap occurred).
#
# This script reports, per buoy, the largest-d_i intervals with their real
# inter-call gap (minutes) and wall-clock time, so they can be cross-referenced
# against known recording/detector gaps or seasonal lulls. It also prints a
# calibration summary (fraction of events whose per-event credible band
# excludes the diagonal).
#
# Reads the Stage-4 rtct output (rtct/<buoy>/<buoy>LGCPSE_rtct.RData); buoys
# with no rtct file are skipped with a warning, so it degrades gracefully if
# rtct/ has not been rsync'd down.
#
# Usage:   Rscript 06_qqOutliers.R          <-- run WITHOUT --buoy; loops all.
# Env:     QQ_TOPN=<n>   number of top-d intervals per buoy (default 15).
#
# Outputs (fig/combined/):
#   qq_outliers.csv / .tex          top-d intervals per buoy
#   qq_calibration_summary.csv      per-buoy calibration fractions
# =============================================================================

rm(list = ls())
library(tidyverse); library(xtable)

source('src/RFtns.R')   # config sourced per-buoy in the loop

buoys       <- c('ns01', 'ns02', 'cox01')
buoy_labels <- c(ns01 = 'NS01', ns02 = 'NS02', cox01 = 'COX01')
topn        <- as.integer(Sys.getenv('QQ_TOPN', unset = '15'))

outlier_list <- list()
summary_list <- list()

for (b in buoys) {
  Sys.setenv(BUOY = b)
  source('src/config.R')   # std, path.rtct, datai, fiti_lgcp
  fiti <- fiti_lgcp

  rtctfile <- paste0(path.rtct, datai, fiti, '_rtct.RData')
  if (!file.exists(rtctfile)) {
    warning(sprintf('rtct file missing for %s (%s) — skipped. %s',
                    b, rtctfile, 'Run 04_rtctLGCPSE.R and rsync rtct/ down.'))
    next
  }
  load(rtctfile)   # ts, postCompen (cols 4:6 = per-event increment lb, med, ub)

  n   <- length(ts)
  gap <- c(NA, diff(ts))   # real inter-call gap (minutes), preceding each event

  qq <- tibble(
    event = seq_len(n),
    ts    = ts,
    when  = std + ts * 60,            # wall-clock (std origin, from config)
    gap_min = gap,
    d_lb  = postCompen[, 4],
    d     = postCompen[, 5],
    d_ub  = postCompen[, 6]
  ) %>%
    # Theoretical Exp(1) quantile at each event's rank in the sorted-d sequence,
    # matching 05_sumRTCT.R: log(n) - log(n - (rank - 0.5)).
    arrange(d) %>%
    mutate(theoretical = log(n) - log(n - (row_number() - 0.5))) %>%
    arrange(event)

  # ── Calibration summary: does each event's credible band straddle y = x? ───
  above <- qq$d_lb > qq$theoretical    # whole band above diagonal (too long)
  below <- qq$d_ub < qq$theoretical    # whole band below diagonal (too short)
  summary_list[[b]] <- tibble(
    Buoy          = buoy_labels[[b]],
    n_events      = n,
    frac_above    = round(mean(above), 4),
    frac_below    = round(mean(below), 4),
    frac_outside  = round(mean(above | below), 4),
    max_d         = round(max(qq$d), 2),
    max_gap_hr    = round(max(gap, na.rm = TRUE) / 60, 2)
  )

  # ── Top-d intervals (the upper-tail points) ────────────────────────────────
  outlier_list[[b]] <- qq %>%
    slice_max(d, n = topn) %>%
    transmute(
      Buoy = buoy_labels[[b]],
      rank = row_number(),
      when = format(when, '%Y-%m-%d %H:%M'),
      gap_hr      = round(gap_min / 60, 2),
      d           = round(d, 2),
      theoretical = round(theoretical, 2),
      excess      = round(d - theoretical, 2)   # how far above the diagonal
    )
}

# ── Write & print ─────────────────────────────────────────────────────────────
out_dir <- file.path('fig', 'combined')
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

if (length(summary_list)) {
  summary_tbl <- bind_rows(summary_list)
  cat('\n=== Q-Q calibration summary (frac_outside = events whose band excludes y=x) ===\n')
  print(as.data.frame(summary_tbl), row.names = FALSE)
  write_csv(summary_tbl, file.path(out_dir, 'qq_calibration_summary.csv'))
}

if (length(outlier_list)) {
  outlier_tbl <- bind_rows(outlier_list)
  cat(sprintf('\n=== Top-%d compensator increments per buoy (largest upper-tail gaps) ===\n', topn))
  print(as.data.frame(outlier_tbl), row.names = FALSE)

  write_csv(outlier_tbl, file.path(out_dir, 'qq_outliers.csv'))
  print(xtable(outlier_tbl, caption = 'Largest RTC compensator increments (upper-tail Q-Q departures).'),
        booktabs = FALSE, include.rownames = FALSE,
        file = file.path(out_dir, 'qq_outliers.tex'))
  cat(sprintf('\nWrote tables to %s/\n', out_dir))
} else {
  cat('\n[no rtct outputs found for any buoy — nothing written]\n')
}
