# =============================================================================
# anim_rate.R — Per-site conditional intensity on a fine grid
#
#   lambda_k(t) = mu_k(t) + sum_{t_i < t at site k} a_k * exp(-eta_k * (t - t_i))
#
# with a_k = alpha (unnormalized kernel) or alpha * eta (normalized). Times are
# minutes relative to t0; rates are calls/min internally, calls/h on output.
# =============================================================================

jump_size <- function(fit) {
  ifelse(fit$kernel == 'normalized', fit$alpha * fit$eta, fit$alpha)
}

# Excitation at times `t` (min) from earlier calls at `tc` (min); calls/min
excite_at <- function(t, tc, a, eta) {
  if (!length(tc)) return(numeric(length(t)))
  lag <- outer(t, tc, '-')
  rowSums(ifelse(lag > 0, a * exp(-eta * pmax(lag, 0)), 0))
}

mins_since <- function(x, t0) as.numeric(difftime(x, t0, units = 'mins'))

rate_grid <- function(calls, background, fits, t0, win_min, burn_min = 60, dt = 0.1,
                      sites = NULL) {
  if (is.null(sites)) sites <- fits$site
  tg <- seq(-burn_min, win_min, by = dt)
  do.call(rbind, lapply(sites, function(s) {
    f  <- fits[fits$site == s, ]
    b  <- background[background$site == s, ]
    mu <- approx(mins_since(b$time_utc, t0), b$mu, tg, rule = 1)$y
    if (anyNA(mu)) stop('Background for ', s, ' does not cover the window')
    tc <- mins_since(calls$time_utc[calls$site == s], t0)
    tc <- tc[tc > -burn_min - 10 / f$eta & tc <= win_min]   # older calls have decayed
    ex <- excite_at(tg, tc, jump_size(f), f$eta)
    data.frame(site = s, t_min = tg, time_utc = t0 + tg * 60,
               mu = 60 * mu, excite = 60 * ex, lambda = 60 * (mu + ex))
  }))
}

# Backup-slide table: per-site half-life, responses per call, calls in the
# window, and the model's countercall share (mean posterior P(countercall))
# over the whole fit and within the window.
site_summary <- function(fits, calls, t0, win_min, branching = NULL) {
  out <- data.frame(site = fits$site,
                    half_life_min = log(2) / fits$eta,
                    responses_per_call = jump_size(fits) / fits$eta)
  out$n_calls_window <- vapply(out$site, function(s) {
    tc <- mins_since(calls$time_utc[calls$site == s], t0)
    sum(tc >= 0 & tc <= win_min)
  }, numeric(1))
  if (!is.null(branching)) {
    out$counter_share_fit <- vapply(out$site, function(s)
      mean(branching$p_counter[branching$site == s]), numeric(1))
    out$counter_share_window <- vapply(out$site, function(s) {
      b <- branching[branching$site == s, ]
      tb <- mins_since(b$time_utc, t0)
      mean(b$p_counter[tb >= 0 & tb <= win_min])
    }, numeric(1))
  }
  out
}


# ── Poisson stand-in ───────────────────────────────────────────────────────
# A STAND-IN, NOT A FITTED MODEL: the observed per-minute counts smoothed with a
# Gaussian kernel (sd 60 min, about the GP scale), so one smooth rate carries
# every call and nothing answers anything. A fitted LGCP with no
# self-excitation (plan option 4) would replace it.

# Smoothed per-minute rate (calls/min) at minute midpoints from..to-1 (minutes
# on the scale of `tc`). Calls within 4 sd outside the range are counted, so
# the edges aren't biased low.
smooth_rate <- function(tc, from, to, sd_min = 60) {
  half  <- ceiling(4 * sd_min)
  edges <- seq(floor(from) - half, ceiling(to) + half)
  n     <- tabulate(findInterval(tc, edges, left.open = FALSE), length(edges) - 1)
  k     <- dnorm(-half:half, sd = sd_min); k <- k / sum(k)
  sm    <- stats::filter(n, k, sides = 2)
  keep  <- seq(half + 1, length(n) - half)
  data.frame(t_min = edges[keep] + 0.5, rate = as.numeric(sm[keep]))
}

# Per-site Poisson rate (calls/h) on the rate_grid() time grid
poisson_rate <- function(calls, t0, win_min, burn_min = 60, dt = 0.1, sd_min = 60,
                         sites = unique(calls$site)) {
  tg <- seq(-burn_min, win_min, by = dt)
  do.call(rbind, lapply(sites, function(s) {
    sm <- smooth_rate(mins_since(calls$time_utc[calls$site == s], t0),
                      -burn_min - 1, win_min + 1, sd_min)
    data.frame(site = s, t_min = tg, poisson = 60 * approx(sm$t_min, sm$rate, tg)$y)
  }))
}

# One Poisson call set from a per-minute rate (smooth_rate() output): a Poisson
# count per minute bin, placed uniformly within the bin. Returns sorted minutes.
sim_poisson <- function(sm, seed = 1) {
  set.seed(seed)
  n <- rpois(nrow(sm), sm$rate)
  sort(rep(sm$t_min - 0.5, n) + runif(sum(n)))
}

# Seed in `seeds` whose simulated total is closest to `n_target` (first wins ties)
pick_poisson_seed <- function(sm, n_target, seeds = 1:200) {
  d <- vapply(seeds, function(s) abs(length(sim_poisson(sm, s)) - n_target), numeric(1))
  seeds[which.min(d)]
}
