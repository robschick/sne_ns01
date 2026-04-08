# =============================================================================
# load_fit.R — Load a model fit and prepare post-processing variables
#
# Source this AFTER setting `fiti` and `burn`:
#   fiti <- fiti_lgcp   # or fiti_nhpp
#   burn <- burn_lgcp   # or burn_nhpp
#   source('src/load_fit.R')
#
# Optional: set `thin` to an integer before sourcing to subsample the chain.
# Useful for local testing when memory is limited (postBranching is dropped
# automatically since no post-processing script uses it):
#   thin <- 1000   # keep 1,000 evenly-spaced draws
#   source('src/load_fit.R')
#   rm(thin)       # reset for next source()
#
# Requires: path.data, path.fit, datai, fiti, burn (from config.R)
#
# Produces:
#   data, noise          — from data RData
#   postSamples, postWm  — from fit RData (postWm only for GP models)
#   Xm, knts, rho        — from fit RData
#   p, niters, ts, maxT, m
#   model_has_gp         — TRUE for LGCPSE, FALSE for NHPPSE
#   betaInd, deltaInd (GP only), alphaInd, etaInd
# =============================================================================

load(file.path(path.data, paste0(datai, '.RData')))        # data, noise
load(file.path(path.fit,  paste0(datai, fiti, '.RData')))  # postSamples, Xm, knts, ...

# postBranching is large (niters x n_events) and unused in post-processing
if (exists('postBranching')) rm(postBranching)

p            <- ncol(Xm)
model_has_gp <- exists('postWm') && is.matrix(postWm)

betaInd  <- 1:p
if (model_has_gp) {
  deltaInd <- p + 1
  alphaInd <- p + 2
  etaInd   <- p + 3
} else {
  alphaInd <- p + 1
  etaInd   <- p + 2
}

postSamples <- postSamples[-(1:burn), ]
if (model_has_gp) postWm <- postWm[-(1:burn), ]

if (exists('thin') && !is.null(thin)) {
  idx         <- floor(seq(1, nrow(postSamples), length.out = thin))
  postSamples <- postSamples[idx, ]
  if (model_has_gp) postWm <- postWm[idx, ]
}

niters <- nrow(postSamples)

ts   <- data$ts
maxT <- ceiling(max(ts))
m    <- length(knts) - 1
