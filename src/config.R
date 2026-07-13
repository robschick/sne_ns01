# =============================================================================
# config.R — Single source of truth for all model constants
#
# Source this file at the top of every script:
#   source('src/config.R')
#
# Buoy selection: set via --buoy=ns01 on the command line, or defaults to 'ns01'.
# =============================================================================


# ── Buoy selection ───────────────────────────────────────────────────────────
# Resolve from command-line arg, environment variable, or default.
resolve_buoy <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  for (i in seq_along(args)) {
    if (grepl("^--buoy=", args[i])) {
      return(tolower(sub("^--buoy=", "", args[i])))
    } else if (args[i] == "--buoy" && i < length(args)) {
      return(tolower(args[i + 1]))
    }
  }
  buoy_env <- Sys.getenv("BUOY", unset = NA)
  if (!is.na(buoy_env)) return(tolower(buoy_env))
  return("ns01")
}

buoy <- resolve_buoy()
stopifnot(buoy %in% c("ns01", "ns02", "cox01"))
cat(sprintf("Buoy: %s\n", buoy))


# ── Buoy-specific settings ──────────────────────────────────────────────────
# Raw data files and deployment origins differ per buoy.
# Everything else (analysis window, priors, MCMC settings) is shared.

buoy_settings <- list(
  ns01 = list(
    call_file   = "ns_01_all.rds",
    noise_file  = "ns01_rms_data.rds",
    sst_col     = "NS01",
    deploy_time = "2021-03-18 06:27:00",
    burn        = 50000
  ),
  ns02 = list(
    call_file   = "ns_02_all.rds",
    noise_file  = "ns02_rms_data.rds",
    sst_col     = "NS02",
    deploy_time = "2021-03-10 17:29:00",
    burn        = 50000
  ),
  cox01 = list(
    call_file   = "cox_01_all.rds",
    noise_file  = "cox01_rms_data.rds",
    sst_col     = "COX01",
    deploy_time = "2021-02-26 21:03:00",
    burn        = 50000
  )
)

buoy_cfg <- buoy_settings[[buoy]]


# ── Analysis window ───────────────────────────────────────────────────────────
# Standardized across all buoys: Oct 1 2021 – Apr 30 2022.
# ts = 0 at std, ts in minutes.
# Note: timestamps are labeled UTC but are actually EST.
std_str       <- '2021-10-01 00:00:00'
std           <- as.POSIXct(std_str, tz = 'UTC')
# ~7-month analysis window (Oct 1 → Apr 30). Raw call data extends to
# late-April 2022 for NS01/NS02 and mid-May 2022 for COX01, so this cut
# is at the NS01/NS02 data limit (shared window across all three buoys).
analysis_end  <- as.POSIXct('2022-04-30 00:00:00', tz = 'UTC')

# Harmonic anchor: minutes elapsed since midnight on the start date.
# Derived from std so it stays in sync — 0 min for a midnight origin.
harm_start_time <- as.numeric(format(std, '%H')) * 60 +
                   as.numeric(format(std, '%M'))
harm_day_unit   <- 1  * 24 * 60    # 1,440 min per day
harm_week_unit  <- 7  * 24 * 60    # 10,080 min per week
harm_month_unit <- 30 * 24 * 60    # 43,200 min per "month"


# ── Model identity ────────────────────────────────────────────────────────────
datai     <- buoy
# fiti_lgcp is set in the "Seasonal spline" section below: it stays 'LGCPSE' by
# default and switches to the isolated 'LGCPSEspl' namespace when the spline is on.


# ── Time discretization ───────────────────────────────────────────────────────
# Values from the benchmark report (benchmark_report.Rmd §Recommendation):
# α posterior has plateaued at sback = 60; ρ = 60 gives effective GP range of
# 180 min (3 hrs), ecologically interpretable for background call rate.
sback_lgcp <- 20   # min — segment width for LGCPSE numerical integration
rho_lgcp   <- 60   # min — GP range; effective range = rho * 3 = 180 min


# ── Harmonic periods for design matrix (in minutes) ──────────────────────────
# Each entry generates one sin + one cos column in Xm.
# For a ~7-month window (Oct 2021 – Apr 2022), all periods below have ≥3 cycles.
# Daily/diel term added to capture the diel calling cycle (see QQ upper-tail
# diagnosis); its period (1,440 min) exceeds the GP effective range (3*rho=180),
# so the GP does not absorb it.
harm_periods_lgcp <- c(
  1 * harm_day_unit,     # daily   (~212 cycles)
  1 * harm_week_unit,    # 1-week  (~30 cycles)
  2 * harm_week_unit,    # 2-week  (~15 cycles)
  1 * harm_month_unit,   # 1-month (~7 cycles)
  2 * harm_month_unit    # 2-month (~3.5 cycles)
)


