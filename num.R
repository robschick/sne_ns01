rm(list = ls())
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

source('src/config.R')

# runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 1

path.cpp = 'src/RcppFtns.cpp'

# Switch between models here — everything else adapts automatically
fiti = fiti_lgcp   # or: fiti = fiti_nhpp
burn = burn_lgcp   # or: burn = burn_nhpp

ifelse(!dir.exists(path.num), dir.create(path.num, recursive = T), FALSE)

filename = paste0(path.num, datai, fiti, 'num.RData')


# =============================================================================-
# Load results ----
# =============================================================================-

source('src/load_fit.R')

thinidx     = floor(seq(1, niters, length.out = 1000))
postSamples = postSamples[thinidx, ]
if (model_has_gp) postWm = postWm[thinidx, ]
niters = nrow(postSamples)

indlam0 = sapply(1:length(ts), function(i) which(knts >= ts[i])[1] - 1 - 1)


# =============================================================================-
# Posterior event counts ----
# =============================================================================-

aaa = unique(c(0, seq(1000, niters, by = 1000), niters))

start = 1; postNum = c()
# load(filename); start = which(nrow(postNum) == aaa)

sourceCpp(path.cpp)

for(aa in (start+1):length(aaa) ){

  dummy = c()
  for(iter in (aaa[aa-1]+1):(aaa[aa])){

    if (model_has_gp) {
      lam0m = exp( Xm %*% postSamples[iter, betaInd] + exp(postSamples[iter, deltaInd]) * postWm[iter, ] )
    } else {
      lam0m = exp( Xm %*% postSamples[iter, betaInd] )
    }

    numBack = compIntLam0(maxT, lam0m)
    numSE   = sum(1 - exp( -postSamples[iter, etaInd] * (maxT - ts) )) *
              postSamples[iter, alphaInd] / postSamples[iter, etaInd]

    dummy = rbind(dummy, c(numBack, numSE))
  }

  print(paste0('Computed ', aaa[aa], 'th iteration'))

  postNum = rbind(postNum, dummy)
  save(postNum, file = filename)
}
save(postNum, file = filename)
