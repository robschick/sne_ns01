# =============================================================================
# 05_sumLam.R — Posterior intensity (background, self-excitement, total) over
# time, with a rug of raw call times on the total-intensity panel.
#
# UTC origin is std (from config.R: start of the analysis window), NOT the
# buoy-specific deployment time. `Time` in the lam RData is minutes since std.
#
# Usage:   Rscript 05_sumLam.R --buoy=ns01
# =============================================================================

rm(list = ls()); gc()
library(coda); library(tidyverse); library(grid)

source('src/config.R')
source('src/RFtns.R')

fiti <- fiti_lgcp

ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = TRUE), FALSE)

load(paste0(path.data, datai, '.RData'))    # data, noise
load(paste0(path.lam,  fiti, '_lam.RData')) # tsnew, postBack, postSE, postLam

dat.lam <- bind_rows(
  data.frame(Name = 'Background', Time = tsnew,
             lb = postBack[, 1], median = postBack[, 2], ub = postBack[, 3]),
  data.frame(Name = 'Excitement', Time = tsnew,
             lb = postSE[, 1],   median = postSE[, 2],   ub = postSE[, 3]),
  data.frame(Name = 'Total call', Time = tsnew,
             lb = postLam[, 1],  median = postLam[, 2],  ub = postLam[, 3])
) %>%
  mutate(UTC = std + Time * 60)

# ── Intensity faceted by component ─────────────────────────────────────────
plot.all <- dat.lam %>%
  ggplot() +
  geom_line(aes(x = UTC, y = median)) +
  facet_wrap(~ Name, ncol = 1) +
  labs(x = 'Date', y = 'Intensity') +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))

ggsave(plot = plot.all, width = 8, height = 5,
       filename = paste0(path.fig, 'Lam.pdf'))

# ── Total intensity with rug of raw call times ─────────────────────────────
dat.raw <- data.frame(Time = data$ts) %>%
  mutate(UTC = std + Time * 60)

plot.total.rug <- dat.lam %>%
  filter(Name == 'Total call') %>%
  ggplot() +
  geom_line(aes(x = UTC, y = median)) +
  geom_rug(aes(x = UTC), dat.raw, length = unit(0.05, 'npc'), alpha = 0.125) +
  scale_y_continuous(expand = expansion(mult = c(0, 0), add = c(0.4, 0.1))) +
  labs(x = 'Date', y = 'Total call intensity') +
  theme_bw() +
  theme(axis.text = element_text(size = 7))

ggsave(plot = plot.total.rug, width = 8, height = 4,
       filename = paste0(path.fig, 'LamTotalRug.pdf'))
