# =============================================================================
# design.R — Single owner of the LGCPSE background design matrix Xm.
#
# build_design_matrix() assembles the fixed-effect design at the integration
# knots: intercept, noise/sst covariates, one sin + one cos harmonic column per
# period, and — when the seasonal spline is ON — a natural-spline basis in time
# (with the 2-month harmonic conditionally dropped). It is sourced by the fit and
# prototype scripts so the design lives in exactly one place and cannot drift.
#
# Spline OFF (default): reproduces the historical inline construction byte-for-
# byte — intercept + noise + sst + all harmonics in `harm_periods` (13 columns on
# COX01), tag 'LGCPSE'.
#
# Spline ON: drops `drop_period` (the 2-month harmonic) and appends the spline
# block, so the spline owns all sub-seasonal structure; tag becomes 'LGCPSEspl'
# (set in config.R). The Rcpp sampler is untouched — it sizes off ncol(Xm).
# =============================================================================

# Bridge config.R globals into the cfg list build_design_matrix() expects.
# Pass named overrides to vary a single knob (e.g. the GLM probe forces the
# spline on to compare designs): design_cfg(seasonal_spline = TRUE).
design_cfg <- function(...) {
  base <- list(
    harm_periods    = harm_periods_lgcp,
    harm_start_time = harm_start_time,
    seasonal_spline = seasonal_spline,
    spline_df       = seasonal_spline_df,
    spline_method   = seasonal_spline_method,
    spline_boundary = seasonal_spline_boundary,
    drop_period     = seasonal_spline_drop_period
  )
  modifyList(base, list(...))
}

# Natural-spline seasonal basis in time, evaluated at `knts`. Boundary knots are
# fixed (default = range of the grid) so the basis is reproducible rather than
# drifting with the data. 'pspline' is the Phase-4 fallback and errors until then.
build_seasonal_spline <- function(knts, cfg) {
  method <- if (is.null(cfg$spline_method)) 'ns' else cfg$spline_method
  if (!identical(method, 'ns')) {
    stop(sprintf(
      "seasonal_spline_method '%s' is not implemented until Phase 4; use 'ns'.",
      method))
  }
  bknots <- if (is.null(cfg$spline_boundary)) range(knts) else cfg$spline_boundary
  # Strip the "ns"/"basis" class so cbind returns a plain numeric matrix; the fit
  # only needs the basis values (lam0m is evaluated on this same knt grid).
  unclass(splines::ns(knts, df = cfg$spline_df, Boundary.knots = bknots))
}

# Column-index groups of an Xm built by build_design_matrix(), in build order.
# Single source of truth for post-processing scripts that need to slice Xm by
# component — the harmonic-only background series, or per-coefficient labels —
# without re-deriving the conditional 2-month drop or the spline column count.
#
#   $intercept  1
#   $noise      2
#   $sst        3
#   $harm       harmonic sin/cos columns (2 per retained period; drops the
#               2-month harmonic when the spline is ON, mirroring build_*)
#   $spline     seasonal-spline columns (integer(0) when the spline is OFF)
#   $periods    the harmonic periods actually in the design (post-drop), in
#               build order — feed to fmt_period() for labels
#
# `cfg` is the design_cfg() list. Column indices are derived from cfg alone, so
# this stays in lockstep with build_design_matrix() by construction.
design_columns <- function(cfg) {
  periods <- cfg$harm_periods
  if (isTRUE(cfg$seasonal_spline) && !is.null(cfg$drop_period)) {
    periods <- periods[periods != cfg$drop_period]
  }
  n_harm   <- 2L * length(periods)
  harm     <- if (n_harm)   3L + seq_len(n_harm)             else integer(0)
  n_spline <- if (isTRUE(cfg$seasonal_spline)) as.integer(cfg$spline_df) else 0L
  spline   <- if (n_spline) 3L + n_harm + seq_len(n_spline)  else integer(0)
  list(
    intercept = 1L, noise = 2L, sst = 3L,
    harm = harm, spline = spline,
    periods = periods, n_spline = n_spline
  )
}

# Assemble Xm from covariate vectors aligned to `knts`.
#
#   knts     numeric segment knots (minutes since std)
#   noiseVar covariate vector at knts (already scaled/joined by the caller)
#   sstVar   covariate vector at knts
#   cfg      list from design_cfg(): harm_periods, harm_start_time,
#            seasonal_spline, spline_df, spline_method, spline_boundary,
#            drop_period
#
# Returns the design matrix Xm (nrow = length(knts)).
build_design_matrix <- function(knts, noiseVar, sstVar, cfg) {
  periods <- cfg$harm_periods

  # When the seasonal spline owns sub-seasonal structure, drop the 2-month
  # harmonic so it doesn't compete with / alias the spline.
  if (isTRUE(cfg$seasonal_spline) && !is.null(cfg$drop_period)) {
    periods <- periods[periods != cfg$drop_period]
  }

  # One sin + one cos column per remaining harmonic period. Column order matches
  # the historical inline block in 02_fitLGCPSE.R exactly.
  harm_cols <- do.call(cbind, lapply(periods, function(p) {
    cbind(
      sin(2 * pi * (knts + cfg$harm_start_time) / p),
      cos(2 * pi * (knts + cfg$harm_start_time) / p)
    )
  }))

  Xm <- cbind(1, noiseVar, sstVar, harm_cols)

  if (isTRUE(cfg$seasonal_spline)) {
    Xm <- cbind(Xm, build_seasonal_spline(knts, cfg))
  }

  Xm
}
