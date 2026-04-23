# =============================================================================
# 03_sumLoglik.R — Trace and histogram of -2 log-likelihood for the LGCPSE fit.
#
# Critical burn-in diagnostic. The trace shows -2logL for the POST-BURN retained
# chain (iterations buoy_cfg$burn + 1 .. niters). If the trace is still trending,
# increase buoy_settings[[buoy]]$burn in src/config.R and re-run
# 03_loglikLGCPSE.R on the cluster.
#
# Usage:   Rscript 03_sumLoglik.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(batchmeans); library(xtable)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp
burn <- buoy_cfg$burn

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

load(paste0(path.loglik, datai, fiti, '_loglik.RData'))   # postLogLik

data.loglik <- data.frame(
  Iteration    = burn + seq_along(postLogLik),
  negTwoLoglik = -2 * postLogLik
)

# ── Trace ───────────────────────────────────────────────────────────────────
trace.negTwoLogLik <- data.loglik %>%
  ggplot(aes(x = Iteration, y = negTwoLoglik)) +
  geom_line() +
  labs(x = 'Iteration', y = '-2logL') +
  theme_bw()

ggsave(plot = trace.negTwoLogLik, width = 6, height = 3,
       filename = paste0(path.fig, 'NegTwoLogLikTrace.pdf'))

# ── Histogram ───────────────────────────────────────────────────────────────
hist.negTwoLogLik <- data.loglik %>%
  ggplot(aes(x = negTwoLoglik)) +
  geom_histogram(aes(y = after_stat(density)), bins = 30,
                 color = 'black', fill = 'white') +
  labs(x = '-2logL', y = 'Density') +
  theme_bw()

ggsave(plot = hist.negTwoLogLik, width = 6, height = 3,
       filename = paste0(path.fig, 'NegTwoLogLikHist.pdf'))

# ── Posterior summary ───────────────────────────────────────────────────────
summary.negTwoLogLik <- data.loglik %>%
  summarise(
    Mean = format(round(bm(negTwoLoglik)$est, 1), nsmall = 1),
    SE   = format(round(bm(negTwoLoglik)$se,  1), nsmall = 1)
  )

print(summary.negTwoLogLik)

summary.negTwoLogLik %>%
  xtable() %>%
  print(booktabs = FALSE, include.rownames = FALSE,
        file = paste0(path.fig, 'NegTwoLogLikSummary.tex'))
