rm(list=ls())
library(coda); library(tidyverse); library(egg); library(grid)
library(ggh4x) # facet_grid2
library(batchmeans); library(foreach)
library(xtable)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}


load('data/nopp.RData')
fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')
fits <- fits[4]

ts = data$ts
maxT = ceiling(max(ts))
sback = 120 # unit = min
knts = unique(c(0, seq(0, maxT, by = sback), maxT))
m = length(knts) - 1
rho = 8 * 60 / 3 # effective range is 3 hour


## covariates ----
noise = data.frame(ts = knts) %>%
  left_join(noise)
noiseVar = as.vector(scale(noise$noise))

noise$UTC[1]
# these below have to match those in fitLGCPSE.R
Xm = cbind(
  1,
  noiseVar,
  sin(5 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)), # 4.8h
  cos(5 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)),
  sin(4 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)), # 6h
  cos(4 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)),
  sin(3 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)), # 8h
  cos(3 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)),
  sin(2 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)), # 12h
  cos(2 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)),
  sin(1 * 2 * pi * (knts + 15*60 + 1) / (24 * 60)), # 24h
  cos(1 * 2 * pi * (knts + 15*60 + 1) / (24 * 60))  # should be greater than sback*4 
)

p = ncol(Xm)

betaInd = 1:p
deltaInd = p+1

burn = 50000



# -----------------------------------------------------------------------------=
# XB  ----
# -----------------------------------------------------------------------------=

harmInd = c(3:12)

data.xb = c()
for(j in 1:length(fits)){
  # load(paste0('nopp/fit/nopp', fits[j], '.RData'))
  load('/work/rss10/sne_ns01/fit/noppLGCPSE_5c4h.RData')

  XB = postSamples[-(1:burn),betaInd] %*% t(Xm)
  XBharm = postSamples[-(1:burn),harmInd] %*% t(Xm[,harmInd])

  XBci = t(sapply(1:ncol(XB), function(ii) HPDinterval(as.mcmc(XB[,ii]))[1:2]))
  XBharmci = t(sapply(1:ncol(XBharm), function(ii) HPDinterval(as.mcmc(XBharm[,ii]))[1:2]))

  data.xb = rbind(data.xb, data.frame(fit = fits[j], ts = knts, UTC = noise$UTC, Name = 'X*B', mean = colMeans(XB), lb = XBci[,1], ub = XBci[,2]))
  data.xb = rbind(data.xb, data.frame(fit = fits[j], ts = knts, UTC = noise$UTC, Name = 'X*B with harmonics only', mean = colMeans(XBharm), lb = XBharmci[,1], ub = XBharmci[,2]))

  if(fits[j] %in% c('LGCP', 'LGCPSE')){
    XBW = postSamples[-(1:burn),betaInd] %*% t(Xm) + exp(postSamples[,deltaInd]) * postWm[-(1:burn),]
    XBWci = t(sapply(1:ncol(XBW), function(ii) HPDinterval(as.mcmc(XBW[,ii]))[1:2]))
    data.xb = rbind(data.xb, data.frame(fit = fits[j], ts = knts, UTC = noise$UTC, Name = 'X*B+W', mean = colMeans(XBW), lb = XBWci[,1], ub = XBWci[,2]))
  }
}
save(data.xb, file = 'fig/xb.RData')




# -----------------------------------------------------------------------------=
# plot ----
# -----------------------------------------------------------------------------=

load('fig/xb.RData')

fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')
fits <- fits[4]
newlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iii) NHPP+SE', '(iv) NHPP+GP+SE')
newlabs <- newlabs[4]

data.xb$fit = factor(data.xb$fit, levels = fits, labels = newlabs)

# shade = data.frame(dusk = as.POSIXlt("2009-03-29 18:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
#                    dawn = as.POSIXlt("2009-03-30 06:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
#                    top = Inf,
#                    bottom = -Inf)

library(suncalc)
dummy = getSunlightTimes(date = seq.Date(as.Date('2021-03-19'), as.Date('2021-03-20'), by = 1),
                         lat = 42, lon = -70.4, keep = c("sunrise", "sunset"), tz = "UTC")
shade = data.frame(dusk = dummy$sunset[1],
                   dawn = dummy$sunrise[2],
                   top = Inf,
                   bottom = -Inf)

plot.xb = data.xb %>% 
  # SNE NS01 Date: 2021-03-18 06:27:59; I'll choose the next full day
  filter(UTC %in% seq.POSIXt(as.POSIXlt("2021-03-19 12:00:00", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), by = 'min', length.out = 24*60+1)) %>%
  # filter(fit %in% c('(iv) NHPP+GP+SE')) %>% 
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
  labs(x = 'Hour', y = 'Effect') +
  theme_bw() +
  scale_x_datetime(date_breaks = "2 hours", date_labels = "%H") +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
plot.xb

ggsave(plot = plot.xb, width = 3, height = 2.5, 
       filename = 'fig/noppXB.pdf')
