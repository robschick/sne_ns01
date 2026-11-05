# =============================================================================
# context/ais/03_weekly.R — Weekly AIS traffic within 10 km of each buoy.
#
# One panel per buoy (COX01 -> NS01 -> NS02): mean vessel-hours per day in each
# week of the season, all vessel types. Faint points = weekly values; lines =
# 3-week rolling mean. Analysis winter solid, prior winter dashed, aligned by
# week-of-season (week 1 = Oct 1-7 in both). Built from weekly_series()
# (R/summary.R).
#
# Each panel has its own y-axis: the buoys differ ~10x in traffic, and this
# figure is about timing. The per-buoy table carries the cross-site comparison.
#
# Usage:   Rscript context/ais/03_weekly.R      (from the repo root)
# Input:   context/ais/cache/presence.parquet   (01_download.R)
# Output:  fig/context/ais/weekly_panel.{png,pdf}, fig/context/ais/weekly_series.csv
# =============================================================================

suppressPackageStartupMessages(library(arrow))
source('context/ais/R/summary.R')   # weekly_series(), ais_seasons, buoy_order
source('src/talk_figs.R')           # theme_talk, col_contact

out_dir <- 'fig/context/ais'
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

ws <- weekly_series(as.data.frame(read_parquet('context/ais/cache/presence.parquet')))
write.csv(ws, file.path(out_dir, 'weekly_series.csv'), row.names = FALSE)

# Plot both winters on the analysis winter's calendar, at mid-week.
ws$date   <- ais_seasons$analysis[1] + 7 * (ws$week - 1) + 3
ws$buoy   <- factor(ws$buoy, buoy_order)
ws$winter <- factor(ifelse(ws$season == 'analysis', '2021–22', '2020–21 (prior winter)'),
                    c('2021–22', '2020–21 (prior winter)'))

p <- ggplot(ws, aes(date, colour = winter, linetype = winter)) +
  geom_point(aes(y = hours), size = 2, alpha = 0.3) +
  geom_line(aes(y = smooth), linewidth = 1.3) +
  facet_wrap(~ buoy, ncol = 1, scales = 'free_y') +
  scale_colour_manual(values = c(col_contact, 'grey45'), name = NULL) +
  scale_linetype_manual(values = c('solid', '22'), name = NULL) +
  scale_x_date(date_breaks = '1 month', date_labels = '%b',
               limits = ais_seasons$analysis, expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, NA), breaks = scales::breaks_extended(3),
                     expand = expansion(c(0, 0.08))) +
  labs(title = 'AIS vessel traffic within 10 km of each hydrophone',
       subtitle = 'Vessel-hours per day: weekly values (points) and 3-week mean (lines)',
       x = NULL, y = 'Vessel-hours per day',
       caption = paste0('All AIS vessel types. Each panel has its own scale. ',
                        'AIS misses most small boats.\n',
                        'Vessel presence: Global Fishing Watch (globalfishingwatch.org), CC BY-NC 4.0.')) +
  theme_talk +
  theme(legend.position = 'top', legend.justification = 'left',
        legend.key.width = unit(2.5, 'lines'),
        legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(4, 'pt'),
        panel.spacing.y = unit(14, 'pt'),
        panel.grid.major.x = element_blank(),
        strip.text = element_text(hjust = 0, face = 'bold', size = 22),
        plot.subtitle = element_text(colour = 'grey35', size = 18),
        plot.caption = element_text(hjust = 0, size = 13, colour = 'grey30'),
        plot.caption.position = 'plot')

for (ext in c('png', 'pdf'))
  ggsave(file.path(out_dir, paste0('weekly_panel.', ext)), p, width = 13.33, height = 9,
         dpi = 200, device = if (ext == 'pdf') cairo_pdf else NULL)
cat('Wrote ', out_dir, '/weekly_panel.{png,pdf}\n', sep = '')
