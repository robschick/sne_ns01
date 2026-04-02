rm(list = ls())
library(coda); library(tidyverse); library(egg); library(grid)
library(batchmeans); library(foreach)
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

bm_est = function(x){ bm(x)$est }
bm_se = function(x){ bm(x)$se }
hpd = function(x){ paste0('(', round(HPDinterval(as.mcmc(x))[1], 2), ',', round(HPDinterval(as.mcmc(x))[2], 2), ')') }
hpd1 = function(x){ HPDinterval(as.mcmc(x))[1] }
hpd2 = function(x){ HPDinterval(as.mcmc(x))[2] }
bm2 = function(x){ bm(x)$se }

load('nopp2/data/nopp.RData')

# =============================================================================-
# NHPP + SE ----
# =============================================================================-
fit = 'NHPPSE'
load(paste0('nopp2/fit3/nopp', fit, '.RData'))


p = length(beta)

betaInd = 1:p
etaInd = p+1
alphaInd = p+2

dim(postSamples)

burn = 1000
posterior = postSamples[-(1:burn),]

rtime / 60 / 60


# -----------------------------------------------------------------------------=
## Summary statistics ----
# -----------------------------------------------------------------------------=
par.names = c(paste0('beta', 0:(p-1)), 'eta', 'alpha') # alpha = exp(gamma)
colnames(posterior) = par.names

df.summary = data.frame(
  mean = round(apply(posterior[-(1:burn),], 2, bm_est), 2),
  median = round(apply(posterior[-(1:burn),], 2, median), 2),
  hpd = apply(posterior[-(1:burn),], 2, hpd),
  hpd1 = apply(posterior[-(1:burn),], 2, hpd1),
  hpd2 = apply(posterior[-(1:burn),], 2, hpd2),
  mcse = round(apply(posterior, 2, bm_se), 4),
  ess = round(apply(posterior, 2, ess)),
  acc = round(c(rep(Accprob[1], p), Accprob[2], 1), 2), 
  row.names = par.names) %>%
  mutate(sig = ifelse( (hpd1 > 0) | (0 > hpd2), '*', ''))

df.summary %>% dplyr::select(c(mean, hpd, mcse, ess, acc, sig))




# =============================================================================-
## Convergence check ----
# =============================================================================-
df.hpd = data.frame(t(HPDinterval(as.mcmc(posterior[-(1:burn),]))))
df.ess = data.frame(t(round(apply(posterior[-(1:burn),], 2, ess))))
df.mcse = data.frame(t(round(apply(posterior, 2, bm2), 4)))
df.acc = data.frame(t(round(c(rep(Accprob[1], p), Accprob[2], 1), 2))); colnames(df.acc) = par.names

df.posterior = cbind(data.frame(Iteration = 1:nrow(posterior)), posterior)

df.posterior = df.posterior %>% mutate(est.beta0 = cumsum(beta0)/seq_along(beta0),
                                       est.beta1 = cumsum(beta1)/seq_along(beta1),
                                       est.beta2 = cumsum(beta2)/seq_along(beta2),
                                       est.beta3 = cumsum(beta3)/seq_along(beta3),
                                       est.beta4 = cumsum(beta4)/seq_along(beta4),
                                       est.beta5 = cumsum(beta5)/seq_along(beta4),
                                       est.beta6 = cumsum(beta6)/seq_along(beta4),
                                       est.beta7 = cumsum(beta7)/seq_along(beta4),
                                       est.eta = cumsum(eta)/seq_along(eta),
                                       est.alpha = cumsum(alpha)/seq_along(alpha))




