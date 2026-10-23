# =============================================================================
# 16_sameConversation.R — Talk figure: the same kind of exchange at every buoy;
# NS02 just has more of them.
#
# Left:  exchange size. Each call draws Poisson(m) answers, m = alpha/eta (the
#        kernel is unnormalized), so an exchange started by one contact call has
#        Borel(m) calls in all: P(n) = exp(-m n) (m n)^(n-1) / n!, mean 1/(1-m).
# Right: exchanges started per day = expected contact (background) calls / days.
#
# Usage:   Rscript 16_sameConversation.R
# Input:   out/anim/<buoy>_anim.rds (alpha, eta medians), num/<buoy>/ (postNum)
# Output:  fig/talk/same_conversation.{png,pdf}, fig/talk/same_conversation.csv
# =============================================================================

source('src/talk_figs.R')
library(patchwork)
library(coda)

col_site <- c(COX01 = '#1b9e77', NS01 = '#d95f02', NS02 = '#7570b3')   # Dark2

borel <- function(n, m) exp(-m * n + (n - 1) * log(m * n) - lfactorial(n))

sizes <- c(1:4)
rows <- lapply(buoys, function(b) {
  f <- read_anim(b)$fit
  m <- f$alpha / f$eta
  pn <- borel(sizes, m)
  load(sprintf('num/%s/%sLGCPSEnum.RData', b, b))              # postNum
  per_day <- postNum[, 1] / n_days
  hpd <- HPDinterval(as.mcmc(per_day))[1, ]
  list(size = data.frame(site = labels[[b]], size = c(as.character(sizes), '5+'),
                         p = c(pn, 1 - sum(pn))),
       rate = data.frame(site = labels[[b]], m = m, mean_size = 1 / (1 - m),
                         per_day = mean(per_day), lo = hpd[1], hi = hpd[2]))
})
size <- do.call(rbind, lapply(rows, `[[`, 'size'))
rate <- do.call(rbind, lapply(rows, `[[`, 'rate'))
stopifnot(abs(sum(borel(1:2000, 0.6)) - 1) < 1e-6)
print(format(rate, digits = 3), row.names = FALSE)
write.csv(merge(rate, reshape(size, idvar = 'site', timevar = 'size', direction = 'wide')),
          'fig/talk/same_conversation.csv', row.names = FALSE)

size$site <- factor(size$site, labels[buoys])
size$size <- factor(size$size, c(as.character(sizes), '5+'))
rate$site <- factor(rate$site, rev(labels[buoys]))

p_size <- ggplot(size, aes(size, p, fill = site)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = col_site, name = NULL) +
  scale_y_continuous(labels = scales::percent, expand = expansion(c(0, 0.05))) +
  labs(title = 'How long is an exchange?',
       subtitle = sprintf('Calls per exchange, %.1f on average at every buoy',
                          mean(rate$mean_size)),
       x = 'Calls in the exchange', y = 'Share of exchanges') +
  theme_talk +
  theme(legend.position = c(0.75, 0.8), panel.grid.major.x = element_blank(),
        plot.subtitle = element_text(colour = 'grey35', size = 18))

p_rate <- ggplot(rate, aes(per_day, site, fill = site)) +
  geom_col(width = 0.6) +
  geom_errorbar(aes(xmin = lo, xmax = hi), orientation = 'y', width = 0.2,
                linewidth = 0.8, colour = 'grey15') +
  geom_text(aes(x = hi, label = sprintf('  %.0f a day', per_day)), hjust = 0, size = 7) +
  scale_fill_manual(values = col_site, guide = 'none') +
  scale_x_continuous(expand = expansion(c(0, 0.35))) +
  labs(title = 'How many exchanges start?',
       subtitle = 'Contact calls per day, Oct 2021 – Feb 2022',
       x = 'Exchanges started per day', y = NULL) +
  theme_talk +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(face = 'bold', colour = 'black'),
        plot.subtitle = element_text(colour = 'grey35', size = 18))

save_talk(p_size + p_rate + plot_layout(widths = c(1.15, 1)) +
            plot_annotation(title = 'Same conversation, different crowds',
                            theme = theme(plot.title = element_text(size = 30, face = 'bold'))),
          'same_conversation')
