rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(readr)

source('src/RFtns.R')
sourceCpp('src/RcppFtns.cpp')

# Note that the times of the call data and noise data are labeled UTC but they are actually EST

# =============================================================================-
# Call times ----
# =============================================================================-

ns_01_all <- readRDS("data/ns_01_all.rds")
data = ns_01_all %>%
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
noise = readRDS('data/ns01_rms_data.rds') #%>% 
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


# NS01
# range(ns_01_all$start_datetime)[1]
# [1] "2021-03-18 06:27:59 UTC"
# > range(ns_01_all$end_datetime)[2]
# [1] "2022-02-03 04:10:38 UTC"

# NS02
# > range(ns_02_all$start_datetime)[1]
# [1] "2021-03-10 17:29:06 UTC"
# > range(ns_02_all$end_datetime)[2]
# [1] "2022-02-06 14:17:40 UTC"

# COX01
# > range(cox_01_all$start_datetime)[1]
# [1] "2021-02-26 21:03:38 UTC"
# > range(cox_01_all$end_datetime)[2]
# [1] "2022-02-16 18:48:25 UTC"

std = as.numeric(strptime('2021-03-18 06:27:00.000', "%Y-%m-%d %H:%M:%OS", tz = "UTC"))
std_date <- range(noise$day)[1]
end_date <- range(noise$day)[2]

# =============================================================================-
# SST variable ----
# =============================================================================-
sst = read_csv('data/sst/2025-11-20_SNE_buoys_sst-data.csv') %>%
  dplyr::select(date,	sst_val = NS01) %>% 
  dplyr::filter(date >= std_date & date <= end_date) %>% 
  mutate(sst = as.vector(scale(sst_val))) %>% 
  as.data.frame()


noise = noise %>% 
  dplyr::mutate(ts = ( as.numeric(UTC) - std) / 60, noise = noise_scl) %>% # unit = 1 min
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
# =============================================================================-

std.final = (as.numeric(strptime('2021-03-18 06:27:00.000', "%Y-%m-%d %H:%M:%OS", tz = "UTC")) - std) / 60

data = data %>% 
  filter(ts >= (as.numeric(strptime('2021-03-18 06:27:00.000', "%Y-%m-%d %H:%M:%OS", tz = "UTC")) - std) / 60) %>% 
  filter(ts <= (as.numeric(strptime('2022-04-30 04:00:52.000', "%Y-%m-%d %H:%M:%OS", tz = "UTC")) - std) / 60) %>% 
  mutate(ts = ts - std.final)

plot(data$ts)
length(data$ts)
length(unique(data$ts))


noise = noise %>% 
  filter(ts >= (as.numeric(strptime('2021-03-18 06:27:00.000', "%Y-%m-%d %H:%M:%OS", tz = "UTC")) - std) / 60) %>% 
  filter(ts <= (as.numeric(strptime('2022-04-30 04:00:52.000', "%Y-%m-%d %H:%M:%OS", tz = "UTC")) - std) / 60) %>% 
  mutate(ts = ts - std.final)

dim(noise)
dim(unique(noise))
noise = unique(noise)


save(data, noise, file = 'data/nopp.RData')



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
