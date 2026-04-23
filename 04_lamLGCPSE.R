rm(list = ls()); gc()
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

source('src/config.R')

runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 1

path.cpp = 'src/RcppFtns.cpp'

fiti = fiti_lgcp
burn = burn_lgcp

ifelse(!dir.exists(path.lam), dir.create(path.lam, recursive = T), FALSE)

filename = paste0(path.lam, fiti, '_lam.RData')


# =============================================================================-
# Load results ----
# =============================================================================-

source('src/load_fit.R')

postBeta  = postSamples[, betaInd]
postDelta = exp(postSamples[, deltaInd])
postAlpha = postSamples[, alphaInd]
postEta   = postSamples[, etaInd]



# =============================================================================-
# Posterior intensity ----
# =============================================================================-

tsnew = seq(min(ts), max(ts), length.out = 2000)

aaa = unique(c(0, seq(100, length(tsnew), by = 100), length(tsnew)))

start = 1; postBack = postSE = postLam = c()
# load(filename); start = which(nrow(postLam) == aaa)

sourceCpp(path.cpp)

for(aa in (start+1):length(aaa) ){
  
  dummyBack = dummySE = dummyLam = c()
  for(i in (aaa[aa-1]+1):(aaa[aa])) {
    
    indlam0i = which(knts >= tsnew[i])[1] - 1 - 1
    
    lami = compLamt(tsnew[i], ts, knts, maxT, indlam0i, Xm, 
                    postBeta, postDelta, postWm, postAlpha, postEta)
    
    dummyBack = rbind(dummyBack, as.vector(lami$resBack))
    dummySE = rbind(dummySE, as.vector(lami$resSE))
    dummyLam = rbind(dummyLam, as.vector(lami$resLam))
  }
  
  print(paste0('Completed by ', aaa[aa], 'th time event'))
  
  postBack = rbind(postBack, dummyBack)
  postSE = rbind(postSE, dummySE)
  postLam = rbind(postLam, dummyLam)
  
  save(tsnew, postBack, postSE, postLam, file = filename)
}
save(tsnew, postBack, postSE, postLam, file = filename)



