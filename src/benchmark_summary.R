# =============================================================================
# benchmark_summary.R — Cross-configuration comparison
#
# Loads Phase 1 timing and Phase 2 posteriors from all benchmark combos.
# Produces timing tables, parameter comparison plots, and signal leakage
# analysis.
#
# Usage:
#   Rscript src/benchmark_summary.R
#
# Expects results in fit/benchmark/rho*_sback*/ directories.
# =============================================================================

rm(list = ls())
library(coda); library(tidyverse); library(batchmeans)

source('src/benchmark_config.R')


# ── Helper functions ─────────────────────────────────────────────────────────

lb95 <- function(x) HPDinterval(as.mcmc(x), prob = 0.95)[1]
ub95 <- function(x) HPDinterval(as.mcmc(x), prob = 0.95)[2]
lb90 <- function(x) HPDinterval(as.mcmc(x), prob = 0.90)[1]
ub90 <- function(x) HPDinterval(as.mcmc(x), prob = 0.90)[2]


# =============================================================================-
# 1. Load Phase 1 timing results ----
# =============================================================================-

cat("=== Loading Phase 1 timing results ===\n")

timing_list <- list()
for (i in 1:nrow(benchmark_grid)) {
  row   <- benchmark_grid[i, ]
  label <- paste0("rho", row$rho, "_sback", sprintf("%03d", row$sback))
  fpath <- file.path(path_base, fold.fit, 'benchmark', label, 'phase1_timing.RData')

  if (file.exists(fpath)) {
    load(fpath)
    timing_list[[i]] <- as.data.frame(phase1_results)
    cat(sprintf("  Loaded combo %d: %s\n", i, label))
  } else {
    cat(sprintf("  MISSING combo %d: %s\n", i, label))
  }
}

if (length(timing_list) == 0) {
  stop("No Phase 1 results found. Run benchmark_fit.R first.")
}

timing_df <- bind_rows(timing_list)

cat("\n=== Phase 1 Timing Summary ===\n")
print(timing_df %>%
        select(combo_id, rho, sback, m, time_per_iter,
               iters_per_hour, iters_in_3_days, iters_in_5_days) %>%
        as.data.frame(),
      row.names = FALSE)

write.csv(timing_df,
          file.path(bench_path_fig, "timing_summary.csv"),
          row.names = FALSE)


# =============================================================================-
# 2. Timing plots ----
# =============================================================================-

timing_df$sback_label <- paste0(timing_df$sback, " min")
timing_df$rho_label   <- paste0("rho = ", timing_df$rho, " min")

# Time per iteration vs knot count
p_timing <- ggplot(timing_df, aes(x = m, y = time_per_iter,
                                   colour = rho_label, shape = rho_label)) +
  geom_point(size = 3) +
  geom_line() +
  geom_text(aes(label = sback_label), vjust = -1, size = 3) +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "Computational cost vs. grid resolution",
    x = "Number of knots (m)",
    y = "Time per iteration (seconds, log scale)",
    colour = "GP range", shape = "GP range"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(bench_path_fig, "timing_comparison.pdf"),
       plot = p_timing, width = 8, height = 5)
cat("\nSaved timing_comparison.pdf\n")

# Projected iterations within budget
p_budget <- timing_df %>%
  pivot_longer(cols = c(iters_in_3_days, iters_in_5_days),
               names_to = "budget", values_to = "max_iters") %>%
  mutate(budget = ifelse(budget == "iters_in_3_days", "3-day budget", "5-day budget")) %>%
  ggplot(aes(x = factor(sback), y = max_iters,
             fill = rho_label)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 150000, linetype = "dashed", colour = "red") +
  annotate("text", x = 0.5, y = 155000, label = "150k target",
           hjust = 0, colour = "red", size = 3) +
  facet_wrap(~ budget) +
  labs(
    title = "Feasible iterations within time budget",
    x = "sback (minutes)",
    y = "Maximum iterations",
    fill = "GP range"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(bench_path_fig, "budget_feasibility.pdf"),
       plot = p_budget, width = 10, height = 5)
cat("Saved budget_feasibility.pdf\n")


# =============================================================================-
# 3. Load Phase 2 posteriors ----
# =============================================================================-

cat("\n=== Loading Phase 2 posterior results ===\n")

# Parameter names for the benchmark harmonics:
# intercept, noise, sst, then 5 harmonics × (sin, cos) = 10
param_names <- c("Intercept", "Noise", "SST",
                 "Daily sin", "Daily cos",
                 "Weekly sin", "Weekly cos",
                 "Biweekly sin", "Biweekly cos",
                 "Monthly sin", "Monthly cos",
                 "Bimonthly sin", "Bimonthly cos",
                 "delta", "alpha", "eta")

