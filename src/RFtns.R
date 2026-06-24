# =============================================================================
# Shared post-processing helpers
#
# Callers must already have loaded coda (HPDinterval, as.mcmc), batchmeans (bm),
# and ggplot2/grid (ggplot_gtable, ggplot_build) before invoking these.
# =============================================================================

# Extract the legend grob from a ggplot for manual placement.
get_legend <- function(myggplot) {
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  tmp$grobs[[leg]]
}

# Batch-means posterior mean, formatted to a fixed number of decimals.
bmmean <- function(x, digits = 0) {
  format(round(bm(x)$est, digits), nsmall = digits)
}

# HPD interval as a "(lo, hi)" string, rounded and formatted.
hpd <- function(x, prob = 0.95, digits = 0) {
  ci <- HPDinterval(as.mcmc(x), prob = prob)
  paste0('(',
         format(round(ci[1], digits), nsmall = digits), ', ',
         format(round(ci[2], digits), nsmall = digits), ')')
}

# Numeric HPD bounds (rounded). Used when the lo/hi need to flow into other
# computations rather than being printed.
hpd1 <- function(x, prob = 0.95, digits = 2) round(HPDinterval(as.mcmc(x), prob = prob)[1], digits)
hpd2 <- function(x, prob = 0.95, digits = 2) round(HPDinterval(as.mcmc(x), prob = prob)[2], digits)

# Raw (unrounded) HPD bounds at fixed probabilities.
lb95 <- function(x) HPDinterval(as.mcmc(x), prob = 0.95)[1]
ub95 <- function(x) HPDinterval(as.mcmc(x), prob = 0.95)[2]
lb90 <- function(x) HPDinterval(as.mcmc(x), prob = 0.90)[1]
ub90 <- function(x) HPDinterval(as.mcmc(x), prob = 0.90)[2]

# Format a harmonic period (in minutes) as "1 wk", "2 mo", etc. — drives
# predictor labels in the harmonic-effects plots so they cannot drift out of
# sync with harm_periods_lgcp.
fmt_period <- function(minutes) {
  day   <- 1  * 24 * 60   # 1,440
  week  <- 7  * 24 * 60   # 10,080
  month <- 30 * 24 * 60   # 43,200
  vapply(minutes, function(m) {
    if      (m %% month == 0) sprintf('%g mo',  m / month)
    else if (m %% week  == 0) sprintf('%g wk',  m / week)
    else if (m %% day   == 0) sprintf('%g day', m / day)
    else                      sprintf('%g min', m)
  }, character(1))
}


simulateNHPP = function(intensity_ftn, maxintensity, maxTime){
  points = c()
  newTime = 0

  while(TRUE){
    newTime = newTime + rexp(1, maxintensity)
    if(newTime > maxTime){
      break
    }
    if(runif(1) < intensity_ftn(newTime) / maxintensity){
      points = c(points, newTime)
    }
  }

  return( points )
}

simulateHawkes = function(alpha, eta, maxT, lam0m, knts, displayOutput = TRUE){
  
  maxh = 1
  
  fn_lam0 = function(t){
    lam0 = compLam0(t, maxT, lam0m, which(knts >= t)[1] - 1 - 1, knts)
    return( as.vector(lam0) )
  }
  maxlam0 = max(lam0m)
  
  x = simulateNHPP(fn_lam0, maxlam0, maxT)
  
  if (displayOutput == TRUE) { print( sprintf("%s events generated from the background process", length(x)) ) }
  
  if(alpha == 0){
    ord = order(x)
    x = x[ord]
    caused = rep(0, length(x))
    
  } else {
    count = 1
    caused = rep(0, length(x))
    while (TRUE) {
      if (count > length(x)) {
        break
      }
      pt = x[count]
      
      fn_trig = function(tdiff) {
        return( alpha * comph(tdiff, eta) )
      }
      
      maxintensity = alpha * maxh
      pts = simulateNHPP(fn_trig, maxintensity, maxT - pt)
      if( !is.null(pts) ){
        x = c(x, pts + pt)
        if (displayOutput == TRUE) { print( sprintf("%s events generated so far", length(x)) ) }
        caused = c(caused, rep(pt, length(pts)))
      }
      count = count + 1
    }
    ord = order(x)
    x = x[ord]
    caused = caused[ord]
    for (i in 1:length(caused)) {
      if (caused[i] == 0) {
        next
      }
      caused[i] = which(x == caused[i])
    }
  }
 
  return(list(ts = x, branching = caused))
}

