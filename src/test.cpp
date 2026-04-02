// -*- mode: C++; c-indent-level: 4; c-basic-offset: 4; indent-tabs-mode: nil; -*-


// we only include RcppArmadillo.h which pulls Rcpp.h in for us
#include <RcppArmadillo.h>
#include <limits>
#include <omp.h>

// [[Rcpp::depends(RcppArmadillo)]]
// [[Rcpp::plugins(openmp)]]

#define minimum(x,y) (((x) < (y)) ? (x) : (y))

using namespace std;
using namespace Rcpp;
using namespace arma;



// ============================================================================-
// Approximations to background rate
// ============================================================================-

// Compute lam0
// [[Rcpp::export]]
vec compLam0(vec ts, double maxT, vec lam0m, vec indlam0, vec knts){
  int n = ts.size(), m = lam0m.size()-1, dummy;
  vec lam0 = zeros(n);
  
  for(int i = 0; i < n; i ++){
    dummy = indlam0[i];
    lam0[i] = lam0m[dummy] + ( (lam0m[dummy+1] - lam0m[dummy]) / (maxT / m) ) * (ts[i] - knts[dummy]);
  }
  
  return lam0;
}


// Approximation to integral of lam0
// [[Rcpp::export]]
double compIntLam0(double maxT, vec lam0m){
  int m = lam0m.size()-1;
  double intLam0 = 0;
  
  for(int i = 0; i < m; i ++){
    intLam0 = intLam0 + (lam0m[i] + lam0m[i+1]) * maxT / (2 * m);
  }
  
  return intLam0;
}



// ============================================================================-
// Random time change theorem
// ============================================================================-

// [[Rcpp::export]]
double rtctIntLam0(double tsi, int indlam0i, vec lam0m, double maxT, vec knts){
  double intlam0i = 0;
  int m = lam0m.size()-1;
  
  for(int j = 0; j < indlam0i; j ++){
    intlam0i = intlam0i + (lam0m[j] + lam0m[j+1]) * maxT / (2 * m);
  }
  
  double lam0i = lam0m[ indlam0i ] + 
    ( (lam0m[ indlam0i + 1 ] - lam0m[ indlam0i ]) / (maxT / m) ) * 
    (tsi - knts[ indlam0i ]);
  
  intlam0i = intlam0i + (lam0m[ indlam0i ] + lam0i) * (tsi - knts[ indlam0i ]) / 2;
  
  return intlam0i;
}



// [[Rcpp::export]]
vec rtctIntLam0i(double tsi, mat Xm, double maxT, vec knts, int indlam0i, mat beta, mat Wm){
  int niters = beta.n_rows, p = beta.n_cols, m = Wm.n_cols;
  vec betahat(p), Wmhat(m), lam0mhat(m), intlam0i(niters);
  
  for(int iter = 0; iter < niters; iter ++){
    betahat = trans( beta.row(iter) );
    Wmhat = trans( Wm.row(iter) );
    lam0mhat = exp( Xm * betahat + Wmhat );
    intlam0i[iter] = rtctIntLam0(tsi, indlam0i, lam0mhat, maxT, knts);
  }
  
  return intlam0i;
}



// [[Rcpp::export]]
vec rtctIntLam0iter(vec ts, mat Xm, double maxT, vec knts, vec indlam0, vec beta, vec Wm){
  int n = ts.size(), m = Wm.size();
  vec lam0m(m), intlam0iter(n);
  
  lam0m = exp( Xm * beta + Wm );
  for(int i = 0; i < n; i ++){
    intlam0iter[i] = rtctIntLam0(ts[i], indlam0[i], lam0m, maxT, knts);
  }
  
  return intlam0iter;
}



// [[Rcpp::export]]
double rtctSumIntH(double tsi, vec ts, double eta){
  uvec ind = find( ts < tsi );
  int sizeind = ind.size();
  vec res(sizeind);
  
  for(int j = 0; j < sizeind; j ++){
    res[j] = (1 - exp( -eta * (tsi - ts[j]) )) / eta;
  }
  
  return sum(res);
}



// [[Rcpp::export]]
vec rtctSumIntHi(double tsi, vec ts, vec alpha, vec eta){
  int niters = eta.size();
  vec intTrigi(niters);
  double alphaiter, etaiter;
  
  for(int iter = 0; iter < niters; iter ++){
    alphaiter = alpha[iter];
    etaiter = eta[iter];
    intTrigi[iter] = alphaiter * rtctSumIntH(tsi, ts, etaiter);
  }
  
  return intTrigi;
}


// [[Rcpp::export]]
vec rtctSumIntHiter(vec ts, mat Xm, double alpha, double eta){
  int n = ts.size();
  vec intTrig(n);
  
  for(int i = 0; i < n; i ++){
    intTrig[i] = alpha * rtctSumIntH(ts[i], ts, eta);
  }
  
  return intTrig;
}



// ============================================================================-
// Intensity function
// ============================================================================-

