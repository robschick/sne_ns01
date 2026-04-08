# =============================================================================
# benchmark_diagnostics.R — Harmonic resolution verification plots
#
# For each sback in the experiment grid, constructs the design matrix at that
# resolution and plots all 5 harmonic components. Shows where the daily cycle
# becomes under-resolved due to insufficient grid resolution.
#
# Usage:
#   Rscript src/benchmark_diagnostics.R
#   Rscript src/benchmark_diagnostics.R --months=1   # laptop subset
#
# No fitting required — this is a standalone diagnostic.
# =============================================================================

rm(list = ls())
library(tidyverse)

source('src/benchmark_config.R')

load(paste0(path.data, datai, '.RData'))

ts   <- data$ts
maxT <- ceiling(max(ts))

cat(sprintf("Data: %d events, maxT = %.0f min (%.1f days)\n",
            length(ts), maxT, maxT / (24 * 60)))


# =============================================================================-
# Reference: "true" harmonics at 1-minute resolution ----
# =============================================================================-

harm_names <- c("Daily", "Weekly", "Biweekly", "Monthly", "Bimonthly")

# Fine reference grid (1-min) for a 1-week window to show detail
ref_window <- min(7 * 24 * 60, maxT)  # 1 week or maxT if shorter
t_ref      <- seq(0, ref_window, by = 1)


# =============================================================================-
# Build harmonics at each sback and collect for plotting ----
# =============================================================================-

# Get unique sback values across both arms
all_sback <- sort(unique(benchmark_grid$sback))

plot_data <- list()

for (sb in all_sback) {
  knts_sb <- unique(c(0, seq(0, maxT, by = sb), maxT))

  # Restrict to the plotting window
  knts_window <- knts_sb[knts_sb <= ref_window]
  if (max(knts_window) < ref_window) {
    knts_window <- c(knts_window, ref_window)
  }

  for (h in seq_along(harm_periods_bench)) {
    period <- harm_periods_bench[h]

    # Harmonics at this sback resolution
    sin_vals <- sin(2 * pi * (knts_window + harm_start_time) / period)
    cos_vals <- cos(2 * pi * (knts_window + harm_start_time) / period)

    plot_data[[length(plot_data) + 1]] <- data.frame(
      t_min    = knts_window,
      t_hours  = knts_window / 60,
      sin_val  = sin_vals,
      cos_val  = cos_vals,
      harmonic = harm_names[h],
      sback    = sb,
      type     = "grid",
      stringsAsFactors = FALSE
    )
  }
}

# Reference harmonics at 1-min resolution
for (h in seq_along(harm_periods_bench)) {
  period <- harm_periods_bench[h]
  plot_data[[length(plot_data) + 1]] <- data.frame(
    t_min    = t_ref,
    t_hours  = t_ref / 60,
    sin_val  = sin(2 * pi * (t_ref + harm_start_time) / period),
    cos_val  = cos(2 * pi * (t_ref + harm_start_time) / period),
    harmonic = harm_names[h],
    sback    = 1,
    type     = "reference",
    stringsAsFactors = FALSE
  )
}

df <- bind_rows(plot_data)
df$harmonic <- factor(df$harmonic, levels = harm_names)
df$sback_label <- ifelse(df$type == "reference",
                         "1 min (reference)",
                         paste0(df$sback, " min"))
df$sback_label <- factor(df$sback_label,
                         levels = c("1 min (reference)",
                                    paste0(sort(all_sback), " min")))


# =============================================================================-
# Plot 1: Sine components across sback values (1-week window) ----
# =============================================================================-

# Focus on daily and weekly harmonics where resolution matters most
df_short <- df %>% filter(harmonic %in% c("Daily", "Weekly"))

p1 <- ggplot(df_short, aes(x = t_hours, y = sin_val,
                            colour = sback_label, linewidth = type)) +
  geom_line() +
  geom_point(data = df_short %>% filter(type == "grid"),
             aes(x = t_hours, y = sin_val), size = 0.5) +
  facet_wrap(~ harmonic, ncol = 1, scales = "free_y") +
  scale_linewidth_manual(values = c("reference" = 0.3, "grid" = 0.6),
                          guide = "none") +
  scale_colour_brewer(palette = "Dark2", name = "sback") +
  labs(
    title = "Harmonic resolution at different sback values (sine component)",
    subtitle = sprintf("First week of data (%.0f hours)", ref_window / 60),
    x = "Time (hours)",
    y = "sin(2\u03c0t / period)"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(bench_path_fig, "harmonic_resolution_short.pdf"),
       plot = p1, width = 10, height = 6)
