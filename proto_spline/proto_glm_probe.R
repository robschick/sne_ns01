# =============================================================================
# proto_glm_probe.R — isolate the Phase-1 QUESTION from MCMC convergence.
#
# The full-sampler prototype couldn't show the seasonal bend because 1500 iters
# aren't converged (even the known-good baseline trended the wrong way). But the
# real Phase-1 claim is narrower: *can a natural-spline basis in the design
# represent the spring decline that harmonics alone cannot?* That is a property
# of the DESIGN MATRIX, not the MCMC. So probe it with a fast Poisson GLM on
# binned counts (drops GP + self-excitation on purpose) — it converges instantly.
#
# Compares two mean models on the same segment grid:
#   harmonics only              (= current background design)
#   harmonics + seasonal spline (= Phase-1 addition)
#
# Run from REPO ROOT:  BUOY=cox01 Rscript proto_spline/proto_glm_probe.R
# =============================================================================

rm(list = ls())
suppressMessages({library(tidyverse)})

source('src/config.R')
source('src/design.R')                     # build_design_matrix(), design_cfg()
stopifnot(buoy == 'cox01')
load(paste0(path.data, datai, '.RData'))   # data, noise

SBACK     <- 120
SPLINE_DF <- 6
outdir    <- 'proto_spline'

ts   <- data$ts
maxT <- ceiling(max(ts))
knts <- unique(c(0, seq(0, maxT, by = SBACK), maxT))
m    <- length(knts) - 1

# ── binned counts per segment [knts[i], knts[i+1]) ───────────────────────────
w  <- diff(knts)                                   # segment widths (min)
y  <- as.integer(table(cut(ts, breaks = knts, right = FALSE)))
kL <- knts[1:m]                                    # left edge = covariate location

# ── design at segment left edges, built by the shared owner (src/design.R) ───
noise_j  <- data.frame(ts = kL) %>% left_join(noise, by = 'ts')
noiseVar <- as.vector(scale(noise_j$noise)); noiseVar[is.na(noiseVar)] <- 0
sstVar   <- as.vector(noise_j$sst); sstVar[is.na(sstVar)] <- median(sstVar, na.rm = TRUE)

# Xh = spline OFF (all harmonics); Xs = spline ON — the real Phase-2 design, so
# it drops the 2-month harmonic and appends the ns() basis. Both include the
# builder's intercept column, hence the `- 1` in the glm formulas below.
Xh <- build_design_matrix(kL, noiseVar, sstVar, design_cfg(seasonal_spline = FALSE))
Xs <- build_design_matrix(kL, noiseVar, sstVar,
                          design_cfg(seasonal_spline = TRUE, spline_df = SPLINE_DF))

logw <- log(w)
fit_h <- glm(y ~ Xh - 1, family = poisson, offset = logw)
fit_s <- glm(y ~ Xs - 1, family = poisson, offset = logw)

cat(sprintf('harmonics only              : %2d cols  AIC=%.0f  resid.dev=%.0f\n',
            ncol(Xh), AIC(fit_h), deviance(fit_h)))
cat(sprintf('harmonics + seasonal spline : %2d cols  AIC=%.0f  resid.dev=%.0f\n',
            ncol(Xs), AIC(fit_s), deviance(fit_s)))
cat(sprintf('  -> spline block nets %+d cols, drops AIC by %.0f\n',
            ncol(Xs) - ncol(Xh), AIC(fit_h) - AIC(fit_s)))

# Full-rank check: dropping the 2-mo harmonic + adding the spline must not induce
# collinearity (an acceptance criterion for the Phase-2 design).
cat(sprintf('  design rank: Xh %d/%d, Xs %d/%d  (full rank: %s)\n',
            qr(Xh)$rank, ncol(Xh), qr(Xs)$rank, ncol(Xs),
            qr(Xh)$rank == ncol(Xh) && qr(Xs)$rank == ncol(Xs)))

# ── fitted per-minute rate over time (remove the width offset) ───────────────
when <- as.POSIXct(std) + kL * 60
rate <- function(f) as.vector(predict(f, type = 'response')) / w
res  <- bind_rows(
  tibble(when, rate = rate(fit_h), model = 'harmonics only'),
  tibble(when, rate = rate(fit_s), model = 'harmonics + seasonal spline'))
obs  <- tibble(when, rate = y / w)

# daily-mean smooth so the seasonal shape is legible under the diel wiggle
res_d <- res %>% mutate(day = as.Date(when)) %>%
  group_by(model, day) %>% summarise(rate = mean(rate), .groups = 'drop')
obs_d <- obs %>% mutate(day = as.Date(when)) %>%
  group_by(day) %>% summarise(rate = mean(rate), .groups = 'drop')

p <- ggplot(res_d, aes(day, rate, colour = model)) +
  geom_point(data = obs_d, aes(day, rate), inherit.aes = FALSE,
             colour = 'grey55', size = 0.7) +
  geom_line(linewidth = 0.9) +
  labs(title = 'Phase-1 probe (GLM): does a spline basis capture the spring decline?',
       subtitle = 'cox01 - daily-mean call rate; grey = observed, lines = fitted mean (GP/Hawkes excluded)',
       x = NULL, y = 'calls per minute', colour = NULL) +
  theme_bw() + theme(legend.position = 'top')

ggsave(file.path(outdir, 'proto_glm_probe.pdf'), p, width = 9, height = 4.5)
cat(sprintf('\nWrote %s/proto_glm_probe.pdf\n', outdir))
