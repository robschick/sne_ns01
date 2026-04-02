rm(list = ls())
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)


# runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 1


fold.data = 'data'
fold.fit = 'fit' 
fold.loglik = 'loglik' 


path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
path.loglik = paste0( fold.loglik, '/')
ifelse(!dir.exists(path.loglik), dir.create(path.loglik, recursive = T), FALSE)



path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')


datai = 'nopp'
fiti = 'LGCPSE_5c4h'

filename = paste0(path.loglik, datai, fiti, '_loglik.RData')

# =============================================================================-
# Load results ----
# =============================================================================-

load(paste0(fold.data, '/', datai, '.RData'))
load(paste0(path.fit, datai, fiti, '.RData'))


p = length(beta);p
ncol(Xm)

betaInd = 1:p
deltaInd = p+1
alphaInd = p+2
etaInd = p+3


burn = 10000
postSamples = postSamples[-(1:burn),]
postWm = postWm[-(1:burn),]

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

start = 1; postLogLik = c()
# load(filename); start = which(length(postLogLik) == aaa)

sourceCpp(path.cpp)

for(aa in (start+1):length(aaa) ){
  
  dummy = c()
  for(iter in (aaa[aa-1]+1):(aaa[aa])){
    
    lam0m = exp( Xm %*% postSamples[iter,betaInd] + exp(postSamples[iter,deltaInd]) * postWm[iter,] );
    dummy = c(dummy, compLogLiki(ts, maxT, lam0m, indlam0, knts, postSamples[iter,alphaInd], postSamples[iter,etaInd]))
  }
  
  print(paste0('Computed ', aaa[aa], 'th iteration'))
  
  postLogLik = c(postLogLik, dummy)
  save(postLogLik, file = filename)
}
save(postLogLik, file = filename)




