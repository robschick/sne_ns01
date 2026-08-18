# =============================================================================
# 05c_sumRTCTzoomAll.R — All-buoy full vs. bulk-zoom RTC Q-Q panel.
#
# Loop-all companion to 05b_sumRTCTzoom.R (which does one buoy at a time). It
# builds, for every buoy, the same two views of the random-time-change Q-Q
# diagnostic and arranges them into a single labelled figure:
#
#   columns = buoys (NS01, NS02, COX01)   <- side by side
#   row 1   = full range  (the upper tail is visible)
#   row 2   = central COVERAGE zoom (default 95%; the bulk is legible)
#
# Every panel is titled "<BUOY> — Full" / "<BUOY> — Zoom" so it is unambiguous
# which is which. Each panel keeps its own axis limits: the full panels differ
# a lot across buoys (COX01's end-of-window tail dwarfs NS02's), which is
# expected; the zoom panels clip near the same Exp(1) quantile (~3) and so line
# up naturally for a bulk-calibration comparison.
#
# As in 05b, the zoom is a coord_cartesian() viewport change only — points,
# band, diagonal, and MSD are computed on the full data, nothing is dropped.
#
# Reads the Stage-4 rtct output (rtct/<buoy>/<buoy>LGCPSE_rtct.RData); buoys
# with no rtct file are skipped with a warning (degrades gracefully if rtct/
# has not been rsync'd down).
#
# Usage:   Rscript 05c_sumRTCTzoomAll.R       <-- run WITHOUT --buoy; loops all.
# Env:     QQ_COVERAGE=<f>   central fraction shown in the zoom (default 0.95).
#
# Output:  fig/combined/QQband_allbuoys.pdf
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(patchwork)

source('src/RFtns.R')   # config sourced per-buoy in the loop

buoys       <- c('ns01', 'ns02', 'cox01')
buoy_labels <- c(ns01 = 'NS01', ns02 = 'NS02', cox01 = 'COX01')
coverage    <- as.numeric(Sys.getenv('QQ_COVERAGE', unset = '0.99'))
stopifnot(coverage > 0, coverage < 1)

# ── Shared base plot builder ─────────────────────────────────────────────────
# full and zoom differ only in coord_cartesian() limits and the panel title.
build_qq <- function(df, line.df, limits, title) {
  df %>%
    ggplot(aes(x = Theoretical)) +
    geom_ribbon(aes(ymin = lb, ymax = newub), fill = 'grey70', alpha = 0.8) +
    geom_point(aes(y = Sample), size = 0.5) +
    geom_line(aes(x = x, y = y), line.df) +
    coord_cartesian(xlim = limits, ylim = limits, expand = FALSE) +
    labs(x = 'Theoretical', y = 'Sample', title = title) +
    theme_bw() +
    theme(plot.title = element_text(size = 10))
}

full_plots <- list()
zoom_plots <- list()

for (b in buoys) {
  Sys.setenv(BUOY = b)
  source('src/config.R')   # path.rtct, datai, fiti_lgcp
  fiti  <- fiti_lgcp
  label <- buoy_labels[[b]]

  rtctfile <- paste0(path.rtct, datai, fiti, '_rtct.RData')
  if (!file.exists(rtctfile)) {
    warning(sprintf('rtct file missing for %s (%s) — skipped. %s',
                    b, rtctfile, 'Run 04_rtctLGCPSE.R and rsync rtct/ down.'))
    next
  }
  load(rtctfile)   # ts, postCompen (cols 4:6 = per-event increment lb, med, ub)

  data.d <- data.frame(
    lb = postCompen[, 4],
    d  = postCompen[, 5],
    ub = postCompen[, 6]
  )

  # Q-Q data — identical construction to 05_sumRTCT.R.
  data.qq <- data.d %>%
    arrange(d) %>%
    mutate(
      Sample      = d,
      Theoretical = log(n()) - log(n() - (row_number() - 0.5))
    )

  xymax    <- max(c(data.qq$Sample, data.qq$Theoretical))
  full_lim <- xymax * 1.05   # 5% headroom so the largest outliers aren't
                             # clipped against the top edge (expand = FALSE).
  line.df  <- data.frame(x = c(0, full_lim), y = c(0, full_lim))
  data.qq  <- data.qq %>% mutate(newub = pmin(ub, full_lim))

  # Zoom limit: the `coverage` quantile of the Theoretical/Sample values; both
  # axes share the larger so the diagonal stays at 45 deg.
  zoom_lim <- max(
    quantile(data.qq$Theoretical, coverage, names = FALSE),
    quantile(data.qq$Sample,      coverage, names = FALSE)
  )

  full_plots[[b]] <- build_qq(data.qq, line.df, c(0, full_lim),
                              sprintf('%s - Full', label))
  zoom_plots[[b]] <- build_qq(data.qq, line.df, c(0, zoom_lim),
                              sprintf('%s - Zoom (central %g%%)',
                                      label, 100 * coverage))
}

# ── Compose: buoys across columns, Full row over Zoom row ────────────────────
if (!length(full_plots)) {
  cat('\n[no rtct outputs found for any buoy — nothing written]\n')
} else {
  ncol   <- length(full_plots)                       # only buoys that loaded
  panels <- wrap_plots(c(full_plots, zoom_plots), ncol = ncol, byrow = TRUE) #+
    # plot_annotation(
    #   title = 'RTC Q-Q diagnostics: full range (top) vs. bulk zoom (bottom)'
    # )

  out_dir <- file.path('fig', 'combined')
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  outfile <- file.path(out_dir, 'QQband_allbuoys.pdf')

  ggsave(plot = panels, filename = outfile,
         width = 4 * ncol, height = 8)
  cat(sprintf('Wrote %d-buoy panel (central %g%% zoom) to %s\n',
              ncol, 100 * coverage, outfile))
}
