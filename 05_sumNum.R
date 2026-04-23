rm(list=ls())
library(coda); library(tidyverse); library(egg); library(grid)
# library(ggh4x) # facet_grid2
library(spgs) # chisq.unif.test
library(batchmeans); library(foreach)
library(xtable)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

HPDprob = 0.95
bmmean = function(x) { format(round(bm(x)$est), nsmall = 0) }
hpd = function(x){ paste0('(',
                          format(round(HPDinterval(as.mcmc(x), prob = HPDprob)[1]), nsmall = 0), ', ',
                          format(round(HPDinterval(as.mcmc(x), prob = HPDprob)[2]), nsmall = 0), ')') }


fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')

# NHPPSE
load(paste0('num/nopp', fits[3], 'num.RData'))
apply(cbind(rowSums(postNum), postNum), 2, bmmean)
apply(cbind(rowSums(postNum), postNum), 2, hpd)

# LGCPSE
load(paste0('num/nopp', fits[4], 'num.RData'))
apply(cbind(rowSums(postNum), postNum), 2, bmmean)
apply(cbind(rowSums(postNum), postNum), 2, hpd)
