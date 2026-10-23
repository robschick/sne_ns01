# =============================================================================
# 17_rateDrivers.R — Talk figure: what moved the detected call rate, day by day.
#
# The background is log mu = intercept + noise + SST + harmonics + GP, so each
# piece multiplies the rate. Per day, each piece is shown as
# exp(daily mean of its log contribution - its season mean): 2 = doubled the
# rate that day, 0.5 = halved it. Answering is the daily ratio of total to
# background expected calls, (mu + excitation) / mu, left uncentred so 1x means
# no answers that day (centring would put call-free days below 1x).
#
# Pieces are posterior medians per knot (10b_paramExport.R); answering uses
# the plug-in alpha, eta medians from the animation export, as in 12_lamPanels.R.
#
# Usage:   Rscript 17_rateDrivers.R
# Input:   out/anim/<buoy>_params.rds, out/anim/<buoy>_anim.rds
# Output:  fig/talk/rate_drivers_<buoy>.{png,pdf}
# =============================================================================

source('src/talk_figs.R')

pieces <- c(noise = 'Noise (what we can detect)', sst = 'Water temperature',
            harm  = 'Seasonal cycles (1 day to 2 months)',
            gp    = 'Leftover: what the covariates miss')

model_day <- function(ts) pmin(floor(ts / 1440), n_days - 1)

drivers <- function(b) {
  k   <- read_params(b)$knots
  day <- model_day(k$ts)
  d <- do.call(rbind, lapply(names(pieces), function(nm) {
    v <- tapply(k[[nm]], day, mean)
    data.frame(component = pieces[[nm]], day = as.integer(names(v)),
               factor = exp(v - mean(v)))
  }))

  a  <- read_anim(b)
  bg <- a$background
  ex <- excite_grid(bg$ts, sort(a$calls$ts), a$fit$alpha, a$fit$eta)
  bday <- model_day(bg$ts)
  ratio <- tapply(bg$mu + ex, bday, sum) / tapply(bg$mu, bday, sum)
  typical <- exp(mean(log(ratio)))
  ans <- data.frame(component = sprintf('Answering (1x = no answers that day; typically x%.1f)',
                                        typical),
                    day = as.integer(names(ratio)), factor = as.vector(ratio))

  out <- rbind(d, ans)
  out$component <- factor(out$component, c(unname(pieces), ans$component[1]))
  out$date <- as.Date('2021-10-01') + out$day
  out
}

for (b in buoys) {
  d <- drivers(b)
  rng <- tapply(d$factor, d$component, function(f) diff(log(range(f))))
  cat(sprintf('%s  swing (log range) by component:\n', labels[[b]])); print(round(rng, 2))

  p <- ggplot(d, aes(date, factor)) +
    geom_hline(yintercept = 1, colour = 'grey60') +
    geom_line(linewidth = 0.8, colour = 'grey15') +
    facet_wrap(~ component, ncol = 1) +
    scale_y_log10(breaks = 10^(-3:3), labels = function(x) paste0(format(x, drop0trailing = TRUE,
                                                                        scientific = FALSE), 'x')) +
    scale_x_date(date_breaks = '1 month', date_labels = '%b', expand = c(0.01, 0)) +
    labs(title = sprintf('What moved the call rate at %s', labels[[b]]),
         subtitle = 'Each line multiplies the detected call rate; 1x is a typical day for that driver',
         x = NULL, y = NULL) +
    theme_talk +
    theme(strip.text = element_text(hjust = 0, face = 'bold', size = 17),
          axis.text.y = element_text(size = 14),
          panel.grid.major.y = element_line(colour = 'grey92'),
          panel.grid.major.x = element_blank(),
          panel.spacing.y = unit(1, 'lines'),
          plot.subtitle = element_text(colour = 'grey35', size = 17))

  save_talk(p, paste0('rate_drivers_', b), height = 9)
}
