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


load('nopp/data/nopp.RData')
fits = c('NHPP', 'LGCP', 'NHPPSE', 'LGCPSE')
# fits = c('NHPP', 'LGCP', 'LGCPSE')

burn = 10000

data.loglik = c()
for(j in 1:length(fits)){
  load(paste0('nopp/loglik/nopp', fits[j], 'loglik.RData'))
  
  data.loglik = rbind(data.loglik, 
                      data.frame(fit = fits[j], Iteration = burn + 1:length(postLogLik), negTwoLoglik = -2*postLogLik))
}

newlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iii) NHPP+SE', '(iv) NHPP+GP+SE')
# newlabs = c('(i) NHPP', '(ii) NHPP+GP', '(iv) NHPP+GP+SE')

data.loglik$fit = factor(data.loglik$fit, levels = fits, labels = newlabs)



# -----------------------------------------------------------------------------=
# Posterior distribution of -2 * loglik ----
# -----------------------------------------------------------------------------=

burn = 10000

trace.negTwoLogLik = data.loglik %>% 
  filter(Iteration > burn) %>%
  ggplot(aes(x = Iteration, y = negTwoLoglik)) +
  geom_line() +
  facet_wrap(~fit, scales = 'free', nrow = 1) +
  # facet_wrap(~fit, nrow = 1) +
  labs(x = 'Iteration', y = '-2logL')
trace.negTwoLogLik

ggsave(plot = trace.negTwoLogLik, width = 10, height = 2, filename = 'nopp/fig/noppNegTwoLogLikTrace.eps')


groups = list(c(2, 3, 4))
dummy = c()
for(i in 1:length(groups)){
  
  range_ = data.loglik %>% 
    filter(Iteration > burn) %>%
    filter(fit %in% newlabs[groups[[i]]]) %>% 
    select(negTwoLoglik) %>% 
    range()
  
  for(j in groups[[i]]){
    dummy = rbind(dummy, data.frame(fit = newlabs[j], negTwoLoglik = range_)) 
  }
}


histall.negTwoLogLik = data.loglik %>% 
  filter(Iteration >= burn) %>%
  ggplot(aes(x = negTwoLoglik)) +
  geom_histogram(aes(y = ..density..), bins = 30, color="black", fill="white") +
  facet_wrap(~fit, scales = 'free', nrow = 1) +
  labs(x = '-2logL', y = 'Density')
histall.negTwoLogLik

ggsave(plot = histall.negTwoLogLik, width = 10, height = 2, filename = 'nopp/fig/noppNegTwoLogLikHistAll.eps')


hist.negTwoLogLik = data.loglik %>% 
  filter(fit %in% newlabs[-1]) %>% 
  filter(Iteration >= burn) %>%
  ggplot(aes(x = negTwoLoglik)) +
  geom_histogram(aes(y = ..density..), bins = 50, color="black", fill="white") +
  geom_blank(data = dummy) +
  facet_wrap(~fit, scales = 'free', nrow = 1) +
  labs(x = '-2logL', y = 'Density')
hist.negTwoLogLik

ggsave(plot = hist.negTwoLogLik, width = 8, height = 2, filename = 'nopp/fig/noppNegTwoLogLikHist.eps')


# plot.negTwoLogLik = ggarrange(trace.negTwoLogLik, hist.negTwoLogLik)
# ggsave(plot = plot.negTwoLogLik, width = 10, height = 4, filename = 'nopp/fig/noppNegTwoLogLik.eps')




data.loglik %>% 
  group_by(fit) %>% 
  summarise(Mean = format(round(bm(negTwoLoglik)[[1]], 1), nsmall = 1), 
            SE = format(round(bm(negTwoLoglik)[[2]], 1), nsmall = 1)) %>% 
  t() %>% 
  xtable() %>% 
  print(booktabs = F, include.colnames = F)
  

