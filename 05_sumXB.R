# =============================================================================
# 05_sumXB.R — Harmonic component of the log background intensity (X*B with
# harmonics only) plus the full X*B and X*B+W series, saved for downstream use.
#
# Xm column layout (see 02_fitLGCPSE.R): intercept, noise, SST, harmonic sin/cos
# pairs. harmInd = 4:p picks out the harmonic columns only.
#
# Usage:   Rscript 05_sumXB.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp
source('src/load_fit.R')   # data, noise, postSamples, postWm, Xm, knts, betaInd, deltaInd

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

# Align noise (UTC) with the knts grid so we can plot against wall time.
noise <- data.frame(ts = knts) %>% left_join(noise, by = 'ts')

harmInd <- 4:ncol(Xm)

XB     <- postSamples[, betaInd] %*% t(Xm)
XBharm <- postSamples[, harmInd] %*% t(Xm[, harmInd])
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

save(data.xb, file = paste0(path.fig, 'xb.RData'))

# ── Plot: harmonic component only ──────────────────────────────────────────
plot.xb <- data.xb %>%
  filter(Name == 'X*B with harmonics only') %>%
  ggplot() +
  geom_ribbon(aes(x = UTC, ymin = lb, ymax = ub), fill = 'lightsteelblue', alpha = 0.6) +
  geom_line(aes(x = UTC, y = mean)) +
  geom_hline(yintercept = 0, linetype = 'dashed') +
  labs(x = 'Month', y = 'Effect') +
  theme_bw() +
  scale_x_datetime(date_breaks = '1 month', date_labels = '%b') +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))

ggsave(plot = plot.xb, width = 6, height = 3,
       filename = paste0(path.fig, 'XB.pdf'))
