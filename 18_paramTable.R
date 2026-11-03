# =============================================================================
# 18_paramTable.R — Talk tables: posterior mean and 95% HPD of every LGCPSE
# parameter, one gt table per buoy.
#
# Rows are grouped into the background rate (log-scale regression
# coefficients and the GP scale delta), self-excitation (alpha, eta), and two
# quantities derived per draw (answers per call alpha/eta, half-life ln2/eta).
# A coefficient is bold when its 95% HPD interval excludes zero. A combined
# table puts the buoys side by side without the harmonic terms.
#
# Usage:   Rscript 18_paramTable.R
# Input:   out/anim/<buoy>_params.rds (10b_paramExport.R)
# Output:  fig/talk/param_tables/<buoy>_params.{rds,html,png} and
#          combined_params.{rds,html,png} (all buoys, no harmonics); the .rds is the
#          gt object (readRDS() it and print, or gt::gtsave() it elsewhere)
# =============================================================================

library(gt); library(coda)
source('src/talk_figs.R')          # buoys, labels, read_params()
source('src/RFtns.R')              # lb95, ub95, fmt_period

out_dir <- 'fig/talk/param_tables'
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Harmonic columns are h<period in minutes>_<sin|cos>
param_label <- function(nm) {
  fixed <- c(intercept = 'Intercept', noise = 'Noise', sst = 'SST',
             delta = 'GP scale (δ)', alpha = 'Jump per call (α, per min)',
             eta = 'Decay rate (η, per min)')
  if (nm %in% names(fixed)) return(fixed[[nm]])
  m <- regmatches(nm, regexec('^h([0-9]+)_(sin|cos)$', nm))[[1]]
  paste0(fmt_period(as.numeric(m[2])), ' cycle, ', c(sin = 'sine', cos = 'cosine')[[m[3]]])
}

param_summary <- function(b) {
  x  <- read_params(b)
  d  <- x$draws
  d$answers  <- d$alpha / d$eta
  d$halflife <- log(2) / d$eta
  coefs <- setdiff(names(x$draws), c('delta', 'alpha', 'eta'))
  out <- data.frame(
    key   = names(d),
    group = ifelse(names(d) %in% c(coefs, 'delta'), 'Background rate (log scale)',
            ifelse(names(d) %in% c('alpha', 'eta'), 'Self-excitation', 'Derived')),
    mean  = vapply(d, mean, 0),
    lo    = vapply(d, lb95, 0),
    hi    = vapply(d, ub95, 0))
  out$label <- vapply(out$key, function(k) switch(k,
    answers  = 'Answers per call (α/η)',
    halflife = 'Answer half-life (min, ln2/η)',
    param_label(k)), '')
  # Judge on the printed (2-dp) bounds: the 2,000 thinned draws can put a
  # borderline bound just past zero (NS01 2-mo sine, -0.004) where the full
  # chain behind Table 3 does not, and a bold "-0.00" reads as a contradiction
  out$excl0 <- out$key %in% coefs & (round(out$lo, 2) > 0 | round(out$hi, 2) < 0)
  list(tab = out, meta = x$meta)
}

# sprintf keeps the sign of values that round to zero (-0.004 -> −0.00), so a
# bold interval never shows an unsigned 0.00 bound
fmt2 <- function(x) sub('^-', '\u2212', sprintf('%.2f', x))

param_gt <- function(b) {
  s <- param_summary(b)
  gt(s$tab[, c('group', 'label', 'mean', 'lo', 'hi')],
     groupname_col = 'group', rowname_col = 'label') |>
    tab_header(title = paste(labels[[b]], 'parameter estimates')) |>
    cols_label(mean = 'Posterior mean', lo = '95% HPD lower', hi = '95% HPD upper') |>
    fmt(columns = c(mean, lo, hi), fns = fmt2) |>
    tab_style(style = cell_text(weight = 'bold'),
              locations = cells_body(rows = s$tab$excl0)) |>
    tab_style(style = cell_text(weight = 'bold'), locations = cells_row_groups()) |>
    tab_source_note(paste0('Bold: coefficient whose 95% HPD interval, as printed, excludes zero ',
                           '(\u03b4, \u03b1 and \u03b7 are positive by definition).')) |>
    opt_table_font(font = google_font('Roboto')) |>
    tab_options(table.font.size = px(16), heading.title.font.size = px(22),
                heading.align = 'left', data_row.padding = px(3))
}

# All three buoys side by side, one "mean (lower, upper)" cell per buoy; the
# harmonic terms are left to the per-buoy tables
combined_gt <- function() {
  s    <- setNames(lapply(buoys, param_summary), buoys)
  keep <- !grepl('^h[0-9]+_', s[[1]]$tab$key)
  tab  <- s[[1]]$tab[keep, c('group', 'label')]
  for (b in buoys) {
    t <- s[[b]]$tab[keep, ]
    stopifnot(identical(t$key, s[[1]]$tab$key[keep]))
    tab[[b]] <- sprintf('%s (%s, %s)', fmt2(t$mean), fmt2(t$lo), fmt2(t$hi))
  }
  # No bold here: every coefficient left in the table excludes zero at every buoy
  gt(tab, groupname_col = 'group', rowname_col = 'label') |>
    tab_header(title = 'Parameter estimates by buoy') |>
    cols_label(.list = as.list(labels[buoys])) |>
    cols_align('center', columns = all_of(buoys)) |>
    tab_style(style = cell_text(weight = 'bold'), locations = cells_row_groups()) |>
    tab_source_note('Posterior mean (95% HPD). Seasonal and daily cycle terms not shown.') |>
    opt_table_font(font = google_font('Roboto')) |>
    tab_options(table.font.size = px(16), heading.title.font.size = px(22),
                heading.align = 'left', data_row.padding = px(3))
}

save_gt <- function(g, name) {
  f <- file.path(out_dir, name)
  saveRDS(g, paste0(f, '.rds'))
  gtsave(g, paste0(f, '.html'))
  gtsave(g, paste0(f, '.png'), zoom = 2, expand = 10)
  cat('Wrote ', f, '.{rds,html,png}\n', sep = '')
}

for (b in buoys) {
  m <- read_params(b)$meta
  cat(sprintf('%s: %s iterations, burn-in %s, %s draws (%s)\n', labels[[b]], m$n_iter, m$burn,
              m$draws, m$fit_file))
  if (b %in% c('ns01', 'ns02') && m$n_iter < 150000) cat('  NOTE: not the 150k fit; re-export it with 10b_paramExport.R\n')
  save_gt(param_gt(b), paste0(b, '_params'))
}
save_gt(combined_gt(), 'combined_params')
