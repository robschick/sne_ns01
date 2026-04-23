# =============================================================================
# benchmark_fit.R — GP resolution benchmarking driver
#
# Usage:
#   Phase 1 (timing only, ~1000 iterations):
#     Rscript src/benchmark_fit.R --combo=3
#
#   Phase 2 (full MCMC chain):
#     Rscript src/benchmark_fit.R --combo=3 --full
#
#   Laptop mode (temporal subset):
#     Rscript src/benchmark_fit.R --combo=3 --months=1
#     Rscript src/benchmark_fit.R --combo=3 --months=3 --full
#
# Combo IDs (from benchmark_config.R):
#   1: rho=60, sback=30    5: rho=30, sback=15
#   2: rho=60, sback=60    6: rho=30, sback=30
#   3: rho=60, sback=120   7: rho=30, sback=60
#   4: rho=60, sback=180   8: rho=30, sback=90
# =============================================================================

rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(foreach)

source('src/benchmark_config.R')

path.cpp <- 'src/RcppFtns.cpp'
sourceCpp(path.cpp)


# =============================================================================-
# Load data ----
# =============================================================================-

load(paste0(path.data, datai, '.RData'))

# Subset to analysis window (applies --months truncation if set)
maxT_window <- as.numeric(difftime(analysis_end, std, units = "mins"))

ts  <- data$ts[data$ts <= maxT_window]
maxT <- ceiling(max(ts))

# Filter noise to match
noise <- noise[noise$ts <= maxT_window, ]

cat(sprintf("Data: %d events, maxT = %.0f min (%.1f days)\n",
            length(ts), maxT, maxT / (24 * 60)))


# =============================================================================-
# Set up GP grid from benchmark combo ----
# =============================================================================-

rho   <- bench_rho
sback <- bench_sback
knts  <- unique(c(0, seq(0, maxT, by = sback), maxT))
m     <- length(knts) - 1

cat(sprintf("Grid: sback=%d min, rho=%d min, m=%d knots\n", sback, rho, m))


# =============================================================================-
# Covariates ----
# =============================================================================-

# Noise + SST at knot locations
noise_knts <- data.frame(ts = knts) %>%
  left_join(noise)
noiseVar <- as.vector(scale(noise_knts$noise))
sstVar   <- as.vector(noise_knts$sst)

# Harmonic columns: one sin + one cos per period in harm_periods_bench
harm_cols <- do.call(cbind, lapply(harm_periods_bench, function(p) {
  cbind(
    sin(2 * pi * (knts + harm_start_time) / p),
    cos(2 * pi * (knts + harm_start_time) / p)
  )
}))
Xm <- cbind(1, noiseVar, sstVar, harm_cols)
p  <- ncol(Xm)

cat(sprintf("Design matrix: %d knots x %d columns (%d harmonics)\n",
            nrow(Xm), p, length(harm_periods_bench)))


# =============================================================================-
# Initial values ----
# =============================================================================-

beta  <- rnorm(p)
delta <- log(1)
alpha <- 1
eta   <- 1


# =============================================================================-
# GP covariance matrix ----
# =============================================================================-

cat("Computing covariance matrix... ")
ptm_cov <- proc.time()[3]

tdiffm <- matrix(0, m + 1, m + 1)
for (i in 1:(m + 1)) {
  for (j in 1:i) {
    tdiffm[i, j] <- tdiffm[j, i] <- abs(knts[i] - knts[j])
  }
}
Sigmam     <- exp(-tdiffm / rho)
invSigmam  <- solve(Sigmam)
cholSigmam <- chol(Sigmam)

time_cov <- proc.time()[3] - ptm_cov
cat(sprintf("done (%.1f sec)\n", time_cov))

Wm   <- t(cholSigmam) %*% rnorm(m + 1)
lam0m <- as.vector(exp(Xm %*% beta + exp(delta) * Wm))


# =============================================================================-
# Approximation indices ----
# =============================================================================-

n       <- length(ts)
indlam0 <- sapply(1:n, function(i) which(knts >= ts[i])[1] - 1 - 1)
lam0    <- compLam0(ts, maxT, lam0m, indlam0, knts)
intLam0 <- compIntLam0(maxT, lam0m)


# =============================================================================-
# MCMC setup ----
# =============================================================================-

betaInd  <- 1:p
deltaInd <- p + 1
alphaInd <- p + 2
etaInd   <- p + 3

sigma2   <- sigma2_init
adapIter <- rep(1, 3)
COVbeta  <- diag(p)
COVdelta <- 1
COVeta   <- 1

lb_eta <- lb_eta_days
ub_eta <- 3 / min(diff(ts))

updateCOV <- TRUE


# =============================================================================-
# Phase 1: Timing characterization ----
# =============================================================================-

cat(sprintf("\n=== Phase 1: Timing (%d iterations) ===\n", bench_phase1_iters))

sourceCpp(path.cpp)

ptm_phase1 <- proc.time()[3]

dummy <- fitLGCPSE(
  bench_phase1_iters, ts, Xm, maxT, knts, tdiffm, beta, delta, rho,
  alpha, eta, Wm, indlam0, shape_alpha, rate_alpha, lb_eta,
  ub_eta, sigma2, COVbeta, COVdelta, COVeta, updateCOV, adaptInterval,
  adaptFactorExponent, adapIter)

time_phase1 <- proc.time()[3] - ptm_phase1

time_per_iter   <- time_phase1 / bench_phase1_iters
iters_per_hour  <- 3600 / time_per_iter
iters_per_day   <- iters_per_hour * 24
iters_in_3_days <- iters_per_day * 3
iters_in_5_days <- iters_per_day * 5

