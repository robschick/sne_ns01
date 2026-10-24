# =============================================================================
# 15_quietSeason.R — Talk figure: calls missing on noisy days.
#
# Counterfactual from 10b_paramExport.R: noise capped at each buoy's quietest-
# 10% level (quieter times unchanged), everything else as fitted. The gap
# between quiet and actual is drawn in two parts: the missing contact calls
# (background) and the answers those would have drawn (x 1/(1 - alpha/eta)).
#
# The model sees detected calls only, so the gap is "missed by the detector, or
# never made": masking and calling less are not separable from detections.
#
# Usage:   Rscript 15_quietSeason.R
# Input:   out/anim/<buoy>_params.rds
# Output:  fig/talk/quiet_season_ns01.{png,pdf}   (i) NS01 + season totals
#          fig/talk/quiet_season_all.{png,pdf}    (ii) three buoys, shared y
#          fig/talk/quiet_season.csv
# =============================================================================

source('src/talk_figs.R')
library(patchwork)

col_gap_contact <- col_contact
col_gap_answer  <- '#92c5de'             # light end of the same RdBu blue
col_detected    <- 'grey70'

params <- setNames(lapply(buoys, read_params), buoys)

daily <- do.call(rbind, lapply(buoys, function(b) {
  d <- params[[b]]$quiet$daily
  data.frame(site = labels[[b]], date = as.Date('2021-10-01') + d$day,
             detected = d$total_actual, contact = d$gap_contact, total_gap = d$gap_total)
}))
daily$site <- factor(daily$site, labels[buoys])

season <- do.call(rbind, lapply(buoys, function(b) {
  s <- params[[b]]$season
  data.frame(site = labels[[b]],
             detected = s['total_actual', 'med'], quiet = s['total_quiet', 'med'],
             missing = s['gap_total', 'med'], missing_lo = s['gap_total', 'lo'],
             missing_hi = s['gap_total', 'hi'], contact = s['gap_contact', 'med'])
}))
season$share <- season$missing / season$quiet
print(format(season, digits = 3, big.mark = ','), row.names = FALSE)
write.csv(season, 'fig/talk/quiet_season.csv', row.names = FALSE)

title    <- 'Calls missing on noisy days'
subtitle <- 'Expected calls per day as fitted, and with noise held to the quietest 10% of times'
caveat   <- paste0('Missing = missed by the detector, or never made:\n',
                   '   (1) masking: the whales called and we did not hear them\n',
                   '   (2) behavior: the whales called less\n',
                   'Detections alone cannot tell these apart.')

fill_scale <- scale_fill_manual(
  values = c(detected = col_detected, contact = col_gap_contact, answers = col_gap_answer),
  breaks = c('detected', 'contact', 'answers'),
  labels = c('Detected', 'Missing contact calls', '+ the answers they would have drawn'),
  name = NULL)

season_plot <- function(d, facet = FALSE) {
  p <- ggplot(d, aes(date)) +
    geom_area(aes(y = detected, fill = 'detected')) +
    geom_ribbon(aes(ymin = detected, ymax = detected + contact, fill = 'contact')) +
    geom_ribbon(aes(ymin = detected + contact, ymax = detected + total_gap, fill = 'answers')) +
    fill_scale +
    scale_x_date(date_breaks = '1 month', date_labels = '%b', expand = c(0, 0)) +
    scale_y_continuous(labels = scales::comma, expand = expansion(c(0, 0.05))) +
    labs(x = NULL, y = 'Calls per day') +
    theme_talk +
    theme(legend.position = 'top', legend.justification = 'left',
          panel.grid.major.x = element_blank())
  if (facet)
    p <- p + facet_wrap(~ site, ncol = 1) +
      theme(strip.text = element_text(hjust = 0, face = 'bold', size = 22))
  p
}

# ── (i) NS01 in detail + season totals for all three ──────────────────────────
ns01 <- daily[daily$site == 'NS01', ]
p_ns01 <- season_plot(ns01) +
  labs(title = paste0(title, ': NS01'), subtitle = subtitle)

season$site <- factor(season$site, rev(labels[buoys]))
bar <- function(x0, x1, fill) {
  geom_rect(aes(xmin = {{ x0 }}, xmax = {{ x1 }}, fill = fill,
                ymin = as.numeric(site) - 0.325, ymax = as.numeric(site) + 0.325))
}
p_tot <- ggplot(season, aes(y = site)) +
  bar(0, detected, 'detected') +
  bar(detected, detected + contact, 'contact') +
  bar(detected + contact, detected + missing, 'answers') +
  fill_scale + guides(fill = 'none') +
  geom_text(aes(x = detected + missing,
                label = sprintf('  %s missing (%.0f%%)', scales::comma(missing, 100), 100 * share)),
            hjust = 0, size = 6) +
  scale_x_continuous(labels = scales::comma, expand = expansion(c(0, 0.45))) +
  labs(x = 'Calls over the season', y = NULL, caption = caveat) +
  theme_talk +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(face = 'bold', colour = 'black'),
        plot.caption = element_text(hjust = 0, size = 15, colour = 'grey30'),
        plot.caption.position = 'plot')

save_talk(p_ns01 / p_tot + plot_layout(heights = c(2.4, 1)), 'quiet_season_ns01')

# ── (ii) three buoys on a shared y-axis ───────────────────────────────────────
p_all <- season_plot(daily, facet = TRUE) +
  labs(title = title, subtitle = subtitle, caption = caveat) +
  theme(plot.caption = element_text(hjust = 0, size = 15, colour = 'grey30'),
        plot.caption.position = 'plot')
save_talk(p_all, 'quiet_season_all', height = 9)
