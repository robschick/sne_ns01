# =============================================================================
# load_fit.R — Load an LGCPSE fit and prepare post-processing variables
#
# Source this AFTER setting `fiti`:
#   fiti <- fiti_lgcp
#   source('src/load_fit.R')
#
# Burn-in is read from buoy_cfg$burn (set in config.R). Override per-call by
# setting `burn` before sourcing if you need a one-off value.
#
# Optional: set `thin` to an integer before sourcing to subsample the chain.
# Useful for local testing when memory is limited (postBranching is dropped
# automatically since no post-processing script uses it):
#   thin <- 1000   # keep 1,000 evenly-spaced draws
#   source('src/load_fit.R')
#   rm(thin)       # reset for next source()
#
# Requires: path.data, path.fit, datai, fiti, buoy_cfg (from config.R)
#
# Produces:
#   data, noise                          — from data RData
#   postSamples, postWm                  — from fit RData
#   Xm, knts, rho                        — from fit RData
#   p, niters, ts, maxT, m
#   betaInd, deltaInd, alphaInd, etaInd
# =============================================================================

# All `exists()` checks use inherits=FALSE so they see only the sourcing
# environment — otherwise `coda::thin`, for example, would satisfy
# exists('thin') and trip the subsampling branch below.
if (!exists('burn', inherits = FALSE) || is.null(burn)) burn <- buoy_cfg$burn

load(file.path(path.data, paste0(datai, '.RData')))        # data, noise
load(file.path(path.fit,  paste0(datai, fiti, '.RData')))  # postSamples, Xm, knts, ...

# postBranching is large (niters x n_events) and unused in post-processing
if (exists('postBranching', inherits = FALSE)) rm(postBranching)

p        <- ncol(Xm)
betaInd  <- 1:p
deltaInd <- p + 1
alphaInd <- p + 2
etaInd   <- p + 3

postSamples <- postSamples[-(1:burn), ]
postWm      <- postWm[-(1:burn), ]

if (exists('thin', inherits = FALSE) && !is.null(thin)) {
  idx         <- floor(seq(1, nrow(postSamples), length.out = thin))
  postSamples <- postSamples[idx, ]
  postWm      <- postWm[idx, ]
}

niters <- nrow(postSamples)

ts   <- data$ts
maxT <- ceiling(max(ts))
m    <- length(knts) - 1
