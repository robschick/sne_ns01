# =============================================================================
# 05b_sumRTCTzoom.R — Full vs. bulk-zoom RTC Q-Q diagnostics for the LGCPSE fit.
#
# Companion to 05_sumRTCT.R. That script writes a single full-range Q-Q plot
# (QQband.pdf); the upper-tail departures (see docs/qq_diagnostics_findings.md)
# dominate the axes and hide the bulk calibration. This script writes TWO views
# of the same plot so they can be shown side by side:
#
#   QQband_full.pdf  — full range; the long upper tail is visible.
#   QQband_zoom.pdf  — axes clipped to the central COVERAGE fraction (default
#                      95%) of events, so the well-calibrated bulk is legible.
#   QQband_panels.pdf — the two stacked into one figure (if patchwork installed).
#
# The zoom uses coord_cartesian(), which only changes the viewport: the points,
# credible band, diagonal, and MSD are computed on the full data exactly as in
# 05_sumRTCT.R. Nothing is dropped or refit — the zoom is purely visual.
#
# Usage:   Rscript 05b_sumRTCTzoom.R --buoy=ns01
# Env:     QQ_COVERAGE=<f>   central fraction shown in the zoom (default 0.95).
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(xtable)

source('src/config.R')
source('src/RFtns.R')

fiti     <- fiti_lgcp
coverage <- as.numeric(Sys.getenv('QQ_COVERAGE', unset = '0.95'))
stopifnot(coverage > 0, coverage < 1)

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

load(paste0(path.rtct, datai, fiti, '_rtct.RData'))   # ts, postCompen, intlami

# postCompen columns: 1:3 = cumulative compensator quantiles (lb, med, ub)
#                     4:6 = per-event increment d quantiles     (lb, med, ub)
data.d <- data.frame(
  lb = postCompen[, 4],
  d  = postCompen[, 5],
  ub = postCompen[, 6]
)

# ── Q-Q data (identical construction to 05_sumRTCT.R) ────────────────────────
data.qq <- data.d %>%
  arrange(d) %>%
  mutate(
    Sample      = d,
    Theoretical = log(n()) - log(n() - (row_number() - 0.5))
  )

xymax    <- max(c(data.qq$Sample, data.qq$Theoretical))
full_lim <- xymax * 1.05   # 5% headroom so the largest outliers aren't clipped
                           # against the top edge (expand = FALSE).
line.df  <- data.frame(x = c(0, full_lim), y = c(0, full_lim))

data.qq <- data.qq %>% mutate(newub = pmin(ub, full_lim))

# ── Shared base plot builder ─────────────────────────────────────────────────
# The full and zoom views differ only in coord_cartesian() limits and title.
build_qq <- function(df, limits, title) {
  df %>%
    ggplot(aes(x = Theoretical)) +
    geom_ribbon(aes(ymin = lb, ymax = newub), fill = 'grey70', alpha = 0.8) +
    geom_point(aes(y = Sample), size = 0.5) +
    geom_line(aes(x = x, y = y), line.df) +
    coord_cartesian(xlim = limits, ylim = limits, expand = FALSE) +
    labs(x = 'Theoretical', y = 'Sample', title = title) +
    theme_bw()
}

# ── Full view (whole range; the tail is visible) ─────────────────────────────
plot.full <- build_qq(data.qq, limits = c(0, full_lim), title = 'Full range')

ggsave(plot = plot.full, width = 4, height = 4,
       filename = paste0(path.fig, 'QQband_full.pdf'))

# ── Zoom view (central `coverage` fraction; bulk calibration is legible) ─────
# Clip the axes at the `coverage` quantile of the Theoretical (and Sample)
# values; both axes share the larger limit so the diagonal stays at 45 deg.
zoom_lim <- max(
  quantile(data.qq$Theoretical, coverage, names = FALSE),
  quantile(data.qq$Sample,      coverage, names = FALSE)
)
zoom_title <- sprintf('Central %g%% (zoom)', 100 * coverage)
plot.zoom  <- build_qq(data.qq, limits = c(0, zoom_lim), title = zoom_title)

ggsave(plot = plot.zoom, width = 4, height = 4,
       filename = paste0(path.fig, 'QQband_zoom.pdf'))

# ── Combined two-panel figure (optional; needs patchwork) ────────────────────
if (requireNamespace('patchwork', quietly = TRUE)) {
  panels <- patchwork::wrap_plots(plot.full, plot.zoom, nrow = 1)
  ggsave(plot = panels, width = 8, height = 4,
         filename = paste0(path.fig, 'QQband_panels.pdf'))
} else {
  message('patchwork not installed — skipping QQband_panels.pdf; ',
          'full and zoom written as separate files.')
}

cat(sprintf('Buoy %s: zoom clips axes at %.3f (central %g%% of events).\n',
            buoy, zoom_lim, 100 * coverage))
cat(sprintf('Wrote QQband_full.pdf and QQband_zoom.pdf to %s\n', path.fig))
