# =============================================================================
# 05_sumRTCT.R — Random-time-change Q-Q diagnostic for the LGCPSE fit.
#
# If the compensator model is correct, the transformed inter-event times should
# be i.i.d. Exp(1); the Q-Q plot against the theoretical quantiles of the
# descending-log spacings diagnoses model fit.
#
# Usage:   Rscript 05_sumRTCT.R --buoy=ns01
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(xtable)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

load(paste0(path.rtct, datai, fiti, '_rtct.RData'))   # ts, postCompen, intlami

# postCompen columns: 1:3 = cumulative compensator quantiles (lb, med, ub)
#                     4:6 = per-event increment d quantiles     (lb, med, ub)
data.d <- data.frame(
  lb = postCompen[, 4],
  d  = postCompen[, 5],
  ub = postCompen[, 6]
)

# ── Q-Q plot ───────────────────────────────────────────────────────────────
data.qq <- data.d %>%
  arrange(d) %>%
  mutate(
    Sample      = d,
    Theoretical = log(n()) - log(n() - (row_number() - 0.5))
  )

xymax   <- max(c(data.qq$Sample, data.qq$Theoretical))
line.df <- data.frame(x = c(0, xymax), y = c(0, xymax))

data.qq <- data.qq %>% mutate(newub = pmin(ub, xymax))

plot.qqband <- data.qq %>%
  ggplot(aes(x = Theoretical)) +
  geom_ribbon(aes(ymin = lb, ymax = newub), fill = 'grey70', alpha = 0.8) +
  geom_point(aes(y = Sample), size = 0.5) +
  geom_line(aes(x = x, y = y), line.df) +
  labs(x = 'Theoretical', y = 'Sample') +
  theme_bw()

ggsave(plot = plot.qqband, width = 4, height = 4,
       filename = paste0(path.fig, 'QQband.pdf'))

# ── Mean-squared difference (empirical vs expected) ────────────────────────
tab.msd <- data.qq %>%
  summarise(msd = format(round(mean((Sample - Theoretical)^2), 3), nsmall = 3))

print(tab.msd)

tab.msd %>%
  xtable() %>%
  print(booktabs = TRUE, include.rownames = FALSE,
        file = paste0(path.fig, 'QQmsd.tex'))