// [[Rcpp::export]]
vec compLam0i(double tsi, mat Xm, double maxT, vec knts, int indlam0i, mat beta, mat Wm){
  int niters = beta.n_rows, p = beta.n_cols, m = Wm.n_cols;
  vec betahat(p), Wmhat(m), lam0mhat(m), lam0i(niters);
  
  for(int iter = 0; iter < niters; iter ++){
    betahat = trans( beta.row(iter) );
    Wmhat = trans( Wm.row(iter) );
    lam0mhat = exp( Xm * betahat + Wmhat );
    lam0i[iter] = lam0mhat[indlam0i] + ( (lam0mhat[indlam0i+1] - lam0mhat[indlam0i]) / (maxT / m) ) * (tsi - knts[indlam0i]);
  }
  
  return lam0i;
}


// [[Rcpp::export]]
vec compSumAHi(double tsi, vec ts, vec alpha, vec eta){
  int niters = eta.size();
  vec intTrigi(niters);
  double alphaiter, etaiter;
  
  uvec ind = find( ts < tsi );
  int sizeind = ind.size();
  double res = 0;
  
  for(int iter = 0; iter < niters; iter ++){
    alphaiter = alpha[iter];
    etaiter = eta[iter];
    
    if(sizeind != 0){
      res = 0;
      for(int j = 0; j < sizeind; j ++){
        res = res + exp(- etaiter * (tsi - ts[j]));
      }
    }
    
    intTrigi[iter] = alphaiter * res;
  }
  
  return intTrigi;
}



// [[Rcpp::export]]
vec compSumAHiter(vec ts, vec tsout, double alpha, double eta){
  int n = tsout.size(), sizeind;
  vec intTrig(tsout);
  uvec ind;
  double res;
  
  for(int i = 0; i < n; i ++){
    
    ind = find( ts < tsout[i] );
    sizeind = ind.size();
    res = 0;
    
    if(sizeind != 0){
      for(int j = 0; j < sizeind; j ++){
        res = res + exp(- eta * (tsout[i] - ts[j]));
      }
    }
    
    intTrig[i] = alpha * res;
  }
  
  return intTrig;
}



// ============================================================================-
// Compute log-likelihood
// ============================================================================-

// Compute log-likelihood for a single posterior sample
// [[Rcpp::export]]
double compLogLiki(vec ts, double maxT, vec lam0m, vec indlam0, vec knts, double alpha, double eta){
  int m = lam0m.size()-1, n = ts.size(), sizeind, dummy;
  double mui, sumIntH;
  vec lam = zeros(n), intLam0 = zeros(m);
  
  for(int i = 0; i < n; i ++){
    
    // background
    dummy = indlam0[i];
    mui = lam0m[dummy] + ( (lam0m[dummy+1] - lam0m[dummy]) / (maxT / m) ) * (ts[i] - knts[dummy]);
    
    if(alpha == 0){
      lam[i] = mui;
      
    } else {
      // self-exciting
      uvec ind = find( ts < ts[i] );
      sizeind = ind.size();
      vec hi = zeros(sizeind);
      for(int j = 0; j < sizeind; j ++){
        hi[j] = exp( -eta * (ts[i] - ts[j]));
      }
      
      lam[i] = mui + alpha * sum(hi);
    }
  }
  
  for(int i = 0; i < m; i ++){
    intLam0[i] = (lam0m[i] + lam0m[i+1]) * maxT / (2 * m);
  }
  
  if(alpha == 0){
    return sum( log(lam) ) - sum(intLam0);
    
  } else {
    sumIntH = sum( 1 - exp(- eta * (maxT - ts)) ) / eta;
    return sum( log(lam) ) - sum(intLam0) - alpha * sumIntH;  
  }
}



// Compute log-likelihood across multiple posterior samples
// [[Rcpp::export]]
vec compLogLik(vec ts, mat Xm, double maxT, vec indlam0, vec knts, mat beta, mat Wm, vec alpha, vec eta){
  int niters = beta.n_rows, p = beta.n_cols, m = Wm.n_cols;
  vec loglik = zeros(niters), lam0m = zeros(m);
  
  for(int iter = 0; iter < niters; iter ++){
    lam0m = exp( Xm * trans( beta.row(iter) ) + trans( Wm.row(iter) ) );
    
    loglik[iter] = compLogLiki(ts, maxT, lam0m, indlam0, knts, alpha[iter], eta[iter]);
  }
  
  return loglik;
}


// ============================================================================-
// Distribution functions
// ============================================================================-

// Log of unnormalized Gaussian pdf
// [[Rcpp::export]]
double normal_logh(double y, double mu, double sig2){
  return - 0.5 * pow(y - mu, 2) / sig2;
}


// Log of unnormalized Gamma pdf
// [[Rcpp::export]]
double gamma_logh(double y, double alpha, double beta){
  return (alpha-1) * log(y) - beta * y;
}


// Log of unnormalized inverse Gamma pdf
// [[Rcpp::export]]
double invgamma_logh(double y, double alpha, double beta){
  return (-alpha-1) * log(y) - beta / y;
}


