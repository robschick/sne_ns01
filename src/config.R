# =============================================================================
# config.R — Single source of truth for all model constants
#
# Source this file at the top of every script:
#   source('src/config.R')
# =============================================================================


# ── Analysis window ───────────────────────────────────────────────────────────
# std is the time origin: ts = 0 at std, ts in minutes.
# analysis_end filters the upper bound; set to NULL to use all available data.
# Note: timestamps are labeled UTC but are actually EST.
std_str       <- '2021-10-01 00:00:00'
std           <- as.POSIXct(std_str, tz = 'UTC')
analysis_end  <- as.POSIXct('2022-04-30 04:01:00', tz = 'UTC')  # full NS01 extent

# Harmonic anchor: minutes elapsed since midnight on the start date.
# Derived from std so it stays in sync — 0 min for a midnight origin.
harm_start_time <- as.numeric(format(std, '%H')) * 60 +
                   as.numeric(format(std, '%M'))
harm_week_unit  <- 7  * 24 * 60    # 10,080 min per week
harm_month_unit <- 30 * 24 * 60    # 43,200 min per "month"


# ── Model identity ────────────────────────────────────────────────────────────
datai     <- 'nopp'
fiti_lgcp <- 'LGCPSE'
fiti_nhpp <- 'NHPPSE'


# ── Time discretization ───────────────────────────────────────────────────────
sback_lgcp <- 12 * 60   # 720 min — segment width for LGCPSE numerical integration
sback_nhpp <- 30        # 30 min  — segment width for NHPPSE

rho_lgcp <- 3 * 12 * 60 / 3   # 60 min  (effective range = rho * 3 = 180 min)
rho_nhpp <- 30                  # 30 min  (effective range = 90 min)


# ── Harmonic periods for design matrix (in minutes) ──────────────────────────
# Each entry generates one sin + one cos column in Xm.
# For a ~7-month window (Oct 2021 – Apr 2022), all periods below have ≥3 cycles.
harm_periods_lgcp <- c(
  1 * harm_week_unit,    # 1-week  (~30 cycles)
  2 * harm_week_unit,    # 2-week  (~15 cycles)
  1 * harm_month_unit,   # 1-month (~7 cycles)
  2 * harm_month_unit    # 2-month (~3.5 cycles)
)

# NHPPSE: defined inline in fitNHPPSE_parallel.R (different unit structure)


# ── MCMC settings ─────────────────────────────────────────────────────────────
niters_lgcp         <- 150000
adaptInterval       <- 200
adaptFactorExponent <- 0.8
sigma2_init         <- rep(0.2^2, 3)   # initial proposal variances


# ── Hawkes prior bounds ───────────────────────────────────────────────────────
shape_alpha <- 0.001
rate_alpha  <- 0.001
lb_eta_days <- 3 / 20   # lower bound for eta (set before ts is loaded)
# ub_eta is data-dependent: 3 / min(diff(ts)) — computed after loading data


# ── Burn-in ───────────────────────────────────────────────────────────────────
# Set ONCE after inspecting the loglik trace plot (loglikLGCPSE.R / loglikNHPPSE.R).
# All downstream scripts (lam, rtct, num, sum*) read burn from here.
burn_lgcp <- 50000
burn_nhpp <- 50000


# ── Output paths ─────────────────────────────────────────────────────────────
# Fit files live on the HPC cluster; all other outputs are local.
hpc_base   <- '/work/rss10/sne_ns01'
local_base <- normalizePath('.')
path_base  <- if (dir.exists(hpc_base)) hpc_base else local_base

fold.data    <- 'data'
fold.fit     <- 'fit'
fold.loglik  <- 'loglik'
fold.lam     <- 'lam'
fold.rtct    <- 'rtct'
fold.num     <- 'num'

path.data    <- file.path(local_base, fold.data,   '')
path.fit     <- file.path(path_base,  fold.fit,    '')
path.loglik  <- file.path(local_base, fold.loglik, '')
path.lam     <- file.path(local_base, fold.lam,    '')
path.rtct    <- file.path(local_base, fold.rtct,   '')
path.num     <- file.path(local_base, fold.num,    '')
