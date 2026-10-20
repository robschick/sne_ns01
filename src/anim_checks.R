# =============================================================================
# anim_checks.R — Input and rate sanity checks for the talk animation
# =============================================================================

is_utc <- function(x) inherits(x, 'POSIXct') && identical(attr(x, 'tzone'), 'UTC')

check_inputs <- function(sites, calls, effort, fits, background) {
  shown <- fits$site
  stopifnot(
    'every fitted site has a location'   = all(shown %in% sites$site),
    'every fitted site has calls'        = all(shown %in% calls$site),
    'every fitted site has a background' = all(shown %in% background$site),
    'times are UTC POSIXct' = is_utc(calls$time_utc) && is_utc(background$time_utc) &&
                              is_utc(effort$start_utc) && is_utc(effort$end_utc),
    'eta > 0'     = all(fits$eta > 0),
    'mu > 0'      = all(background$mu > 0),
    'kernel type' = all(fits$kernel %in% c('unnormalized', 'normalized'))
  )

  # Calls outside effort: warn only, since effort blocks are trimmed for clock slack
  for (s in shown) {
    e  <- effort[effort$site == s, ]
    tc <- as.numeric(calls$time_utc[calls$site == s])
    inside <- rowSums(outer(tc, as.numeric(e$start_utc), '>=') &
                      outer(tc, as.numeric(e$end_utc), '<=')) > 0
    if (any(!inside)) message(sprintf('%s: %d of %d calls fall outside (trimmed) effort',
                                      s, sum(!inside), length(tc)))
  }

  br <- jump_size(fits) / fits$eta
  if (any(br >= 1)) warning('Branching ratio >= 1 (non-stationary) at: ',
                            paste(fits$site[br >= 1], collapse = ', '))
  invisible(TRUE)
}

# The compensator over the window should be near the observed count (it is the
# expected count given the history); a large mismatch usually means a per-min
# vs per-h slip or the wrong kernel type. Also checks the jump at each call.
# With a `poisson` column, also reports that line's integral (poisson_ratio),
# which should be near 1 by construction since it smooths the observed counts.
check_rate <- function(rate, calls, fits, t0, win_min, dt = 0.1, tol = 3) {
  out <- do.call(rbind, lapply(unique(rate$site), function(s) {
    r  <- rate[rate$site == s & rate$t_min >= 0 & rate$t_min <= win_min, ]
    tc <- mins_since(calls$time_utc[calls$site == s], t0)
    n_obs <- sum(tc >= 0 & tc <= win_min)

    f   <- fits[fits$site == s, ]
    a   <- jump_size(f)
    tin <- tc[tc > 0 & tc < win_min]
    jumps <- if (length(tin)) {
      eps <- 1e-6
      prior <- tc[tc > -1e3 & tc <= win_min]
      excite_at(tin + eps, prior, a, f$eta) - excite_at(tin - eps, prior, a, f$eta)
    } else numeric(0)
    # Calls with identical stamps jump together, so allow integer multiples of a
    jump_ok <- all(abs(jumps / a - round(jumps / a)) < 1e-3 & round(jumps / a) >= 1)

    data.frame(site = s, n_obs = n_obs, expected = sum(r$lambda / 60) * dt,
               expected_poisson = if (is.null(r$poisson)) NA else sum(r$poisson / 60) * dt,
               jump_ok = jump_ok)
  }))
  out$ratio <- out$expected / pmax(out$n_obs, 1)
  out$poisson_ratio <- out$expected_poisson / pmax(out$n_obs, 1)
  bad <- out$n_obs > 0 & (out$ratio > tol | out$ratio < 1 / tol)
  if (any(bad)) warning('Expected vs observed count off by > ', tol, 'x at: ',
                        paste(out$site[bad], collapse = ', '))
  stopifnot('lambda jumps by a_k at each call' = all(out$jump_ok))
  out
}