posterior_list <- list()
for (i in 1:nrow(benchmark_grid)) {
  row   <- benchmark_grid[i, ]
  label <- paste0("rho", row$rho, "_sback", sprintf("%03d", row$sback))
  fpath <- file.path(path_base, fold.fit, 'benchmark', label, 'phase2_fit.RData')

  if (!file.exists(fpath)) {
    cat(sprintf("  MISSING combo %d: %s (Phase 2)\n", i, label))
    next
  }

  load(fpath)
  cat(sprintf("  Loaded combo %d: %s (%d samples)\n",
              i, label, nrow(postSamples)))

  # Determine burn-in: use first 1/3 of samples
  n_samples <- nrow(postSamples)
  burn_i    <- floor(n_samples / 3)
  post_burn <- postSamples[(burn_i + 1):n_samples, ]

  p_i <- ncol(post_burn) - 3  # last 3 columns: delta, alpha, eta

  # Build summary for each parameter
  for (j in 1:ncol(post_burn)) {
    if (j <= p_i) {
      pname <- if (j <= length(param_names)) param_names[j] else paste0("beta_", j)
    } else if (j == p_i + 1) {
      pname <- "delta"
    } else if (j == p_i + 2) {
      pname <- "alpha"
    } else {
      pname <- "eta"
    }

    vals <- post_burn[, j]
    posterior_list[[length(posterior_list) + 1]] <- data.frame(
      combo_id  = i,
      rho       = row$rho,
      sback     = row$sback,
      label     = label,
      parameter = pname,
      mean      = mean(vals),
      median    = median(vals),
      lb95      = lb95(vals),
      ub95      = ub95(vals),
      lb90      = lb90(vals),
      ub90      = ub90(vals),
      n_samples = nrow(post_burn),
      stringsAsFactors = FALSE
    )
  }
}

if (length(posterior_list) == 0) {
  cat("\nNo Phase 2 results found. Skipping posterior comparison plots.\n")
  cat("Run benchmark_fit.R with --full to generate Phase 2 results.\n")
  quit(save = "no")
}

post_df <- bind_rows(posterior_list)
post_df$rho_label <- paste0("rho = ", post_df$rho)
post_df$sback_label <- factor(paste0(post_df$sback, " min"),
                               levels = paste0(sort(unique(post_df$sback)), " min"))

write.csv(post_df,
          file.path(bench_path_fig, "posterior_summary.csv"),
          row.names = FALSE)


# =============================================================================-
# 4. Key parameter comparison: alpha, eta, delta ----
# =============================================================================-

key_params <- c("alpha", "eta", "delta")
df_key <- post_df %>% filter(parameter %in% key_params)
df_key$parameter <- factor(df_key$parameter, levels = key_params)

p_key <- ggplot(df_key, aes(x = sback_label, y = mean, colour = rho_label)) +
  geom_point(size = 2, position = position_dodge(width = 0.4)) +
  geom_linerange(aes(ymin = lb95, ymax = ub95),
                 position = position_dodge(width = 0.4), linewidth = 0.4) +
  geom_linerange(aes(ymin = lb90, ymax = ub90),
                 position = position_dodge(width = 0.4), linewidth = 1.0) +
  facet_wrap(~ parameter, scales = "free_y", ncol = 1) +
  labs(
    title = "Key parameters across grid resolutions",
    subtitle = "Thin lines = 95% HPD, thick lines = 90% HPD",
    x = "sback",
    y = "Posterior estimate",
    colour = "GP range"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(bench_path_fig, "parameter_comparison.pdf"),
       plot = p_key, width = 8, height = 10)
cat("Saved parameter_comparison.pdf\n")


# =============================================================================-
# 5. Beta (covariate) comparison ----
# =============================================================================-

beta_params <- c("Noise", "SST",
                 "Daily sin", "Daily cos",
                 "Weekly sin", "Weekly cos",
                 "Biweekly sin", "Biweekly cos",
                 "Monthly sin", "Monthly cos",
                 "Bimonthly sin", "Bimonthly cos")
df_beta <- post_df %>% filter(parameter %in% beta_params)
df_beta$parameter <- factor(df_beta$parameter, levels = beta_params)

p_beta <- ggplot(df_beta, aes(x = sback_label, y = mean, colour = rho_label)) +
  geom_point(size = 1.5, position = position_dodge(width = 0.4)) +
  geom_linerange(aes(ymin = lb95, ymax = ub95),
                 position = position_dodge(width = 0.4), linewidth = 0.3) +
  geom_linerange(aes(ymin = lb90, ymax = ub90),
                 position = position_dodge(width = 0.4), linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.2) +
  facet_wrap(~ parameter, scales = "free_y", ncol = 3) +
  labs(
    title = "Covariate effects across grid resolutions",
    subtitle = "Thin lines = 95% HPD, thick lines = 90% HPD",
    x = "sback",
    y = "Posterior estimate",
    colour = "GP range"
  ) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
        strip.text = element_text(size = 8))

ggsave(file.path(bench_path_fig, "covariate_comparison.pdf"),
       plot = p_beta, width = 12, height = 10)
cat("Saved covariate_comparison.pdf\n")


# =============================================================================-
# 6. Signal leakage: alpha vs delta across resolutions ----
# =============================================================================-

df_leakage <- post_df %>%
  filter(parameter %in% c("alpha", "delta")) %>%
  select(combo_id, rho, sback, rho_label, sback_label, parameter, mean) %>%
  pivot_wider(names_from = parameter, values_from = mean)

p_leakage <- ggplot(df_leakage, aes(x = delta, y = alpha,
                                     colour = rho_label, label = sback_label)) +
  geom_point(size = 3) +
  geom_text(vjust = -1, size = 3) +
  geom_path(aes(group = rho_label), linetype = "dotted", linewidth = 0.4) +
  labs(
    title = "Signal leakage: excitation vs. GP variance",
    subtitle = "Movement along this path shows signal transfer between components",
    x = "delta (log GP variance) — posterior mean",
    y = "alpha (branching ratio) — posterior mean",
    colour = "GP range"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(bench_path_fig, "signal_leakage.pdf"),
       plot = p_leakage, width = 8, height = 6)
cat("Saved signal_leakage.pdf\n")


cat("\n=== Summary complete ===\n")
cat(sprintf("All outputs saved to %s\n", bench_path_fig))
