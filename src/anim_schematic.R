# =============================================================================
# anim_schematic.R — "Family tree" of contact calls and countercalls
#
# A tree is a data frame: id, t (min), parent (id or NA), type
# ('contact' | 'counter'), gen (0 for contact calls).
# =============================================================================

col_contact <- '#2166ac'
col_counter <- '#b2182b'

add_generations <- function(tree) {
  tree$gen <- integer(nrow(tree))
  for (i in order(tree$t)) {
    p <- tree$parent[i]
    if (!is.na(p)) tree$gen[i] <- tree$gen[tree$id == p] + 1L
  }
  tree
}

# Cluster algorithm: contact calls ~ Poisson(mu) on [0, horizon]; each call has
# Poisson(alpha / eta) children at Exp(eta) delays (unnormalized kernel).
simulate_family_tree <- function(mu = 0.05, alpha = 0.15, eta = 0.25, horizon = 90,
                                 seed = 1) {
  set.seed(seed)
  n0 <- rpois(1, mu * horizon)
  ev <- data.frame(id = seq_len(n0), t = sort(runif(n0, 0, horizon)),
                   parent = rep(NA_integer_, n0))
  queue <- ev$id
  while (length(queue)) {
    i <- queue[1]; queue <- queue[-1]
    nk <- rpois(1, alpha / eta)
    if (!nk) next
    tk <- ev$t[ev$id == i] + rexp(nk, eta)
    tk <- tk[tk <= horizon]
    if (!length(tk)) next
    new <- data.frame(id = max(ev$id) + seq_along(tk), t = tk, parent = i)
    ev <- rbind(ev, new); queue <- c(queue, new$id)
  }
  ev$type <- ifelse(is.na(ev$parent), 'contact', 'counter')
  add_generations(ev[order(ev$t), ])
}

# Seed giving ~n_contact contact calls and a total in `n_total`
pick_tree_seed <- function(..., n_contact = 3, n_total = 8:12, seeds = 1:2000) {
  for (s in seeds) {
    tr <- simulate_family_tree(..., seed = s)
    if (sum(tr$type == 'contact') == n_contact && nrow(tr) %in% n_total) return(s)
  }
  stop('No seed in range meets the target; widen n_total or seeds')
}

# Tree from real calls: `branching` rows (site, i, time_utc, p_counter, parent,
# parent_prob) for one site and span. A call is a countercall when
# p_counter >= 0.5; a link is drawn when the modal parent has posterior
# probability > min_prob and is itself in the span.
tree_from_fit <- function(branching, site, start_utc, span_min, min_prob = 0.5) {
  b <- branching[branching$site == site &
                 branching$time_utc >= start_utc &
                 branching$time_utc <= start_utc + span_min * 60, ]
  tree <- data.frame(id = b$i, t = mins_since(b$time_utc, start_utc),
                     parent = ifelse(b$parent_prob > min_prob & b$parent %in% b$i,
                                     b$parent, NA_integer_),
                     type = ifelse(b$p_counter >= 0.5, 'counter', 'contact'))
  add_generations(tree[order(tree$t), ])
}

# Span inside [t0, t0 + win_min] at `site` with a call count in `n_total` and the
# most drawn links, trying each length in `span_mins` (busy sites need short
# spans). Returns list(start, span_min), or NULL if nothing qualifies.
pick_tree_span <- function(branching, site, t0, win_min, span_mins = c(5, 10, 15, 20, 30),
                           n_total = 8:15, step_min = 1) {
  cand <- do.call(rbind, lapply(span_mins, function(sp) {
    starts <- t0 + seq(0, win_min - sp, by = step_min) * 60
    data.frame(start = starts, span_min = sp, links = vapply(starts, function(s) {
      tr <- tree_from_fit(branching, site, s, sp)
      if (!nrow(tr) %in% n_total || !any(tr$type == 'contact')) return(-Inf)
      sum(!is.na(tr$parent))
    }, numeric(1)))
  }))
  if (all(!is.finite(cand$links))) return(NULL)
  best <- cand[which.max(cand$links), ]
  list(start = best$start, span_min = best$span_min, links = best$links)
}

# Top: calls by generation with curved arrows to each countercall's parent.
# Bottom: the same calls on a timeline with the rate curve they produce.
draw_family_tree <- function(tree, path, mu, alpha, eta, time_label = 'minutes',
                             width = 10, height = 5.2) {
  tree$type <- factor(tree$type, c('contact', 'counter'))
  links <- merge(tree[!is.na(tree$parent), c('t', 'gen', 'parent')],
                 setNames(tree[, c('id', 't', 'gen')], c('parent', 't0', 'gen0')))
  span <- max(tree$t) * 1.04 + 1

  # Label the first contact call and the first countercall that has a drawn parent
  lab_c <- tree[tree$type == 'contact', ][1, ]
  lab_k <- tree[tree$type == 'counter' & !is.na(tree$parent), ][1, ]
  labs_df <- rbind(
    data.frame(t = lab_c$t, gen = lab_c$gen - 0.45, txt = 'starts a conversation',
               col = col_contact, hjust = 0.5),
    if (nrow(lab_k) && !is.na(lab_k$t))
      data.frame(t = lab_k$t + 0.025 * span, gen = lab_k$gen,
                 txt = 'answers a call heard\nminutes earlier', col = col_counter, hjust = 0))

  top <- ggplot(tree, aes(t, -gen)) +
    geom_curve(data = links, aes(x = t0, y = -gen0, xend = t, yend = -gen),
               curvature = 0.3, colour = 'grey45', linewidth = 0.5,
               arrow = arrow(length = unit(2.2, 'mm'), type = 'closed')) +
    geom_point(aes(shape = type, colour = type), size = 4.2, stroke = 1.4, fill = col_contact) +
    geom_text(data = labs_df, aes(y = -gen, label = txt, colour = I(col), hjust = hjust),
              size = 4.2, fontface = 'bold', lineheight = 0.9) +
    scale_shape_manual(values = c(contact = 21, counter = 1), guide = 'none') +
    scale_colour_manual(values = c(contact = col_contact, counter = col_counter), guide = 'none') +
    scale_x_continuous(limits = c(0, span), expand = c(0.01, 0)) +
    scale_y_continuous(expand = expansion(add = c(0.4, 0.9))) +
    theme_void(base_size = 13)

  tg <- seq(0, span, length.out = 1500)
  rt <- data.frame(t = tg, lam = 60 * (mu + excite_at(tg, tree$t, alpha, eta)))
  bottom <- ggplot(rt, aes(t, lam)) +
    geom_hline(yintercept = 60 * mu, colour = col_bg, linewidth = 0.6) +
    geom_line(colour = col_hawkes, linewidth = 0.8) +
    geom_segment(data = tree, aes(x = t, xend = t, y = 0, yend = -0.12 * max(rt$lam),
                                  colour = type), inherit.aes = FALSE, linewidth = 1) +
    scale_colour_manual(values = c(contact = col_contact, counter = col_counter), guide = 'none') +
    scale_x_continuous(limits = c(0, span), expand = c(0.01, 0), name = time_label) +
    labs(y = 'calls per hour') +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank())

  p <- top / bottom + plot_layout(heights = c(1.5, 1))
  files <- paste0(path, c('.pdf', '.png'))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggsave(files[1], p, width = width, height = height, bg = 'white')
  ggsave(files[2], p, width = width, height = height, dpi = 200, bg = 'white')
  files
}
