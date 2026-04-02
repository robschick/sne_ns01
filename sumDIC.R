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

fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')

burn = 10000 # decided based on trace plots of -2logL


# =============================================================================-
# Compute DID ----
# =============================================================================-
# load('nopp/data/nopp.RData')
# 
# ts = data$ts
# maxT = ceiling(max(ts))
# sback = 20 # unit = min
# knts = unique(c(0, seq(0, maxT, by = sback), maxT))
# m = length(knts) - 1
# phi = 60 # effective range is 3 hour
# 
# 
# ## covariates ----
# noise = data.frame(ts = knts) %>%
#   left_join(noise)
# noiseVar = as.vector(scale(noise$noise))
# 
# noise$UTC[1]
# 
# Xm = cbind(1,
#            noiseVar,
#            sin(2*pi*(knts + 15*60 + 1)/(8*60)),
#            cos(2*pi*(knts + 15*60 + 1)/(8*60)),
#            sin(2*pi*(knts + 15*60 + 1)/(12*60)),
#            cos(2*pi*(knts + 15*60 + 1)/(12*60)),
#            sin(2*pi*(knts + 15*60 + 1)/(24*60)),
#            cos(2*pi*(knts + 15*60 + 1)/(24*60))) # should be greater than sback*4
# p = ncol(Xm)
# indlam0 = sapply(1:length(ts), function(i) which(knts >= ts[i])[1] - 1 - 1)
# 
# 
# data.dic = c()
# 
# 
# # -----------------------------------------------------------------------------=
# ## Model (1) NHPP ----
# # -----------------------------------------------------------------------------=
# j = 1
# load(paste0('nopp/fit/nopp', fits[j], '.RData'))
# load(paste0('nopp/loglik/nopp', fits[j], 'loglik.RData'))
# print(paste0(fits[j], ': ', length(postLogLik)))
# 
# if((burn - (nrow(postSamples) - length(postLogLik))) > 0){
#   postLogLik = postLogLik[-(1:(burn - (nrow(postSamples) - length(postLogLik))))]
#   postSamples = postSamples[-(1:burn),]  
# }
# 
# 
# p = length(beta)
# betaInd = 1:p
# 
# sourceCpp('src/RcppFtns.cpp')
# 
# lam0m = exp( Xm %*% colMeans(postSamples[,betaInd]) );
# devianceAtMean = -2 * compLogLiki(ts, maxT, lam0m, indlam0, knts, 0, 1)
# 
# data.dic = rbind(data.dic,
#                  data.frame(fit = fits[j], ExpDeviance = mean(-2*postLogLik),
#                             lb = hpd1(-2*postLogLik), ub = hpd2(-2*postLogLik),
#                             EffNumPar = mean(-2*postLogLik) - devianceAtMean,
#                             DIC = mean(-2*postLogLik) - devianceAtMean + mean(-2*postLogLik)))
# 
# 
# 
# # -----------------------------------------------------------------------------=
# ## Model (2) NHPP+GP ----
# # -----------------------------------------------------------------------------=
# j = 2
# load(paste0('nopp/fit/nopp', fits[j], '.RData'))
# load(paste0('nopp/loglik/nopp', fits[j], 'loglik.RData'))
# print(paste0(fits[j], ': ', length(postLogLik)))
# 
# if((burn - (nrow(postSamples) - length(postLogLik))) > 0){
#   postLogLik = postLogLik[-(1:(burn - (nrow(postSamples) - length(postLogLik))))]
#   postSamples = postSamples[-(1:burn),]
#   postWm = postWm[-(1:burn),]
# }
# 
# p = length(beta)
# 
# betaInd = 1:p
# deltaInd = p+1
# 
# sourceCpp('src/RcppFtns.cpp')
# 
# lam0m = exp( Xm %*% colMeans(postSamples[,betaInd]) + mean(exp(postSamples[,deltaInd])) * colMeans(postWm) );
# devianceAtMean = -2 * compLogLiki(ts, maxT, lam0m, indlam0, knts, 0, 1)
# 
# data.dic = rbind(data.dic,
#                  data.frame(fit = fits[j], ExpDeviance = mean(-2*postLogLik),
#                             lb = hpd1(-2*postLogLik), ub = hpd2(-2*postLogLik),
#                             EffNumPar = mean(-2*postLogLik) - devianceAtMean,
#                             DIC = mean(-2*postLogLik) - devianceAtMean + mean(-2*postLogLik)))
# 
# 
# 
# # -----------------------------------------------------------------------------=
# ## Model (3) NHPP+SE ----
# # -----------------------------------------------------------------------------=
# j = 3
# load(paste0('nopp/fit/nopp', fits[j], '.RData'))
# load(paste0('nopp/loglik/nopp', fits[j], 'loglik.RData'))
# print(paste0(fits[j], ': ', length(postLogLik)))
# 
# if((burn - (nrow(postSamples) - length(postLogLik))) > 0){
#   postLogLik = postLogLik[-(1:(burn - (nrow(postSamples) - length(postLogLik))))]
#   postSamples = postSamples[-(1:burn),] 
# }
# 
# p = length(beta)
# 
# betaInd = 1:p
# alphaInd = p+1
# etaInd = p+2
# 
# sourceCpp('src/RcppFtns.cpp')
# 
# lam0m = exp( Xm %*% colMeans(postSamples[,betaInd]) );
# devianceAtMean = -2 * compLogLiki(ts, maxT, lam0m, indlam0, knts, mean(postSamples[,alphaInd]), mean(postSamples[,etaInd]))
# 
# data.dic = rbind(data.dic,
#                  data.frame(fit = fits[j], ExpDeviance = mean(-2*postLogLik),
#                             lb = hpd1(-2*postLogLik), ub = hpd2(-2*postLogLik),
#                             EffNumPar = mean(-2*postLogLik) - devianceAtMean,
#                             DIC = mean(-2*postLogLik) - devianceAtMean + mean(-2*postLogLik)))
# 
# 
# 
# # -----------------------------------------------------------------------------=
# ## Model (4) NHPP+GP+SE ----
# # -----------------------------------------------------------------------------=
# j = 4
# load(paste0('nopp/fit/nopp', fits[j], '.RData'))
# load(paste0('nopp/loglik/nopp', fits[j], 'loglik.RData'))
# print(paste0(fits[j], ': ', length(postLogLik)))
# 
# if((burn - (nrow(postSamples) - length(postLogLik))) > 0){
#   postLogLik = postLogLik[-(1:(burn - (nrow(postSamples) - length(postLogLik))))]
#   postSamples = postSamples[-(1:burn),]
#   postWm = postWm[-(1:burn),]
# }
# 
# p = length(beta)
# 
# betaInd = 1:p
# deltaInd = p+1
# alphaInd = p+2
# etaInd = p+3
# 
# sourceCpp('src/RcppFtns.cpp')
# 
# lam0m = exp( Xm %*% colMeans(postSamples[,betaInd]) + mean(exp(postSamples[,deltaInd])) * colMeans(postWm) );
# devianceAtMean = -2 * compLogLiki(ts, maxT, lam0m, indlam0, knts, mean(postSamples[,alphaInd]), mean(postSamples[,etaInd]))
# 
# data.dic = rbind(data.dic,
#                  data.frame(fit = fits[j], ExpDeviance = mean(-2*postLogLik),
#                             lb = hpd1(-2*postLogLik), ub = hpd2(-2*postLogLik),
#                             EffNumPar = mean(-2*postLogLik) - devianceAtMean,
#                             DIC = mean(-2*postLogLik) - devianceAtMean + mean(-2*postLogLik)))
# 
# 
# save(data.dic, file = 'nopp/fig/noppDIC.RData')



# =============================================================================-
# Summary ----
# =============================================================================-
load('nopp/fig/noppDIC.RData')

newlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iii) NHPP+SE', '(iv) NHPP+GP+SE')
data.dic$fit = factor(data.dic$fit, levels = fits, labels = newlabs)

data.dic$ExpDeviance = format(round(data.dic$ExpDeviance), nsmall = 0)
data.dic$EffNumPar = format(round(data.dic$EffNumPar), nsmall = 0)
data.dic$DIC = format(round(data.dic$DIC), nsmall = 0)
data.dic$lb = format(round(data.dic$lb), nsmall = 0)
data.dic$ub = format(round(data.dic$ub), nsmall = 0)


data.dic = data.dic %>% 
  mutate(HPD = paste0('(', lb, ', ', ub, ')')) %>% 
  select(fit, ExpDeviance, HPD, EffNumPar, DIC)


data.dic %>% 
  select(-EffNumPar) %>% 
  xtable() %>% 
  print(booktabs = F, include.rownames = F)







