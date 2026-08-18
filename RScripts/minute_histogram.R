# =============================================================================
# minute_histogram.R — Clock-minute histogram of ALL detections, per buoy.
#
# Follow-up to the clock-boundary correction in docs/qq_diagnostics_findings.md
# ("The ~05:00 signature"). A processing boundary that stamps or displaces
# detections shows up as a single-minute (or few-minute) spike at a fixed clock
# time across the whole dataset; biology varies smoothly at hour scale and
# cannot produce that. Each minute is tested against the mean of its ±30-min
# neighborhood (Poisson upper tail, Bonferroni across 1440 minutes).
#
# Uses all detections in each call file (not just the analysis window): the
# boundary is a property of the acquisition/processing chain, so the full
# record gives the most power.
#
# Usage:   Rscript RScripts/minute_histogram.R
# Output:  fig/combined/minute_histogram.png       (full day)
#          fig/combined/minute_histogram_zoom.png  (04:00-06:30)
#          printed table of flagged minutes
# =============================================================================

library(tidyverse)

calls <- tribble(
  ~Buoy,    ~file,
  'COX01',  'data/cox_01_all.rds',
  'NS01',   'data/ns_01_all.rds',
  'NS02',   'data/ns_02_all.rds'
) %>%
  mutate(dat = map(file, readRDS)) %>%
  mutate(dat = map(dat, ~ tibble(when = .x$start_datetime))) %>%
  select(-file) %>%
  unnest(dat) %>%
  mutate(min_of_day = hour(when) * 60 + minute(when))

counts <- calls %>%
  count(Buoy, min_of_day) %>%
  complete(Buoy, min_of_day = 0:1439, fill = list(n = 0))

# Local baseline: mean count over the ±30-min neighborhood (excluding the
# minute itself), computed on the circular day.
neigh_mean <- function(n) {
  k <- 30
  len <- length(n)
  sapply(seq_len(len), function(i) {
    idx <- ((i - 1 + c(-k:-1, 1:k)) %% len) + 1
    mean(n[idx])
  })
}

counts <- counts %>%
  group_by(Buoy) %>%
  arrange(min_of_day, .by_group = TRUE) %>%
  mutate(
    baseline = neigh_mean(n),
    p_pois = ppois(n - 1, baseline, lower.tail = FALSE),
    flagged = p_pois < 0.05 / 1440
  ) %>%
  ungroup()

cat('\nMinutes flagged as spikes (Poisson vs ±30-min baseline, Bonferroni):\n')
counts %>%
  filter(flagged) %>%
  mutate(clock = sprintf('%02d:%02d', min_of_day %/% 60, min_of_day %% 60)) %>%
  select(Buoy, clock, n, baseline, p_pois) %>%
  arrange(Buoy, p_pois) %>%
  print(n = 50)

counts <- counts %>%
  mutate(hr = min_of_day / 60)

p_full <- ggplot(counts, aes(x = hr, y = n)) +
  geom_step(linewidth = 0.2, colour = 'grey30') +
  geom_point(data = filter(counts, flagged), colour = 'firebrick', size = 1.5) +
  geom_vline(xintercept = 5, colour = 'steelblue4', linetype = 'dotted') +
  facet_wrap(~Buoy, ncol = 1, scales = 'free_y') +
  scale_x_continuous(breaks = seq(0, 24, 4),
                     labels = sprintf('%02d:00', seq(0, 24, 4)),
                     expand = c(0, 0)) +
  labs(x = NULL, y = 'Detections per clock minute (all data)',
       caption = paste('Red points: minutes exceeding their ±30-min Poisson',
                       'baseline at Bonferroni-corrected p < 0.05.',
                       'Dotted line: 05:00.')) +
  theme_bw()

p_zoom <- counts %>%
  filter(hr >= 4, hr <= 6.5) %>%
  ggplot(aes(x = hr, y = n)) +
  geom_col(width = 1 / 60, fill = 'grey40') +
  geom_col(data = . %>% filter(flagged), width = 1 / 60, fill = 'firebrick') +
  geom_vline(xintercept = 5, colour = 'steelblue4', linetype = 'dotted') +
  facet_wrap(~Buoy, ncol = 1, scales = 'free_y') +
  scale_x_continuous(breaks = seq(4, 6.5, 0.5),
                     labels = c('04:00', '04:30', '05:00', '05:30',
                                '06:00', '06:30')) +
  labs(x = NULL, y = 'Detections per clock minute (all data)',
       caption = 'Zoom on the 04:00-06:30 window around the gap-end cluster.') +
  theme_bw()

ggsave('fig/combined/minute_histogram.png', p_full,
       width = 7, height = 7, dpi = 330, bg = 'white')
ggsave('fig/combined/minute_histogram_zoom.png', p_zoom,
       width = 7, height = 7, dpi = 330, bg = 'white')
