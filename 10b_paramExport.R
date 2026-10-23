# =============================================================================
# 10b_paramExport.R — Export what the parameter talk figures need from one
# buoy's LGCPSE fit (docs/talk_figures_spec.md): the background split into its
# log-scale pieces per knot, and the "quiet noise" counterfactual per day.
# The laptop scripts 14_–17_ read the result; they never load the fit.
#
# Usage:   Rscript 10b_paramExport.R --buoy=ns01     (cluster: aci_param_export.sh)
# Env:     PARAM_FIT_FILE  fit RData to read instead of path.fit (use the
#                          *.100k.RData backup while a resumed chain is running:
#                          the live file is rewritten every 1,000 iterations)
#          PARAM_BURN      burn-in override (default buoy_cfg$burn)
#          PARAM_THIN      posterior draws kept after burn-in (default 2000)
#          PARAM_QUIET_Q   noise quantile that counts as "quiet" (default 0.10)
# Output:  out/anim/<buoy>_params.rds, a list with
#   draws   per draw: beta (named), delta, alpha, eta
#   knots   per 20-min knot: ts (model minutes), x_noise (Xm noise column),
#           noise_dep (deployment-scaled noise, for the dB calibration),
#           sst_c (deg C), and median/lo/hi of each log-scale contribution:
#           intercept, noise, sst, harm (sum of harmonics), gp (delta * W)
#   quiet   x_cap (noise cap on the x_noise scale) and, per model day
#           (day 0 = Oct 1), median/lo/hi across draws of expected background
#           calls (actual, quiet), expected calls incl. answers (actual,
#           quiet; background / (1 - alpha/eta)), the contact-call gap, and the
#           whole-exchange gap = contact gap / (1 - alpha/eta)
#   season  the same four quantities summed over the window
#   meta    buoy, fit file, burn, draws kept, chain length, created
# =============================================================================

rm(list = ls()); invisible(gc())

source('src/config.R')
source('src/design.R')

fiti     <- fiti_lgcp
thin_n   <- as.integer(Sys.getenv('PARAM_THIN', 2000))
quiet_q  <- as.numeric(Sys.getenv('PARAM_QUIET_Q', 0.10))
burn     <- as.integer(Sys.getenv('PARAM_BURN', buoy_cfg$burn))
fit_file <- Sys.getenv('PARAM_FIT_FILE', file.path(path.fit, paste0(datai, fiti, '.RData')))

out_dir <- file.path(local_base, 'out', 'anim')
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
filename <- file.path(out_dir, paste0(buoy, '_params.rds'))


# =============================================================================-
# Load fit ----
# =============================================================================-

load(file.path(path.data, paste0(datai, '.RData')))   # data, noise
cat('Loading', fit_file, '\n')
load(fit_file)                                         # postSamples, postWm, Xm, knts, ...
if (exists('postBranching', inherits = FALSE)) rm(postBranching)
invisible(gc())

n_iter <- nrow(postSamples)
stopifnot(n_iter > burn)
keep <- floor(seq(burn + 1, n_iter, length.out = thin_n))
postSamples <- postSamples[keep, ]
postWm      <- postWm[keep, ]
invisible(gc())

cols <- design_columns(design_cfg())
stopifnot(ncol(Xm) == max(cols$harm, cols$sst), cols$n_spline == 0)

p     <- ncol(Xm)
beta  <- postSamples[, 1:p]
delta <- exp(postSamples[, p + 1])        # sampler stores log delta
alpha <- postSamples[, p + 2]
eta   <- postSamples[, p + 3]
br    <- alpha / eta                      # answers per call (unnormalized kernel)
stopifnot(all(br < 1))

# Harmonic columns named by period in minutes, e.g. h1440_sin, h1440_cos
colnames(beta) <- c('intercept', 'noise', 'sst',
                    paste0(rep(paste0('h', cols$periods), each = 2), c('_sin', '_cos')))


# =============================================================================-
# Covariates at the knots ----
# Same join as 02_fitLGCPSE.R: noise and SST rows whose ts equals a knot.
# =============================================================================-

idx <- match(knts, noise$ts)
noise_dep <- as.vector(noise$noise)[idx]
sst_c     <- noise$sst_val[idx]
x_noise   <- Xm[, cols$noise]
stopifnot(isTRUE(all.equal(as.vector(scale(noise_dep)), x_noise, tolerance = 1e-8)))


# =============================================================================-
# Log-scale pieces of the background, per knot ----
# log mu = intercept + noise + SST + harmonics + delta * W
# =============================================================================-

qs <- function(M) {                       # draws x knots -> knots x (med, lo, hi)
  t(apply(M, 2, quantile, probs = c(0.5, 0.025, 0.975), names = FALSE))
}

