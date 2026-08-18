# =============================================================================
# proto_fit_spline.R — Phase-1 PROTOTYPE (mechanics check, NOT a real fit).
#
# Goal: confirm that adding a natural-spline basis in time to Xm (a) runs through
# the existing Rcpp sampler with zero C++ changes, and (b) lets the background
# intensity bend DOWN through the spring seasonal silence that the harmonics +
# short GP structurally cannot represent.
#
# Deliberate shortcuts (this is a plumbing check, the chains are NOT converged):
#   * sback coarsened 20 -> 120 min  (~13.6k knots -> ~2.3k) so setup + a short
#     MCMC run in minutes. GP constraints still hold: eff. range 180 in (120,1440).
#   * short MCMC (NITER below), single adaptive block.
#
# Run from the REPO ROOT:  BUOY=cox01 Rscript proto_spline/proto_fit_spline.R
# =============================================================================

rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(splines)

source('src/config.R')            # buoy=cox01 via BUOY env; harmonics, priors, etc.
sourceCpp('src/RcppFtns.cpp')

stopifnot(buoy == 'cox01')
load(paste0(path.data, datai, '.RData'))   # data, noise  (7-month window)

# ---- prototype knobs --------------------------------------------------------
SBACK     <- 120     # coarse segments for a fast mechanics check (real fit: 20)
SPLINE_DF <- 6       # natural-spline degrees of freedom for the seasonal term
NITER     <- 1500    # short; illustrative posterior mean only
outdir    <- 'proto_spline'
set.seed(1)

# ---- setup: mirrors 02_fitLGCPSE.R exactly, except SBACK ---------------------
ts   <- data$ts
maxT <- ceiling(max(ts))
rho  <- rho_lgcp

knts <- unique(c(0, seq(0, maxT, by = SBACK), maxT))
m    <- length(knts) - 1

noise_j  <- data.frame(ts = knts) %>% left_join(noise, by = 'ts')
noiseVar <- as.vector(scale(noise_j$noise))
sstVar   <- as.vector(noise_j$sst)
# guard: the trailing maxT knot may miss the noise grid -> NA. Fill neutrally.
noiseVar[is.na(noiseVar)] <- 0
sstVar[is.na(sstVar)]     <- median(sstVar, na.rm = TRUE)

harm_cols <- do.call(cbind, lapply(harm_periods_lgcp, function(p) {
  cbind(sin(2 * pi * (knts + harm_start_time) / p),
        cos(2 * pi * (knts + harm_start_time) / p))
}))

# The ONLY structural change: a natural-spline basis in time as extra columns.
spline_cols <- ns(knts, df = SPLINE_DF)

Xm_base <- cbind(1, noiseVar, sstVar, harm_cols)                 # existing model
Xm_spl  <- cbind(1, noiseVar, sstVar, harm_cols, spline_cols)    # + seasonal spline

# ---- one short fit; returns posterior-mean background over knts -------------
run_fit <- function(Xm, label) {
  p <- ncol(Xm)
  beta  <- rnorm(p); delta <- log(1); alpha <- 1; eta <- 1

  tdiffm <- as.matrix(dist(knts, diag = TRUE, upper = TRUE))
  Sigmam <- exp(-tdiffm / rho)
  Wm     <- t(chol(Sigmam)) %*% rnorm(m + 1)

  indlam0 <- sapply(1:length(ts), function(i) which(knts >= ts[i])[1] - 2)

  cat(sprintf('[%s] p=%d cols, m=%d knots — starting %d iters...\n',
              label, p, m, NITER))
  t0 <- proc.time()[3]
  fit <- fitLGCPSE(NITER, ts, Xm, maxT, knts, tdiffm, beta, delta, rho,
                   alpha, eta, Wm, indlam0, shape_alpha, rate_alpha,
                   lb_eta_days, 3 / min(diff(ts)), sigma2_init,
                   diag(p), 1, 1, TRUE, adaptInterval,
                   adaptFactorExponent, rep(1, 3))
  cat(sprintf('[%s] done in %.1f s\n', label, proc.time()[3] - t0))

  keep    <- (floor(NITER / 2) + 1):NITER          # illustrative "burn-in"
  betaMat <- fit$postSamples[keep, 1:p, drop = FALSE]
  deltaV  <- fit$postSamples[keep, p + 1]
  WmMat   <- fit$postWm[keep, , drop = FALSE]

  lam0m <- sapply(seq_along(keep), function(k)
    exp(Xm %*% betaMat[k, ] + exp(deltaV[k]) * WmMat[k, ]))
  data.frame(when = as.POSIXct(std) + knts * 60,
             lam0 = rowMeans(lam0m),
             model = label)
}

res <- bind_rows(run_fit(Xm_base, 'harmonics + GP (current)'),
                 run_fit(Xm_spl,  'harmonics + GP + seasonal spline'))

# ---- diagnostic figure ------------------------------------------------------
ev <- data.frame(when = as.POSIXct(std) + ts * 60)
p <- ggplot(res, aes(when, lam0, colour = model)) +
  geom_line(linewidth = 0.7) +
  geom_rug(data = ev, aes(when), inherit.aes = FALSE,
           alpha = 0.15, length = grid::unit(0.02, 'npc')) +
  scale_y_log10() +
  labs(title = 'Phase-1 prototype: can the background bend down in spring?',
       subtitle = sprintf('cox01, sback=%d, df=%d, %d iters (NOT converged) — rug = call times',
                          SBACK, SPLINE_DF, NITER),
       x = NULL, y = 'posterior-mean background intensity (log scale)',
       colour = NULL) +
  theme_bw() + theme(legend.position = 'top')

ggsave(file.path(outdir, 'proto_background_curves.pdf'), p, width = 9, height = 4.5)
write_csv(res, file.path(outdir, 'proto_background_curves.csv'))
cat(sprintf('\nWrote %s/proto_background_curves.{pdf,csv}\n', outdir))
