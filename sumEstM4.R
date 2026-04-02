rm(list = ls())
library(coda); library(tidyverse); library(egg); library(grid)
library(batchmeans); library(foreach)
library(xtable)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}


bmmean = function(x) { format(round(bm(x)$est, 1), nsmall = 1) }
lb95 = function(x){ HPDinterval(as.mcmc(x), prob = 0.95)[1] }
ub95 = function(x){ HPDinterval(as.mcmc(x), prob = 0.95)[2] }
lb90 = function(x){ HPDinterval(as.mcmc(x), prob = 0.90)[1] }
ub90 = function(x){ HPDinterval(as.mcmc(x), prob = 0.90)[2] }


load('nopp/data/nopp.RData')

burn = 10000

# -----------------------------------------------------------------------------=
# Credible intervals ----
# -----------------------------------------------------------------------------=
load('nopp/fit/noppLGCPSE.RData')


p = length(beta)
betaInd = 1:p
kappaInd = p+1
phiInd = p+2
etaInd = p+3
alphaInd = p+4

postbetas = postSamples[-(1:burn), betaInd[-1]]


Predictors = c('Noise',
               paste0('8h ', c('sine', 'cosine')), paste0('12h ', c('sine', 'cosine')), 
               paste0('24h ', c('sine', 'cosine')))

dat = data.frame(Mean = colMeans(postbetas), 
                 lb95 = apply(postbetas, 2, lb95), ub95 = apply(postbetas, 2, ub95),
                 lb90 = apply(postbetas, 2, lb90), ub90 = apply(postbetas, 2, ub90),
                 Predictor = Predictors)



dat$Predictor = factor(dat$Predictor, levels = rev(unique(dat$Predictor)))
# dat = dat %>% mutate(hasZero = ifelse(CIlow <= 0 & CIup >= 0, 'Include zero', 'Do not include zero'))


plot.ci = dat %>% 
  ggplot(aes(y = Predictor)) +
  # geom_errorbar(aes(xmin = lb95, xmax = ub95), width = 0.2) +
  geom_point(aes(x = Mean), size = 2) +
  geom_linerange(aes(xmin = lb95, xmax = ub95)) +
  geom_linerange(aes(xmin = lb90, xmax = ub90), linewidth = 1.2) +
  geom_vline(xintercept = 0, linetype = 1, size = 0.2) +
  # scale_x_break(c(-0.25, -0.13)) +
  # scale_x_break(c(0.21, 1.77), ticklabels = c(1.8)) +
  labs(x = 'HPD interval', y = 'Covariates', title = '(a) HPD intervals for covariates')+
  guides(linetype = guide_legend(title=""),
         shape = guide_legend(title="")) +
  theme(legend.position = 'none')
plot.ci


ggsave(plot = plot.ci, width = 4.5, height = 3,
       # file = 'nopp/fig/noppCI.eps')
       file = 'nopp/fig/noppCI.pdf')


round(dat[1,1:3], 2)

# -----------------------------------------------------------------------------=
# Harmonic effects ----
# -----------------------------------------------------------------------------=

load('nopp/fig/xb.RData')

fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')
newlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iii) NHPP+SE', '(iv) NHPP+GP+SE')

data.xb$fit = factor(data.xb$fit, levels = fits, labels = newlabs)

shade = data.frame(dusk = as.POSIXlt("2009-03-29 18:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
                   dawn = as.POSIXlt("2009-03-30 06:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
                   top = Inf,
                   bottom = -Inf)

# library(suncalc)
# dummy = getSunlightTimes(date = seq.Date(as.Date('2009-03-29'), as.Date('2009-03-30'), by = 1), 
#                          lat = 42, lon = -70.4, keep = c("sunrise", "sunset"), tz = "UTC")
# shade = data.frame(dusk = dummy$sunset[1], 
#                    dawn = dummy$sunrise[2],
#                    top = Inf,
#                    bottom = -Inf)

plot.xb = data.xb %>% 
  filter(UTC %in% seq.POSIXt(as.POSIXlt("2009-03-29 12:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), by = 'min', length.out = 24*60+1)) %>% 
  filter(fit %in% c('(iv) NHPP+GP+SE')) %>% 
  filter(Name == 'X*B with harmonics only') %>% 
  ggplot() +
  geom_rect(data = shade,
            aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
            fill = 'gray50', alpha = 0.5) +
  geom_ribbon(aes(x = UTC, ymin = lb, ymax = ub), fill = "lightsteelblue", alpha = 0.6) +
  # geom_line(aes(x = UTC, y = ub), linetype = 'dotted') +
  # geom_line(aes(x = UTC, y = lb), linetype = 'dotted') +
  geom_line(aes(x = UTC, y = mean)) +
  # facet_wrap(~ fit, nrow = 1) +
  geom_hline(yintercept = 0, linetype = 'dashed') +
  labs(x = 'Hour', y = 'Harmonic diurnal effects') +
  theme_bw() +
  scale_x_datetime(date_breaks = "2 hours", date_labels = "%H") +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
plot.xb

ggsave(plot = plot.xb, width = 3, height = 2.5, device = cairo_ps,
       filename = 'nopp/fig/noppXB.eps')

ggsave(plot = plot.xb, width = 3, height = 2.5,
       filename = 'nopp/fig/noppXB.pdf')


# -----------------------------------------------------------------------------=
# Combine figures ----
# -----------------------------------------------------------------------------=

# plot.both = ggarrange(plot.ci, plot.xb, nrow = 1)
# 
# ggsave(plot = plot.both, width = 9, height = 3, device = cairo_ps,
#        filename = 'nopp/fig/noppCInXB.eps')













