# =============================================================================
# 05_sumCombined.R — One wide table across all three buoys (NS01, NS02, COX01).
#
# Assembles, in a single pass:
#   1. Regression / excitement coefficients   (reads fit/ via load_fit.R)
#        - covariates: Noise, SST
#        - harmonics:  sin + cos per period in harm_periods_lgcp
#        - alpha (excitement), delta (GP scale), eta (decay)
#   2. Expected call counts                    (reads num/ Stage-4 output)
#        - Observed (raw in-window calls), Total, Background,
#          Counter (= self-excitement)
#
# Each cell is "mean (lb95, ub95)"; coefficient means carry a trailing '*'
# when the 95% HPD excludes zero.
#
# Usage:   Rscript 05_sumCombined.R          <-- run WITHOUT --buoy.
# The script loops the three buoys internally by setting BUOY and re-sourcing
# config.R, so passing --buoy on the command line would override the loop and
# is not supported here.
#
# Outputs (fig/combined/):
#   combined_coeffs.tex / .csv
#   combined_counts.tex / .csv   (only if num/ outputs are present)
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(batchmeans); library(xtable)

source('src/design.R')  # design_columns(); config sourced in loop
source('src/RFtns.R')   # bm helpers, lb95/ub95, fmt_period; config sourced in loop

buoys       <- c('ns01', 'ns02', 'cox01')
buoy_labels <- c(ns01 = 'NS01', ns02 = 'NS02', cox01 = 'COX01')

# "mean (lo, hi)" with a significance star when the interval excludes 0.
fmt_ci <- function(x, digits) {
  m  <- mean(x)
  lo <- lb95(x); hi <- ub95(x)
  star <- if ((lo > 0) || (hi < 0)) '*' else ''
  fmt  <- paste0('%.', digits, 'f (%.', digits, 'f, %.', digits, 'f)%s')
  sprintf(fmt, m, lo, hi, star)
}

# Integer "mean (lo, hi)" for counts, using batch-means mean + HPD.
fmt_count <- function(x) {
  m  <- round(bm(x)$est)
  ci <- round(HPDinterval(as.mcmc(x)))
  sprintf('%d (%d, %d)', m, ci[1], ci[2])
}

coef_list  <- list()
count_list <- list()
param_order <- NULL   # canonical row order, captured from the first buoy

for (b in buoys) {
  Sys.setenv(BUOY = b)
  source('src/config.R')        # refresh buoy, paths, harm_periods_lgcp, fiti_lgcp, datai
  fiti <- fiti_lgcp
  burn <- NULL                  # force load_fit.R to use buoy_cfg$burn
  source('src/load_fit.R')      # postSamples, Xm, betaInd, deltaInd, alphaInd, etaInd

  # ── Coefficients ──────────────────────────────────────────────────────────
  # design_columns() owns the conditional 2-month drop and spline count, so the
  # labels track the design whether the spline is ON ('LGCPSEspl') or OFF.
  cols          <- design_columns(design_cfg())
  harm_labels   <- unlist(lapply(fmt_period(cols$periods), function(lbl)
    c(paste(lbl, 'sine'), paste(lbl, 'cosine'))))
  spline_labels <- if (cols$n_spline) paste('Spline', seq_len(cols$n_spline)) else character(0)
  Predictors    <- c('Noise', 'SST', harm_labels, spline_labels)

  postbetas <- postSamples[, betaInd[-1], drop = FALSE]   # drop intercept
  stopifnot(ncol(postbetas) == length(Predictors))

  postparams <- postSamples[, c(alphaInd, deltaInd, etaInd), drop = FALSE]
  param_block <- c('alpha (excitement)', 'delta (GP scale)', 'eta (decay)')

  allmat      <- cbind(postbetas, postparams)
  param_names <- c(Predictors, param_block)

  coef_df <- tibble(
    param = param_names,
    !!buoy_labels[[b]] := vapply(seq_len(ncol(allmat)),
                                 function(j) fmt_ci(allmat[, j], 3),
                                 character(1))
  )
  coef_list[[b]] <- coef_df
  if (is.null(param_order)) param_order <- param_names

  # ── Counts: observed (always) + modeled (Stage-4 num output, if present) ────
  # Observed = raw calls in the analysis window; data is the windowed call set
  # loaded by load_fit.R, so nrow(data) is the observed count (no interval).
  rows <- c(Observed = format(nrow(data), big.mark = ','))

  numfile <- paste0(path.num, datai, fiti, 'num.RData')
  if (file.exists(numfile)) {
    load(numfile)   # postNum: col1 = background, col2 = self-excitement
    comp <- cbind(Total                       = rowSums(postNum),
                  Background                   = postNum[, 1],
                  `Counter (self-excitement)`  = postNum[, 2])
    rows <- c(rows, vapply(seq_len(ncol(comp)),
                           function(j) fmt_count(comp[, j]), character(1)) |>
                    setNames(colnames(comp)))
  } else {
    warning(sprintf('num file missing for %s (%s) — modeled counts skipped. %s',
                    b, numfile, 'Run 04_numLGCPSE.R and rsync num/ down.'))
  }

  count_list[[b]] <- tibble(Component = names(rows),
                            !!buoy_labels[[b]] := unname(rows))

  rm(postSamples, postWm); gc()
}

# ── Merge into wide tables ────────────────────────────────────────────────────
out_dir <- file.path('fig', 'combined')
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

coef_tbl <- reduce(coef_list, full_join, by = 'param') %>%
  mutate(param = factor(param, levels = param_order)) %>%
  arrange(param) %>%
  mutate(param = as.character(param))

cat('\n=== Combined coefficients (mean (95% HPD); * = HPD excludes 0) ===\n')
print(as.data.frame(coef_tbl), row.names = FALSE)

write_csv(coef_tbl, file.path(out_dir, 'combined_coeffs.csv'))
print(xtable(coef_tbl, caption = 'LGCPSE coefficients across buoys.'),
      booktabs = FALSE, include.rownames = FALSE,
      file = file.path(out_dir, 'combined_coeffs.tex'))

if (length(count_list)) {
  count_order <- c('Observed', 'Total', 'Background', 'Counter (self-excitement)')
  count_tbl <- reduce(count_list, full_join, by = 'Component') %>%
    mutate(Component = factor(Component, levels = count_order)) %>%
    arrange(Component) %>%
    mutate(Component = as.character(Component))
  cat('\n=== Combined counts: Observed (raw) vs. modeled mean (95% HPD) ===\n')
  print(as.data.frame(count_tbl), row.names = FALSE)

  write_csv(count_tbl, file.path(out_dir, 'combined_counts.csv'))
  print(xtable(count_tbl, caption = 'Expected calls: total, background, counter.'),
        booktabs = FALSE, include.rownames = FALSE,
        file = file.path(out_dir, 'combined_counts.tex'))
} else {
  cat('\n[counts skipped — no num/ outputs found for any buoy]\n')
}

cat(sprintf('\nWrote tables to %s/\n', out_dir))
