# =============================================================================
# 14_volumeKnob.R — Talk figure: what +5 dB of noise does to the calls we detect.
#
# Share still detected after +5 dB = exp(beta_noise * 5 / dB_per_SD), per
# posterior draw, where dB_per_SD is the SD of RMS noise (dB re 1 uPa) across
# the buoy's knots (the model's noise covariate is standardized per buoy).
# Shown as 10 calls per buoy with the lost share grayed out.
#
# Usage:   Rscript 14_volumeKnob.R
# Input:   out/anim/<buoy>_params.rds (10b_paramExport.R), data/<buoy>_rms_data.rds
# Output:  fig/talk/volume_knob.{png,pdf}, fig/talk/volume_knob.csv
# =============================================================================

source('src/talk_figs.R')

step_db <- 5

ret <- do.call(rbind, lapply(buoys, function(b) {
  x  <- read_params(b)
  kd <- knot_db(b, x$knots)
  r  <- exp(x$draws$noise * step_db / kd$db_per_sd)
  data.frame(site = labels[[b]], db_per_sd = kd$db_per_sd,
             beta_noise = median(x$draws$noise),
             kept = median(r), kept_lo = quantile(r, 0.025, names = FALSE),
             kept_hi = quantile(r, 0.975, names = FALSE))
}))
print(format(ret, digits = 3), row.names = FALSE)
write.csv(ret, 'fig/talk/volume_knob.csv', row.names = FALSE)

ret$site <- factor(ret$site, rev(labels[buoys]))
dots <- do.call(rbind, lapply(seq_len(nrow(ret)), function(i)
  data.frame(site = ret$site[i], k = 1:10, heard = 1:10 <= round(10 * ret$kept[i]))))

p <- ggplot(dots, aes(k, site)) +
  geom_point(aes(colour = heard), size = 13) +
  geom_point(data = dots[!dots$heard, ], shape = 21, size = 13, colour = 'grey60',
             stroke = 1, fill = NA) +
  geom_text(data = ret, aes(x = 11, y = site,
                            label = sprintf('%.0f%% still detected  (%.0f–%.0f%%)',
                                            100 * kept, 100 * kept_lo, 100 * kept_hi)),
            hjust = 0, size = 7) +
  scale_colour_manual(values = c(`TRUE` = 'grey15', `FALSE` = 'grey92'), guide = 'none') +
  scale_x_continuous(limits = c(0.4, 19.5), expand = c(0, 0)) +
  labs(title = sprintf('Turn the ocean up %d dB, and we detect fewer calls', step_db),
       subtitle = 'Each row: 10 calls on a typical day, and how many we still detect when it is 5 dB noisier',
       x = NULL, y = NULL) +
  theme_talk +
  theme(axis.text.x = element_blank(), panel.grid = element_blank(),
        axis.text.y = element_text(face = 'bold', colour = 'black', size = 24),
        plot.subtitle = element_text(colour = 'grey35', size = 18))

save_talk(p, 'volume_knob', height = 5.5)
