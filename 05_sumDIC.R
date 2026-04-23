rm(list=ls())
library(coda); library(tidyverse); library(egg); library(grid)
# library(ggh4x) # facet_grid2
library(batchmeans); library(foreach)
library(xtable)
library(Rcpp); library(RcppArmadillo)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}
hpd1 = function(x){ round(HPDinterval(as.mcmc(x))[1], 2) }
hpd2 = function(x){ round(HPDinterval(as.mcmc(x))[2], 2) }



comb = foreach(i = 3:5, .combine = rbind) %do% {
  cbind(i, 2:4) # number of cycles, effective range of GP in hours
}
nrow(comb)


fold = 'real'
fold.data = 'data'
fold.fit = 'fit' 
fold.loglik = 'loglik' 
fold.fig = 'fig' 


path.fit = paste0('/work/bk232/upcallHawkes/schannel_rev/', fold, '/', fold.fit, '/')
path.loglik = paste0(fold, '/', fold.loglik, '/')
path.fig = paste0(fold, '/', fold.fig, '/')
ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')


datai = 'nopp'

burn = 10000 # decided based on trace plots of -2logL


# =============================================================================-
# Compute DIC ----
# =============================================================================-
load(paste0(fold, '/', fold.data, '/', datai, '.RData'))

ts = data$ts
maxT = ceiling(max(ts))
sback = 20 # unit = min
knts = unique(c(0, seq(0, maxT, by = sback), maxT))
m = length(knts) - 1
indlam0 = sapply(1:length(ts), function(i) which(knts >= ts[i])[1] - 1 - 1)


data.dic = c()


# -----------------------------------------------------------------------------=
## Model (4) NHPP+GP+SE ----
# -----------------------------------------------------------------------------=

for(runID in 1:nrow(comb)){
  
  fiti = paste0('LGCPSE_', comb[runID, 1], 'c', comb[runID, 2], 'h')
  
  load(paste0(path.fit, datai, fiti, '.RData'))
  load(paste0(path.loglik, datai, fiti, '_loglik.RData'))
  
  print(paste0(fiti, ': ', length(postLogLik)))
  
  if((burn - (nrow(postSamples) - length(postLogLik))) > 0){
    postLogLik = postLogLik[-(1:(burn - (nrow(postSamples) - length(postLogLik))))]
    postSamples = postSamples[-(1:burn),]
    postWm = postWm[-(1:burn),]
  }
  
  p = length(beta)
  
  betaInd = 1:p
  deltaInd = p+1
  alphaInd = p+2
  etaInd = p+3
  
  sourceCpp(path.cpp)
  
  lam0m = exp( Xm %*% colMeans(postSamples[,betaInd]) + mean(exp(postSamples[,deltaInd])) * colMeans(postWm) );
  devianceAtMean = -2 * compLogLiki(ts, maxT, lam0m, indlam0, knts, mean(postSamples[,alphaInd]), mean(postSamples[,etaInd]))
  
  data.dic = rbind(
    data.dic,
    data.frame(
      fit = fiti, numHarmonics = comb[runID,1], effRange = comb[runID,2],
      ExpDeviance = mean(-2*postLogLik),
      lb = hpd1(-2*postLogLik), ub = hpd2(-2*postLogLik),
      EffNumPar = mean(-2*postLogLik) - devianceAtMean,
      DIC = mean(-2*postLogLik) - devianceAtMean + mean(-2*postLogLik)
    )
  )
  save(data.dic, file = paste0(path.fig, datai, 'DIC_harmonic_rho.RData'))
}






# =============================================================================-
# Summary ----
# =============================================================================-
load(paste0(path.fig, datai, 'DIC_harmonic_rho.RData'))



tab.dic = data.dic %>% 
  mutate(
    ExpDeviance = format(round(ExpDeviance), nsmall = 0),
    EffNumPar = format(round(EffNumPar), nsmall = 0),
    DIC = format(round(DIC), nsmall = 0),
    lb = format(round(lb), nsmall = 0),
    ub = format(round(ub), nsmall = 0)
  ) %>% 
  mutate(HPD = paste0('(', lb, ', ', ub, ')')) %>% 
  select(fit, numHarmonics, effRange, ExpDeviance, HPD, EffNumPar, DIC)


tab.dic %>% 
  select(-c(fit, EffNumPar)) %>% 
  xtable() %>% 
  print(booktabs = F, include.rownames = F)







