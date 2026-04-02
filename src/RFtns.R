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

