rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(foreach)


# runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
# runID = 1

fold.data = 'data'
fold.fit = 'fit' 


path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
ifelse(!dir.exists(path.fit), dir.create(path.fit, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')


datai = 'nopp'
fiti = 'LGCPSE_5c4h'


load(paste0(fold.data, '/', datai, '.RData'))
filename = paste0(path.fit, datai, fiti, '.RData')

sourceCpp(path.cpp)

# ===========================================================================-
# Set up ----
# ===========================================================================-
ts = data$ts
maxT = ceiling(max(ts))
rho = 3 * 12 * 60 / 3 # effective range for GP is rho * 3

# effective range (rho*3) should be smaller than shortest harmonic 
# and greater than sback

# for numerical integration of the background intensity
sback = 12 * 60 # unit = min # length of each segment
knts = unique(c(0, seq(0, maxT, by = sback), maxT)) # segment points
m = length(knts) - 1 # number of segments for numerical integration



## covariates ----
noise = data.frame(ts = knts) %>%
  left_join(noise)
noiseVar = as.vector(scale(noise$noise))
sstVar = as.vector(noise$sst)

noise$UTC[1]

# Xm = cbind(
#   1,
#   noiseVar,
#   sin(2 * pi * (knts + 6*60 + 27) / (1 * 30 * 24 * 60)), # 1m * 30d * 24h * 60m
#   cos(2 * pi * (knts + 6*60 + 27) / (1 * 30 * 24 * 60)),
#   sin(2 * pi * (knts + 6*60 + 27) / (2 * 30 * 24 * 60)), # 2m * 30d * 24h * 60m
#   cos(2 * pi * (knts + 6*60 + 27) / (2 * 30 * 24 * 60)),
#   sin(2 * pi * (knts + 6*60 + 27) / (4 * 30 * 24 * 60)), # 4m * 30d * 24h * 60m
#   cos(2 * pi * (knts + 6*60 + 27) / (4 * 30 * 24 * 60)) # 4m * 30d * 24h * 60m  # should be at least sback*4*2
# )

# New Harmonics, per email with Bok Kang on 2025-07-21
# range(ns_01_all$start_datetime)[1]
# [1] "2021-03-18 06:27:59 UTC"
# harm_start_time <- (06 hours) * (60 minutes) + (27 minutes)
harm_start_time <- 06 * 60 + 27
harm_month_unit <- 30 * 24 * 60

Xm = cbind(
  1,
  noiseVar,
  sstVar,
  sin(2 * pi * (knts + harm_start_time) / (1 * harm_month_unit)), # 1m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (1 * harm_month_unit)),
  sin(2 * pi * (knts + harm_start_time) / (3 * harm_month_unit)), # 3m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (3 * harm_month_unit)), 
  sin(2 * pi * (knts + harm_start_time) / (6 * harm_month_unit)), # 6m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (6 * harm_month_unit)),
  sin(2 * pi * (knts + harm_start_time) / (12 * harm_month_unit)), # 12m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (12 * harm_month_unit))
)


p = ncol(Xm)
# 
# par(mfrow = c(2,3))
# for(i in 3:p){
#   plot(knts, Xm[,i], type = 'l')
# }



## Initial values for parameters ----
beta = rnorm(p)
delta = log(1)
alpha = 1
eta = 1


## Compute Wm (GP at centroids (knts)) ----
tdiffm = matrix(0, m+1, m+1)
for(i in 1:(m+1)){
  for(j in 1:i){
    tdiffm[i,j] = tdiffm[j,i] = abs(knts[i] - knts[j])
  }
}
Sigmam = exp(- tdiffm / rho)
invSigmam = solve(Sigmam)
cholSigmam = chol(Sigmam)
Wm = t(cholSigmam) %*% rnorm(m+1)
lam0m = as.vector( exp(Xm %*% beta + exp(delta) * Wm) )


## Approximation ----
n = length(ts)
indlam0 = sapply(1:n, function(i) which(knts >= ts[i])[1] - 1 - 1)
lam0 = compLam0(ts, maxT, lam0m, indlam0, knts)
intLam0 = compIntLam0(maxT, lam0m)
# par(mfrow = c(1, 1))
# plot(knts, lam0m, type = 'l')
# points(ts, lam0, col = 2)


## Others ---
betaInd = 1:p
deltaInd = p+1
alphaInd = p+2
etaInd = p+3

sigma2 = rep(0.2^2, 3)
adapIter = rep(1, 3)
COVbeta = diag(p)
COVdelta = COVeta = 1

lb_eta = 3 / 20
ub_eta = 3 / min(diff(ts))
shape_alpha = rate_alpha = 0.001


niters = 150000
updateCOV = TRUE
adaptInterval = 200
adaptFactorExponent = 0.8
outers = c(0, seq(1000, niters, by = 1000))

start = 1; postSamples = postBranching = postWm = c(); Accprob = 0; rtime = 0
# load(filename); start = which(outers == nrow(postSamples))

# i = 2; outers = seq(0, 2000, by = 100); adaptInterval = 50

sourceCpp(path.cpp)

for(i in (start+1):length(outers) ){
  outeri = outers[i]-outers[i-1]
  
  ptm = proc.time()[3]
  dummy = fitLGCPSE(
    outeri, ts, Xm, maxT, knts, tdiffm, beta, delta, rho, 
    alpha, eta, Wm, indlam0, shape_alpha, rate_alpha, lb_eta, 
    ub_eta, sigma2, COVbeta, COVdelta, COVeta, updateCOV, adaptInterval, 
    adaptFactorExponent, adapIter) 
  rtime = rtime + proc.time()[3] - ptm
  
  postSamples = rbind(postSamples, dummy$postSamples)
  postBranching = rbind(postBranching, dummy$postBranching)
  postWm = rbind(postWm, dummy$postWm)
  Accprob = ( Accprob * outers[i-1] + colSums(dummy$Accprob) ) / outers[i]
  
  nSamples = nrow(postSamples)
  beta = postSamples[nSamples, betaInd]
  delta = postSamples[nSamples, deltaInd]
  alpha = postSamples[nSamples, alphaInd]
  eta = postSamples[nSamples, etaInd]
  
  sigma2 = dummy$sigma2
  adapIter = dummy$adapIter
  Wm = dummy$Wm
  COVbeta = dummy$COVbeta
  COVdelta = dummy$COVdelta
  COVeta = dummy$COVeta
  
  save(rtime, postSamples, postBranching, postWm, Accprob, beta, delta, alpha, eta, 
       lb_eta, ub_eta, shape_alpha, rate_alpha,
       sigma2, adapIter, Wm, COVbeta, COVdelta, COVeta,
       updateCOV, adaptInterval, adaptFactorExponent, adapIter,
       sback, knts, rho, Xm,
       file = filename)
}


