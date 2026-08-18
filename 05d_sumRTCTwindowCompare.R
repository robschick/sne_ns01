# =============================================================================
# 05d_sumRTCTwindowCompare.R — 5-month vs 7-month RTC Q-Q for NS01.
#
# Robustness check for the end-of-season over-dispersion question: does trimming
# the analysis window from 7 months (Oct 1 -> Apr 30) to 5 months (Oct 1 -> ~Mar 1)
# tighten the upper tail of the random-time-change Q-Q?
#
# NOT part of the config-driven pipeline. It reads two MANUALLY preserved local
# compensators (the 5-month fit was overwritten on the cluster; only its pulled-
# down rtct survives). Both use the standard postCompen layout from
# 04_rtctLGCPSE.R:
#   cols 1:3 = cumulative compensator quantiles (lb, med, ub)
#   cols 4:6 = per-event increment d quantiles  (lb, med, ub)   <- d ~ Exp(1) if OK
# The Q-Q transform mirrors 05_sumRTCT.R exactly.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

files <- c(
  `5-month` = 'rtct/ns01/ns01LGCPSE_rtct.5mo.RData',
  `7-month` = 'rtct/ns01/ns01LGCPSE_rtct.7mo.RData'
)

# ── Build the Q-Q frame for one window ───────────────────────────────────────
qq_one <- function(file, label) {
  e <- new.env(); load(file, envir = e)
  data.frame(lb = e$postCompen[, 4],
             d  = e$postCompen[, 5],
             ub = e$postCompen[, 6]) %>%
    arrange(d) %>%
    mutate(window      = label,
           Sample      = d,
           Theoretical = log(n()) - log(n() - (row_number() - 0.5)))
}

qq <- bind_rows(Map(qq_one, files, names(files)))

# ── Goodness of fit: mean-squared deviation from the 45-degree line ──────────
msd <- qq %>%
  group_by(window) %>%
  summarise(n   = n(),
            msd = mean((Sample - Theoretical)^2),
            # tail-only MSD: increments beyond the Exp(1) 90th pct (~2.30)
            msd_tail = mean(((Sample - Theoretical)^2)[Theoretical > qexp(0.90)]),
            .groups = 'drop')
print(msd)

lab <- setNames(sprintf('%s (MSD %.2f)', msd$window, msd$msd), msd$window)
qq   <- qq %>% mutate(window_lab = lab[window])

xymax   <- max(qq$Sample, qq$Theoretical)
line.df <- data.frame(x = c(0, xymax), y = c(0, xymax))

# ── Full-range overlay ───────────────────────────────────────────────────────
p_full <- ggplot(qq, aes(Theoretical, Sample, colour = window_lab)) +
  geom_line(aes(x, y), line.df, inherit.aes = FALSE,
            linetype = 2, colour = 'grey40') +
  geom_point(size = 0.4, alpha = 0.6) +
  scale_colour_manual(values = c('#1b9e77', '#d95f02'), name = NULL) +
  labs(x = 'Theoretical Exp(1) quantile', y = 'Sample increment',
       title = 'NS01 RTC Q-Q: 5-month vs 7-month window') +
  theme_bw() + theme(legend.position = c(0.02, 0.98),
                     legend.justification = c(0, 1))

# ── Bulk zoom (drop the extreme tail so the body is visible) ─────────────────
zmax <- qexp(0.995)   # ~5.3
p_zoom <- p_full +
  coord_cartesian(xlim = c(0, zmax), ylim = c(0, zmax)) +
  labs(title = 'NS01 RTC Q-Q (bulk zoom, <= 99.5th pct)')

dir.create('fig/ns01', recursive = TRUE, showWarnings = FALSE)
ggsave('fig/ns01/QQband_windowCompare.pdf',      p_full, width = 5, height = 5)
ggsave('fig/ns01/QQband_windowCompare_zoom.pdf', p_zoom, width = 5, height = 5)

cat('\nWrote fig/ns01/QQband_windowCompare.pdf and _zoom.pdf\n')