pieces <- list(
  noise = outer(beta[, 'noise'], x_noise),
  sst   = outer(beta[, 'sst'],   Xm[, cols$sst]),
  harm  = beta[, cols$harm] %*% t(Xm[, cols$harm]),
  gp    = delta * postWm
)

knots <- data.frame(ts = knts, x_noise = x_noise, noise_dep = noise_dep, sst_c = sst_c,
                    intercept = median(beta[, 'intercept']),
                    intercept_lo = quantile(beta[, 'intercept'], 0.025, names = FALSE),
                    intercept_hi = quantile(beta[, 'intercept'], 0.975, names = FALSE))
for (nm in names(pieces)) {
  q <- qs(pieces[[nm]])
  knots[[nm]] <- q[, 1]; knots[[paste0(nm, '_lo')]] <- q[, 2]; knots[[paste0(nm, '_hi')]] <- q[, 3]
}

log_mu <- beta[, 'intercept'] + Reduce(`+`, pieces)          # draws x knots
stopifnot(isTRUE(all.equal(log_mu, beta %*% t(Xm) + delta * postWm,
                           check.attributes = FALSE)))
rm(pieces); invisible(gc())


# =============================================================================-
# Quiet-noise counterfactual ----
# Cap noise at the quiet quantile: times above it come down, quieter times are
# unchanged. mu_quiet = mu * exp(beta_noise * (min(x, cap) - x)).
# Expected calls per day from the trapezoid rule on the knots (the background is
# linear between knots, as in compIntLam0()).
# =============================================================================-

x_cap <- quantile(x_noise, quiet_q, names = FALSE)
shift <- pmin(x_noise, x_cap) - x_noise                       # <= 0

mu       <- exp(log_mu)
mu_quiet <- mu * exp(outer(beta[, 'noise'], shift))
rm(log_mu); invisible(gc())

d  <- diff(knts)
wk <- c(d / 2, 0) + c(0, d / 2)                                # trapezoid weight per knot
day <- floor(knts / 1440)
day[day > max(day[knts < max(knts)])] <- max(day[knts < max(knts)])   # end knot joins the last day
A  <- matrix(0, length(knts), length(unique(day)))
A[cbind(seq_along(knts), match(day, sort(unique(day))))] <- wk

back_actual <- mu %*% A                                        # draws x days
back_quiet  <- mu_quiet %*% A
gap_contact <- back_quiet - back_actual
gap_total   <- gap_contact / (1 - br)
stopifnot(all(gap_contact >= -1e-8))

per_day <- function(M, nm) {
  q <- qs(M)
  setNames(as.data.frame(q), paste0(nm, c('', '_lo', '_hi')))
}
quiet <- list(
  x_cap = x_cap, quiet_q = quiet_q,
  daily = cbind(day = sort(unique(day)),
                per_day(back_actual, 'back_actual'), per_day(back_quiet, 'back_quiet'),
                per_day(back_actual / (1 - br), 'total_actual'),
                per_day(back_quiet / (1 - br), 'total_quiet'),
                per_day(gap_contact, 'gap_contact'), per_day(gap_total, 'gap_total'))
)

tot <- function(M) quantile(rowSums(M), c(0.5, 0.025, 0.975), names = FALSE)
season <- rbind(back_actual = tot(back_actual), back_quiet = tot(back_quiet),
                gap_contact = tot(gap_contact), gap_total = tot(gap_total),
                total_actual = tot(back_actual / (1 - br)),
                total_quiet  = tot(back_quiet  / (1 - br)))
colnames(season) <- c('med', 'lo', 'hi')
print(round(season))

# Sanity check against Stage 4 (num/): same fit, different draws and integrator
numfile <- paste0(path.num, datai, fiti, 'num.RData')
if (file.exists(numfile)) {
  load(numfile)                                                # postNum
  cat(sprintf('Background total: here %.0f, num/ %.0f (%+.1f%%)\n',
              season['back_actual', 'med'], median(postNum[, 1]),
              100 * (season['back_actual', 'med'] / median(postNum[, 1]) - 1)))
}


# =============================================================================-
# Save ----
# =============================================================================-

draws <- data.frame(beta, delta = delta, alpha = alpha, eta = eta)

saveRDS(list(draws = draws, knots = knots, quiet = quiet, season = season,
             meta = list(buoy = buoy, fiti = fiti, fit_file = fit_file, burn = burn,
                         draws = length(keep), n_iter = n_iter, created = Sys.time())),
        filename)
cat(sprintf('Wrote %s  (chain %d iterations, %d draws; noise cap at x = %.2f)\n',
            filename, n_iter, length(keep), x_cap))
