# =============================================================================
# design.R — Single owner of the LGCPSE background design matrix Xm.
#
# build_design_matrix() assembles the fixed-effect design at the integration
# knots: intercept, noise/sst covariates, and one sin + one cos harmonic column
# per period. It is sourced by the fit and prototype scripts so the design lives
# in exactly one place and cannot drift between them.
#
# Phase 1 (this file): no-op extraction. With the default config the builder
# reproduces the historical inline construction byte-for-byte — intercept +
# noise + sst + all harmonics in `harm_periods` (13 columns on COX01).
#
# Phase 2 will extend this function (behind a config toggle) to drop the 2-month
# harmonic and append a natural-spline seasonal basis; the seam is here so that
# change touches only this file.
# =============================================================================

# Assemble Xm from covariate vectors aligned to `knts`.
#
#   knts     numeric segment knots (minutes since std)
#   noiseVar covariate vector at knts (already scaled/joined by the caller)
#   sstVar   covariate vector at knts
#   cfg      list with:
#              harm_periods    numeric vector of harmonic periods (minutes)
#              harm_start_time  harmonic phase anchor (minutes)
#
# Returns the design matrix Xm (nrow = length(knts)).
build_design_matrix <- function(knts, noiseVar, sstVar, cfg) {
  # One sin + one cos column per harmonic period. Column order matches the
  # historical inline block in 02_fitLGCPSE.R exactly.
  harm_cols <- do.call(cbind, lapply(cfg$harm_periods, function(p) {
    cbind(
      sin(2 * pi * (knts + cfg$harm_start_time) / p),
      cos(2 * pi * (knts + cfg$harm_start_time) / p)
    )
  }))

  Xm <- cbind(1, noiseVar, sstVar, harm_cols)
  Xm
}
