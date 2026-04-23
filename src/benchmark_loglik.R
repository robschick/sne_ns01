# =============================================================================
# benchmark_loglik.R — Post-hoc loglikelihood replay for benchmark combos
#
# Mirrors the loop in 03_loglikLGCPSE.R but iterates over the benchmark grid
# (fit/<buoy>/benchmark/*/phase2_fit.RData) and keeps the FULL chain — no
# burn-in is applied here, since we want to see where the LL stabilizes.
#
# For each combo:
#   1. Load phase2_fit.RData (postSamples, postWm, Xm, knts, phase1_results)
#   2. Reconstruct ts/maxT from phase1_results$subset_months
#   3. Replay LL via compLogLiki (Rcpp), saving every 1000 iters
#   4. Compute ESS / Geweke on the post-burn (1/3 discarded) LL chain
#
# Usage:
#   Rscript src/benchmark_loglik.R                    # all combos, no thinning
#   Rscript src/benchmark_loglik.R --combo=3          # just one combo
#   Rscript src/benchmark_loglik.R --thin=10          # replay every 10th sample
#
# Outputs (in fig/<buoy>/benchmark/):
#   loglik_traces.RData      - list of per-combo LL data frames
#   loglik_traces.pdf        - faceted trace plots
#   loglik_diagnostics.csv   - ESS/Geweke/post-mean/SE per combo
#
# Per-combo intermediate saves at:
#   fit/<buoy>/benchmark/<label>/phase2_loglik.RData
# =============================================================================