// Logo of unnormalized MVN pdf
// [[Rcpp::export]]
double MVN_logh(vec y, vec mu, mat invSigma){
  vec result = - 0.5 * trans(y - mu) * invSigma * (y - mu);
  return result[0];
}



// ============================================================================-
// Functions
// ============================================================================-

// Triggering function h
// [[Rcpp::export]]
double comph(double tdiff, double eta){
  return exp( -eta * tdiff ); // ***
}


// Sample latent branching structure
// [[Rcpp::export]]
vec sampleBranching(vec ts, vec lam0, double alpha, double eta) {
  int n = ts.size(), parent, ndummy;
  double temp;
  vec branching = zeros(n), probs;
  uvec dummy;
  
  std::random_device rd;
  std::mt19937 gen(rd());
  
  for (int i = 1; i < n; i++) {
    
    dummy = find( ts < ts[i] );
    ndummy = dummy.size();
    
    if(ndummy == 0){
      branching[i] = 0;
      
    } else {
      probs = zeros(ndummy + 1);
      probs[0] = lam0[i];
      
      for (int j = 0; j < ndummy; j++) {
        temp = alpha * comph(ts[i] - ts[ dummy[j] ], eta);
        probs[j+1] = temp;
      }
      probs = probs / sum(probs);
      std::discrete_distribution<> d(probs.begin(), probs.end());
      
      parent = d(gen);
      branching[i] = parent;
    }
  }
  
  return branching;
}


// Sample latent branching structure with truncation
// [[Rcpp::export]]
vec sampleBranchingTrunc(vec ts, vec lam0, double alpha, double eta, double lb_eta) {
  int n = ts.size(), parent, ndummy;
  double temp, ubtdiff = 1/lb_eta * 1000;
  vec branching = zeros(n), probs;
  uvec dummy;
  
  std::random_device rd;
  std::mt19937 gen(rd());
  
  for (int i = 1; i < n; i++) {
    
    dummy = find( ( ts < ts[i] ) && ( abs(ts[i] - ts) < ubtdiff ) );
    ndummy = dummy.size();
    
    if(ndummy == 0){
      branching[i] = 0;
      
    } else {
      probs = zeros(ndummy + 1);
      probs[0] = lam0[i];
      
      for (int j = 0; j < ndummy; j++) {
        temp = alpha * comph(ts[i] - ts[ dummy[j] ], eta);
        probs[j+1] = temp;
      }
      probs = probs / sum(probs);
      std::discrete_distribution<> d(probs.begin(), probs.end());
      
      parent = d(gen);
      // branching[i] = parent;
      if(parent == 0){
        branching[i] = 0;
      } else {
        branching[i] = dummy[parent-1];  
      }
    }
  }
  
  return branching;
}



// ============================================================================-
// Posterior sampling ---
// ============================================================================-

// NHPP
// [[Rcpp::export]]
List fitNHPP(int niter, vec ts, mat Xm, double maxT, vec knts,
             vec beta, vec indlam0, vec sigma2, mat COVbeta, 
             bool updateCOV, int adaptInterval, double adaptFactorExponent, vec adapIter) {
  
  double negativeInf = -std::numeric_limits<float>::infinity();;
  double positiveInf = std::numeric_limits<float>::infinity();;
  
  int n = ts.size(), p = beta.size(), m = knts.size() - 1;
  double logprob;
  mat postSamples = zeros(niter, p), accprob = zeros(niter, 1);
  vec postj;
  vec newlam0m, lam0, newlam0, newbeta;
  double newdelta, intLam0, newintLam0;
  vec rhat = zeros(1), gamma1 = zeros(1), gamma2 = zeros(1), dummyaccprob;
  double c0 = 1, c1 = adaptFactorExponent, ropt = 0.234, shape, scale;
  
  mat cholCOVbeta;
  cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
  
  vec XmB = Xm * beta, newXmB = zeros(m+1);
  vec lam0m = exp( XmB );
  
  intLam0 = compIntLam0(maxT, lam0m);
  lam0 = compLam0(ts, maxT, lam0m, indlam0, knts);
  
  
  
  // Start MCMC
  for(int s = 0; s < niter; s++) {
    
    
    // M-H updates for beta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(0);
        rhat[0] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[0] = 1 / pow(adapIter[0], c1);
        gamma2[0] = c0 * gamma1[0];
        sigma2[0] = exp( log(sigma2[0]) + gamma2[0] * (rhat[0] - ropt) );
        
        COVbeta = COVbeta + gamma1[0] * ( cov( postSamples( span(s+1-adaptInterval, s-1), span(0, p-1) ) ) - COVbeta );
        cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
        
        adapIter[0] = adapIter[0] + 1;
      }
    }
    
    newbeta = beta + cholCOVbeta * randn(p);
    newXmB = Xm * newbeta;
    newlam0m = exp(newXmB);
    newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
    newintLam0 = compIntLam0(maxT, newlam0m);
    
    logprob = (sum(log(newlam0)) - sum(log(lam0))) - (newintLam0 - intLam0) +
      MVN_logh(newbeta, zeros(p), diagmat(ones(p)) / 100) - MVN_logh(beta, zeros(p), diagmat(ones(p)) / 100);
    
    if (log(randu()) < logprob) {
      beta = newbeta;
      XmB = newXmB;
      lam0m = newlam0m;
      lam0 = newlam0;
      intLam0 = newintLam0;
      
      accprob(s, 0) = 1;
    }
    
    for(int l = 0; l < p; l ++){
      postSamples(s, l) = beta[l];
    }
    
    
    
    if ( (s+1) % 100 == 0 ) {
      Rprintf("Generated %d samples...\n", s+1);
    }
  }
  
  return Rcpp::List::create(Rcpp::Named("postSamples") = postSamples,
                            Rcpp::Named("Accprob") = accprob,
                            Rcpp::Named("sigma2") = sigma2,
                            Rcpp::Named("adapIter") = adapIter,
                            Rcpp::Named("COVbeta") = COVbeta);
}





