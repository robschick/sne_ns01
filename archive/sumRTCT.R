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


fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')
fits <- fits[4]

data.comp = c()
data.d = c()
for(j in 1:length(fits)){
  # load(paste0('nopp/rtct/nopp', fits[j], 'rtct.RData'))
  # print(paste0(fits[j], ': n = ', nrow(postCompen)))
  load("/hpc/group/schicklab/sne_ns01/rtct/noppLGCPSE_5c4h_rtct.RData")
  
  data.comp = rbind(data.comp, data.frame(fit = fits[j], ts = ts[1:nrow(postCompen)], lb = postCompen[1:nrow(postCompen),1], t = postCompen[1:nrow(postCompen),2], ub = postCompen[1:nrow(postCompen),3]))
  data.d = rbind(data.d, data.frame(fit = fits[j], lb = postCompen[1:nrow(postCompen),4], d = postCompen[1:nrow(postCompen),5], ub = postCompen[1:nrow(postCompen),6]))
}

fitlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iii) NHPP+CC', '(iv) NHPP+GP+CC')
fitlabs = fitlabs[4]

data.comp$fit = factor(data.comp$fit, levels = fits, labels = fitlabs)
data.d$fit = factor(data.d$fit, levels = fits, labels = fitlabs)



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


## range of x-axis and y-axis ----
# new.data.qq = data.qq %>% 
#   group_by(fit) %>% 
#   mutate(newub = ifelse(ub > max(Sample), max(max(Sample), max(Theoretical)), ub))


## common axis ---
groups = list(c(2, 3, 4))
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



## Q-Q plot with uncertainty band ----
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
       width = 6.5, height = 1.9,
       filename = 'nopp/fig/noppQQband.pdf')


## Q-Q plot with uncertainty band (Single Model) ----
plot.qqband = data.qq %>% 
  ggplot(aes(x = Theoretical)) +
  geom_ribbon(aes(ymin = lb, ymax = ub), fill = "grey70", alpha = 0.8) +
  geom_point(aes(y = Sample), size = 0.5) +
  geom_line(aes(x = x, y = y), range.qq) +
  # geom_blank(aes(x = Theoretical, y = Sample), dummy) +
  theme_bw()
plot.qqband


# ggsave(plot = plot.qqband,
#        width = 6.5, height = 1.9,
#        filename = 'fig/sne_ns01_noppQQband.pdf')

ggsave(plot = plot.qqband,
       filename = 'fig/sne_ns01_noppQQband.png',
       device = 'png',
       dpi = 'retina',
       width = 10, height = 6.1, units = 'in')  



## mean squared difference between empirical and expected ----
data.qq %>%
  group_by(fit) %>% 
  summarise(msd = round(mean((Sample - Theoretical)^2), 3)) %>% 
  t() %>% 
  as.data.frame() %>% 
  xtable() %>% 
  print(booktabs = T, include.colnames = F) 