rm(list = ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(coda); library(batchmeans)

source('src/benchmark_config.R')

path.cpp <- 'src/RcppFtns.cpp'
sourceCpp(path.cpp)


# ── CLI: filter to a single combo? ───────────────────────────────────────────
# --combo=N    : per-combo replay only, aggregation skipped
# --combos=1-8 : aggregate over a subset (range or comma list); skips others
# --thin=N     : replay every Nth posterior sample
args <- commandArgs(trailingOnly = TRUE)
explicit_combo <- NULL
combos_filter  <- NULL
thin <- 1L
for (a in args) {
  if (grepl("^--combo=", a)) {
    explicit_combo <- as.integer(sub("^--combo=", "", a))
  } else if (grepl("^--combos=", a)) {
    spec <- sub("^--combos=", "", a)
    if (grepl("^[0-9]+-[0-9]+$", spec)) {
      parts <- as.integer(strsplit(spec, "-")[[1]])
      combos_filter <- parts[1]:parts[2]
    } else {
      combos_filter <- as.integer(strsplit(spec, ",")[[1]])
    }
    if (any(is.na(combos_filter))) stop("--combos must be a range (1-8) or list (1,2,3)")
  } else if (grepl("^--thin=", a)) {
    thin <- as.integer(sub("^--thin=", "", a))
    if (is.na(thin) || thin < 1) stop("--thin must be a positive integer")
  }
}
target_ids <- if (!is.null(explicit_combo)) {
  explicit_combo
} else if (!is.null(combos_filter)) {
  combos_filter
} else {
  benchmark_grid$combo_id
}


# ── Raw data once ───────────────────────────────────────────────────────────
load(paste0(path.data, datai, '.RData'))   # data, noise


# ── Per-combo replay ────────────────────────────────────────────────────────
ll_traces <- list()
diag_rows <- list()

for (cid in target_ids) {
  row   <- benchmark_grid[benchmark_grid$combo_id == cid, ]
  label <- paste0("rho", row$rho, "_sback", sprintf("%03d", row$sback))

  fit_dir <- file.path(path_base, fold.fit, buoy, 'benchmark', label)
  fpath   <- file.path(fit_dir, 'phase2_fit.RData')
  if (!file.exists(fpath)) {
    fit_dir <- file.path(path_base, fold.fit, 'benchmark', label)
    fpath   <- file.path(fit_dir, 'phase2_fit.RData')
  }
  if (!file.exists(fpath)) {
    cat(sprintf("  MISSING combo %d: %s\n", cid, label))
    next
  }

  cat(sprintf("\n=== Combo %d: %s ===\n", cid, label))
  load(fpath)   # postSamples, postWm, knts, Xm, phase1_results, ...

  # Reconstruct the analysis window used at fit time
  subset_months <- phase1_results$subset_months
  if (is.null(subset_months) || is.na(subset_months)) {
    maxT_window <- as.numeric(difftime(analysis_end, std, units = "mins"))
  } else {
    end_i       <- std + subset_months * 30 * 24 * 60 * 60
    maxT_window <- as.numeric(difftime(end_i, std, units = "mins"))
  }

  ts_i   <- data$ts[data$ts <= maxT_window]
  maxT_i <- ceiling(max(ts_i))

  indlam0 <- sapply(seq_along(ts_i),
                    function(k) which(knts >= ts_i[k])[1] - 1 - 1)

  p        <- ncol(Xm)
  betaInd  <- 1:p
  deltaInd <- p + 1
  alphaInd <- p + 2
  etaInd   <- p + 3

  niters_i   <- nrow(postSamples)
  keep_iters <- seq(1, niters_i, by = thin)
  n_kept     <- length(keep_iters)
  cat(sprintf("  events=%d, knots=%d, iters=%d, thin=%d, kept=%d\n",
              length(ts_i), length(knts), niters_i, thin, n_kept))

  # Incremental-save replay loop — chunking is in kept-sample space so the
  # save cadence is consistent regardless of thin.
  ll_file <- file.path(fit_dir, 'phase2_loglik.RData')
  aaa     <- unique(c(0, seq(1000, n_kept, by = 1000), n_kept))

  if (file.exists(ll_file)) {
    if (exists("thin_used")) rm(thin_used)   # prevent leak from prior combo
    load(ll_file)   # postLogLik, thin_used (if written by this version)
    saved_thin <- if (exists("thin_used")) thin_used else 1L
    if (saved_thin != thin) {
      stop(sprintf(
        "Existing %s was produced with thin=%d but --thin=%d requested. Delete it and rerun.",
        ll_file, saved_thin, thin))
    }
    start <- which(aaa == length(postLogLik))
    if (length(start) == 0) {
      stop(sprintf(
        "Existing %s has length %d which is not a checkpoint boundary. Delete it and rerun.",
        ll_file, length(postLogLik)))
    }
    cat(sprintf("  resuming from %d kept samples (thin=%d)\n",
                length(postLogLik), thin))
  } else {
    postLogLik <- c()
    start      <- 1
  }

  ptm <- proc.time()[3]
  if (start < length(aaa)) {
    for (aa in (start + 1):length(aaa)) {
      chunk <- numeric(aaa[aa] - aaa[aa - 1])
      for (k in (aaa[aa - 1] + 1):aaa[aa]) {
        it <- keep_iters[k]
        lam0m <- exp(Xm %*% postSamples[it, betaInd] +
                     exp(postSamples[it, deltaInd]) * postWm[it, ])
        chunk[k - aaa[aa - 1]] <-
          compLogLiki(ts_i, maxT_i, lam0m, indlam0, knts,
                      postSamples[it, alphaInd], postSamples[it, etaInd])
      }
      postLogLik <- c(postLogLik, chunk)
      thin_used  <- thin
      save(postLogLik, thin_used, file = ll_file)
      if (aa %% 5 == 0 || aa == length(aaa)) {
        cat(sprintf("    %d/%d kept (iter %d/%d, %.1f sec)\n",
                    aaa[aa], n_kept, keep_iters[aaa[aa]], niters_i,
                    proc.time()[3] - ptm))
      }
    }
    cat(sprintf("  replay done (%.1f sec total)\n", proc.time()[3] - ptm))
  } else {
    cat("  already complete — skipping replay\n")
  }

  ll_traces[[as.character(cid)]] <- data.frame(
    combo_id  = cid,
    rho       = row$rho,
    sback     = row$sback,
    label     = label,
    iteration = keep_iters,
    loglik    = postLogLik,
    stringsAsFactors = FALSE
  )

  # ── Diagnostics on post-burn LL (first 1/3 discarded) ──────────────────────
  burn_i  <- floor(n_kept / 3)
  post_ll <- postLogLik[(burn_i + 1):n_kept]
  mcmc_ll <- as.mcmc(post_ll)
  ess     <- as.numeric(effectiveSize(mcmc_ll))
  gew     <- geweke.diag(mcmc_ll, frac1 = 0.1, frac2 = 0.5)
  bm_ll   <- bm(post_ll)

  diag_rows[[length(diag_rows) + 1]] <- data.frame(
    combo_id      = cid,
    rho           = row$rho,
    sback         = row$sback,
    label         = label,
    total_iters   = niters_i,
    thin          = thin,
    n_kept        = n_kept,
    post_burn_n   = length(post_ll),
    ll_ess        = round(ess),
    ll_ess_per_1k = round(ess / length(post_ll) * 1000, 1),
    geweke_z      = round(gew$z, 3),
    geweke_p      = round(2 * pnorm(-abs(gew$z)), 4),
    post_mean     = round(bm_ll$est, 3),
    post_se       = round(bm_ll$se, 4),
    stringsAsFactors = FALSE
  )
}

if (length(ll_traces) == 0) {
  stop("No phase2_fit.RData files found for the requested combos.")
}

# When invoked with --combo=N, do per-combo replay only and stop.
# Aggregate outputs require all combos and are produced by a follow-up
# invocation without --combo (which reads the per-combo phase2_loglik.RData
# files and skips re-replay).
if (!is.null(explicit_combo)) {
  cat(sprintf("\nDone (--combo=%d). Aggregate outputs skipped.\n", explicit_combo))
  cat("Run `Rscript src/benchmark_loglik.R --buoy=<buoy>` without --combo to aggregate.\n")
  quit(save = "no")
}


# ── Save aggregate outputs ──────────────────────────────────────────────────
save(ll_traces, file = file.path(bench_path_fig, 'loglik_traces.RData'))

diag_df <- bind_rows(diag_rows)
write.csv(diag_df,
          file.path(bench_path_fig, 'loglik_diagnostics.csv'),
          row.names = FALSE)

cat("\n=== Loglikelihood diagnostics (post burn-in = first 1/3) ===\n")
print(diag_df %>%
        select(combo_id, rho, sback, total_iters,
               ll_ess, ll_ess_per_1k, geweke_z, geweke_p, post_mean) %>%
        as.data.frame(),
      row.names = FALSE)

problems <- diag_df %>% filter(ll_ess < 400 | geweke_p < 0.05)
if (nrow(problems) > 0) {
  cat("\n  WARNING: combos with LL ESS < 400 or Geweke p < 0.05:\n")
  print(problems %>%
          select(combo_id, rho, sback, ll_ess, geweke_z, geweke_p) %>%
          as.data.frame(),
        row.names = FALSE)
} else {
  cat("\n  All combos: LL ESS > 400 and Geweke p > 0.05.\n")
}


# ── Trace plot (thinned for plotting only — diagnostics use full chain) ─────
ll_df <- bind_rows(ll_traces)
ll_df$combo_label <- paste0("Combo ", ll_df$combo_id,
                             " (rho=", ll_df$rho,
                             ", sback=", ll_df$sback, ")")

thinned <- ll_df %>%
  group_by(combo_id) %>%
  mutate(keep_every = max(1, floor(n() / 2000)),
         keep       = (iteration %% keep_every) == 0) %>%
  filter(keep) %>%
  ungroup()

burn_df <- ll_df %>%
  group_by(combo_label) %>%
  summarise(burn = floor(max(iteration) / 3), .groups = 'drop')

p_ll <- ggplot(thinned, aes(x = iteration, y = loglik)) +
  geom_line(linewidth = 0.2, alpha = 0.8) +
  geom_vline(data = burn_df, aes(xintercept = burn),
             linetype = "dashed", colour = "red", linewidth = 0.3) +
  facet_wrap(~ combo_label, scales = "free_y", ncol = 2) +
  labs(title = "Log-likelihood trace — post-hoc replay",
       subtitle = "Red dashed line = burn-in cutoff (first 1/3 of chain)",
       x = "Iteration", y = "log L") +
  theme_bw() +
  theme(strip.text = element_text(size = 8))

ggsave(file.path(bench_path_fig, 'loglik_traces.pdf'),
       plot = p_ll, width = 10, height = 10)

cat(sprintf("\nSaved loglik_traces.pdf, loglik_diagnostics.csv, loglik_traces.RData\n"))
cat(sprintf("  -> %s\n", bench_path_fig))
