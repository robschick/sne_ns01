rm(list = ls())
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

load('data/nopp.RData')
# load(paste0('fit/noppLGCPSE_5c4h.RData'))
load("/work/rss10/sne_ns01/fit/noppLGCPSE_5c4h.RData")

filename = paste0('num/noppLGCPSEnum.RData')

p = length(beta)

betaInd = 1:p
deltaInd = p+1
alphaInd = p+2
etaInd = p+3


burn = 50000
postSamples = postSamples[-(1:burn),]
postWm = postWm[-(1:burn),]

nrow(postSamples); nrow(postWm)
niters = nrow(postSamples)

thinidx <- floor(seq(1, niters, length.out = 1000))
postSamples = postSamples[thinidx, ]
niters = nrow(postSamples)

# =============================================================================-
# Posterior intensity ----
# =============================================================================-
ts = data$ts
maxT = ceiling(max(ts))
m = length(knts) - 1
p = ncol(Xm)


indlam0 = sapply(1:length(ts), function(i) which(knts >= ts[i])[1] - 1 - 1)

aaa = unique(c(0, seq(1000, niters, by = 1000), niters))

start = 1; postNum = c()
# load(filename); start = which(nrow(postNum) == aaa)

sourceCpp('src/RcppFtns.cpp')

for(aa in (start+1):length(aaa) ){
  
  dummy = c()
  for(iter in (aaa[aa-1]+1):(aaa[aa])){
    
    lam0m = exp( Xm %*% postSamples[iter,betaInd] + exp(postSamples[iter,deltaInd]) *  postWm[iter,] );
    numBack = compIntLam0(maxT, lam0m)
    numSE = sum(1 - exp( - postSamples[iter,etaInd] * (maxT - ts) ) ) * postSamples[iter,alphaInd] / postSamples[iter,etaInd]
    
    dummy = rbind(dummy, c(numBack, numSE))
  }
  
  print(paste0('Computed ', aaa[aa], 'th iteration'))
  
  postNum = rbind(postNum, dummy)
  save(postNum, file = filename)
}
save(postNum, file = filename)

