# =============================================================================
# anim_gaps.R — Backup slide: time between calls, real vs Poisson
#
# Over each site's whole fit window, compares the gaps between consecutive
# calls with those of Poisson call sets simulated from the smoothed rate
# (smooth_rate(), sim_poisson() in anim_rate.R; a stand-in, not a fitted model).
# =============================================================================

# Share of gaps under 1 and 2 min, and var/mean of 5-min counts over [from, to)
gap_stats <- function(tc, from, to) {
  g  <- diff(sort(tc))
  n5 <- tabulate(findInterval(tc, seq(from, to, by = 5)), floor((to - from) / 5))
  c(lt1 = mean(g < 1), lt2 = mean(g < 2), var_mean_5min = var(n5) / mean(n5))
}

# Per site: real calls in the fit window (range of the fitted call times in
# `branching`) and `n_rep` Poisson replicates (seeds seed, seed + 1, ...).
# Calls outside the fit window still inform the smoothed rate near its edges.
# Returns list(summary, gaps): one summary row per site and statistic; gaps has
# site, set ('real' or replicate number) and gap_min.
compare_gaps <- function(calls, branching, sd_min = 60, n_rep = 20, seed = 1) {
  per_site <- lapply(unique(branching$site), function(s) {
    tb <- range(branching$time_utc[branching$site == s])
    to <- ceiling(mins_since(tb[2], tb[1]))
    tc <- mins_since(calls$time_utc[calls$site == s], tb[1])
    sm <- smooth_rate(tc, 0, to, sd_min)
    real <- tc[tc >= 0 & tc < to]
    sims <- lapply(seed + seq_len(n_rep) - 1, function(k) sim_poisson(sm, k))

    st_real <- gap_stats(real, 0, to)
    st_sim  <- vapply(sims, gap_stats, numeric(3), from = 0, to = to)
    summary <- data.frame(
      site = s, stat = names(st_real), n_calls = length(real), real = st_real,
      poisson_seed1 = st_sim[, 1], poisson_mean = rowMeans(st_sim),
      poisson_lo = apply(st_sim, 1, quantile, 0.025),
      poisson_hi = apply(st_sim, 1, quantile, 0.975), row.names = NULL)
    gaps <- rbind(data.frame(site = s, set = 'real', gap_min = diff(sort(real))),
                  do.call(rbind, lapply(seq_along(sims), function(k)
                    data.frame(site = s, set = as.character(k), gap_min = diff(sims[[k]])))))
    list(summary = summary, gaps = gaps)
  })
  list(summary = do.call(rbind, lapply(per_site, `[[`, 'summary')),
       gaps    = do.call(rbind, lapply(per_site, `[[`, 'gaps')))
}

# Histogram of gaps on 0..max_min (share of all gaps per `bin_min` bin): real
# as bars, Poisson as the replicate range (band) and median (line). One slide.
plot_gap_distribution <- function(cmp, out, max_min = 10, bin_min = 0.25,
                                  sites = unique(cmp$summary$site)) {
  breaks <- seq(0, max_min, by = bin_min)
  h <- do.call(rbind, lapply(split(cmp$gaps, list(cmp$gaps$site, cmp$gaps$set), drop = TRUE),
    function(d) data.frame(site = d$site[1], set = d$set[1], mid = head(breaks, -1) + bin_min / 2,
                           share = tabulate(findInterval(d$gap_min, breaks), length(breaks) - 1) /
                                   nrow(d))))
  real <- h[h$set == 'real', ]
  band <- do.call(rbind, lapply(split(h[h$set != 'real', ], ~ site + mid, drop = TRUE),
    function(d) data.frame(site = d$site[1], mid = d$mid[1], lo = min(d$share),
                           hi = max(d$share), med = median(d$share))))
  real$site <- factor(real$site, sites); band$site <- factor(band$site, sites)

  lt1 <- cmp$summary[cmp$summary$stat == 'lt1', ]
  lab <- data.frame(site = factor(lt1$site, sites),
                    label = sprintf('Gaps under 1 min\nreal %.0f%%\nPoisson %.0f%%',
                                    100 * lt1$real, 100 * lt1$poisson_mean))

  p <- ggplot() +
    geom_col(data = real, aes(mid, share), width = bin_min, fill = col_call, alpha = 0.85) +
    geom_ribbon(data = band, aes(mid, ymin = lo, ymax = hi), fill = col_pois, alpha = 0.3) +
    geom_line(data = band, aes(mid, med), colour = col_pois, linewidth = 1.1) +
    geom_text(data = lab, aes(x = max_min * 0.97, y = Inf, label = label), hjust = 1,
              vjust = 1.2, size = 5.5, lineheight = 0.95) +
    facet_wrap(~ site, nrow = 1) +
    scale_x_continuous(limits = c(0, max_min), breaks = seq(0, max_min - 2, 2), expand = c(0, 0),
                       name = 'minutes between consecutive calls') +
    scale_y_continuous(labels = function(x) paste0(100 * x, '%'), expand = c(0, 0, 0.05, 0),
                       name = 'share of gaps') +
    theme_minimal(base_size = 18) +
    theme(strip.text = element_text(face = 'bold', size = 20),
          panel.grid.minor = element_blank(), panel.spacing.x = unit(1.5, 'lines'),
          plot.title = element_text(face = 'bold', size = 22)) +
    labs(title = 'Real calls come closer together than a Poisson model allows',
         subtitle = paste0('Orange: real calls over the whole fit window.\n',
                           'Blue: Poisson calls from the same smoothed rate (line = median, ',
                           sprintf('band = range of %d simulations).', length(unique(h$set)) - 1)))
  for (ext in c('pdf', 'png')) ggsave(paste0(out, '.', ext), p, width = 13.33, height = 7.5,
                                      dpi = 150, bg = 'white')
  invisible(p)
}
