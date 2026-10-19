# =============================================================================
# anim_window.R — Choose the on-screen time window
# =============================================================================

# Slide a `win_min` window in `step_min` steps and score it by total calls plus
# `site_bonus` for each site with at least `min_calls`. Only windows fully
# inside recording effort at every shown site (and inside `bounds`, e.g. the
# fit window) are kept. Returns the top `n` non-overlapping windows.
pick_window <- function(calls, effort, win_min = 120, step_min = 10, sites = NULL,
                        bounds = NULL, site_bonus = 25, min_calls = 3, n = 5) {
  if (is.null(sites)) sites <- sort(unique(calls$site))
  win_s <- win_min * 60
  rng <- if (is.null(bounds)) range(calls$time_utc) else bounds
  starts <- seq(rng[1], rng[2] - win_s, by = step_min * 60)

  covered <- Reduce(`&`, lapply(sites, function(s) {
    e <- effort[effort$site == s, ]
    vapply(as.numeric(starts), function(t)
      any(as.numeric(e$start_utc) <= t & as.numeric(e$end_utc) >= t + win_s), logical(1))
  }))

  counts <- vapply(sites, function(s) {
    tc <- sort(as.numeric(calls$time_utc[calls$site == s]))
    findInterval(as.numeric(starts) + win_s, tc) - findInterval(as.numeric(starts), tc)
  }, numeric(length(starts)))
  counts <- matrix(counts, ncol = length(sites), dimnames = list(NULL, sites))

  score <- rowSums(counts) + site_bonus * rowSums(counts >= min_calls)
  score[!covered] <- -Inf

  # Greedy: best window, drop everything overlapping it, repeat
  picked <- integer(0)
  ord <- order(score, decreasing = TRUE)
  for (i in ord[is.finite(score[ord])]) {
    if (all(abs(as.numeric(starts[i]) - as.numeric(starts[picked])) >= win_s)) picked <- c(picked, i)
    if (length(picked) == n) break
  }
  out <- data.frame(start_utc = starts[picked], n_calls = rowSums(counts)[picked],
                    n_sites_active = rowSums(counts >= min_calls)[picked],
                    score = score[picked])
  cbind(out, counts[picked, , drop = FALSE])
}