### trace plot ----
tc.beta0 = df.posterior %>% ggplot(aes(x = Iteration, y = beta0)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[0]), subtitle = paste0('ESS=', df.ess$beta0, ', MCSE=', df.mcse$beta0, ', ACC=', df.acc$beta0)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta1 = df.posterior %>% ggplot(aes(x = Iteration, y = beta1)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[1]), subtitle = paste0('ESS=', df.ess$beta1, ', MCSE=', df.mcse$beta1, ', ACC=', df.acc$beta1)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta2 = df.posterior %>% ggplot(aes(x = Iteration, y = beta2)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[2]), subtitle = paste0('ESS=', df.ess$beta2, ', MCSE=', df.mcse$beta2, ', ACC=', df.acc$beta2)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta3 = df.posterior %>% ggplot(aes(x = Iteration, y = beta3)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[3]), subtitle = paste0('ESS=', df.ess$beta3, ', MCSE=', df.mcse$beta3, ', ACC=', df.acc$beta3)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta4 = df.posterior %>% ggplot(aes(x = Iteration, y = beta4)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[4]), subtitle = paste0('ESS=', df.ess$beta4, ', MCSE=', df.mcse$beta4, ', ACC=', df.acc$beta4)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta5 = df.posterior %>% ggplot(aes(x = Iteration, y = beta5)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[5]), subtitle = paste0('ESS=', df.ess$beta5, ', MCSE=', df.mcse$beta5, ', ACC=', df.acc$beta5)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta6 = df.posterior %>% ggplot(aes(x = Iteration, y = beta6)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[6]), subtitle = paste0('ESS=', df.ess$beta6, ', MCSE=', df.mcse$beta6, ', ACC=', df.acc$beta6)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta7 = df.posterior %>% ggplot(aes(x = Iteration, y = beta7)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[7]), subtitle = paste0('ESS=', df.ess$beta7, ', MCSE=', df.mcse$beta7, ', ACC=', df.acc$beta7)) +
  theme(plot.subtitle = element_text(size = 7.4))


