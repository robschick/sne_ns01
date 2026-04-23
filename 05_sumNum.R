# =============================================================================
# 05_sumNum.R — Posterior expected event counts (background + self-excitement).
#
# Usage:   Rscript 05_sumNum.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(batchmeans); library(xtable)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

load(paste0(path.num, datai, fiti, 'num.RData'))   # postNum: cols = c(numBack, numSE)

postNum.total <- cbind(Total = rowSums(postNum),
                       Background = postNum[, 1],
                       SelfExcitement = postNum[, 2])

tab.num <- data.frame(
  Component = colnames(postNum.total),
  Mean      = apply(postNum.total, 2, bmmean, digits = 0),
  HPD       = apply(postNum.total, 2, hpd,    digits = 0),
  row.names = NULL
)

print(tab.num)

tab.num %>%
  xtable() %>%
  print(booktabs = FALSE, include.rownames = FALSE,
        file = paste0(path.fig, 'Num.tex'))
