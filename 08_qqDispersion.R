# =============================================================================
# 08_qqDispersion.R — Quantify under/over-dispersion of the RTC compensator
#                     increments, per buoy.
#
# Background. If the LGCPSE compensator is correct, the per-event increments
# d_i = \int_{t_{i-1}}^{t_i} lambda are i.i.d. Exp(1): mean 1, var 1, CV 1,
# memoryless. The Q-Q plots (05/05b/05c) show the *shape* of the departure;
# this script puts numbers on it and separates two mechanisms:
#
#  (1) Budget conservation. sum_i d_i = \int_0^T lambda ~= n is (nearly) pinned
#      by the fit, so mean(d) ~= 1 even when a few silences blow up d. A handful
#      of huge increments therefore forces the *bulk* below 1 -> underdispersion.
#      Test: drop the top-k d_i. If the trimmed mean falls well below 1 and the
#      trimmed variance collapses, the bulk underdispersion is the shadow of the
#      outliers, not a pervasive misfit. (Expected, esp. for COX01.)
#
#  (2) Over-adaptive intensity (in-sample optimism). A flexible GP + the
#      self-exciting term can track where calls fell, compressing increments
#      toward 1 and leaving negative serial structure. Test: lag-1 autocorr of
#      U_i = 1 - exp(-d_i) (Unif(0,1) under the model), in EVENT order. A
#      sizeable negative acf1 points at over-adaption; clean rhythm at genuine
#      calling regularity.
#
# Also reports the bulk Q-Q slope (robust line through the central region;
# slope < 1 == underdispersion) and a KS test of d against Exp(1).
#
# Reads rtct/<buoy>/<buoy>LGCPSE_rtct.RData; buoys with no rtct file are skipped
# with a warning (degrades gracefully if rtct/ has not been rsync'd down).
#
# Usage:   Rscript 08_qqDispersion.R       <-- run WITHOUT --buoy; loops all.
# Env:     QQ_DROP=<k>      number of top-d_i removed for the trimmed stats (5).
#          QQ_BULK=<f>      central fraction defining "bulk" for the slope (.95).
#          QQ_LBLAG=<m>     max lag for the Ljung-Box serial-corr test (20).
#
# Outputs (fig/combined/):
#   qq_dispersion.csv / .tex     one row per buoy
# =============================================================================

rm(list = ls())
library(tidyverse); library(xtable)

source('src/RFtns.R')   # config sourced per-buoy in the loop

buoys       <- c('ns01', 'ns02', 'cox01')
buoy_labels <- c(ns01 = 'NS01', ns02 = 'NS02', cox01 = 'COX01')
drop_k      <- as.integer(Sys.getenv('QQ_DROP', unset = '5'))
bulk_frac   <- as.numeric(Sys.getenv('QQ_BULK', unset = '0.95'))
lb_lag      <- as.integer(Sys.getenv('QQ_LBLAG', unset = '20'))
stopifnot(drop_k >= 0, bulk_frac > 0, bulk_frac < 1, lb_lag >= 1)

disp_list <- list()

