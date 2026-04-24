rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(readr)

source('src/RFtns.R')
sourceCpp('src/RcppFtns.cpp')
source('src/config.R')   # std, analysis_end, datai, buoy_cfg

# Note that the times of the call data and noise data are labeled UTC but they are actually EST

# =============================================================================-
# Call times ----
# =============================================================================-

call_all <- readRDS(file.path("data", buoy_cfg$call_file))
data = call_all %>%
  dplyr::mutate(Channel = 1) %>%
  dplyr::select(ts, Channel) %>%
  dplyr::arrange(ts)

# plot(data$ts)
# length(data$ts)
# length(unique(data$ts))

# data$ts = data$ts - 1


# =============================================================================-
# Noise variable ----
# =============================================================================-
noise = readRDS(file.path("data", buoy_cfg$noise_file)) #%>%
  # mutate(noise_scl = scale(RMS))


# Create complete minute sequence
full_UTC <- seq(min(noise$UTC), max(noise$UTC), by = "1 min")

# Identify which full_UTC times are NOT in the original noise data
original_times <- as.numeric(noise$UTC)
full_times <- as.numeric(full_UTC)
is_interpolated <- !full_times %in% original_times

# Interpolate RMS values
rms_interp <- approx(
  as.numeric(noise$UTC),
  noise$RMS,
  xout = as.numeric(full_UTC),
  rule = 2
)$y

# Add jitter scaled to local variability
set.seed(314)
rms_sd <- sd(noise$RMS, na.rm = TRUE) * 0.05
jitter <- rnorm(length(rms_interp), mean = 0, sd = rms_sd)
jitter[!is_interpolated] <- 0
rms_interp <- rms_interp + jitter

# Build filled data frame
noise_filled <- data.frame(
  UTC = full_UTC,
  day = as.Date(full_UTC),
  RMS = rms_interp
)

# Verify gaps are filled
noise_filled |>
  arrange(UTC) |>
  mutate(diff_min = as.numeric(difftime(UTC, lag(UTC), units = "mins"))) |>
  filter(diff_min > 1)

noise = noise_filled %>%
  mutate(noise_scl = scale(RMS))
# End Noise Variable ---------------


# Raw call data ranges (for reference; verify with
# `min(<buoy>_all$start_datetime); max(<buoy>_all$end_datetime)`):
#
# NS01:  2021-03-18 06:27:59 UTC  –  2022-04-30 04:00:52 UTC
# NS02:  2021-03-10 17:29:06 UTC  –  2022-04-28 02:41:01 UTC
# COX01: 2021-02-26 21:03:38 UTC  –  2022-05-14 20:13:20 UTC
#
# The analysis window (std → analysis_end in config.R) is a modeling
# choice — it may be narrower than the data range.

# Deployment origin: fixed reference from which call $ts is measured (minutes).
# Do not change this — it is a property of the raw data, not the analysis window.
std_deploy     <- as.POSIXct(buoy_cfg$deploy_time, tz = 'UTC')
std_orig_num   <- as.numeric(std_deploy)   # seconds, for noise ts computation

# Analysis window in minutes from deployment origin (std and analysis_end from config.R)
offset_min <- as.numeric(difftime(std,          std_deploy, units = 'mins'))
end_min    <- as.numeric(difftime(analysis_end, std_deploy, units = 'mins'))

std_date <- as.Date(std)
end_date <- as.Date(analysis_end)

# =============================================================================-
# SST variable ----
# =============================================================================-
sst = read_csv('data/sst/2025-11-20_SNE_buoys_sst-data.csv') %>%
  dplyr::select(date, sst_val = !!buoy_cfg$sst_col) %>%
  dplyr::filter(date >= std_date & date <= end_date) %>%
  mutate(sst = as.vector(scale(sst_val))) %>%
  as.data.frame()


noise = noise %>%
  dplyr::mutate(ts = ( as.numeric(UTC) - std_orig_num) / 60, noise = noise_scl) %>% # unit = 1 min from deployment origin
  dplyr::filter(ts >= 0) %>%
  dplyr::select(UTC, date = day, ts, noise) %>%
  dplyr::arrange(ts)

noise <- noise %>%
  left_join(sst, by = "date")


## Check if there are missing data in noise ----
# ts = data$ts
# maxT = ceiling(max(ts))
# 
# dummy = data.frame(ts = unique(c(0, seq(0, maxT, by = 1), maxT))) %>%
#   left_join(noise)
# 
# which(is.na(dummy$noise)) # 900  9823
# any(is.na(dummy %>% slice(901:9822) %>% select(noise) %>% unlist()))
# dummy[c(901, 9822),]
# 2009-03-28 15:01:00 100.3619
# 2009-04-03 08:45:00  98.6896




# =============================================================================-
# Final dataset ----
# Filter to analysis window [std, analysis_end] and re-zero ts so ts=0 at std.
# offset_min and end_min are in minutes from the deployment origin (std_deploy).
# =============================================================================-

n_raw <- nrow(data)

data = data %>%
  filter(ts >= offset_min, ts <= end_min) %>%
  mutate(ts = ts - offset_min)

noise = noise %>%
  filter(ts >= offset_min, ts <= end_min) %>%
  mutate(ts = ts - offset_min)

noise = unique(noise)


save(data, noise, file = paste0('data/', datai, '.RData'))


# ── Summary ──────────────────────────────────────────────────────────────────
cat(sprintf('\n=== %s ===\n', toupper(buoy)))
cat(sprintf('  Window:            %s  ->  %s\n',
            format(std, '%Y-%m-%d'), format(analysis_end, '%Y-%m-%d')))
cat(sprintf('  Raw events:        %d\n', n_raw))
cat(sprintf('  Events in window:  %d  (%.1f%% of raw)\n',
            nrow(data), 100 * nrow(data) / n_raw))
cat(sprintf('  Unique timestamps: %d  (%d duplicates)\n',
            length(unique(data$ts)), nrow(data) - length(unique(data$ts))))
cat(sprintf('  Noise grid rows:   %d\n\n', nrow(noise)))



# =============================================================================-
# Noise plot ----
# =============================================================================-
# load('data/nopp.RData')
# head(noise)
# 
# shade = data.frame(dusk = seq.POSIXt(as.POSIXlt("2009-03-28 18:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), by = 'day', length.out = 6), 
#                    dawn = seq.POSIXt(as.POSIXlt("2009-03-29 06:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), by = 'day', length.out = 6),
#                    top = Inf,
#                    bottom = -Inf)
# 
# 
# plot.noise = noise %>%
#   ggplot() +
#   geom_rect(data = shade,
#             aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
#             fill = 'gray50', alpha = 0.5) +
#   geom_line(aes(x = UTC, y = noise)) +
#   labs(x = 'Time', y = 'Noise') +
#   theme_bw() +
#   scale_x_datetime(date_breaks = "1 day", date_labels = "%b-%d") +
#   theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
# 
# ggsave(plot = plot.noise, width = 5, height = 2.8, device = cairo_ps,
#        filename = 'fig/nopp2009noise.eps')