// NHPP plus self-exciting
// Gamma prior for alpha and Uniform prior for eta
// [[Rcpp::export]]
List fitNHPPSE(int niter, vec ts, mat Xm, double maxT, vec knts,
               vec beta, double alpha, double eta,
               vec indlam0,
               double shape_alpha, double rate_alpha, 
               double lb_eta, double ub_eta,
               vec sigma2, mat COVbeta, double COVeta,
               bool updateCOV, int adaptInterval, double adaptFactorExponent, vec adapIter) {
  
  double negativeInf = -std::numeric_limits<float>::infinity();;
  double positiveInf = std::numeric_limits<float>::infinity();;
  
  int n = ts.size(), p = beta.size(), m = knts.size() - 1, numbackground, numoffsp, dummy_k;
  double logprob;
  mat postSamples = zeros(niter, p+2), postBranching = zeros(niter, n), accprob = zeros(niter, 2);
  vec postj;
  vec branching(n), tdoffsp;
  vec newlam0m, lam0, newlam0, lam0z0, newlam0z0, newbeta;
  double newalpha, neweta, intLam0, newintLam0;
  uvec dummy_background;
  vec rhat = zeros(2), gamma1 = zeros(2), gamma2 = zeros(2), dummyaccprob;
  double c0 = 1, c1 = adaptFactorExponent, ropt = 0.234, shape, scale;
  
  mat cholCOVbeta;
  double cholCOVeta;
  cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
  cholCOVeta = sqrt( sigma2[1] * COVeta );
  
  vec XmB = Xm * beta, newXmB = zeros(m+1);
  vec lam0m = exp( XmB );
  
  intLam0 = compIntLam0(maxT, lam0m);
  lam0 = compLam0(ts, maxT, lam0m, indlam0, knts);
  
  // Start MCMC
  for(int s = 0; s < niter; s++) {
    
    // Gibbs update for latent branching structure
    // branching = sampleBranching(ts, lam0, alpha, eta);
    branching = sampleBranchingTrunc(ts, lam0, alpha, eta, lb_eta);
    postBranching.row(s) = trans( branching );
    
    dummy_background = find( branching == 0 );
    numbackground = dummy_background.size();
    numoffsp = n - numbackground;
    tdoffsp = zeros(numoffsp);
    dummy_k = 0;
    for (int i = 0; i < n; i++) {
      if (branching[i] > 0) {
        tdoffsp[dummy_k] = ts[i] - ts[branching[i]-1]; // time difference between parent and offspring
        dummy_k = dummy_k + 1;
      }
    }
    lam0z0 = zeros(numbackground);
    for(int i = 0; i < numbackground; i ++){
      lam0z0[i] = lam0[dummy_background[i]];
    }
    
    
    // M-H updates for beta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(0);
        rhat[0] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[0] = 1 / pow(adapIter[0], c1);
        gamma2[0] = c0 * gamma1[0];
        sigma2[0] = exp( log(sigma2[0]) + gamma2[0] * (rhat[0] - ropt) );
        
        COVbeta = COVbeta + gamma1[0] * ( cov( postSamples( span(s+1-adaptInterval, s-1), span(0, p-1) ) ) - COVbeta );
        cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
        
        adapIter[0] = adapIter[0] + 1;
      }
    }
    
    newbeta = beta + cholCOVbeta * randn(p);
    newXmB = Xm * newbeta;
    newlam0m = exp(newXmB );
    newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
    newintLam0 = compIntLam0(maxT, newlam0m);
    
    newlam0z0 = zeros(numbackground);
    for(int i = 0; i < numbackground; i ++){
      newlam0z0[i] = newlam0[dummy_background[i]];
    }
    
    logprob = (sum(log(newlam0z0)) - sum(log(lam0z0))) - (newintLam0 - intLam0) +
      MVN_logh(newbeta, zeros(p), diagmat(ones(p)) / 100) - MVN_logh(beta, zeros(p), diagmat(ones(p)) / 100);
    
    if (log(randu()) < logprob) {
      beta = newbeta;
      XmB = newXmB;
      lam0m = newlam0m;
      lam0 = newlam0;
      intLam0 = newintLam0;
      lam0z0 = newlam0z0;
      
      accprob(s, 0) = 1;
    }
    
    for(int l = 0; l < p; l ++){
      postSamples(s, l) = beta[l];
    }
    
    
    
    // M-H update for alpha
    shape = shape_alpha + numoffsp;
    scale = ( 1 / ( rate_alpha + sum( 1 - exp(- eta * (maxT - ts)) ) / eta ) );
    
    alpha = randg(distr_param(shape, scale));
    postSamples(s, p) = alpha;
    
    
    
    // M-H updates for eta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(1);
        rhat[1] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[1] = 1 / pow(adapIter[1], c1);
        gamma2[1] = c0 * gamma1[1];
        sigma2[1] = exp( log(sigma2[1]) + gamma2[1] * (rhat[1] - ropt) );
        
        postj = postSamples.col(p+1);
        COVeta = COVeta + gamma1[1] * ( var( postj.rows(s+1-adaptInterval, s-1) ) - COVeta );
        cholCOVeta = sqrt( sigma2[1] * COVeta );
        
        adapIter[1] = adapIter[1] + 1;
      }
    }
    
    neweta = eta + cholCOVeta * randn();
    
    if( (neweta < lb_eta) || (neweta > ub_eta) ){
      logprob = negativeInf;
      
    } else {
      
      if( numoffsp == 0 ){
        logprob = - alpha * ( sum( 1 - exp(- neweta * (maxT - ts)) ) / neweta - sum( 1 - exp(- eta * (maxT - ts)) ) / eta );
        
      } else {
        logprob = - sum(tdoffsp) * (neweta - eta) -
          alpha * ( sum( 1 - exp(- neweta * (maxT - ts)) ) / neweta - sum( 1 - exp(- eta * (maxT - ts)) ) / eta );
      }
    }
    
    if (log(randu()) < logprob) {
      eta = neweta;
      
      accprob(s, 1) = 1;
    }
    postSamples(s, p+1) = eta;
    
    
    
    
    if ( (s+1) % 100 == 0 ) {
      Rprintf("Generated %d samples...\n", s+1);
    }
  }
  
  return Rcpp::List::create(Rcpp::Named("postSamples") = postSamples,
                            Rcpp::Named("postBranching") = postBranching,
                            Rcpp::Named("Accprob") = accprob,
                            Rcpp::Named("sigma2") = sigma2,
                            Rcpp::Named("adapIter") = adapIter,
                            Rcpp::Named("COVbeta") = COVbeta,
                            Rcpp::Named("COVeta") = COVeta);
}




