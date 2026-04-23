rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(foreach)

# runID = as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))
runID = 7

num = as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1"))
print(num)

fold.data = 'data'
fold.fit = 'fit' 


path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
ifelse(!dir.exists(path.fit), dir.create(path.fit, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns_parallel.cpp')


# datai = paste0('nopp', runID)
datai = 'nopp'
fiti = 'NHPPSE_parallel'

load(paste0(fold.data, '/', datai, '.RData'))
filename = paste0(path.fit, datai, fiti, '.RData')

sourceCpp(path.cpp)


# ===========================================================================-
# Set up ----
# ===========================================================================-
ts = data$ts
maxT = ceiling(max(ts))
rho = 3 * 30 / 3 # effective range for GP is rho * 3

# effective range (rho*3) should be smaller than shortest harmonic 
# and greater than sback

# for numerical integration of the background intensity
sback = 30 # unit = min # length of each segment; had been 12 * 60
knts = unique(c(0, seq(0, maxT, by = sback), maxT)) # segment points
m = length(knts) - 1 # number of segments for numerical integration

## covariates ----
noise = data.frame(ts = knts) %>%
  left_join(noise)
noiseVar = as.vector(scale(noise$noise))
sstVar = as.vector(noise$sst)

noise$UTC[1]

# range(ns_01_all$start_datetime)[1]
# [1] "2021-03-18 06:27:59 UTC"
# harm_start_time <- (06 hours) * (60 minutes) + (27 minutes)
harm_start_time <- 06 * 60 + 27
harm_hourly_unit <- 60
harm_month_unit <- 30 * 24 * 60
Xm = cbind(
  1,
  noiseVar,
  sstVar,
  # Hourly
  sin(2 * pi * (knts + harm_start_time) / (6 * harm_hourly_unit)), # 6h * 60m
  cos(2 * pi * (knts + harm_start_time) / (6 * harm_hourly_unit)),
  sin(2 * pi * (knts + harm_start_time) / (8 * harm_hourly_unit)), # 8h * 60m
  cos(2 * pi * (knts + harm_start_time) / (8 * harm_hourly_unit)),
  sin(2 * pi * (knts + harm_start_time) / (12 * harm_hourly_unit)), # 12h * 60m
  cos(2 * pi * (knts + harm_start_time) / (12 * harm_hourly_unit)),
  sin(2 * pi * (knts + harm_start_time) / (24 * harm_hourly_unit)), # 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (24 * harm_hourly_unit)),
  # Monthly
  sin(2 * pi * (knts + harm_start_time) / (1 * harm_month_unit)), # 1m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (1 * harm_month_unit)),
  sin(2 * pi * (knts + harm_start_time) / (2 * harm_month_unit)), # 2m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (2 * harm_month_unit)),
  sin(2 * pi * (knts + harm_start_time) / (4 * harm_month_unit)), # 4m * 30d * 24h * 60m
  cos(2 * pi * (knts + harm_start_time) / (4 * harm_month_unit)) # 4m * 30d * 24h * 60m  # should be at least sback*4*2
)


p = ncol(Xm)

# par(mfrow = c(2,2))
# for(i in 4:7){
#   plot(knts, Xm[,i], type = 'l')
# }


## Initial values for parameters ----
beta = rnorm(p)
alpha = 1
eta = 1


lam0m = as.vector( exp(Xm %*% beta ) )


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
alphaInd = p+1
etaInd = p+2

sigma2 = rep(0.2^2, 2)
adapIter = rep(1, 2)
COVbeta = diag(p)
COVeta = 1

lb_eta = 3 / 20
ub_eta = 3 / min(diff(ts))
shape_alpha = rate_alpha = 0.001

niters = 100000
updateCOV = TRUE
adaptInterval = 200
adaptFactorExponent = 0.8
outers = c(0, seq(1000, niters, by = 1000))

start = 1; postSamples = postBranching = c(); Accprob = 0; rtime = 0
# load(filename); start = which(outers == nrow(postSamples))

# i = 2; outers = seq(0, 2000, by = 100); adaptInterval = 50

sourceCpp(path.cpp)

for(i in (start+1):length(outers) ){
  outeri = outers[i]-outers[i-1]
  
  ptm = proc.time()[3]
  dummy = fitNHPPSE_parallel(
    outeri, ts, Xm, maxT, knts, beta, alpha, eta, indlam0, 
    shape_alpha, rate_alpha, lb_eta, ub_eta, sigma2, COVbeta, 
    COVeta, updateCOV, adaptInterval, adaptFactorExponent, adapIter, num) 
  rtime = rtime + proc.time()[3] - ptm
  
  postSamples = rbind(postSamples, dummy$postSamples)
  postBranching = rbind(postBranching, dummy$postBranching)
  Accprob = ( Accprob * outers[i-1] + colSums(dummy$Accprob) ) / outers[i]
  
  nSamples = nrow(postSamples)
  beta = postSamples[nSamples, betaInd]
  alpha = postSamples[nSamples, alphaInd]
  eta = postSamples[nSamples, etaInd]
  
  sigma2 = dummy$sigma2
  adapIter = dummy$adapIter
  COVbeta = dummy$COVbeta
  COVeta = dummy$COVeta
  
  save(rtime, postSamples, postBranching, Accprob, beta, alpha, eta, 
       lb_eta, ub_eta, shape_alpha, rate_alpha,
       sigma2, adapIter, COVbeta, COVeta,
       updateCOV, adaptInterval, adaptFactorExponent, adapIter,
       sback, knts, rho, Xm,
       file = filename)
}


