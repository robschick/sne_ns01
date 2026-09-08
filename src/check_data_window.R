# =============================================================================
# check_data_window.R — Preflight: does data/<buoy>.RData match the window
# configured in src/config.R?
#
# 02_fitLGCPSE.R takes its event times from data/<buoy>.RData as-is; the
# analysis_end in config.R only takes effect when 01_data.R is re-run. In
# Aug 2026 the NS01/NS02 re-fits (8 + 17 node-days) ran on a stale 7-month
# data file because that step was skipped on the cluster. This script prints
# the data file's provenance and exits non-zero if the data extend past the
# configured window, so aci_fit.sh aborts before burning walltime.
#
# Usage:  Rscript src/check_data_window.R --buoy=ns01   (or BUOY=ns01 env)
# =============================================================================
source('src/config.R')   # buoy, std, analysis_end, path.data, datai

f <- paste0(path.data, datai, '.RData')
if (!file.exists(f)) stop('Data file missing: ', f, ' -- run 01_data.R first')
load(f)                  # data, noise

max_day  <- max(data$ts) / 1440
cfg_days <- as.numeric(difftime(analysis_end, std, units = 'days'))

cat(sprintf('=== data window: %s  mtime=%s  events=%d  max_day=%.1f  config_window=%.0f d ===\n',
            f, format(file.mtime(f), '%Y-%m-%d %H:%M'), nrow(data), max_day, cfg_days))

if (max_day > cfg_days + 1) {
  stop(sprintf(paste('Data extend to day %.1f but the configured window is %.0f d.',
                     'The data file is stale -- re-run 01_data.R for %s before fitting.'),
               max_day, cfg_days, buoy))
}
if (max_day < cfg_days - 14) {
  cat(sprintf('WARNING: data end at day %.1f, well short of the %.0f d window (deliberate truncation?)\n',
              max_day, cfg_days))
}
cat('Data window check: OK\n')