// LGCP
// Elliptical slice sampling (ESS) for W, fixed rho, exponential covariance function with variance kappa, W follows Normal with mean of 0
// variance kappa ~ inv-Gamma
// [[Rcpp::export]]
List fitLGCP(int niter, vec ts, mat Xm, double maxT, vec knts, mat tdiffm,
             vec beta, double delta, double rho, vec Wm, vec indlam0,
             vec sigma2, mat COVbeta, double COVdelta,
             bool updateCOV, int adaptInterval, double adaptFactorExponent, vec adapIter) {
  
  double negativeInf = -std::numeric_limits<float>::infinity();;
  double positiveInf = std::numeric_limits<float>::infinity();;
  
  int n = ts.size(), p = beta.size(), m = knts.size() - 1;
  double logprob;
  mat postSamples = zeros(niter, p+1), postWm(niter, m+1), accprob = zeros(niter, 2);
  vec postj;
  vec newlam0m, newWm, lam0, newlam0, newbeta;
  double newdelta, intLam0, newintLam0;
  vec rhat = zeros(2), gamma1 = zeros(2), gamma2 = zeros(2), dummyaccprob;
  double c0 = 1, c1 = adaptFactorExponent, ropt = 0.234, shape, scale;
  vec xvals;
  double llprev, llthred, llnew, thetamin, thetamax, theta;
  vec priorWm;
  bool accept;
  int count;
  
  mat cholCOVbeta;
  double cholCOVdelta;
  cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
  cholCOVdelta = sqrt( sigma2[1] * COVdelta );
  
  vec XmB = Xm * beta, newXmB = zeros(m+1);
  vec lam0m = exp( XmB + exp(delta) * Wm );
  
  intLam0 = compIntLam0(maxT, lam0m);
  lam0 = compLam0(ts, maxT, lam0m, indlam0, knts);
  mat Sigma = exp( - tdiffm / rho);
  mat cholSigma = chol( Sigma );
  
  
  // Start MCMC
  for(int s = 0; s < niter; s++) {
    
    
    // M-H updates for beta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(0);
        rhat[0] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[0] = 1 / pow(adapIter[0], c1);
        gamma2[0] = c0 * gamma1[0];
        sigma2[0] = exp( log(sigma2[0]) + gamma2[0] * (rhat[0] - ropt) );
        
        COVbeta = COVbeta + gamma1[0] * ( cov( postSamples( span(s+1-adaptInterval, s-1), span(0, p-1) ) ) - COVbeta );
        cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
        
        adapIter[0] = adapIter[0] + 1;
      }
    }
    
    newbeta = beta + cholCOVbeta * randn(p);
    newXmB = Xm * newbeta;
    newlam0m = exp(newXmB + exp(delta) * Wm);
    newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
    newintLam0 = compIntLam0(maxT, newlam0m);
    
    logprob = (sum(log(newlam0)) - sum(log(lam0))) - (newintLam0 - intLam0) +
      MVN_logh(newbeta, zeros(p), diagmat(ones(p)) / 100) - MVN_logh(beta, zeros(p), diagmat(ones(p)) / 100);
    
    if (log(randu()) < logprob) {
      beta = newbeta;
      XmB = newXmB;
      lam0m = newlam0m;
      lam0 = newlam0;
      intLam0 = newintLam0;
      
      accprob(s, 0) = 1;
    }
    
    for(int l = 0; l < p; l ++){
      postSamples(s, l) = beta[l];
    }
    
    
    
    // Elliptical slice sampling (Murray et al., 2010, ICAIS) for Wm
    llprev = sum(log(lam0)) - intLam0;
    priorWm = trans( cholSigma ) * randn(m+1);
    
    thetamin = 0;
    thetamax = 2 * M_PI;
    theta = thetamin + randu() * (thetamax - thetamin);
    thetamin = theta - 2 * M_PI;
    thetamax = theta;
    
    llthred = llprev + log(randu());
    accept = false;
    count = 0;
    
    while(accept == false){
      count = count + 1;
      
      newWm = Wm * cos(theta) + priorWm * sin(theta);
      newlam0m = exp(XmB + exp(delta) * newWm);
      newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
      newintLam0 = compIntLam0(maxT, newlam0m);
      llnew = sum(log(newlam0)) - newintLam0;
      
      if(llnew > llthred){
        llprev = llnew;
        accept = true;
      } else {
        if(theta < 0){ thetamin = theta; } else { thetamax = theta; }
        theta = thetamin + randu() * (thetamax - thetamin);
        // Rprintf("ESS %d iterations...\n", count);
      }
    }
    Wm = newWm;
    lam0m = newlam0m;
    lam0 = newlam0;
    intLam0 = newintLam0;
    
    postWm.row(s) = trans(Wm);
    
    
    
    // MH updates for delta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(1);
        rhat[1] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[1] = 1 / pow(adapIter[1], c1);
        gamma2[1] = c0 * gamma1[1];
        sigma2[1] = exp( log(sigma2[1]) + gamma2[1] * (rhat[1] - ropt) );
        
        postj = postSamples.col(p);
        COVdelta = COVdelta + gamma1[1] * ( var( postj.rows(s+1-adaptInterval, s-1) ) - COVdelta );
        cholCOVdelta = sqrt( sigma2[1] * COVdelta );
        
        adapIter[1] = adapIter[1] + 1;
      }
    }
    
    newdelta = delta + cholCOVdelta * randn();
    newlam0m = exp(XmB + exp(newdelta) * Wm);
    newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
    newintLam0 = compIntLam0(maxT, newlam0m);
    
    logprob = (sum(log(newlam0)) - sum(log(lam0))) - (newintLam0 - intLam0) +
      normal_logh(newdelta, 0, 100) - normal_logh(delta, 0, 100);
    
    if (log(randu()) < logprob) {
      delta = newdelta;
      lam0 = newlam0;
      intLam0 = newintLam0;
      
      accprob(s, 1) = 1;
    }
    
    postSamples(s, p) = delta;
    
    
    
    
    if ( (s+1) % 100 == 0 ) {
      Rprintf("Generated %d samples...\n", s+1);
    }
  }
  
  return Rcpp::List::create(Rcpp::Named("postSamples") = postSamples,
                            Rcpp::Named("postWm") = postWm,
                            Rcpp::Named("Wm") = Wm,
                            Rcpp::Named("Accprob") = accprob,
                            Rcpp::Named("sigma2") = sigma2,
                            Rcpp::Named("adapIter") = adapIter,
                            Rcpp::Named("COVbeta") = COVbeta,
                            Rcpp::Named("COVdelta") = COVdelta);
}





