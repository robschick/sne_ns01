# =============================================================================
# benchmark_config.R — Configuration for GP resolution benchmarking experiment
#
# Defines the (rho, sback) grid, maps SLURM array indices to combos,
# and sets shared harmonic periods.
#
# Source this file at the top of benchmark scripts:
#   source('src/benchmark_config.R')
#
# This sources config.R internally — do not source both.
# =============================================================================

source('src/config.R')


# ── Experiment grid ──────────────────────────────────────────────────────────
# Two rho arms, four sback levels each.
# Constraints enforced:
#   - sback < rho * 3  (GP must correlate across grid cells)
#   - rho * 3 < 1440   (effective range < daily harmonic period)

benchmark_grid <- data.frame(
  combo_id   = 1:8,
  rho        = c(  60,   60,   60,   60,   30,   30,   30,   30),
  sback      = c(  30,   60,  120,  180,   15,   30,   60,   90),
  arm_label  = c(rep("rho60", 4), rep("rho30", 4)),
  stringsAsFactors = FALSE
)

# Validate constraints
stopifnot(all(benchmark_grid$sback <= benchmark_grid$rho * 3))
stopifnot(all(benchmark_grid$rho * 3 < 1440))


# ── Resolve combo from SLURM or command-line ─────────────────────────────────
# Priority: command-line arg > SLURM_ARRAY_TASK_ID > interactive default (1)

resolve_combo_id <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  # Check for --combo=N or --combo N
  combo_arg <- NULL
  for (i in seq_along(args)) {
    if (grepl("^--combo=", args[i])) {
      combo_arg <- as.integer(sub("^--combo=", "", args[i]))
    } else if (args[i] == "--combo" && i < length(args)) {
      combo_arg <- as.integer(args[i + 1])
    }
  }
  if (!is.null(combo_arg)) return(combo_arg)

  # Fall back to SLURM array task ID
  slurm_id <- Sys.getenv("SLURM_ARRAY_TASK_ID", unset = NA)
  if (!is.na(slurm_id)) return(as.integer(slurm_id))

  # Interactive default
  return(1L)
}

# Check for --months=N flag (laptop temporal subset)
resolve_subset_months <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  for (i in seq_along(args)) {
    if (grepl("^--months=", args[i])) {
      return(as.numeric(sub("^--months=", "", args[i])))
    } else if (args[i] == "--months" && i < length(args)) {
      return(as.numeric(args[i + 1]))
    }
  }
  return(NULL)  # NULL = use full dataset
}

# Check for --full flag (run Phase 2)
resolve_full_run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  return("--full" %in% args)
}

# Check for --niters=N flag (override iteration count for Phase 2)
resolve_niters <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  for (i in seq_along(args)) {
    if (grepl("^--niters=", args[i])) {
      return(as.integer(sub("^--niters=", "", args[i])))
    } else if (args[i] == "--niters" && i < length(args)) {
      return(as.integer(args[i + 1]))
    }
  }
  return(NULL)  # NULL = auto-calculate from time budget
}


# ── Apply combo selection ────────────────────────────────────────────────────

bench_combo_id    <- resolve_combo_id()
bench_combo       <- benchmark_grid[benchmark_grid$combo_id == bench_combo_id, ]
bench_rho         <- bench_combo$rho
bench_sback       <- bench_combo$sback
bench_label       <- paste0("rho", bench_rho, "_sback", sprintf("%03d", bench_sback))
bench_full_run      <- resolve_full_run()
bench_subset_months <- resolve_subset_months()
bench_niters_override <- resolve_niters()

cat(sprintf("Benchmark combo %d: rho=%d, sback=%d (%s)\n",
            bench_combo_id, bench_rho, bench_sback, bench_label))


# ── Adjust analysis window for laptop subset ─────────────────────────────────

if (!is.null(bench_subset_months)) {
  analysis_end <- std + bench_subset_months * 30 * 24 * 60 * 60  # approximate months
  cat(sprintf("Laptop mode: subsetting to %.1f months (end = %s)\n",
              bench_subset_months, format(analysis_end, tz = 'UTC')))
}


# ── Harmonics ────────────────────────────────────────────────────────────────
# Adapted to the analysis window length. A harmonic is only included if the
# window contains at least 3 full cycles (enough for identifiability).
#
# Full 7 months:  daily, weekly, biweekly, monthly, bimonthly
# 3 months:       daily, weekly, biweekly, monthly
# 1 month:        daily, weekly

harm_day_unit <- 24 * 60  # 1,440 min

# All candidate periods (minutes) with labels
harm_candidates <- data.frame(
  period = c(
    1 * harm_day_unit,      # 1,440 min
    1 * harm_week_unit,     # 10,080 min
    2 * harm_week_unit,     # 20,160 min
    1 * harm_month_unit,    # 43,200 min
    2 * harm_month_unit     # 86,400 min
  ),
  label = c("daily", "weekly", "biweekly", "monthly", "bimonthly"),
  stringsAsFactors = FALSE
)

# Window length in minutes
window_min <- as.numeric(difftime(analysis_end, std, units = "mins"))
min_cycles <- 3  # require at least 3 full cycles

keep <- harm_candidates$period * min_cycles <= window_min
harm_periods_bench <- harm_candidates$period[keep]
harm_labels_bench  <- harm_candidates$label[keep]

cat(sprintf("Analysis window: %.1f days (%.1f months)\n",
            window_min / (24 * 60), window_min / harm_month_unit))
cat(sprintf("Harmonics included (%d): %s\n",
            length(harm_periods_bench),
            paste(harm_labels_bench, collapse = ", ")))


# ── Phase 1 settings ────────────────────────────────────────────────────────

bench_phase1_iters <- 1000   # iterations for timing characterization


# ── Output paths ─────────────────────────────────────────────────────────────

bench_path_fit <- file.path(path_base, fold.fit, 'benchmark', bench_label, '')
bench_path_fig <- file.path(local_base, 'fig', 'benchmark', '')

ifelse(!dir.exists(bench_path_fit), dir.create(bench_path_fit, recursive = TRUE), FALSE)
ifelse(!dir.exists(bench_path_fig), dir.create(bench_path_fig, recursive = TRUE), FALSE)
