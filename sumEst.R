rm(list = ls())
library(coda); library(tidyverse); library(egg); library(grid)
library(batchmeans); library(foreach)
library(xtable)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

HPDprob = 0.95

# sum = function(x){ paste0(format(round(bm(x)$est, 2), nsmall = 2), ' (', 
#                           format(round(HPDinterval(as.mcmc(x))[1], 2), nsmall = 2), ', ',
#                           format(round(HPDinterval(as.mcmc(x))[2], 2), nsmall = 2), ')') }

# bmmean = function(x) { format(round(bm(x)$est, 2), nsmall = 2) }
# hpd = function(x){ paste0('(',
#                           format(round(HPDinterval(as.mcmc(x), prob = HPDprob)[1], 2), nsmall = 2), ', ',
#                           format(round(HPDinterval(as.mcmc(x), prob = HPDprob)[2], 2), nsmall = 2), ')') }
# hpd1 = function(x){ HPDinterval(as.mcmc(x), prob = HPDprob)[1] }
# hpd2 = function(x){ HPDinterval(as.mcmc(x), prob = HPDprob)[2] }

bmmean = function(x) { format(round(bm(x)$est, 2), nsmall = 2) }
hpd = function(x){ paste0('(',
                          format(round(HPDinterval(as.mcmc(x), prob = HPDprob)[1], 2), nsmall = 2), ', ',
                          format(round(HPDinterval(as.mcmc(x), prob = HPDprob)[2], 2), nsmall = 2), ')') }
hpd1 = function(x){ HPDinterval(as.mcmc(x), prob = HPDprob)[1] }
hpd2 = function(x){ HPDinterval(as.mcmc(x), prob = HPDprob)[2] }


load('nopp/data/nopp.RData')

burn = 10000

# -----------------------------------------------------------------------------=
# NHPP ----
# -----------------------------------------------------------------------------=
load('nopp/fit/noppNHPP.RData')

p = length(beta)

row.names = c('Intercept', 'Noise',
              paste0('8h ', c('sin', 'cos')), paste0('12h ', c('sin', 'cos')), 
              paste0('24h ', c('sin', 'cos')), 'GP var')
row.names.SE = c('Intercept', 'Noise',
                 paste0('8h ', c('sin', 'cos')), paste0('12h ', c('sin', 'cos')), 
                 paste0('24h ', c('sin', 'cos')), 'GP var', 'SE intensity', 'Decay')

par = c(paste0('$\\beta_{', 0:(p-1), '}$'), '$\\kappa$')
par.SE = c(paste0('$\\beta_{', 0:(p-1), '}$'), '$\\kappa$', '$\\alpha/\\eta$', '$\\eta$')


betaInd = 1:p

posterior = postSamples[-(1:burn), c(betaInd)]

sumNHPP = data.frame(
  par = par,
  mean = c(apply(posterior, 2, bmmean), NA),
  hpd = c(apply(posterior, 2, hpd), NA),
  hpd1 = c(apply(posterior, 2, hpd1), NA),
  hpd2 = c(apply(posterior, 2, hpd2), NA),
  row.names = row.names) %>% 
  mutate(sig = ifelse( (hpd1 > 0) | (0 > hpd2), '*', '')) %>%
  select(c(par, mean, hpd, sig))


# -----------------------------------------------------------------------------=
# LGCP ----
# -----------------------------------------------------------------------------=
load('nopp/fit/noppLGCP.RData')

betaInd = 1:p
kappaInd = p+1
phiInd = p+2

posterior = postSamples[-(1:burn), c(betaInd, kappaInd)]

sumLGCP = data.frame(
  mean = c(apply(posterior, 2, bmmean)),
  hpd = c(apply(posterior, 2, hpd)),
  hpd1 = c(apply(posterior, 2, hpd1)),
  hpd2 = c(apply(posterior, 2, hpd2))) %>% 
  mutate(sig = ifelse( (hpd1 > 0) | (0 > hpd2), '*', '')) %>%
  select(c(mean, hpd, sig))





# -----------------------------------------------------------------------------=
# NHPP + SE ----
# -----------------------------------------------------------------------------=
load('nopp/fit/noppNHPPSE.RData')

betaInd = 1:p
etaInd = p+1
alphaInd = p+2

postSamples[,alphaInd] = postSamples[,alphaInd] / postSamples[,etaInd]
posterior = postSamples[-c(1:burn), c(betaInd, alphaInd, etaInd)]


sumNHPPSE = data.frame(
  par = par.SE,
  mean = c(apply(posterior, 2, bmmean)[1:p], NA, apply(posterior, 2, bmmean)[(p+1):(p+2)]),
  hpd = c(apply(posterior, 2, hpd)[1:p], NA, apply(posterior, 2, hpd)[(p+1):(p+2)]),
  hpd1 = c(apply(posterior, 2, hpd1)[1:p], NA, apply(posterior, 2, hpd1)[(p+1):(p+2)]),
  hpd2 = c(apply(posterior, 2, hpd2)[1:p], NA, apply(posterior, 2, hpd2)[(p+1):(p+2)]),
  row.names = row.names.SE) %>%
  mutate(sig = ifelse( (hpd1 > 0) | (0 > hpd2), '*', '')) %>%
  select(c(par, mean, hpd, sig))




# -----------------------------------------------------------------------------=
# LGCP + SE ----
# -----------------------------------------------------------------------------=
load('nopp/fit/noppLGCPSE.RData')

betaInd = 1:p
deltaInd = p+1
alphaInd = p+2
etaInd = p+3

postSamples[,alphaInd] = postSamples[,alphaInd] / postSamples[,etaInd]
posterior = postSamples[-c(1:burn), c(betaInd, deltaInd, alphaInd, etaInd)]


sumLGCPSE = data.frame(
  mean = c(apply(posterior, 2, bmmean)),
  hpd = c(apply(posterior, 2, hpd)),
  hpd1 = c(apply(posterior, 2, hpd1)),
  hpd2 = c(apply(posterior, 2, hpd2))) %>% 
  mutate(sig = ifelse( (hpd1 > 0) | (0 > hpd2), '*', '')) %>%
  select(c(mean, hpd, sig))



# -----------------------------------------------------------------------------=
# Table
# -----------------------------------------------------------------------------=
cbind(sumNHPP, sumLGCP) %>% 
  xtable() %>% 
  print(booktabs = T, sanitize.text.function = function(x) {x})

cbind(sumNHPPSE, sumLGCPSE) %>% 
  xtable() %>% 
  print(booktabs = T, sanitize.text.function = function(x) {x})



# sumNHPPSE %>%
#   xtable() %>% 
#   print(sanitize.text.function = function(x) {x})

dummy = cbind(par.SE, sumLGCPSE)
rownames(dummy) = row.names.SE
dummy %>% 
  xtable() %>% 
  print(booktabs = T, sanitize.text.function = function(x) {x})


t(dummy) %>% 
  xtable() %>% 
  print(booktabs = T, sanitize.text.function = function(x) {x})



