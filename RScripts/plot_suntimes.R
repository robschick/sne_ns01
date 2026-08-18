# =============================================================================
# plot_suntimes.R — Gap-end clock time vs date, with solar dawn curves.
#
# Tests whether the ~05:00 gap-end clustering (docs/qq_diagnostics_findings.md,
# "The diel signature") tracks real dawn or sits on a fixed clock boundary.
# Real dawn drifts ~1.5 h across Oct–Feb at these latitudes; a processing
# boundary does not. The timezone offset only shifts the curves vertically —
# the tracking-vs-flat verdict is offset-invariant.
#
# Usage:   Rscript RScripts/plot_suntimes.R
# Output:  fig/combined/gap_end_vs_dawn.pdf / .png
# =============================================================================

library(tidyverse)
library(suncalc)

# Gap-end timestamps are labeled UTC but are actually EST (UTC-5); solar times
# come back in true UTC. Convert curves onto the data's clock.
tz_offset_hr <- -5

buoys <- read.csv(
  'data/buoy_locs.csv',
  strip.white = TRUE,
  colClasses = 'character'
) %>%
  rename_with(str_trim) %>%
  mutate(across(c(Lat, Lon), ~ as.numeric(str_replace_all(.x, '−', '-'))))

gaps <- read_csv('fig/combined/gap_vs_coverage.csv', show_col_types = FALSE) %>%
  mutate(
    date = as_date(when),
    clock_hr = hour(when) + minute(when) / 60,
    Buoy = factor(Buoy, levels = c('COX01', 'NS01', 'NS02'))
  )

# Daily solar grid per buoy across the analysis window (smooth curves).
solar <- crossing(
  buoys %>% select(DeployID, lat = Lat, lon = Lon),
  date = seq(as_date('2021-10-01'), as_date('2022-03-01'), by = '1 day')
) %>%
  getSunlightTimes(data = ., tz = 'UTC',
                   keep = c('sunrise', 'dawn', 'nauticalDawn')) %>%
  bind_cols(DeployID = rep(buoys$DeployID, each = 152)) %>%
  pivot_longer(c(sunrise, dawn, nauticalDawn),
               names_to = 'event', values_to = 'utc') %>%
  mutate(
    clock_hr = (hour(utc) + minute(utc) / 60 + tz_offset_hr) %% 24,
    event = recode(event, sunrise = 'Sunrise', dawn = 'Civil dawn',
                   nauticalDawn = 'Nautical dawn'),
    Buoy = factor(DeployID, levels = levels(gaps$Buoy))
  )

plot.dawn <- ggplot() +
  geom_line(
    data = solar,
    aes(x = date, y = clock_hr, linetype = event),
    colour = 'steelblue4'
  ) +
  geom_hline(yintercept = 5, colour = 'grey40', linetype = 'dotted') +
  geom_vline(xintercept = as_date('2021-11-07'),
             colour = 'grey40', linetype = 'dotted') +
  geom_point(
    data = gaps,
    aes(x = date, y = clock_hr, size = d),
    colour = 'firebrick', alpha = 0.7
  ) +
  facet_wrap(~Buoy, ncol = 1) +
  scale_y_continuous(
    breaks = seq(0, 24, 4),
    labels = sprintf('%02d:00', seq(0, 24, 4)),
    limits = c(0, 24),
    expand = c(0, 0)
  ) +
  scale_size_continuous(range = c(1, 4)) +
  labs(
    x = NULL,
    y = 'Gap-end clock time (as stored; nominal EST)',
    linetype = NULL,
    size = 'Compensator\nincrement d',
    caption = paste(
      'Dotted lines: 05:00 clock time (fixed-clock hypothesis) and the',
      '2021-11-07 DST transition.\nSolar curves shifted UTC-5 onto the data',
      'clock; a different fixed offset moves the curves\nvertically but',
      'cannot change their seasonal slope.'
    )
  ) +
  theme_bw() +
  theme(legend.position = 'bottom', legend.box = 'vertical',
        plot.caption = element_text(hjust = 0))

ggsave('fig/combined/gap_end_vs_dawn.pdf', plot.dawn,
       width = 7, height = 8.5, bg = 'white')
ggsave('fig/combined/gap_end_vs_dawn.png', plot.dawn,
       width = 7, height = 8.5, dpi = 330, bg = 'white')
