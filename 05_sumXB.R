# =============================================================================
# 05_sumXB.R — Harmonic component of the log background intensity (X*B with
# harmonics only) plus the full X*B and X*B+W series, saved for downstream use.
#
# Xm column layout (see src/design.R): intercept, noise, SST, harmonic sin/cos
# pairs, and — when the seasonal spline is ON — the spline basis. design_columns()
# supplies the harmonic vs. spline column indices so "harmonics only" excludes the
# spline, and the spline component (the end-of-season decline) is split out on its
# own when present.
#
# Usage:   Rscript 05_sumXB.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse)

source('src/config.R')
source('src/design.R')
source('src/RFtns.R')

fiti <- fiti_lgcp

# Optional posterior thinning to bound peak memory. This script forms three
# dense niters x n_knots matrices (XB, XBharm, XBW), so the largest buoy (NS02)
# can OOM on a memory-limited node. Set THIN=<n> to keep n evenly-spaced draws;
# unset (default) uses the full post-burn chain. load_fit.R reads `thin`.
thin <- if (Sys.getenv("THIN", unset = "") == "") NULL else as.integer(Sys.getenv("THIN"))
source('src/load_fit.R')   # data, noise, postSamples, postWm, Xm, knts, betaInd, deltaInd
rm(thin)                   # reset so a stray value can't leak into later sources

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

# Align noise (UTC) with the knts grid so we can plot against wall time.
noise <- data.frame(ts = knts) %>% left_join(noise, by = 'ts')

cols    <- design_columns(design_cfg())
harmInd <- cols$harm

XB     <- postSamples[, betaInd] %*% t(Xm)
XBharm <- postSamples[, harmInd] %*% t(Xm[, harmInd, drop = FALSE])
XBW    <- XB + exp(postSamples[, deltaInd]) * postWm

XBci     <- t(apply(XB,     2, function(x) HPDinterval(as.mcmc(x))[1:2]))
XBharmci <- t(apply(XBharm, 2, function(x) HPDinterval(as.mcmc(x))[1:2]))
XBWci    <- t(apply(XBW,    2, function(x) HPDinterval(as.mcmc(x))[1:2]))

data.xb <- bind_rows(
  data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B',
             mean = colMeans(XB),     lb = XBci[, 1],     ub = XBci[, 2]),
  data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B with harmonics only',
             mean = colMeans(XBharm), lb = XBharmci[, 1], ub = XBharmci[, 2]),
  data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B+W',
             mean = colMeans(XBW),    lb = XBWci[, 1],    ub = XBWci[, 2])
)

# Seasonal-spline component only (present when seasonal_spline is ON). This is
# the term that carries the end-of-season calling decline the harmonics
# structurally cannot — the visual acceptance check for the spline design.
if (length(cols$spline)) {
  XBspl   <- postSamples[, cols$spline, drop = FALSE] %*%
             t(Xm[, cols$spline, drop = FALSE])
  XBsplci <- t(apply(XBspl, 2, function(x) HPDinterval(as.mcmc(x))[1:2]))
  data.xb <- bind_rows(
    data.xb,
    data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B seasonal spline',
               mean = colMeans(XBspl), lb = XBsplci[, 1], ub = XBsplci[, 2])
  )
}

save(data.xb, file = paste0(path.fig, 'xb.RData'))

# ── Component plots ─────────────────────────────────────────────────────────
# Same styling for each single-component series; used for the harmonic-only plot
# (always) and the seasonal-spline plot (only when the spline is ON).
plot_component <- function(name) {
  data.xb %>%
    filter(Name == name) %>%
    ggplot() +
    geom_ribbon(aes(x = UTC, ymin = lb, ymax = ub), fill = 'lightsteelblue', alpha = 0.6) +
    geom_line(aes(x = UTC, y = mean)) +
    geom_hline(yintercept = 0, linetype = 'dashed') +
    labs(x = 'Month', y = 'Effect') +
    theme_bw() +
    scale_x_datetime(date_breaks = '1 month', date_labels = '%b') +
    theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
}

ggsave(plot = plot_component('X*B with harmonics only'), width = 6, height = 3,
       filename = paste0(path.fig, 'XB.pdf'))

# The seasonal-spline component: the end-of-season decline the harmonics cannot
# represent (only written when the spline is ON).
if (length(cols$spline)) {
  ggsave(plot = plot_component('X*B seasonal spline'), width = 6, height = 3,
         filename = paste0(path.fig, 'XBspline.pdf'))
}
