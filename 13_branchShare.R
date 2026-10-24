# =============================================================================
# 13_branchShare.R — How many calls answer another call, at each buoy.
#
# Two views of the Stage-4 count draws (04_numLGCPSE.R), one per figure:
#   branch_share  — share of calls that are counter-calls (self-excitement),
#                   mean and 95% HPD per buoy, on a 0-100% axis
#   branch_counts — expected contact calls (background) and counter-calls as a
#                   stacked bar per buoy, with the share printed on each bar
#
# The share is taken per posterior draw (counter / (background + counter)) and
# then summarized: background and counter are strongly negatively correlated
# (they sum to ~the observed count), so dividing the summary means would give
# an interval with no meaning. Mean and HPD match combined_counts.tex.
#
# Reads only num/<buoy>/ (no fit objects), so it runs on the laptop. Re-run
# after Stage 4 is re-run on new fits.
#
# Usage:   Rscript 13_branchShare.R
# Input:   num/<buoy>/<buoy>LGCPSEnum.RData   (postNum: background, counter)
# Output:  fig/talk/branch_share.{png,pdf}, fig/talk/branch_counts.{png,pdf},
#          fig/talk/branch_share.csv
# =============================================================================

library(ggplot2)
library(coda)
source('src/anim_schematic.R')   # col_contact, col_counter

buoys  <- c('cox01', 'ns01', 'ns02')     # west -> east, as in the paper
labels <- c(cox01 = 'COX01', ns01 = 'NS01', ns02 = 'NS02')

hpd <- function(x) HPDinterval(as.mcmc(x), prob = 0.95)[1, ]

summ <- do.call(rbind, lapply(buoys, function(b) {
  load(sprintf('num/%s/%sLGCPSEnum.RData', b, b))   # postNum
  bg <- postNum[, 1]; ce <- postNum[, 2]
  share <- ce / (bg + ce)
  data.frame(site = labels[[b]], draws = nrow(postNum),
             background = mean(bg), background_lo = hpd(bg)[1], background_hi = hpd(bg)[2],
             counter = mean(ce), counter_lo = hpd(ce)[1], counter_hi = hpd(ce)[2],
             share = mean(share), share_lo = hpd(share)[1], share_hi = hpd(share)[2])
}))
summ$site <- factor(summ$site, rev(labels[buoys]))   # first buoy on top
print(format(summ, digits = 3), row.names = FALSE)

dir.create('fig/talk', recursive = TRUE, showWarnings = FALSE)
write.csv(summ, 'fig/talk/branch_share.csv', row.names = FALSE)

pct <- function(x) sprintf('%.0f%%', 100 * x)

theme_talk <- theme_minimal(base_size = 22) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        axis.text.y = element_text(face = 'bold', colour = 'black'),
        plot.background = element_rect(fill = 'white', colour = NA),
        plot.margin = margin(6, 24, 6, 6))

# ── Share of calls that are counter-calls ────────────────────────────────────
p_share <- ggplot(summ, aes(share, site)) +
  geom_vline(xintercept = 0.5, colour = 'grey75', linetype = 'dashed') +
  geom_pointrange(aes(xmin = share_lo, xmax = share_hi), colour = col_counter,
                  size = 1.2, linewidth = 1.5) +
  geom_text(aes(label = sprintf('%s (%s–%s)', pct(share), pct(share_lo), pct(share_hi))),
            nudge_y = 0.3, size = 6) +
  scale_x_continuous(labels = scales::percent, limits = c(0, 1),
                     breaks = seq(0, 1, 0.25), expand = c(0.01, 0)) +
  labs(x = 'Share of calls that answer another call', y = NULL) +
  theme_talk

ggsave('fig/talk/branch_share.png', p_share, width = 11, height = 4.5, dpi = 200)
ggsave('fig/talk/branch_share.pdf', p_share, width = 11, height = 4.5, device = cairo_pdf)

# ── Expected calls: contact calls + counter-calls ────────────────────────────
long <- rbind(
  data.frame(site = summ$site, part = 'Contact calls', n = summ$background),
  data.frame(site = summ$site, part = 'Counter-calls', n = summ$counter))
long$part <- factor(long$part, c('Counter-calls', 'Contact calls'))   # contact on the left

xmax <- max(summ$background + summ$counter)

p_counts <- ggplot(long, aes(n, site, fill = part)) +
  geom_col(width = 0.6) +
  # HPD of the split between the two parts
  geom_errorbar(data = summ, aes(xmin = background_lo, xmax = background_hi, y = site),
                inherit.aes = FALSE, orientation = 'y', width = 0.2, linewidth = 0.8,
                colour = 'grey15') +
  geom_text(data = summ, aes(x = background + counter, y = site,
                             label = sprintf('%s counter-calls', pct(share))),
            inherit.aes = FALSE, hjust = -0.05, size = 6) +
  scale_fill_manual(values = c('Contact calls' = col_contact, 'Counter-calls' = col_counter),
                    breaks = c('Contact calls', 'Counter-calls'), name = NULL) +
  scale_x_continuous(labels = scales::comma, limits = c(0, xmax * 1.35),
                     expand = c(0, 0)) +
  labs(x = 'Expected calls, Oct 2021 – Feb 2022', y = NULL) +
  theme_talk +
  theme(legend.position = 'top', legend.justification = 'left')

ggsave('fig/talk/branch_counts.png', p_counts, width = 11, height = 5, dpi = 200)
ggsave('fig/talk/branch_counts.pdf', p_counts, width = 11, height = 5, device = cairo_pdf)

cat('Wrote fig/talk/branch_share.* and fig/talk/branch_counts.*\n')