for (b in buoys) {
  Sys.setenv(BUOY = b)
  source('src/config.R')   # path.rtct, datai, fiti_lgcp
  fiti  <- fiti_lgcp
  label <- buoy_labels[[b]]

  rtctfile <- paste0(path.rtct, datai, fiti, '_rtct.RData')
  if (!file.exists(rtctfile)) {
    warning(sprintf('rtct file missing for %s (%s) — skipped. %s',
                    b, rtctfile, 'Run 04_rtctLGCPSE.R and rsync rtct/ down.'))
    next
  }
  load(rtctfile)   # ts, postCompen (col 5 = per-event increment, median)

  d <- postCompen[, 5]          # event order (as stored), NOT sorted
  n <- length(d)

  # ── Full dispersion (Exp(1) target: mean = var = CV = 1) ───────────────────
  mean_d <- mean(d)
  var_d  <- var(d)
  cv_d   <- sd(d) / mean_d

  # ── Budget test: drop the top-k increments and re-measure ──────────────────
  keep      <- d <= sort(d, decreasing = TRUE)[min(drop_k + 1, n)]
  mean_trim <- mean(d[keep])
  var_trim  <- var(d[keep])

  # ── Over-adaption test: lag-1 autocorr of U = 1 - exp(-d), in event order ───
  # U ~ Unif(0,1) and i.i.d. under a correct compensator. acf1 reads the SIGN of
  # any serial dependence (> 0 missing slow structure; < 0 over-adaptive). The
  # Ljung-Box test pools lags 1..lb_lag for a proper omnibus H0: no autocorr.
  U    <- 1 - exp(-d)
  acf1 <- as.numeric(acf(U, lag.max = 1, plot = FALSE)$acf[2])
  lb   <- Box.test(U, lag = lb_lag, type = 'Ljung-Box')

  # ── Bulk Q-Q slope (slope < 1 == underdispersion) ──────────────────────────
  # Sorted d vs Exp(1) order-statistic quantiles, restricted to the central
  # `bulk_frac`; OLS slope through that bulk.
  qq <- tibble(d = sort(d)) %>%
    mutate(theo = log(n) - log(n - (row_number() - 0.5)))
  cut <- quantile(qq$theo, bulk_frac, names = FALSE)
  bulk_slope <- coef(lm(d ~ theo, data = filter(qq, theo <= cut)))[['theo']]

  # ── KS against Exp(1) ──────────────────────────────────────────────────────
  ks <- suppressWarnings(ks.test(d, 'pexp', rate = 1))

  disp_list[[b]] <- tibble(
    Buoy        = label,
    n_events    = n,
    mean_d      = round(mean_d, 3),
    var_d       = round(var_d, 3),
    cv_d        = round(cv_d, 3),
    mean_drop   = round(mean_trim, 3),   # mean after dropping top-k
    var_drop    = round(var_trim, 3),    # var  after dropping top-k
    bulk_slope  = round(bulk_slope, 3),  # < 1 == underdispersed bulk
    acf1_U      = round(acf1, 3),        # < 0 == over-adaptive; > 0 missing slow structure
    lb_stat     = round(as.numeric(lb$statistic), 1),  # Ljung-Box Q, lags 1..lb_lag
    lb_p        = signif(lb$p.value, 3), # H0: no serial autocorrelation in U
    lb_lag      = lb_lag,
    ks_D        = round(as.numeric(ks$statistic), 3),
    ks_p        = signif(ks$p.value, 3),
    drop_k      = drop_k
  )
}

# ── Write & print ─────────────────────────────────────────────────────────────
if (!length(disp_list)) {
  cat('\n[no rtct outputs found for any buoy — nothing written]\n')
} else {
  disp_tbl <- bind_rows(disp_list)

  cat('\n=== RTC compensator dispersion (Exp(1) target: mean=var=cv=1) ===\n')
  cat('mean_d ~ 1 (budget); var_d/cv_d < 1 = underdispersed; ',
      'mean_drop<<1 & var_drop<<1 = bulk deflated by the top-', drop_k,
      ' outliers; acf1_U < 0 = over-adaptive, > 0 = missing slow structure; ',
      'lb_p = Ljung-Box (lags 1..', lb_lag, ') H0 no serial autocorr.\n', sep = '')
  print(as.data.frame(disp_tbl), row.names = FALSE)

  out_dir <- file.path('fig', 'combined')
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  write_csv(disp_tbl, file.path(out_dir, 'qq_dispersion.csv'))
  print(xtable(disp_tbl,
               caption = 'RTC compensator-increment dispersion per buoy.'),
        booktabs = FALSE, include.rownames = FALSE,
        file = file.path(out_dir, 'qq_dispersion.tex'))
  cat(sprintf('\nWrote qq_dispersion.csv/.tex to %s/\n', out_dir))
}
