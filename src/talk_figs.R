# =============================================================================
# talk_figs.R — Shared pieces for the parameter talk figures (14_–17_;
# docs/talk_figures_spec.md): buoy order, theme, export loaders, dB calibration.
# Laptop only: reads out/anim/ exports and data/, never a fit file.
# =============================================================================

library(ggplot2)
source('src/anim_schematic.R')   # col_contact, col_counter

buoys  <- c('cox01', 'ns01', 'ns02')     # west -> east, as in the paper
labels <- c(cox01 = 'COX01', ns01 = 'NS01', ns02 = 'NS02')
n_days <- 151                            # Oct 1 2021 - Mar 1 2022

theme_talk <- theme_minimal(base_size = 22) +
  theme(panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = 'white', colour = NA),
        plot.title = element_text(face = 'bold'),
        plot.title.position = 'plot',
        plot.margin = margin(10, 24, 10, 10))

save_talk <- function(p, name, width = 13.33, height = 7.5) {
  dir.create('fig/talk', recursive = TRUE, showWarnings = FALSE)
  ggsave(file.path('fig/talk', paste0(name, '.png')), p, width = width, height = height,
         dpi = 200)
  ggsave(file.path('fig/talk', paste0(name, '.pdf')), p, width = width, height = height,
         device = cairo_pdf)
  cat('Wrote fig/talk/', name, '.{png,pdf}\n', sep = '')
}

read_params <- function(b) readRDS(sprintf('out/anim/%s_params.rds', b))   # 10b_paramExport.R
read_anim   <- function(b) readRDS(sprintf('out/anim/%s_anim.rds', b))     # 10a_animExport.R

# Noise in dB re 1 uPa (RMS). The fit's noise column is scale() of a
# deployment-scaled RMS whose scale() attributes were not kept, so recover the
# affine map RMS = a + b * noise_dep from the raw 1-min RMS file.
db_calibration <- function(b) {
  rms <- readRDS(sprintf('data/%s_rms_data.rds', b))
  e <- new.env(); load(sprintf('data/%s.RData', b), envir = e)
  j  <- match(e$noise$UTC, rms$UTC); ok <- !is.na(j)
  f  <- lm(rms$RMS[j[ok]] ~ as.vector(e$noise$noise)[ok])
  r2 <- summary(f)$r.squared
  if (r2 < 0.999) stop(sprintf('%s: dB calibration R^2 = %.4f', b, r2))
  unname(coef(f))
}

# dB at each knot, and dB per unit of the model's noise covariate
knot_db <- function(b, knots) {
  cf <- db_calibration(b)
  db <- cf[1] + cf[2] * knots$noise_dep
  list(db = db, db_per_sd = sd(db, na.rm = TRUE))
}

# Excitation on a sorted grid from sorted call times, by running decay:
# O(grid + calls) instead of the grid x calls outer product.
excite_grid <- function(tg, tc, a, eta) {
  out <- numeric(length(tg))
  s <- 0; last <- tg[1]; j <- 1; n <- length(tc)
  for (k in seq_along(tg)) {
    while (j <= n && tc[j] < tg[k]) {          # add calls strictly before tg[k]
      s <- s * exp(-eta * (tc[j] - last)) + a
      last <- tc[j]; j <- j + 1
    }
    s <- s * exp(-eta * (tg[k] - last)); last <- tg[k]
    out[k] <- s
  }
  out
}