// LGCP plus self-exciting
// Elliptical slice sampling (ESS) for W, fixed rho, exponential covariance function with variance 1, W follows Normal with mean of 0
// Gamma prior for alpha and Uniform prior for eta
// [[Rcpp::export]]
List fitLGCPSE(int niter, vec ts, mat Xm, double maxT, vec knts, mat tdiffm,
               vec beta, double delta, double rho, double alpha, double eta,
               vec Wm, vec indlam0,
               double shape_alpha, double rate_alpha, 
               double lb_eta, double ub_eta,
               vec sigma2, mat COVbeta, double COVdelta, double COVeta,
               bool updateCOV, int adaptInterval, double adaptFactorExponent, vec adapIter) {
  
  double negativeInf = -std::numeric_limits<float>::infinity();;
  double positiveInf = std::numeric_limits<float>::infinity();;
  
  int n = ts.size(), p = beta.size(), m = knts.size() - 1, numbackground, numoffsp, dummy_k;
  double logprob;
  mat postSamples = zeros(niter, p+3), postBranching = zeros(niter, n), postWm(niter, m+1), accprob = zeros(niter, 3);
  vec postj;
  vec branching(n), tdoffsp;
  vec newlam0m, newWm, lam0, newlam0, lam0z0, newlam0z0, newbeta;
  double newdelta, newalpha, neweta, intLam0, newintLam0;
  uvec dummy_background;
  vec rhat = zeros(3), gamma1 = zeros(3), gamma2 = zeros(3), dummyaccprob;
  double c0 = 1, c1 = adaptFactorExponent, ropt = 0.234, shape, scale;
  vec xvals;
  double llprev, llthred, llnew, thetamin, thetamax, theta;
  vec priorWm;
  bool accept;
  int count;
  
  mat cholCOVbeta;
  double cholCOVdelta, cholCOVeta;
  cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
  cholCOVdelta = sqrt( sigma2[1] * COVdelta );
  cholCOVeta = sqrt( sigma2[2] * COVeta );
  
  vec XmB = Xm * beta, newXmB = zeros(m+1);
  vec lam0m = exp( XmB + exp(delta) * Wm );
  
  intLam0 = compIntLam0(maxT, lam0m);
  lam0 = compLam0(ts, maxT, lam0m, indlam0, knts);
  mat Sigma = exp( - tdiffm / rho);
  mat cholSigma = chol( Sigma );
  
  
  // Start MCMC
  for(int s = 0; s < niter; s++) {
    
    // Gibbs update for latent branching structure
    // branching = sampleBranching(ts, lam0, alpha, eta);
    branching = sampleBranchingTrunc(ts, lam0, alpha, eta, lb_eta);
    postBranching.row(s) = trans( branching );
    
    dummy_background = find( branching == 0 );
    numbackground = dummy_background.size();
    numoffsp = n - numbackground;
    tdoffsp = zeros(numoffsp);
    dummy_k = 0;
    for (int i = 0; i < n; i++) {
      if (branching[i] > 0) {
        tdoffsp[dummy_k] = ts[i] - ts[branching[i]-1]; // time difference between parent and offspring
        dummy_k = dummy_k + 1;
      }
    }
    lam0z0 = zeros(numbackground);
    for(int i = 0; i < numbackground; i ++){
      lam0z0[i] = lam0[dummy_background[i]];
    }
    
    
    // M-H updates for beta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(0);
        rhat[0] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[0] = 1 / pow(adapIter[0], c1);
        gamma2[0] = c0 * gamma1[0];
        sigma2[0] = exp( log(sigma2[0]) + gamma2[0] * (rhat[0] - ropt) );
        
        COVbeta = COVbeta + gamma1[0] * ( cov( postSamples( span(s+1-adaptInterval, s-1), span(0, p-1) ) ) - COVbeta );
        cholCOVbeta = trans( chol( sigma2[0] * ( COVbeta + 0.0000000001 * diagmat(ones(p)) ) ) );
        
        adapIter[0] = adapIter[0] + 1;
      }
    }
    
    newbeta = beta + cholCOVbeta * randn(p);
    newXmB = Xm * newbeta;
    newlam0m = exp(newXmB + exp(delta) * Wm);
    newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
    newintLam0 = compIntLam0(maxT, newlam0m);
    
    newlam0z0 = zeros(numbackground);
    for(int i = 0; i < numbackground; i ++){
      newlam0z0[i] = newlam0[dummy_background[i]];
    }
    
    logprob = (sum(log(newlam0z0)) - sum(log(lam0z0))) - (newintLam0 - intLam0) +
      MVN_logh(newbeta, zeros(p), diagmat(ones(p)) / 100) - MVN_logh(beta, zeros(p), diagmat(ones(p)) / 100);
    
    if (log(randu()) < logprob) {
      beta = newbeta;
      XmB = newXmB;
      lam0m = newlam0m;
      lam0 = newlam0;
      intLam0 = newintLam0;
      lam0z0 = newlam0z0;
      
      accprob(s, 0) = 1;
    }
    
    for(int l = 0; l < p; l ++){
      postSamples(s, l) = beta[l];
    }
    
    
    
    // Elliptical slice sampling (Murray et al., 2010, ICAIS) for Wm
    llprev = sum(log(lam0z0)) - intLam0;
    priorWm = trans( cholSigma ) * randn(m+1);
    
    thetamin = 0;
    thetamax = 2 * M_PI;
    theta = thetamin + randu() * (thetamax - thetamin);
    thetamin = theta - 2 * M_PI;
    thetamax = theta;
    
    llthred = llprev + log(randu());
    accept = false;
    count = 0;
    
    while(accept == false){
      count = count + 1;
      
      newWm = Wm * cos(theta) + priorWm * sin(theta);
      newlam0m = exp(XmB + exp(delta) * newWm);
      newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
      newintLam0 = compIntLam0(maxT, newlam0m);
      newlam0z0 = zeros(numbackground);
      for(int i = 0; i < numbackground; i ++){
        newlam0z0[i] = newlam0[dummy_background[i]];
      }
      llnew = sum(log(newlam0z0)) - newintLam0;
      
      if(llnew > llthred){
        llprev = llnew;
        accept = true;
      } else {
        if(theta < 0){ thetamin = theta; } else { thetamax = theta; }
        theta = thetamin + randu() * (thetamax - thetamin);
        // Rprintf("ESS %d iterations...\n", count);
      }
    }
    Wm = newWm;
    lam0m = newlam0m;
    lam0 = newlam0;
    intLam0 = newintLam0;
    lam0z0 = newlam0z0;
    
    postWm.row(s) = trans(Wm);
    
    
    
    // MH updates for delta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(1);
        rhat[1] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[1] = 1 / pow(adapIter[1], c1);
        gamma2[1] = c0 * gamma1[1];
        sigma2[1] = exp( log(sigma2[1]) + gamma2[1] * (rhat[1] - ropt) );
        
        postj = postSamples.col(p);
        COVdelta = COVdelta + gamma1[1] * ( var( postj.rows(s+1-adaptInterval, s-1) ) - COVdelta );
        cholCOVdelta = sqrt( sigma2[1] * COVdelta );
        
        adapIter[1] = adapIter[1] + 1;
      }
    }
    
    newdelta = delta + cholCOVdelta * randn();
    newlam0m = exp(XmB + exp(newdelta) * Wm);
    newlam0 = compLam0(ts, maxT, newlam0m, indlam0, knts);
    newintLam0 = compIntLam0(maxT, newlam0m);
    
    newlam0z0 = zeros(numbackground);
    for(int i = 0; i < numbackground; i ++){
      newlam0z0[i] = newlam0[dummy_background[i]];
    }
    
    logprob = (sum(log(newlam0z0)) - sum(log(lam0z0))) - (newintLam0 - intLam0) +
      normal_logh(newdelta, 0, 100) - normal_logh(delta, 0, 100);
    
    if (log(randu()) < logprob) {
      delta = newdelta;
      lam0 = newlam0;
      intLam0 = newintLam0;
      lam0z0 = newlam0z0;
      
      accprob(s, 1) = 1;
    }
    
    postSamples(s, p) = delta;
    
    
    
    // M-H update for alpha
    shape = shape_alpha + numoffsp;
    scale = ( 1 / ( rate_alpha + sum( 1 - exp(- eta * (maxT - ts)) ) / eta ) );
    
    alpha = randg(distr_param(shape, scale));
    postSamples(s, p+1) = alpha;
    
    
    
    // M-H updates for eta
    if( updateCOV ){
      if( (s+1 >= adaptInterval) && (s+1 - (adaptInterval * trunc((s+1) / adaptInterval)) == 0) ){
        dummyaccprob = accprob.col(2);
        rhat[2] = sum( dummyaccprob.rows(s+1-adaptInterval, s-1) ) / (adaptInterval-1);
        gamma1[2] = 1 / pow(adapIter[2], c1);
        gamma2[2] = c0 * gamma1[2];
        sigma2[2] = exp( log(sigma2[2]) + gamma2[2] * (rhat[2] - ropt) );
        
        postj = postSamples.col(p+2);
        COVeta = COVeta + gamma1[2] * ( var( postj.rows(s+1-adaptInterval, s-1) ) - COVeta );
        cholCOVeta = sqrt( sigma2[2] * COVeta );
        
        adapIter[2] = adapIter[2] + 1;
      }
    }
    
    neweta = eta + cholCOVeta * randn();
    
    if( (neweta < lb_eta) || (neweta > ub_eta) ){
      logprob = negativeInf;
      
    } else {
      
      if( numoffsp == 0 ){
        logprob = - alpha * ( sum( 1 - exp(- neweta * (maxT - ts)) ) / neweta - sum( 1 - exp(- eta * (maxT - ts)) ) / eta );
        
      } else {
        logprob = - sum(tdoffsp) * (neweta - eta) -
          alpha * ( sum( 1 - exp(- neweta * (maxT - ts)) ) / neweta - sum( 1 - exp(- eta * (maxT - ts)) ) / eta );
      }
    }
    
    if (log(randu()) < logprob) {
      eta = neweta;
      
      accprob(s, 2) = 1;
    }
    postSamples(s, p+2) = eta;
    
    
    
    
    if ( (s+1) % 100 == 0 ) {
      Rprintf("Generated %d samples...\n", s+1);
    }
  }
  
  return Rcpp::List::create(Rcpp::Named("postSamples") = postSamples,
                            Rcpp::Named("postBranching") = postBranching,
                            Rcpp::Named("postWm") = postWm,
                            Rcpp::Named("Wm") = Wm,
                            Rcpp::Named("Accprob") = accprob,
                            Rcpp::Named("sigma2") = sigma2,
                            Rcpp::Named("adapIter") = adapIter,
                            Rcpp::Named("COVbeta") = COVbeta,
                            Rcpp::Named("COVdelta") = COVdelta,
                            Rcpp::Named("COVeta") = COVeta);
}




