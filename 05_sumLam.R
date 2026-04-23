rm(list=ls()); gc()
library(coda); library(tidyverse); library(egg); library(grid)
# library(ggh4x) # facet_grid2
library(spgs) # chisq.unif.test
library(batchmeans); library(foreach)
library(xtable)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

theme_set(theme_bw())


fold = 'real'
fold.data = 'data'
fold.fit = 'fit' 
fold.fig = 'fig' 
fold.lam = 'lam'

path.data = paste0(fold.data, '/')
# path.fit = paste0('/work/bk232/upcallHawkes/schannel_rev/', fold, '/', fold.fit, '/')
path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
path.fig = paste0(fold.fig, '/')
path.lam = paste0(fold.lam, '/')


datai = 'nopp'
fiti = 'LGCPSE_5c4h'

# =============================================================================-
# Load results ----
# =============================================================================-

load(paste0(path.data, datai, '.RData'))
# load(paste0(path.fit, datai, fiti, '.RData'))
load(paste0(path.lam, fiti, '_lam.RData'))

ts = data$ts # unit is minutes


burn = 50000

dat.lam = rbind(
  data.frame(
    Name = 'Backgound', Time = tsnew,
    lb = postBack[,1], median = postBack[,2], ub = postBack[,3]
  ),
  data.frame(
    Name = 'Excitement', Time = tsnew,
    lb = postSE[,1], median = postSE[,2], ub = postSE[,3]
  ),
  data.frame(
    Name = 'Total call', Time = tsnew,
    lb = postLam[,1], median = postLam[,2], ub = postLam[,3]
  )
)


dat.lam = dat.lam %>% 
  mutate(UTC = as.POSIXct(Time * 60, origin = '2021-03-18 06:27:59.000', tz = "UTC", format = '%Y-%m-%d %H:%M:%S'))

library(suncalc)

dummy = getSunlightTimes(
  date = seq.Date(as.Date('2021-03-18'), as.Date('2021-03-18'), by = 1),
  lat = 42, lon = -70.4, keep = c("sunrise", "sunset"), tz = "EST"
)

shade = data.frame(
  dusk = as.POSIXlt(as.character(dummy$sunset[-length(as.character(dummy$sunset))]), tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
  dawn = as.POSIXlt(as.character(dummy$sunrise[-1]), tz = 'UTC', format = '%Y-%m-%d %H:%M:%S'),
  top = Inf,
  bottom = -Inf
)


plot.all = dat.lam %>% 
  ggplot() +
  # geom_rect(data = shade,
  #           aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
  #           fill = 'gray50', alpha = 0.5) +
  # geom_ribbon(aes(x = UTC, ymin = lb, ymax = ub), fill = "lightsteelblue", alpha = 0.6) +
  geom_line(aes(x = UTC, y = median)) +
  facet_wrap(~Name, ncol = 1) +
  labs(x = 'Date', y = 'Intensity') +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))

plot.all

ggsave(plot = plot.all, width = 8, height = 5, 
       filename = paste0(path.fig, datai, 'Lam.pdf'))



# -----------------------------------------------------------------------------=
# Rug plot 
# -----------------------------------------------------------------------------=

dat.raw = data.frame(
  Time = data$ts
)

head(dat.raw)

dat.raw = dat.raw %>% 
  mutate(UTC = as.POSIXct(Time * 60, origin = '2021-03-18 06:27:59.000', tz = "UTC", format = '%Y-%m-%d %H:%M:%S'))


plot.total.rug = dat.lam %>% 
  filter(Name == 'Total call') %>% 
  ggplot() +
  # geom_rect(data = shade,
  #           aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
  #           fill = 'gray50', alpha = 0.5) +
  # geom_ribbon(aes(x = UTC, ymin = lb, ymax = ub), fill = "lightsteelblue", alpha = 0.6) +
  geom_line(aes(x = UTC, y = median)) +
  geom_rug(aes(x = UTC), dat.raw, length = unit(0.05, "npc"), alpha = 0.125) +
  scale_y_continuous(expand = expand_scale(mult = c(0, 0), add = c(0.4, 0.1))) +
  labs(x = 'Date', y = 'Total call intensity') +
  theme_bw() +
  # theme(axis.text.x = element_text(angle = 45, hjust = 0.3, vjust = 0.5))
  theme(
    axis.text= element_text(size = 7)
  )

plot.total.rug  

ggsave(plot = plot.total.rug, width = 8, height = 4,
       filename = paste0(path.fig, datai, 'LamTotalRug.pdf'))

