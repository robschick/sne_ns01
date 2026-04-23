rm(list=ls())
library(coda); library(tidyverse); library(egg); library(grid)
# library(ggh4x) # facet_grid2
library(batchmeans); library(foreach)
library(xtable)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

comb = foreach(i = 3:5, .combine = rbind) %do% {
  cbind(i, 2:4) # number of cycles, effective range of GP in hours
}
nrow(comb)


fold = 'real'
fold.data = 'data'
fold.fit = 'fit' 
fold.loglik = 'loglik' 
fold.fig = 'fig' 


path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
path.loglik = paste0(fold.loglik, '/')
path.fig = paste0(fold.fig, '/')
ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')


datai = 'nopp'



# =============================================================================-
# Compute DID ----
# =============================================================================-

load(paste0(fold.data, '/', datai, '.RData'))


ts = data$ts
maxT = ceiling(max(ts))
sback = 12 * 60 # unit = min
knts = unique(c(0, seq(0, maxT, by = sback), maxT))
m = length(knts) - 1

noise = data.frame(ts = knts) %>%
  left_join(noise)
noiseVar = as.vector(scale(noise$noise))

noise$UTC[1]

burn = 50000

# -----------------------------------------------------------------------------=
# XB  ----
# -----------------------------------------------------------------------------=


data.xb = c()
for(runID in c(9)){
  
  fiti = paste0('LGCPSE_', comb[runID, 1], 'c', comb[runID, 2], 'h')
  load(paste0(path.fit, datai, fiti, '.RData'))
  
  p = ncol(Xm)
  betaInd = 1:p
  deltaInd = p+1
  
  harmInd = c(3:p)

  XB = postSamples[-(1:burn),betaInd] %*% t(Xm)
  XBharm = postSamples[-(1:burn),harmInd] %*% t(Xm[,harmInd])

  XBci = t(sapply(1:ncol(XB), function(ii) HPDinterval(as.mcmc(XB[,ii]))[1:2]))
  XBharmci = t(sapply(1:ncol(XBharm), function(ii) HPDinterval(as.mcmc(XBharm[,ii]))[1:2]))

  data.xb = rbind(data.xb, data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B', mean = colMeans(XB), lb = XBci[,1], ub = XBci[,2]))
  data.xb = rbind(data.xb, data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B with harmonics only', mean = colMeans(XBharm), lb = XBharmci[,1], ub = XBharmci[,2]))

  # if(fiti %in% c('LGCP', 'LGCPSE')){
    XBW = postSamples[-(1:burn),betaInd] %*% t(Xm) + exp(postSamples[,deltaInd]) * postWm[-(1:burn),]
    XBWci = t(sapply(1:ncol(XBW), function(ii) HPDinterval(as.mcmc(XBW[,ii]))[1:2]))
    data.xb = rbind(data.xb, data.frame(fit = fiti, ts = knts, UTC = noise$UTC, Name = 'X*B+W', mean = colMeans(XBW), lb = XBWci[,1], ub = XBWci[,2]))
  # }
  
  save(data.xb, file = paste0(path.fig, 'xb_harmonics_rho.RData'))
}





# -----------------------------------------------------------------------------=
# plot ----
# -----------------------------------------------------------------------------=

load(paste0(path.fig, 'xb_harmonics_rho.RData'))

data.xb$fit = factor(data.xb$fit, levels = unique(data.xb$fit), labels = c('5 harmonics & effective range of 4h'))

library(suncalc)
dummy = getSunlightTimes(date = seq.Date(as.Date('2021-03-18'), as.Date('2021-03-18'), by = 1),
                         lat = 42, lon = -70.4, keep = c("sunrise", "sunset"), tz = "UTC")
shade = data.frame(dusk = as.POSIXlt(as.character(dummy$sunset[1]), tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
                   dawn = as.POSIXlt(as.character(dummy$sunrise[2]), tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
                   top = Inf,
                   bottom = -Inf)

plot.xb = data.xb %>% 
  filter(UTC %in% seq.POSIXt(as.POSIXlt("2021-03-18 06:27:00.000", tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'), 
                             by = 'hour', length.out = 365 * 24)) %>%
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
  labs(x = 'Month', y = 'Effect') +
  theme_bw() +
  scale_x_datetime(date_breaks = "1 month", date_labels = "%b") +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
plot.xb

ggsave(plot = plot.xb, width = 6, height = 3, 
       filename = paste0(path.fig, 'noppXB_harmonics_rho.pdf'))
