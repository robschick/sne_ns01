rm(list = ls())
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

source('src/config.R')

# runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 1

path.cpp = 'src/RcppFtns.cpp'

fiti = fiti_lgcp
burn = burn_lgcp

ifelse(!dir.exists(path.rtct), dir.create(path.rtct, recursive = T), FALSE)

filename = paste0(path.rtct, datai, fiti, '_rtct.RData')


# =============================================================================-
# Load results ----
# =============================================================================-

source('src/load_fit.R')


# =============================================================================-
# Random time change theorem (RTCT) ----
# =============================================================================-

deltaWm = exp(postSamples[, deltaInd]) * postWm

aaa = unique(c(0, seq(10, length(ts), by = 10), length(ts)))

start = 1; postCompen = c()
# load(filename); start = which(nrow(postCompen) == aaa)

sourceCpp(path.cpp)

for(aa in (start+1):length(aaa) ){

  dummy = c()
  for(i in (aaa[aa-1]+1):(aaa[aa])){

    indlam0i = which(knts >= ts[i])[1] - 1 - 1

    if(i == 1){
      intlampre = 0
    } else {
      intlampre = intlami
    }

    intlam0i = rtctIntLam0i(ts[i], Xm, maxT, knts, indlam0i,
                            matrix(postSamples[, betaInd], nrow = niters),
                            deltaWm)
    intTrigi = rtctSumIntHi(ts[i], ts, postSamples[, alphaInd], postSamples[, etaInd])
    intlami  = intlam0i + intTrigi
    di       = intlami - intlampre

    dummy = rbind(dummy, c(quantile(intlami, probs = c(0.025, 0.5, 0.975)),
                           quantile(di,      probs = c(0.025, 0.5, 0.975))))
  }

  print(paste0('Completed by ', aaa[aa], 'th time event'))

  postCompen = rbind(postCompen, dummy)
  save(intlami, ts, postCompen, file = filename)
}
save(intlami, ts, postCompen, file = filename)
