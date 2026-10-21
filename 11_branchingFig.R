# =============================================================================
# 11_branchingFig.R — Step-by-step branching-process build for the NARWC talk
#
# Redraws the hand-made PowerPoint build (fig/talk/images/Slide13-24.png) from
# a cascade simulated at NS01's fitted self-excitation (alpha, eta). Rows are
# Background, Gen. 1, Gen. 2, ... and Observations; each build adds calls
# cluster by cluster. The last frame is the payoff: the observations alone,
# each shaded by the model's probability that it is a contact call.
#
# Usage:
#   Rscript 11_branchingFig.R [--seed=N]
#
# Input:  out/anim/ns01_anim.rds   (from 10a_animExport.R; alpha, eta)
# Output: fig/talk/branching/branching_<k>.png, branching_build.pdf
# =============================================================================

library(ggplot2)
source('src/anim_schematic.R')   # simulate_family_tree(), col_contact, col_counter

args     <- commandArgs(trailingOnly = TRUE)
seed_arg <- sub('^--seed=', '', grep('^--seed=', args, value = TRUE))
out_dir  <- 'fig/talk/branching'
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fit   <- readRDS('out/anim/ns01_anim.rds')$fit
alpha <- fit$alpha                   # jump size per call (per min), unnormalized kernel
eta   <- fit$eta                     # decay rate (per min)
br    <- alpha / eta                 # mean answers per call
cat(sprintf('NS01: alpha %.3f, eta %.3f -> %.2f answers per call, half-life %.1f min\n',
            alpha, eta, br, log(2) / eta))

# ── Pick a legible cascade ───────────────────────────────────────────────────
# Five contact calls, at least one unanswered and at least one call with two
# answers, 12-16 calls in all, no deeper than Gen. 3, calls far enough apart to
# read, and an answer share near the fitted one.
mu      <- 0.15                      # contact calls per min (illustrative, busy window)
horizon <- 32

children_of <- function(tr) vapply(tr$id, function(i) sum(tr$parent == i, na.rm = TRUE), 0L)

legible <- function(tr) {
  kids <- children_of(tr)
  nc   <- sum(tr$type == 'contact')
  nc == 5 && nrow(tr) %in% 12:16 && max(tr$gen) %in% 2:3 &&
    any(kids[tr$type == 'contact'] == 0) && any(kids >= 2) &&
    min(diff(tr$t)) > 0.45 && min(diff(tr$t[tr$type == 'contact'])) > 3 &&
    max(tr$t) < horizon - 1 && abs((nrow(tr) - nc) / nrow(tr) - br) < 0.08
}

seed <- if (length(seed_arg)) as.integer(seed_arg) else {
  s <- Find(function(s) legible(simulate_family_tree(mu, alpha, eta, horizon, seed = s)),
            1:20000)
  if (is.null(s)) stop('No legible seed in 1:20000; relax legible()')
  s
}
tree <- simulate_family_tree(mu, alpha, eta, horizon, seed = seed)
tree$kids <- children_of(tree)
lead      <- 1                       # min of empty axis before the first call
tree$t    <- tree$t + lead

# Cluster = the contact call each call descends from
root <- function(i) { while (!is.na(p <- tree$parent[tree$id == i])) i <- p; i }
tree$cluster <- match(vapply(tree$id, root, 0L), tree$id[tree$type == 'contact'])

# Model's chance that each call is a contact call: mu / lambda(t_i-)
tree$p_contact <- vapply(seq_len(nrow(tree)), function(k) {
  prior <- tree$t[tree$t < tree$t[k]]
  mu / (mu + sum(alpha * exp(-eta * (tree$t[k] - prior))))
}, 0)

# Raise a label when its left neighbour is too close (t_i labels are narrower
# than the percentages)
# than the percentages); runs of close calls step up 0, 1, 2, 0, ...
stack_levels <- function(t, gap) Reduce(function(lv, d) if (d < gap) (lv + 1) %% 3 else 0,
                                        diff(t), accumulate = TRUE, 0)
tree$lift     <- stack_levels(tree$t, 0.8)
tree$lift_pct <- stack_levels(tree$t, 1.3)

n_ans <- sum(tree$type == 'counter')
cat(sprintf('Seed %d: %d calls, %d contact, %d answers (%.2f per call; %.1f calls per exchange)\n',
            seed, nrow(tree), 5L, n_ans, n_ans / nrow(tree), nrow(tree) / 5))

# ── Layout ───────────────────────────────────────────────────────────────────
n_gen  <- max(tree$gen)
rows   <- data.frame(label = c('Background', paste0('Gen. ', seq_len(n_gen)), 'Observations'),
                     y = c(n_gen:0, -1.1))
tree$y <- n_gen - tree$gen
y_obs  <- -1.1
x_end  <- horizon + lead
x_lim  <- c(-8.2, x_end + 1)
y_lim  <- c(y_obs - 0.75, n_gen + 0.75)
w <- 12; h <- 4.5

links <- merge(tree[!is.na(tree$parent), c('id', 'parent', 't', 'y', 'cluster')],
               setNames(tree[, c('id', 't', 'y')], c('parent', 't0', 'y0')))

# Stop each arrow short of its target dot so the head stays visible
in_x <- w / diff(x_lim); in_y <- h / diff(y_lim)          # inches per data unit
len  <- sqrt(((links$t - links$t0) * in_x)^2 + ((links$y - links$y0) * in_y)^2)
cut  <- pmin(0.075 / len, 0.5)
links$t1 <- links$t - cut * (links$t - links$t0)
links$y1 <- links$y - cut * (links$y - links$y0)

