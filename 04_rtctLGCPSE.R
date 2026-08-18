rm(list = ls())
library(foreach); library(doParallel)
library(Rcpp); library(RcppArmadillo)
library(tidyverse)

source('src/config.R')

path.cpp = 'src/RcppFtns.cpp'

fiti = fiti_lgcp

ifelse(!dir.exists(path.rtct), dir.create(path.rtct, recursive = T), FALSE)

filename = paste0(path.rtct, datai, fiti, '_rtct.RData')


# =============================================================================-
# Load results ----
# =============================================================================-

# Optional posterior thinning: the RTC pass is O(n_events x niters), so high-event
# buoys (ns02, 33.6k events) can exceed the 14-day walltime single-threaded. Set
# RTCT_THIN=<target #draws> in the env, e.g.
#   sbatch --export=ALL,BUOY=ns02,RTCT_THIN=25000 aci_rtct.sh
# load_fit.R then subsamples postSamples + postWm to `thin` evenly-spaced draws and
# resets niters (dims stay consistent). 2.5/50/97.5% quantiles are stable at ~25k.
thin <- as.integer(Sys.getenv('RTCT_THIN', unset = ''))
if (is.na(thin)) thin <- NULL

# Optional resume: continue a checkpointed run instead of restarting. The loop
# saves postCompen + intlami every 10 events, so RTCT_RESUME=true reloads them and
# picks up where it stopped (e.g. after a walltime kill). Full posterior only —
# the checkpoint was NOT thinned, so resume + thin would splice inconsistent
# quantiles. Set: sbatch --export=ALL,BUOY=ns02,RTCT_RESUME=true aci_rtct.sh
resume <- tolower(Sys.getenv('RTCT_RESUME', unset = '')) %in% c('1', 'true', 'yes')
if (resume && !is.null(thin))
  stop('RTCT_RESUME and RTCT_THIN are incompatible (checkpoint is full-posterior).')

source('src/load_fit.R')


# =============================================================================-
# Random time change theorem (RTCT) ----
# =============================================================================-

deltaWm = exp(postSamples[, deltaInd]) * postWm

aaa = unique(c(0, seq(10, length(ts), by = 10), length(ts)))

start = 1; postCompen = c()
if (resume && file.exists(filename)) {
  load(filename)                              # restores postCompen, intlami, ts
  start <- which(aaa == nrow(postCompen))
  if (length(start) != 1)
    stop(sprintf('Resume: nrow(postCompen)=%d is not an aaa breakpoint; cannot resume cleanly.',
                 nrow(postCompen)))
  cat(sprintf('Resuming rtct from %d of %d events (aaa idx %d)\n',
              nrow(postCompen), length(ts), start))
}

sourceCpp(path.cpp)

for(aa in (start+1):length(aaa) ){

  dummy = c()
  for(i in (aaa[aa-1]+1):(aaa[aa])){

    indlam0i = which(knts >= ts[i])[1] - 1 - 1

    if(i == 1){
      intlampre = 0
    } else {
      intlampre = intlami
    }

    intlam0i = rtctIntLam0i(ts[i], Xm, maxT, knts, indlam0i,
                            matrix(postSamples[, betaInd], nrow = niters),
                            deltaWm)
    intTrigi = rtctSumIntHi(ts[i], ts, postSamples[, alphaInd], postSamples[, etaInd])
    intlami  = intlam0i + intTrigi
    di       = intlami - intlampre

    dummy = rbind(dummy, c(quantile(intlami, probs = c(0.025, 0.5, 0.975)),
                           quantile(di,      probs = c(0.025, 0.5, 0.975))))
  }

  print(paste0('Completed by ', aaa[aa], 'th time event'))

  postCompen = rbind(postCompen, dummy)
  save(intlami, ts, postCompen, file = filename)
}
save(intlami, ts, postCompen, file = filename)
