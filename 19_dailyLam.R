# =============================================================================
# 19_dailyLam.R — Talk figure: expected detected calls per day at the three
# buoys on a common y-axis, split into background and answers.
#
# The daily view of 12_lamPanels.R. Integrating lambda(t) over each day
# averages out the minute-scale bursts and leaves the season's shape:
#   background = posterior median of the day's integrated mu(t)
#                (10b_paramExport.R, quiet$daily$back_actual; calls that start
#                an exchange)
#   answers    = the day's integral of sum_{t_i < t} alpha * exp(-eta (t - t_i))
#                over the detected calls, with alpha, eta at posterior medians
#                (calls triggered by an earlier call)
# Their sum is within 0.4% of the detected calls at every buoy.
#
# Usage:   Rscript 19_dailyLam.R
# Input:   out/anim/<buoy>_anim.rds (10a_animExport.R), out/anim/<buoy>_params.rds
# Output:  fig/talk/daily_lam.{png,pdf}, fig/talk/daily_lam.csv
# =============================================================================

source('src/talk_figs.R')   # buoys, labels, theme_talk, save_talk, excite_grid(), col_contact

col_answer <- '#92c5de'     # as 15_quietSeason.R

daily <- do.call(rbind, lapply(buoys, function(b) {
  x  <- read_anim(b)
  q  <- read_params(b)$quiet$daily
  tc <- sort(x$calls$ts)
  # 1-min grid: the answers' bumps halve in 1.3-2 min, and a regular grid
  # integrates them without bias.
  tg <- seq(0, max(x$background$ts), by = 1)
  ex <- tapply(excite_grid(tg, tc, x$fit$alpha, x$fit$eta), floor(tg / 1440), sum)
  ex <- ex[as.character(q$day)]; ex[is.na(ex)] <- 0
  data.frame(site = labels[[b]], date = as.Date('2021-10-01') + q$day,
             background = q$back_actual, answers = as.vector(ex),
             calls = tabulate(floor(tc / 1440) + 1, nbins = max(q$day) + 1)[q$day + 1])
}))
write.csv(daily, 'fig/talk/daily_lam.csv', row.names = FALSE)

tot <- aggregate(cbind(background, answers, calls) ~ site, daily, sum)
tot$share <- tot$answers / (tot$background + tot$answers)
print(format(tot, digits = 3, big.mark = ','), row.names = FALSE)

strip <- setNames(sprintf('%s  (%s calls, %.0f%% answers)', tot$site,
                          trimws(format(tot$calls, big.mark = ',')), 100 * tot$share), tot$site)
daily$site <- factor(daily$site, labels[buoys])

long <- rbind(data.frame(daily[, c('site', 'date')], part = 'background', n = daily$background),
              data.frame(daily[, c('site', 'date')], part = 'answers',    n = daily$answers))
long$part <- factor(long$part, c('answers', 'background'))   # background at the bottom

p <- ggplot(long, aes(date, n, fill = part)) +
  geom_area(position = 'stack') +
  facet_wrap(~ site, ncol = 1, labeller = as_labeller(strip)) +
  scale_fill_manual(values = c(background = col_contact, answers = col_answer),
                    breaks = c('background', 'answers'),
                    labels = c('Calls that start an exchange', 'Answers to an earlier call'),
                    name = NULL) +
  scale_x_date(date_breaks = '1 month', date_labels = '%b', expand = c(0, 0)) +
  scale_y_continuous(labels = scales::comma, breaks = scales::breaks_pretty(3),
                     expand = expansion(c(0, 0.05))) +
  labs(title = 'Detected calls per day',
       subtitle = 'Expected from the fitted model, split into calls that start an exchange and the answers they draw',
       x = NULL, y = 'Calls per day') +
  theme_talk +
  theme(legend.position = 'top', legend.justification = 'left',
        legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(4, 'pt'),
        panel.spacing.y = unit(14, 'pt'),
        panel.grid.major.x = element_blank(),
        strip.text = element_text(hjust = 0, face = 'bold', size = 22),
        plot.subtitle = element_text(colour = 'grey35', size = 18))

save_talk(p, 'daily_lam')