tc.alpha = df.posterior %>% ggplot(aes(x = Iteration, y = alpha)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(alpha), subtitle = paste0('ESS=', df.ess$alpha, ', MCSE=', df.mcse$alpha, ', ACC=', df.acc$alpha)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.eta = df.posterior %>% ggplot(aes(x = Iteration, y = eta)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(eta), subtitle = paste0('ESS=', df.ess$eta, ', MCSE=', df.mcse$eta, ', ACC=', df.acc$eta)) +
  theme(plot.subtitle = element_text(size = 7.4))



tc.all = ggarrange(tc.beta0, tc.beta1, tc.beta2, tc.beta3, 
                   tc.beta4, tc.beta5, tc.beta6, tc.beta7, 
                   tc.alpha, tc.eta, ncol = 4)


ggsave(tc.all, width = 9.5, height = 5, 
       filename = paste0('nopp2/fig/nopp', fit, 'trace.eps'))




# =============================================================================-
# NHPP + GP + SE ----
# =============================================================================-
fit = 'LGCPSE'
load(paste0('nopp2/fit3/nopp', fit, '.RData'))

p = length(beta)

betaInd = 1:p
kappaInd = p+1
phiInd = p+2
etaInd = p+3
alphaInd = p+4

dim(postSamples)

burn = 1000
posterior = postSamples[-(1:burn),-phiInd]
Accprob = Accprob[-2]

rtime / 60 / 60


# -----------------------------------------------------------------------------=
## Summary statistics ----
# -----------------------------------------------------------------------------=
par.names = c(paste0('beta', 0:(p-1)), 'kappa', 'eta', 'alpha')
colnames(posterior) = par.names

df.summary = data.frame(
  mean = round(apply(posterior[-(1:burn),], 2, bm_est), 2),
  median = round(apply(posterior[-(1:burn),], 2, median), 2),
  hpd = apply(posterior[-(1:burn),], 2, hpd),
  hpd1 = apply(posterior[-(1:burn),], 2, hpd1),
  hpd2 = apply(posterior[-(1:burn),], 2, hpd2),
  mcse = round(apply(posterior, 2, bm_se), 4),
  ess = round(apply(posterior, 2, ess)),
  acc = round(c(rep(Accprob[1], p), 1, Accprob[2], 1), 2), 
  row.names = par.names) %>%
  mutate(sig = ifelse( (hpd1 > 0) | (0 > hpd2), '*', ''))

df.summary %>% dplyr::select(c(mean, hpd, mcse, ess, acc, sig))




# =============================================================================-
## Convergence check ----
# =============================================================================-
df.hpd = data.frame(t(HPDinterval(as.mcmc(posterior[-(1:burn),]))))
df.ess = data.frame(t(round(apply(posterior[-(1:burn),], 2, ess))))
df.mcse = data.frame(t(round(apply(posterior, 2, bm2), 4)))
df.acc = data.frame(t(round(c(rep(Accprob[1], p), 1, Accprob[2], 1), 2))); colnames(df.acc) = par.names

df.posterior = cbind(data.frame(Iteration = 1:nrow(posterior)), posterior)

# df.posterior = df.posterior %>% mutate(est.beta0 = cumsum(beta0)/seq_along(beta0),
#                                        est.beta1 = cumsum(beta1)/seq_along(beta1),
#                                        est.beta2 = cumsum(beta2)/seq_along(beta2),
#                                        est.beta3 = cumsum(beta3)/seq_along(beta3),
#                                        est.beta4 = cumsum(beta4)/seq_along(beta4),
#                                        est.beta5 = cumsum(beta5)/seq_along(beta4),
#                                        est.beta6 = cumsum(beta6)/seq_along(beta4),
#                                        est.beta7 = cumsum(beta7)/seq_along(beta4),
#                                        est.kappa = cumsum(kappa)/seq_along(kappa),
#                                        est.eta = cumsum(eta)/seq_along(eta),
#                                        est.alpha = cumsum(alpha)/seq_along(alpha))




### trace plot ----
tc.beta0 = df.posterior %>% ggplot(aes(x = Iteration, y = beta0)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[0]), subtitle = paste0('ESS=', df.ess$beta0, ', MCSE=', df.mcse$beta0, ', ACC=', df.acc$beta0)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta1 = df.posterior %>% ggplot(aes(x = Iteration, y = beta1)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[1]), subtitle = paste0('ESS=', df.ess$beta1, ', MCSE=', df.mcse$beta1, ', ACC=', df.acc$beta1)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta2 = df.posterior %>% ggplot(aes(x = Iteration, y = beta2)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[2]), subtitle = paste0('ESS=', df.ess$beta2, ', MCSE=', df.mcse$beta2, ', ACC=', df.acc$beta2)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta3 = df.posterior %>% ggplot(aes(x = Iteration, y = beta3)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[3]), subtitle = paste0('ESS=', df.ess$beta3, ', MCSE=', df.mcse$beta3, ', ACC=', df.acc$beta3)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta4 = df.posterior %>% ggplot(aes(x = Iteration, y = beta4)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[4]), subtitle = paste0('ESS=', df.ess$beta4, ', MCSE=', df.mcse$beta4, ', ACC=', df.acc$beta4)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta5 = df.posterior %>% ggplot(aes(x = Iteration, y = beta5)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[5]), subtitle = paste0('ESS=', df.ess$beta5, ', MCSE=', df.mcse$beta5, ', ACC=', df.acc$beta5)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta6 = df.posterior %>% ggplot(aes(x = Iteration, y = beta6)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[6]), subtitle = paste0('ESS=', df.ess$beta6, ', MCSE=', df.mcse$beta6, ', ACC=', df.acc$beta6)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.beta7 = df.posterior %>% ggplot(aes(x = Iteration, y = beta7)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(beta[7]), subtitle = paste0('ESS=', df.ess$beta7, ', MCSE=', df.mcse$beta7, ', ACC=', df.acc$beta7)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.kappa = df.posterior %>% ggplot(aes(x = Iteration, y = kappa)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(kappa), subtitle = paste0('ESS=', df.ess$kappa, ', MCSE=', df.mcse$kappa, ', ACC=', df.acc$kappa)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.alpha = df.posterior %>% ggplot(aes(x = Iteration, y = alpha)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(alpha), subtitle = paste0('ESS=', df.ess$alpha, ', MCSE=', df.mcse$alpha, ', ACC=', df.acc$alpha)) +
  theme(plot.subtitle = element_text(size = 7.4))

tc.eta = df.posterior %>% ggplot(aes(x = Iteration, y = eta)) +
  geom_line() +
  labs(x = 'Sample size', y = expression(eta), subtitle = paste0('ESS=', df.ess$eta, ', MCSE=', df.mcse$eta, ', ACC=', df.acc$eta)) +
  theme(plot.subtitle = element_text(size = 7.4))


tc.all = ggarrange(tc.beta0, tc.beta1, tc.beta2, tc.beta3, 
                   tc.beta4, tc.beta5, tc.beta6, tc.beta7, 
                   tc.kappa, tc.alpha, tc.eta, ncol = 4)


ggsave(tc.all, width = 10.5, height = 5.5, 
       filename = paste0('nopp2/fig/nopp', fit, 'trace.eps'))


