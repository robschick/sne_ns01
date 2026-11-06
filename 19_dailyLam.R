# =============================================================================
# 19_dailyLam.R — Talk figure: expected detected calls per day at the three
# buoys on a common y-axis, split into background and answers.
#
# The daily view of 12_lamPanels.R. Integrating lambda(t) over each day
# averages out the minute-scale bursts and leaves the season's shape:
#   background = posterior median of the day's integrated mu(t)
#                (10b_paramExport.R, quiet$daily$back_actual; calls that start
#                an exchange)
#   answers    = the day's exact integral of sum_{t_i < t} alpha * exp(-eta (t - t_i))
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

# Each call's bump, integrated exactly over its own day and the next (the bump
# halves in 1.3-2 min, so nothing reaches a third day), cut off at the window
# end T. Days are model days (day 0 = Oct 1, 1440 min each).
answers_by_day <- function(tc, alpha, eta, T, days) {
  d0  <- floor(tc / 1440)
  cum <- function(t) alpha / eta * (1 - exp(-eta * pmax(pmin(t, T) - tc, 0)))   # bump area up to t
  b0  <- 1440 * (d0 + 1)
  own <- tapply(cum(b0), d0, sum)
  nxt <- tapply(cum(b0 + 1440) - cum(b0), d0 + 1, sum)
  out <- setNames(numeric(length(days)), days)
  out[names(own)[names(own) %in% names(out)]] <- own[names(own) %in% names(out)]
  k <- names(nxt)[names(nxt) %in% names(out)]
  out[k] <- out[k] + nxt[k]
  as.vector(out)
}

daily <- do.call(rbind, lapply(buoys, function(b) {
  x  <- read_anim(b)
  p  <- read_params(b)
  q  <- p$quiet$daily
  tc <- sort(x$calls$ts)
  # Window end = the model's maxT (last knot), not the 5-min background grid,
  # which can stop up to 5 min short.
  ex <- answers_by_day(tc, x$fit$alpha, x$fit$eta, max(p$knots$ts), q$day)
  data.frame(site = labels[[b]], date = as.Date('2021-10-01') + q$day,
             background = q$back_actual, answers = as.vector(ex),
             calls = tabulate(floor(tc / 1440) + 1, nbins = max(q$day) + 1)[q$day + 1])
}))
write.csv(daily, 'fig/talk/daily_lam.csv', row.names = FALSE)

tot <- aggregate(cbind(background, answers, calls) ~ site, daily, sum)
tot$share <- tot$answers / (tot$background + tot$answers)
print(format(tot, digits = 3, big.mark = ','), row.names = FALSE)

strip <- setNames(sprintf('%s  (%s calls)', tot$site,
                          trimws(format(tot$calls, big.mark = ','))), tot$site)
daily$site <- factor(daily$site, labels[buoys])

long <- rbind(data.frame(daily[, c('site', 'date')], part = 'background', n = daily$background),
              data.frame(daily[, c('site', 'date')], part = 'answers',    n = daily$answers))
long$part <- factor(long$part, c('answers', 'background'))   # background at the bottom

p <- ggplot(long, aes(date, n, fill = part)) +
  geom_area(position = 'stack') +
  facet_wrap(~ site, ncol = 1, labeller = as_labeller(strip)) +
  scale_fill_manual(values = c(background = col_contact, answers = col_answer),
                    breaks = c('background', 'answers'),
                    labels = c('Contact calls', 'Counter-calls'),   # as branch_counts.png
                    name = NULL) +
  scale_x_date(date_breaks = '1 month', date_labels = '%b', expand = c(0, 0)) +
  scale_y_continuous(labels = scales::comma, breaks = scales::breaks_pretty(3),
                     expand = expansion(c(0, 0.05))) +
  labs(x = NULL, y = 'Calls per day') +
  theme_talk +
  theme(legend.position = 'bottom', legend.justification = 'left',
        legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(8, 'pt'),
        panel.spacing.y = unit(14, 'pt'),
        panel.grid.major.x = element_blank(),
        strip.text = element_text(hjust = 0, face = 'bold', size = 22))

save_talk(p, 'daily_lam')