# Text labels on the first contact call (above it) and the first unanswered
# countercall (below it), where no arrow crosses them
lab <- rbind(
  with(tree[tree$type == 'contact', ][1, ],
       data.frame(t, y = y + 0.38, txt = 'contact call', col = col_contact)),
  with(tree[tree$type == 'counter' & tree$kids == 0, ][1, ],
       data.frame(t, y = y - 0.38, txt = 'counter-call', col = col_counter)))

base_plot <- function(tree_col = 'black') {
  rows$col <- ifelse(rows$label == 'Observations', 'black', tree_col)
  ggplot() +
    geom_segment(data = rows, aes(x = 0, xend = x_end, y = y, yend = y, colour = I(col)),
                 linewidth = 0.5, arrow = arrow(length = unit(2, 'mm'), type = 'closed')) +
    geom_segment(data = rows, aes(x = 0, xend = 0, y = y - 0.12, yend = y + 0.12,
                                  colour = I(col)), linewidth = 0.5) +
    geom_text(data = rows, aes(x = -0.6, y = y, label = label, colour = I(col)),
              hjust = 1, size = 5.2) +
    annotate('text', x = x_end + 0.5, y = rows$y, label = 't', size = 5, fontface = 'italic',
             colour = rows$col) +
    # minute ticks under the observations row
    annotate('segment', x = lead + seq(0, 30, 5), xend = lead + seq(0, 30, 5),
             y = y_obs - 0.06, yend = y_obs - 0.16, linewidth = 0.4, colour = 'grey40') +
    annotate('text', x = lead + seq(0, 30, 5), y = y_obs - 0.34, label = seq(0, 30, 5),
             size = 3.6, colour = 'grey40') +
    annotate('text', x = lead + 30.6, y = y_obs - 0.34, label = 'minutes', hjust = 0,
             size = 3.6, colour = 'grey40') +
    scale_x_continuous(limits = x_lim, expand = c(0, 0)) +
    scale_y_continuous(limits = y_lim, expand = c(0, 0)) +
    theme_void() +
    theme(plot.background = element_rect(fill = 'white', colour = NA),
          plot.margin = margin(6, 10, 6, 6))
}

draw_build <- function(show, t_labels = FALSE) {
  tr <- tree[show, ]
  lk <- links[links$id %in% tr$id, ]
  lb <- lab[lab$t %in% tr$t, ]
  p <- base_plot() +
    geom_segment(data = lk, aes(x = t0, y = y0, xend = t1, yend = y1),
                 linewidth = 0.45, colour = 'grey20',
                 arrow = arrow(length = unit(1.8, 'mm'), type = 'closed')) +
    geom_point(data = tr, aes(t, y, colour = type), size = 3.6) +
    geom_point(data = tr, aes(t, y_obs), size = 3.2) +
    geom_text(data = lb, aes(t, y, label = txt, colour = I(col)), size = 5) +
    scale_colour_manual(values = c(contact = col_contact, counter = col_counter),
                        guide = 'none')
  if (t_labels)
    p <- p + geom_text(data = tr, aes(t, y_obs + 0.32 + 0.22 * lift,
                                      label = paste0('t[', rank(t), ']')),
                       parse = TRUE, size = 4)
  p
}

# Payoff: tree rows faded (we never see them); each observation labelled with
# the model's chance that it started an exchange
draw_payoff <- function() {
  base_plot(tree_col = 'grey80') +
    geom_point(data = tree, aes(t, y_obs), size = 3.2) +
    geom_text(data = tree, aes(t, y_obs + 0.34 + 0.22 * lift_pct, label = sprintf('%.0f%%', 100 * p_contact)),
              size = 3.8, colour = col_contact) +
    annotate('text', x = lead, y = y_obs + 0.85, hjust = 0, size = 4.2, colour = col_contact,
             label = 'Chance each call started an exchange (a contact call):') +
    annotate('text', x = x_end / 2, y = n_gen - 0.5, size = 5.6, fontface = 'bold',
             label = 'The hydrophone records only the bottom row.') +
    annotate('text', x = x_end / 2, y = n_gen - 1.5, size = 4.6, lineheight = 0.95,
             label = paste0('The model can\'t say which call answered which, but it can count them:\n',
                            'over NS01\'s season, ~5,057 contact calls and ~7,966 answers.'))
}

# ── Builds ───────────────────────────────────────────────────────────────────
# 1: first contact call   2: + its answer   3: + second contact call
# 4: + the second exchange's chain of answers (answers get answered)
# 5: everything but the last exchange   6: all, with t_i
cl <- tree$cluster
builds <- list(
  cl == 1 & tree$type == 'contact',
  cl == 1,
  cl == 1 | (cl == 2 & tree$type == 'contact'),
  cl <= 2,
  cl <= 4,
  rep(TRUE, nrow(tree))
)

plots <- c(lapply(seq_along(builds), function(k)
             draw_build(builds[[k]], t_labels = k == length(builds))),
           list(draw_payoff()))

for (k in seq_along(plots))
  ggsave(file.path(out_dir, sprintf('branching_%d.png', k)), plots[[k]],
         width = w, height = h, dpi = 200)
pdf(file.path(out_dir, 'branching_build.pdf'), width = w, height = h)
invisible(lapply(plots, print))
dev.off()
cat('Wrote', length(plots), 'frames to', out_dir, '\n')
