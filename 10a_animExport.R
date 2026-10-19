# =============================================================================
# 10a_animExport.R — Export what the talk animation needs from one buoy's
# LGCPSE fit, so the animation itself (10_hawkesAnim.R) runs on the laptop
# without the multi-GB fit file.
#
# Usage:   Rscript 10a_animExport.R --buoy=ns01     (cluster: aci_anim_export.sh)
# Env:     ANIM_THIN  posterior draws kept after burn-in (default 2000)
#          ANIM_DT    background grid spacing in minutes (default 5)
# Output:  out/anim/<buoy>_anim.rds, a list with
#   fit        1 row: site, alpha, eta (posterior medians, per min), their
#              2.5/97.5% quantiles, kernel = "unnormalized"
#   background site, ts (model minutes), stamp (logger clock, POSIXct "UTC"),
#              mu / mu_lo / mu_hi (calls/min; background incl. GP)
#   calls      site, i, ts, stamp, p_counter, parent (1-based, NA if none),
#              parent_prob
#   meta       buoy, fit tag, burn, draws kept, stamp shift used
#
# Stamps are on the logger clock exactly as in data/release (labelled UTC,
# treated as EST by the model; see src/config.R). 10_hawkesAnim.R applies the
# clock conversion, not this script.
# =============================================================================

rm(list = ls()); gc()
library(Rcpp); library(RcppArmadillo)

source('src/config.R')

fiti   <- fiti_lgcp
thin_n <- as.integer(Sys.getenv('ANIM_THIN', 2000))
dt     <- as.numeric(Sys.getenv('ANIM_DT', 5))
burn   <- buoy_cfg$burn

out_dir <- file.path(local_base, 'out', 'anim')
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
filename <- file.path(out_dir, paste0(buoy, '_anim.rds'))


# =============================================================================-
# Load fit ----
# Loaded directly rather than via load_fit.R, which drops postBranching.
# Thin straight after loading to release the full chains.
# =============================================================================-

load(file.path(path.data, paste0(datai, '.RData')))        # data, noise
load(file.path(path.fit,  paste0(datai, fiti, '.RData')))  # postSamples, postWm, postBranching, Xm, knts

keep <- floor(seq(burn + 1, nrow(postSamples), length.out = thin_n))
postSamples   <- postSamples[keep, ]
postWm        <- postWm[keep, ]
postBranching <- postBranching[keep, , drop = FALSE]
gc()

p     <- ncol(Xm)
beta  <- postSamples[, 1:p]
delta <- exp(postSamples[, p + 1])        # sampler stores log delta
alpha <- postSamples[, p + 2]
eta   <- postSamples[, p + 3]

ts   <- data$ts
maxT <- ceiling(max(ts))
m    <- length(knts) - 1
stopifnot(!is.unsorted(ts), ncol(postBranching) == length(ts))


# =============================================================================-
# Model minutes -> logger-clock stamps ----
# 01_data.R measures ts from buoy_cfg$deploy_time then re-zeros at std, but the
# raw RDS ts origin is the site's first upcall, which can sit up to a minute
# after deploy_time. Add that shift so stamps line up with data/release.
# =============================================================================-

call_all <- readRDS(file.path('data', buoy_cfg$call_file))
shift_s  <- as.numeric(min(call_all$start_datetime)) -
            as.numeric(as.POSIXct(buoy_cfg$deploy_time, tz = 'UTC'))
to_stamp <- function(tmin) std + tmin * 60 + shift_s


# =============================================================================-
# Background rate on a regular grid ----
# Same interpolation as compLamt(): per draw, linear between knots, then take
# quantiles across draws (type 5, which is what Armadillo's quantile() uses). Computed for all knots at once instead of calling
# compLamt() per grid point (which recomputes every knot for every t).
# =============================================================================-

lam0 <- exp(beta %*% t(Xm) + delta * postWm)             # draws x knots
grid <- seq(0, maxT, by = dt)
seg  <- maxT / m
i0   <- pmin(findInterval(grid, knts, rightmost.closed = TRUE), m)   # 1-based knot at/before t
w    <- (grid - knts[i0]) / seg

bq <- matrix(NA_real_, length(grid), 3)
for (ch in split(seq_along(grid), ceiling(seq_along(grid) / 2000))) {
  v <- lam0[, i0[ch], drop = FALSE] +
       sweep(lam0[, i0[ch] + 1, drop = FALSE] - lam0[, i0[ch], drop = FALSE], 2, w[ch], '*')
  bq[ch, ] <- t(apply(v, 2, quantile, probs = c(0.025, 0.5, 0.975), type = 5,
                   names = FALSE))
}

# Spot-check against compLamt() at three grid points (it Rprintf()s; harmless)
sourceCpp('src/RcppFtns.cpp')
for (j in round(quantile(seq_along(grid)[grid > 0 & grid < maxT], c(0.1, 0.5, 0.9)))) {
  ref <- compLamt(grid[j], ts, knts, maxT, which(knts >= grid[j])[1] - 2,
                  Xm, beta, delta, postWm, alpha, eta)$resBack
  stopifnot(isTRUE(all.equal(as.vector(ref), bq[j, ], tolerance = 1e-4)))
}
cat('Background matches compLamt() at 3 spot checks\n')

background <- data.frame(site = toupper(buoy), ts = grid, stamp = to_stamp(grid),
                         mu = bq[, 2], mu_lo = bq[, 1], mu_hi = bq[, 3])
rm(lam0); gc()


# =============================================================================-
# Branching: P(countercall) and modal parent per call ----
# postBranching[, i] == 0 -> background (contact) call; j > 0 -> parent is call j.
# =============================================================================-

n <- length(ts)
modal <- vapply(seq_len(n), function(i) {
  b <- postBranching[, i]; b <- b[b > 0]
  if (!length(b)) return(c(NA_real_, 0))
  tb <- tabulate(b, nbins = n)
  k  <- which.max(tb)
  c(k, tb[k] / nrow(postBranching))
}, numeric(2))

calls <- data.frame(site = toupper(buoy), i = seq_len(n), ts = ts,
                    stamp = to_stamp(ts),
                    p_counter = colMeans(postBranching > 0),
                    parent = modal[1, ], parent_prob = modal[2, ])


# =============================================================================-
# Parameters ----
# Kernel is alpha * exp(-eta * lag) (comph() in RcppFtns.cpp): unnormalized.
# =============================================================================-

q <- function(x) quantile(x, c(0.5, 0.025, 0.975), names = FALSE)
fit <- data.frame(site = toupper(buoy),
                  alpha = q(alpha)[1], alpha_lo = q(alpha)[2], alpha_hi = q(alpha)[3],
                  eta   = q(eta)[1],   eta_lo   = q(eta)[2],   eta_hi   = q(eta)[3],
                  kernel = 'unnormalized')

saveRDS(list(fit = fit, background = background, calls = calls,
             meta = list(buoy = buoy, fiti = fiti, burn = burn, draws = length(keep),
                         dt = dt, shift_s = shift_s, created = Sys.time())),
        filename)
cat(sprintf('Wrote %s  (alpha = %.3g /min, eta = %.3g /min, mean P(counter) = %.2f)\n',
            filename, fit$alpha, fit$eta, mean(calls$p_counter)))