phase1_results <- list(
  combo_id        = bench_combo_id,
  rho             = rho,
  sback           = sback,
  m               = m,
  n_events        = n,
  p_covariates    = p,
  phase1_iters    = bench_phase1_iters,
  time_total_sec  = time_phase1,
  time_per_iter   = time_per_iter,
  time_cov_matrix = time_cov,
  iters_per_hour  = iters_per_hour,
  iters_in_3_days = iters_in_3_days,
  iters_in_5_days = iters_in_5_days,
  subset_months   = bench_subset_months,
  label           = bench_label
)

cat(sprintf("\nPhase 1 results:\n"))
cat(sprintf("  Total time:        %.1f sec\n", time_phase1))
cat(sprintf("  Time/iteration:    %.4f sec\n", time_per_iter))
cat(sprintf("  Cov matrix setup:  %.1f sec\n", time_cov))
cat(sprintf("  Iterations/hour:   %.0f\n", iters_per_hour))
cat(sprintf("  Iterations/day:    %.0f\n", iters_per_day))
cat(sprintf("  Iterations in 3d:  %.0f\n", iters_in_3_days))
cat(sprintf("  Iterations in 5d:  %.0f\n", iters_in_5_days))

save(phase1_results,
     file = file.path(bench_path_fit, 'phase1_timing.RData'))
cat(sprintf("\nPhase 1 saved to %s\n", bench_path_fit))

# Update state from Phase 1 for potential Phase 2 continuation
nSamples <- nrow(dummy$postSamples)
beta     <- dummy$postSamples[nSamples, betaInd]
delta    <- dummy$postSamples[nSamples, deltaInd]
alpha    <- dummy$postSamples[nSamples, alphaInd]
eta      <- dummy$postSamples[nSamples, etaInd]
sigma2   <- dummy$sigma2
adapIter <- dummy$adapIter
Wm       <- dummy$Wm
COVbeta  <- dummy$COVbeta
COVdelta <- dummy$COVdelta
COVeta   <- dummy$COVeta


# =============================================================================-
# Phase 2: Full MCMC chain (optional) ----
# =============================================================================-

if (!bench_full_run) {
  cat("\nPhase 1 complete. Use --full to run Phase 2.\n")
  quit(save = "no")
}

# Iteration count: use --niters=N if provided, otherwise auto-calculate
# from a 3-day wall-clock budget. Floor to nearest 1000 (checkpoint interval).
if (!is.null(bench_niters_override)) {
  niters <- bench_niters_override
} else {
  budget_seconds <- 3 * 24 * 3600
  niters <- floor((budget_seconds / time_per_iter) / 1000) * 1000
  niters <- max(niters, 10000)
}

cat(sprintf("\n=== Phase 2: Full chain (%d iterations, ~%.1f days) ===\n",
            niters, (niters * time_per_iter) / (24 * 3600)))

# Checkpoint loop: save every 1000 iterations (same as 02_fitLGCPSE.R)
outers <- c(0, seq(1000, niters, by = 1000))

# Accumulate from Phase 1 results
postSamples   <- dummy$postSamples
postBranching <- dummy$postBranching
postWm        <- dummy$postWm
Accprob       <- colMeans(dummy$Accprob)

start <- 1
rtime <- time_phase1

filename <- file.path(bench_path_fit, 'phase2_fit.RData')

for (i in (start + 1):length(outers)) {
  outeri <- outers[i] - outers[i - 1]

  ptm <- proc.time()[3]
  dummy <- fitLGCPSE(
    outeri, ts, Xm, maxT, knts, tdiffm, beta, delta, rho,
    alpha, eta, Wm, indlam0, shape_alpha, rate_alpha, lb_eta,
    ub_eta, sigma2, COVbeta, COVdelta, COVeta, updateCOV, adaptInterval,
    adaptFactorExponent, adapIter)
  rtime <- rtime + proc.time()[3] - ptm

  postSamples   <- rbind(postSamples, dummy$postSamples)
  postBranching <- rbind(postBranching, dummy$postBranching)
  postWm        <- rbind(postWm, dummy$postWm)
  Accprob       <- (Accprob * outers[i - 1] + colSums(dummy$Accprob)) / outers[i]

  nSamples <- nrow(postSamples)
  beta     <- postSamples[nSamples, betaInd]
  delta    <- postSamples[nSamples, deltaInd]
  alpha    <- postSamples[nSamples, alphaInd]
  eta      <- postSamples[nSamples, etaInd]

  sigma2   <- dummy$sigma2
  adapIter <- dummy$adapIter
  Wm       <- dummy$Wm
  COVbeta  <- dummy$COVbeta
  COVdelta <- dummy$COVdelta
  COVeta   <- dummy$COVeta

  save(rtime, phase1_results,
       postSamples, postBranching, postWm, Accprob,
       beta, delta, alpha, eta,
       lb_eta, ub_eta, shape_alpha, rate_alpha,
       sigma2, adapIter, Wm, COVbeta, COVdelta, COVeta,
       updateCOV, adaptInterval, adaptFactorExponent,
       sback, knts, rho, Xm,
       file = filename)

  elapsed_hrs <- rtime / 3600
  total_iters <- nrow(postSamples)
  cat(sprintf("  Checkpoint: %d/%d iters, %.1f hrs elapsed, Acc=[%.3f, %.3f, %.3f]\n",
              total_iters, niters + bench_phase1_iters, elapsed_hrs,
              Accprob[1], Accprob[2], Accprob[3]))
}

cat(sprintf("\nPhase 2 complete. Total time: %.1f hrs\n", rtime / 3600))
cat(sprintf("Total iterations: %d (Phase 1: %d + Phase 2: %d)\n",
            nrow(postSamples), bench_phase1_iters, niters))
cat(sprintf("Saved to %s\n", filename))
