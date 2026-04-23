# =============================================================================
# benchmark_laptop_summary.R — Assemble Phase 1 laptop timing into markdown
#
# Usage:
#   Rscript src/benchmark_laptop_summary.R                # defaults to ns01
#   Rscript src/benchmark_laptop_summary.R --buoy=ns02
# =============================================================================

source('src/config.R')

benchmark_grid <- data.frame(
  combo_id = 1:8,
  rho      = c(  60,   60,   60,   60,   30,   30,   30,   30),
  sback    = c(  30,   60,  120,  180,   15,   30,   60,   90)
)

results <- list()
for (i in 1:nrow(benchmark_grid)) {
  row   <- benchmark_grid[i, ]
  label <- paste0("rho", row$rho, "_sback", sprintf("%03d", row$sback))
  fpath <- file.path('fit', buoy, 'benchmark', label, 'phase1_timing.RData')

  if (file.exists(fpath)) {
    load(fpath)
    results[[i]] <- phase1_results
  } else {
    cat(sprintf("MISSING: %s\n", fpath))
  }
}

if (length(results) == 0) stop("No results found.")

# Build markdown
lines <- c(
  sprintf("# Laptop Benchmark Results — %s (1-month subset)", toupper(buoy)),
  "",
  sprintf("**Date:** %s", Sys.Date()),
  sprintf("**Data:** %d events, %.1f days",
          results[[1]]$n_events,
          results[[1]]$m * results[[1]]$sback / (24 * 60)),
  sprintf("**Harmonics:** %d (daily, weekly)", 2),
  "",
  "## Timing Summary",
  "",
  "| Combo | rho (min) | sback (min) | Knots | Cov matrix (sec) | Time/iter (sec) | Iters/hour | Iters in 3 days | Iters in 5 days |",
  "|-------|-----------|-------------|-------|------------------|-----------------|------------|-----------------|-----------------|"
)

for (r in results) {
  lines <- c(lines, sprintf(
    "| %d | %d | %d | %d | %.1f | %.4f | %s | %s | %s |",
    r$combo_id, r$rho, r$sback, r$m,
    r$time_cov_matrix,
    r$time_per_iter,
    format(round(r$iters_per_hour), big.mark = ","),
    format(round(r$iters_in_3_days), big.mark = ","),
    format(round(r$iters_in_5_days), big.mark = ",")
  ))
}

# Add observations
lines <- c(lines, "",
  "## Observations",
  "",
  "- Covariance matrix setup scales with knot count (O(m³)), but is a one-time cost.",
  "- Per-iteration cost is dominated by the event likelihood, not grid resolution.",
  "- All combos are laptop-feasible for 1-month data.",
  ""
)

outfile <- sprintf("benchmark_laptop_results_%s.md", buoy)
writeLines(lines, outfile)
cat(sprintf("Summary written to %s\n", outfile))
