rm(list = ls()); gc()
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 1

fold.data = 'data'
fold.fit = 'fit' 
fold.lam = 'lam'


path.data = paste0(fold.data, '/')
# path.fit = paste0('/work/bk232/upcallHawkes/schannel_rev/', fold, '/', fold.fit, '/')
path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
path.lam = paste0( fold.lam, '/')
ifelse(!dir.exists(path.lam), dir.create(path.lam, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')


datai = 'nopp'
fiti = 'LGCPSE_5c4h'

filename = paste0(path.lam, fiti, '_lam.RData')


# =============================================================================-
# Load results ----
# =============================================================================-

load(paste0(path.data, datai, '.RData'))
load(paste0(path.fit, datai, fiti, '.RData'))


p = length(beta);p
ncol(Xm)

betaInd = 1:p
deltaInd = p+1
alphaInd = p+2
etaInd = p+3


burn = 50000

postBeta = postSamples[-(1:burn),betaInd]
postDelta = exp(postSamples[-(1:burn),deltaInd])
postAlpha = postSamples[-(1:burn),alphaInd]
postEta = postSamples[-(1:burn),etaInd]
postWm = postWm[-(1:burn),]

niters = nrow(postSamples)



# =============================================================================-
# Posterior intensity ----
# =============================================================================-
ts = data$ts
maxT = ceiling(max(ts))
# m = length(knts) - 1

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



