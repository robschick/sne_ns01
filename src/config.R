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
analysis_end  <- as.POSIXct('2022-04-30 04:01:00', tz = 'UTC')

# Harmonic anchor: minutes elapsed since midnight on the start date.
# Derived from std so it stays in sync — 0 min for a midnight origin.
harm_start_time <- as.numeric(format(std, '%H')) * 60 +
                   as.numeric(format(std, '%M'))
harm_week_unit  <- 7  * 24 * 60    # 10,080 min per week
harm_month_unit <- 30 * 24 * 60    # 43,200 min per "month"


# ── Model identity ────────────────────────────────────────────────────────────
datai     <- buoy
fiti_lgcp <- 'LGCPSE'


# ── Time discretization ───────────────────────────────────────────────────────
sback_lgcp <- 12 * 60   # 720 min — segment width for LGCPSE numerical integration

rho_lgcp <- 3 * 12 * 60 / 3   # 60 min  (effective range = rho * 3 = 180 min)


# ── Harmonic periods for design matrix (in minutes) ──────────────────────────
# Each entry generates one sin + one cos column in Xm.
# For a ~7-month window (Oct 2021 – Apr 2022), all periods below have ≥3 cycles.
harm_periods_lgcp <- c(
  1 * harm_week_unit,    # 1-week  (~30 cycles)
  2 * harm_week_unit,    # 2-week  (~15 cycles)
  1 * harm_month_unit,   # 1-month (~7 cycles)
  2 * harm_month_unit    # 2-month (~3.5 cycles)
)


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
# Per-buoy burn lives in buoy_settings[[buoy]]$burn; set after inspecting the
# loglik trace plot (03_sumLoglik.R). burn_lgcp is a transitional alias so
# legacy callers (04_*LGCPSE.R) keep working until Phase 5 rewires them.
burn_lgcp <- buoy_cfg$burn


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
