rm(list=ls())
library(coda); library(tidyverse); library(egg); library(grid)
# library(ggh4x) # facet_grid2
library(spgs) # chisq..test
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


# fold = 'real'
fold.data = 'data'
fold.fit = 'fit' 
fold.rtct = 'rtct' 
fold.fig = 'fig' 


path.fit = paste0('/work/rss10/sne_ns01/', fold.fit, '/')
path.rtct = paste0(fold.rtct, '/')
path.fig = paste0(fold.fig, '/')
ifelse(!dir.exists(path.fig), dir.create(path.fig, recursive = T), FALSE)


path.r = paste0('src/RFtns.R')
path.cpp = paste0('src/RcppFtns.cpp')


datai = 'nopp'


data.comp = c()
data.d = c()
# j = 9 #  [9,] 5 4
for(j in c(1, 9)){
  
  if(j == 1){ # for the NHPP version
    fiti = "NHPPSE"
    load("rtct/noppNHPPSE_parallel_rtct.RData") 
  } 
  
  if(j == 9){
    fiti = paste0('LGCPSE_', comb[j, 1], 'c', comb[j, 2], 'h')
    load(paste0(path.rtct, datai, fiti, '_rtct.RData'))
  }
  
  data.comp = rbind(data.comp, data.frame(fit = fiti, ts = ts[1:nrow(postCompen)], lb = postCompen[1:nrow(postCompen),1], t = postCompen[1:nrow(postCompen),2], ub = postCompen[1:nrow(postCompen),3]))
  data.d = rbind(data.d, data.frame(fit = fiti, lb = postCompen[1:nrow(postCompen),4], d = postCompen[1:nrow(postCompen),5], ub = postCompen[1:nrow(postCompen),6]))
}

data.comp$fit = factor(data.comp$fit, levels = unique(data.comp$fit))
data.d$fit = factor(data.d$fit, levels = unique(data.comp$fit))



# -----------------------------------------------------------------------------=
# Q-Q plot ----
# -----------------------------------------------------------------------------=

data.qq = data.d %>% 
  group_by(fit) %>% 
  reframe(order = order(d), Sample = d[order], lb = lb[order], ub = ub[order],
            Theoretical = log(length(d)) - log(length(d) - (1:length(d)-0.5)))

range.qq = data.qq %>%
  group_by(fit) %>%
  reframe(x = c(0, ifelse( max(Sample) > max(Theoretical), min(c(max(Sample), max(Theoretical))), max(c(max(Sample), max(Theoretical))))),
          y = c(0, ifelse( max(Sample) > max(Theoretical), min(c(max(Sample), max(Theoretical))), max(c(max(Sample), max(Theoretical))))))

# 
# ## range of x-axis and y-axis ----
# # new.data.qq = data.qq %>% 
# #   group_by(fit) %>% 
# #   mutate(newub = ifelse(ub > max(Sample), max(max(Sample), max(Theoretical)), ub))
# 
# 
# ## common axis ---
fitlabs = c('NHPPSE', 'LGCPSE_5c4h')
groups = list(c(1, 2))
dummy = c()
for(i in 1:length(groups)){

  range_ = c(0, data.qq %>%
               filter(fit %in% fitlabs[groups[[i]]]) %>%
               select(Sample, Theoretical) %>%
               max())

  for(j in groups[[i]]){
    dummy = rbind(dummy, data.frame(fit = fitlabs[j], Sample = range_, Theoretical = range(range.qq$x)))
  }
}

new.data.qq = data.qq %>%
  group_by(fit) %>%
  mutate(newub = ifelse((fit %in% fitlabs[groups[[1]]]) & (ub > max(dummy$Sample)),
                        max(max(dummy$Sample), max(Theoretical)), ub))
# 
# 
# 
# ## Q-Q plot with uncertainty band ----
plot.qqband = new.data.qq %>%
  ggplot(aes(x = Theoretical)) +
  geom_ribbon(aes(ymin = lb, ymax = newub), fill = "grey70", alpha = 0.8) +
  geom_point(aes(y = Sample), size = 0.5) +
  geom_line(aes(x = x, y = y), range.qq) +
  geom_blank(aes(x = Theoretical, y = Sample), dummy) +
  facet_wrap(~fit, scales = 'free', nrow = 1) +
  theme_bw()
plot.qqband


ggsave(plot = plot.qqband,
       width = 6, height = 4,
       filename = 'nopp/fig/sne_ns01_noppQQband.pdf')



## mean squared difference between empirical and expected ----
data.qq %>%
  group_by(fit) %>% 
  summarise(msd = format(round(mean((Sample - Theoretical)^2), 3), nsmall = 3)) %>% 
  # t() %>% 
  as.data.frame() %>% 
  xtable() %>% 
  print(booktabs = T, include.rownames = F) 



