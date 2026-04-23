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



comb = foreach(i = 3:5, .combine = rbind) %do% {
  cbind(i, 2:4) # number of cycles, effective range of GP in hours
}
nrow(comb)


fold = 'real'
fold.data = 'data'
fold.fit = 'fit' 
fold.loglik = 'loglik' 
fold.fig = 'fig' 


path.fit = paste0('/work/rss10/sne_ns01/',  fold.fit, '/')
path.loglik = paste0( fold.loglik, '/')
path.fig = paste0( fold.fig, '/')
ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')

runID = 9
datai = 'nopp'
fiti = paste0('LGCPSE_', comb[runID, 1], 'c', comb[runID, 2], 'h')
burn = 50000

# -----------------------------------------------------------------------------=
# Credible intervals ----
# -----------------------------------------------------------------------------=

load(paste0(fold.data, '/', datai, '.RData'))
load(paste0(path.fit, datai, fiti, '.RData'))


p = length(beta)
betaInd = 1:p
deltaInd = p+1
alphaInd = p+2
etaInd = p+3

postbetas = postSamples[-(1:burn), betaInd[-1]]

Predictors = c(
  'Noise',
  'SST',
  paste0('1m ', c('sine', 'cosine')), 
  paste0('3m ', c('sine', 'cosine')), 
  paste0('6m ', c('sine', 'cosine')), 
  paste0('12m ', c('sine', 'cosine'))
  )

dat = data.frame(Mean = colMeans(postbetas), 
                 lb95 = apply(postbetas, 2, lb95), ub95 = apply(postbetas, 2, ub95),
                 lb90 = apply(postbetas, 2, lb90), ub90 = apply(postbetas, 2, ub90),
                 Predictor = Predictors)



dat$Predictor = factor(dat$Predictor, levels = rev(unique(dat$Predictor)))
dat$param = dat$Predictor
# dat = dat %>% mutate(hasZero = ifelse(CIlow <= 0 & CIup >= 0, 'Include zero', 'Do not include zero'))

dat_back <- dat %>% 
  select(c(Predictor, Mean, lb95, ub95)) %>% 
  mutate(sig = ifelse( (lb95 > 0) | (0 > ub95), '*', '')) %>%
  xtable() %>% 
  print(booktabs = F, include.rownames = F)

# Other parameters
postalphas = postSamples[-(1:burn), alphaInd] 
postdeltas = postSamples[-(1:burn), deltaInd]
postetas = postSamples[-(1:burn), etaInd]
postparams <- cbind(postalphas, postdeltas, postetas)
Predictors_params = c(
  'alpa',
  'delta',
  'eta'
)

dat_params = data.frame(Mean = colMeans(postparams), 
                 lb95 = apply(postparams, 2, lb95), ub95 = apply(postparams, 2, ub95),
                 lb90 = apply(postparams, 2, lb90), ub90 = apply(postparams, 2, ub90),
                 param = Predictors_params)

dat_excite <- dat_params %>% 
  select(c(param, Mean, lb95, ub95)) %>% 
  mutate(sig = ifelse( (lb95 > 0) | (0 > ub95), '*', '')) %>%
  xtable() %>% 
  print(booktabs = F, include.rownames = F)

latex_tbl <- bind_rows(dat, dat_params) %>%
  select(param, Mean, lb95, ub95) %>%
  mutate(sig = ifelse((lb95 > 0) | (0 > ub95), "*", "")) %>%
  xtable() %>%
  {capture.output(print(., booktabs = FALSE, include.rownames = FALSE))}

# Now wrap with cat() and write to file
cat(latex_tbl, file = "sne_ns01_background_excitement_coeffs_table.tex", sep = "\n")

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
  theme(
    legend.position = 'none',
    plot.title = element_blank()
  )
plot.ci


ggsave(plot = plot.ci, width = 4.5, height = 3,
       # file = 'nopp/fig/noppCI.eps')
       file = paste0(path.fig, datai, fiti, 'CI.pdf'))



# -----------------------------------------------------------------------------=
# Harmonic effects ----
# -----------------------------------------------------------------------------=
# load(paste0(path.fig, 'xb_harmonics_rho.RData'))
# 
# # fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')
# # newlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iii) NHPP+SE', '(iv) NHPP+GP+SE')
# # data.xb$fit = factor(data.xb$fit, levels = fits, labels = newlabs)
# 
# data.xb$fit = factor(data.xb$fit, levels = unique(data.xb$fit), labels = c('4 harmonics & effective range of 4h'))
# 
# # shade = data.frame(dusk = as.POSIXlt("2009-03-29 18:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
# #                    dawn = as.POSIXlt("2009-03-30 06:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
# #                    top = Inf,
# #                    bottom = -Inf)
# library(suncalc)
# dummy = getSunlightTimes(date = seq.Date(as.Date('2021-02-26'), as.Date('2021-02-27'), by = 1),
#                          lat = 42, lon = -70.4, keep = c("sunrise", "sunset"), tz = "UTC")
# shade = data.frame(dusk = as.POSIXlt(as.character(dummy$sunset[1]), tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
#                    dawn = as.POSIXlt(as.character(dummy$sunrise[2]), tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
#                    top = Inf,
#                    bottom = -Inf)
# 
# plot.xb = data.xb %>% 
#   # filter(UTC %in% seq.POSIXt(as.POSIXlt("2021-02-26 21:03:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), by = 'day', length.out = 365)) %>%
#   filter(UTC %in% seq.POSIXt(as.POSIXlt("2021-02-26 21:03:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), 
#                              by = 'hour', length.out = 365 * 24)) %>%
#   filter(Name == 'X*B with harmonics only') %>% 
#   ggplot() +
#   # geom_rect(data = shade,
#   #           aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
#   #           fill = 'gray50', alpha = 0.5) +
#   geom_ribbon(aes(x = UTC, ymin = lb, ymax = ub), fill = "lightsteelblue", alpha = 0.6) +
#   # geom_line(aes(x = UTC, y = ub), linetype = 'dotted') +
#   # geom_line(aes(x = UTC, y = lb), linetype = 'dotted') +
#   geom_line(aes(x = UTC, y = mean)) +
#   geom_hline(yintercept = 0, linetype = 'dashed') +
#   labs(x = 'Month', y = 'Effect') +
#   theme_bw() +
#   scale_x_datetime(date_breaks = "1 month", date_labels = "%b") +
#   theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
# plot.xb
# 
# ggsave(plot = plot.xb, width = 6, height = 3, 
#        filename = paste0(path.fig, 'noppXB_harmonics_rho.pdf'))


# -----------------------------------------------------------------------------=
# Combine figures ----
# -----------------------------------------------------------------------------=

# plot.both = ggarrange(plot.ci, plot.xb, nrow = 1)
# 
# ggsave(plot = plot.both, width = 9, height = 3, device = cairo_ps,
#        filename = 'nopp/fig/noppCInXB.eps')