cat("Saved harmonic_resolution_short.pdf\n")


# =============================================================================-
# Plot 2: All harmonics, zoomed to 48 hours for daily detail ----
# =============================================================================-

df_daily <- df %>%
  filter(t_hours <= 48) %>%
  filter(harmonic == "Daily")

p2 <- ggplot(df_daily, aes(x = t_hours, y = sin_val,
                            colour = sback_label, linewidth = type)) +
  geom_line() +
  geom_point(data = df_daily %>% filter(type == "grid"),
             aes(x = t_hours, y = sin_val), size = 1.5) +
  scale_linewidth_manual(values = c("reference" = 0.3, "grid" = 0.7),
                          guide = "none") +
  scale_colour_brewer(palette = "Dark2", name = "sback") +
  labs(
    title = "Daily harmonic resolution (48-hour window)",
    subtitle = "Points show knot locations — coarse grids miss the daily cycle",
    x = "Time (hours)",
    y = "sin(2\u03c0t / 1440 min)"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

ggsave(file.path(bench_path_fig, "harmonic_daily_zoom.pdf"),
       plot = p2, width = 10, height = 4)
cat("Saved harmonic_daily_zoom.pdf\n")


# =============================================================================-
# Plot 3: Grid resolution summary table ----
# =============================================================================-

grid_summary <- benchmark_grid %>%
  rowwise() %>%
  mutate(
    knots          = length(unique(c(0, seq(0, maxT, by = sback), maxT))),
    eff_range      = rho * 3,
    daily_pts      = 1440 / sback,
    weekly_pts     = 10080 / sback,
    resolves_daily = ifelse(daily_pts >= 6, "Yes", "No")
  ) %>%
  ungroup()

cat("\n=== Grid Resolution Summary ===\n")
print(as.data.frame(grid_summary), row.names = FALSE)

# Save as CSV for the paper
write.csv(grid_summary,
          file.path(bench_path_fig, "grid_resolution_summary.csv"),
          row.names = FALSE)
cat("\nSaved grid_resolution_summary.csv\n")


# =============================================================================-
# Plot 4: Full design matrix at each sback (first 2 weeks) ----
# =============================================================================-

window_2wk <- min(14 * 24 * 60, maxT)

df_full <- list()
for (sb in all_sback) {
  knts_sb <- unique(c(0, seq(0, maxT, by = sb), maxT))
  knts_w  <- knts_sb[knts_sb <= window_2wk]

  harm_cols_sb <- do.call(cbind, lapply(harm_periods_bench, function(p) {
    cbind(
      sin(2 * pi * (knts_w + harm_start_time) / p),
      cos(2 * pi * (knts_w + harm_start_time) / p)
    )
  }))

  for (h in seq_along(harm_periods_bench)) {
    sin_col <- (h - 1) * 2 + 1
    cos_col <- (h - 1) * 2 + 2
    combined <- sqrt(harm_cols_sb[, sin_col]^2 + harm_cols_sb[, cos_col]^2)

    df_full[[length(df_full) + 1]] <- data.frame(
      t_hours  = knts_w / 60,
      amplitude = harm_cols_sb[, sin_col],
      harmonic = harm_names[h],
      sback    = paste0(sb, " min"),
      stringsAsFactors = FALSE
    )
  }
}

df_full <- bind_rows(df_full)
df_full$harmonic <- factor(df_full$harmonic, levels = harm_names)
df_full$sback    <- factor(df_full$sback,
                           levels = paste0(sort(all_sback), " min"))

p3 <- ggplot(df_full, aes(x = t_hours, y = amplitude)) +
  geom_line(linewidth = 0.4) +
  geom_point(size = 0.3, alpha = 0.5) +
  facet_grid(harmonic ~ sback, scales = "free_y") +
  labs(
    title = "Design matrix harmonics at each grid resolution",
    subtitle = sprintf("First 2 weeks (%.0f hours)", window_2wk / 60),
    x = "Time (hours)",
    y = "Harmonic value (sine component)"
  ) +
  theme_bw() +
  theme(
    strip.text = element_text(size = 7),
    axis.text  = element_text(size = 6)
  )

ggsave(file.path(bench_path_fig, "harmonic_all_grid.pdf"),
       plot = p3, width = 14, height = 10)
cat("Saved harmonic_all_grid.pdf\n")

cat("\nDiagnostics complete.\n")
