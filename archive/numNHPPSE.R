rm(list = ls())
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

# datasets = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')


runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 8

fold = 'sim'
fold.data = 'data'
fold.fit = 'fit' 
fold.num = 'num'

# =============================================================================-
# Load results ----
# =============================================================================-

load('data/nopp.RData')
load('/work/rss10/sne_ns01/fit/noppNHPPSE_parallel.RData')
filename = paste0('num/noppNHPPSEnum.RData')

p = length(beta)

betaInd = 1:p
alphaInd = p+1
etaInd = p+2

burn = 50000
postSamples = postSamples[-(1:burn),]

niters = nrow(postSamples)

thinidx <- floor(seq(1, niters, length.out = 1000))
postSamples = postSamples[thinidx, ]
niters = nrow(postSamples)


# =============================================================================-
# Posterior intensity ----
# =============================================================================-
ts = data$ts
maxT = ceiling(max(ts))
sback = 30 # unit = min
knts = unique(c(0, seq(0, maxT, by = sback), maxT))
m = length(knts) - 1
rho = 3 * 30 / 3 # effective range for GP is rho * 3
p = ncol(Xm)


indlam0 = sapply(1:length(ts), function(i) which(knts >= ts[i])[1] - 1 - 1)

aaa = unique(c(0, seq(1000, niters, by = 1000), niters))

start = 1; postNum = c()
# load(filename); start = which(nrow(postNum) == aaa)

sourceCpp('src/RcppFtns.cpp')

for(aa in (start+1):length(aaa) ){
  
  dummy = c()
  for(iter in (aaa[aa-1]+1):(aaa[aa])){
    
    lam0m = exp( Xm %*% postSamples[iter,betaInd] );
    numBack = compIntLam0(maxT, lam0m)
    numSE = sum(1 - exp( - postSamples[iter,etaInd] * (maxT - ts) ) ) * postSamples[iter,alphaInd] / postSamples[iter,etaInd]
    
    dummy = rbind(dummy, c(numBack, numSE))
  }
  
  print(paste0('Computed ', aaa[aa], 'th iteration'))
  
  postNum = rbind(postNum, dummy)
  save(postNum, file = filename)
}
save(postNum, file = filename)

