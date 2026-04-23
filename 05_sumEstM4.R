# =============================================================================
# 05_sumEstM4.R — Posterior HPD intervals for LGCPSE regression coefficients.
#
# Predictor labels are derived from harm_periods_lgcp via fmt_period() so they
# cannot silently drift out of sync with the design matrix.
#
# Usage:   Rscript 05_sumEstM4.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(batchmeans); library(xtable)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp
source('src/load_fit.R')   # postSamples, Xm, betaInd, deltaInd, alphaInd, etaInd

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

# ── Predictor labels ────────────────────────────────────────────────────────
# Xm structure (see 02_fitLGCPSE.R): intercept, noise, SST, then (sin, cos) per
# period in harm_periods_lgcp. betaInd[-1] drops the intercept.
harm_labels <- unlist(lapply(fmt_period(harm_periods_lgcp), function(lbl) {
  c(paste(lbl, 'sine'), paste(lbl, 'cosine'))
}))
Predictors <- c('Noise', 'SST', harm_labels)

postbetas <- postSamples[, betaInd[-1]]
stopifnot(ncol(postbetas) == length(Predictors))

dat <- data.frame(
  Mean      = colMeans(postbetas),
  lb95      = apply(postbetas, 2, lb95), ub95 = apply(postbetas, 2, ub95),
  lb90      = apply(postbetas, 2, lb90), ub90 = apply(postbetas, 2, ub90),
  Predictor = Predictors
)
dat$Predictor <- factor(dat$Predictor, levels = rev(unique(dat$Predictor)))
dat$param     <- dat$Predictor

# ── Excitement parameters (alpha, delta, eta) ───────────────────────────────
postparams <- postSamples[, c(alphaInd, deltaInd, etaInd)]
colnames(postparams) <- c('alpha', 'delta', 'eta')

dat_params <- data.frame(
  Mean  = colMeans(postparams),
  lb95  = apply(postparams, 2, lb95), ub95 = apply(postparams, 2, ub95),
  lb90  = apply(postparams, 2, lb90), ub90 = apply(postparams, 2, ub90),
  param = colnames(postparams)
)

# ── Combined LaTeX table ────────────────────────────────────────────────────
latex_tbl <- bind_rows(dat, dat_params) %>%
  select(param, Mean, lb95, ub95) %>%
  mutate(sig = ifelse((lb95 > 0) | (0 > ub95), '*', '')) %>%
  xtable() %>%
  {capture.output(print(., booktabs = FALSE, include.rownames = FALSE))}

cat(latex_tbl,
    file = paste0(path.fig, 'background_excitement_coeffs_table.tex'),
    sep  = '\n')

# ── CI plot ─────────────────────────────────────────────────────────────────
plot.ci <- dat %>%
  ggplot(aes(y = Predictor)) +
  geom_point(aes(x = Mean), size = 2) +
  geom_linerange(aes(xmin = lb95, xmax = ub95)) +
  geom_linerange(aes(xmin = lb90, xmax = ub90), linewidth = 1.2) +
  geom_vline(xintercept = 0, linewidth = 0.2) +
  labs(x = 'HPD interval', y = 'Covariates') +
  theme_bw() +
  theme(legend.position = 'none', plot.title = element_blank())

ggsave(plot = plot.ci, width = 4.5, height = 3,
       filename = paste0(path.fig, 'CI.pdf'))
