# =============================================================================
# 05_sumDIC.R — DIC for the LGCPSE fit.
#
# Expected deviance is from the cluster-computed post-burn postLogLik; deviance
# at the posterior mean is computed in-process via compLogLiki.
#
# Usage:   Rscript 05_sumDIC.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(batchmeans); library(xtable)
library(Rcpp); library(RcppArmadillo)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp
source('src/load_fit.R')   # data, postSamples, postWm, Xm, knts, ts, maxT, betaInd, ...

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

load(paste0(path.loglik, datai, fiti, '_loglik.RData'))   # postLogLik

indlam0 <- sapply(seq_along(ts), function(i) which(knts >= ts[i])[1] - 1 - 1)

sourceCpp('src/RcppFtns.cpp')

lam0m <- exp(Xm %*% colMeans(postSamples[, betaInd]) +
             mean(exp(postSamples[, deltaInd])) * colMeans(postWm))

devianceAtMean <- -2 * compLogLiki(ts, maxT, lam0m, indlam0, knts,
                                   mean(postSamples[, alphaInd]),
                                   mean(postSamples[, etaInd]))

expDev <- mean(-2 * postLogLik)

data.dic <- data.frame(
  fit         = fiti,
  ExpDeviance = expDev,
  lb          = hpd1(-2 * postLogLik),
  ub          = hpd2(-2 * postLogLik),
  EffNumPar   = expDev - devianceAtMean,
  DIC         = 2 * expDev - devianceAtMean
)

save(data.dic, file = paste0(path.fig, 'DIC.RData'))

tab.dic <- data.dic %>%
  mutate(
    ExpDeviance = format(round(ExpDeviance), nsmall = 0),
    EffNumPar   = format(round(EffNumPar),   nsmall = 0),
    DIC         = format(round(DIC),         nsmall = 0),
    lb          = format(round(lb),          nsmall = 0),
    ub          = format(round(ub),          nsmall = 0),
    HPD         = paste0('(', lb, ', ', ub, ')')
  ) %>%
  select(fit, ExpDeviance, HPD, EffNumPar, DIC)

print(tab.dic)

tab.dic %>%
  select(-EffNumPar) %>%
  xtable() %>%
  print(booktabs = FALSE, include.rownames = FALSE,
        file = paste0(path.fig, 'DIC.tex'))