# ── Seasonal spline ───────────────────────────────────────────────────────────
# A natural-spline basis in time added to the background design to represent the
# end-of-season calling decline that harmonics + a short GP structurally cannot.
# Built by build_design_matrix() in src/design.R. When ON:
#   * the 2-month harmonic is dropped (the spline owns all sub-seasonal structure,
#     so keeping it would compete with / alias the spline), and
#   * the fit tag switches to 'LGCPSEspl' so every output (fit/loglik/lam/rtct/
#     num/fig + archive) lands in an isolated namespace and never collides with
#     production 'LGCPSE' files.
# Default OFF reproduces the exact 13-column LGCPSE design bit-for-bit.
# Per-buoy enablement. The spline is currently scoped to COX01 only; NS01/NS02
# stay production (bit-for-bit LGCPSE) until the COX01 7-month spline results are
# reviewed. This is the ONLY place the spline is turned on/off — design.R and
# fiti_lgcp both read the resolved scalar `seasonal_spline` below, so nothing
# downstream changes. Buoys not listed default to FALSE (fail-safe: they read the
# production LGCPSE fit that actually exists, never a phantom LGCPSEspl file).
#
# NOTE: cox01 = TRUE is the experiment default on the `seasonal-spline-phase3`
# branch. master keeps all buoys FALSE — do not carry cox01 = TRUE onto master
# when merging.
seasonal_spline_by_buoy <- c(
  ns01  = FALSE,
  ns02  = FALSE,
  cox01 = TRUE
)
seasonal_spline <- isTRUE(unname(seasonal_spline_by_buoy[buoy]))
cat(sprintf("Seasonal spline for %s: %s\n", buoy, seasonal_spline))
seasonal_spline_df          <- 6                # natural-spline degrees of freedom
seasonal_spline_method      <- 'ns'             # 'ns' | 'pspline' (Phase 4 fallback)
seasonal_spline_boundary    <- NULL             # NULL -> range(knts); else c(lo, hi)
seasonal_spline_drop_period <- 2 * harm_month_unit  # harmonic dropped when spline ON


# ── Fit tag (isolated namespace when the spline is on) ────────────────────────
fiti_lgcp <- if (isTRUE(seasonal_spline)) 'LGCPSEspl' else 'LGCPSE'


# ── MCMC settings ─────────────────────────────────────────────────────────────
niters_lgcp         <- 250000 # 100000 — bumped for COX01 spline convergence (resume-and-extend)
adaptInterval       <- 200
adaptFactorExponent <- 0.8
sigma2_init         <- rep(0.2^2, 3)   # initial proposal variances


# ── Hawkes prior bounds ───────────────────────────────────────────────────────
shape_alpha <- 0.001
rate_alpha  <- 0.001
lb_eta_days <- 3 / 20   # lower bound for eta (set before ts is loaded)
# ub_eta is data-dependent: 3 / min(diff(ts)) — computed after loading data


# ── Burn-in ───────────────────────────────────────────────────────────────────
# Per-buoy burn lives in buoy_settings[[buoy]]$burn; set after inspecting the
# loglik trace plot (03_sumLoglik.R). Post-processing scripts read it via
# load_fit.R, which falls back to buoy_cfg$burn when `burn` is unset.


# ── Output paths ─────────────────────────────────────────────────────────────
# Fit files have a three-tier fallback so the same config works everywhere:
#   1. /work/rss10/sne_ns01     — primary cluster scratch (75-day wipe)
#   2. /hpc/group/schicklab/... — persistent lab share (auto-archive target)
#   3. local                    — laptop after rsync
# All other outputs (loglik/lam/rtct/num/fig) are always local.
hpc_base         <- '/work/rss10/sne_ns01'
hpc_archive_base <- '/hpc/group/schicklab/sne_ns01'
local_base       <- normalizePath('.')

fold.data    <- 'data'
fold.fit     <- 'fit'
fold.loglik  <- 'loglik'
fold.lam     <- 'lam'
fold.rtct    <- 'rtct'
fold.num     <- 'num'
fold.fig     <- 'fig'

fit_base <- if (dir.exists(file.path(hpc_base, fold.fit, buoy))) {
  hpc_base
} else if (dir.exists(file.path(hpc_archive_base, fold.fit, buoy))) {
  hpc_archive_base
} else {
  local_base
}
path_base <- fit_base   # legacy alias used by benchmark_*.R

path.data    <- file.path(local_base, fold.data,   '')
path.fit     <- file.path(fit_base,   fold.fit,    buoy, '')
path.loglik  <- file.path(local_base, fold.loglik, buoy, '')
path.lam     <- file.path(local_base, fold.lam,    buoy, '')
path.rtct    <- file.path(local_base, fold.rtct,   buoy, '')
path.num     <- file.path(local_base, fold.num,    buoy, '')
path.fig     <- file.path(local_base, fold.fig,    buoy, '')
