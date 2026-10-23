# =============================================================================
# 12_lamPanels.R — Talk figure: total call intensity at the three buoys on a
# common y-axis, with a rug of detected calls.
#
# Built from the animation exports (10a_animExport.R), which hold the current
# fit for every buoy (NS01/NS02 5-month refits, clean-timestamp COX01):
#
#   lambda(t) = mu(t) + sum_{t_i < t} alpha * exp(-eta * (t - t_i))
#
# with mu(t) the posterior-median background on the export's 5-min grid and
# alpha, eta at their posterior medians (a plug-in, not the posterior median of
# lambda that 05_sumLam.R plots on its 2,000-point grid). Rates in calls/hour.
#
# Usage:   Rscript 12_lamPanels.R
# Input:   out/anim/<buoy>_anim.rds
# Output:  fig/talk/lam_panels.png, fig/talk/lam_panels.pdf
# =============================================================================

library(ggplot2)

buoys  <- c('cox01', 'ns01', 'ns02')     # west -> east, as in the paper
labels <- c(cox01 = 'COX01', ns01 = 'NS01', ns02 = 'NS02')

# Excitation on a sorted grid from sorted call times, by running decay:
# O(grid + calls) instead of the grid x calls outer product.
excite_grid <- function(tg, tc, a, eta) {
  out <- numeric(length(tg))
  s <- 0; last <- tg[1]; j <- 1; n <- length(tc)
  for (k in seq_along(tg)) {
    while (j <= n && tc[j] < tg[k]) {          # add calls strictly before tg[k]
      s <- s * exp(-eta * (tc[j] - last)) + a
      last <- tc[j]; j <- j + 1
    }
    s <- s * exp(-eta * (tg[k] - last)); last <- tg[k]
    out[k] <- s
  }
  out
}

rates <- list(); calls <- list()
for (b in buoys) {
  x  <- readRDS(sprintf('out/anim/%s_anim.rds', b))
  bg <- x$background
  ex <- excite_grid(bg$ts, sort(x$calls$ts), x$fit$alpha, x$fit$eta)
  rates[[b]] <- data.frame(site = labels[[b]], stamp = bg$stamp,
                           lambda = 60 * (bg$mu + ex), mu = 60 * bg$mu)
  calls[[b]] <- data.frame(site = labels[[b]], stamp = x$calls$stamp)
  cat(sprintf('%-5s %6d calls  peak %.0f calls/h  integral %.0f\n', labels[[b]],
              nrow(x$calls), max(rates[[b]]$lambda),
              sum(rates[[b]]$lambda) * 5 / 60))
}
rates <- do.call(rbind, rates); calls <- do.call(rbind, calls)

n_calls <- table(calls$site)
strip   <- setNames(sprintf('%s  (%s calls)', names(n_calls),
                            trimws(format(as.integer(n_calls), big.mark = ','))), names(n_calls))
rates$site <- factor(rates$site, labels[buoys])
calls$site <- factor(calls$site, labels[buoys])

ymax  <- max(rates$lambda)
rug_y <- c(-0.16, -0.04) * ymax           # rug band below zero

p <- ggplot(rates, aes(stamp, lambda)) +
  geom_segment(data = calls, aes(x = stamp, xend = stamp, y = rug_y[1], yend = rug_y[2]),
               inherit.aes = FALSE, alpha = 0.12, linewidth = 0.3) +
  geom_line(linewidth = 0.35) +
  facet_wrap(~ site, ncol = 1, labeller = as_labeller(strip)) +
  scale_x_datetime(date_breaks = '1 month', date_labels = '%b', expand = c(0.01, 0)) +
  scale_y_continuous(breaks = scales::breaks_pretty(4), expand = c(0, 0),
                     limits = c(rug_y[1] - 0.02 * ymax, ymax * 1.04)) +
  labs(x = NULL, y = 'Calls per hour') +
  theme_bw(base_size = 22) +
  theme(strip.background = element_blank(),
        strip.text = element_text(hjust = 0, face = 'bold', size = 22),
        panel.grid.minor = element_blank(),
        panel.spacing.y = unit(0.8, 'lines'))

dir.create('fig/talk', recursive = TRUE, showWarnings = FALSE)
ggsave('fig/talk/lam_panels.png', p, width = 13.33, height = 7.5, dpi = 200, bg = 'white')
ggsave('fig/talk/lam_panels.pdf', p, width = 13.33, height = 7.5, bg = 'white')
