# =============================================================================
# anim_draw.R — Static basemap and one animation frame
# =============================================================================

library(ggplot2)
library(patchwork)
library(sf)

col_call   <- '#d95f02'   # orange: call ticks and rings
col_hawkes <- '#1b7837'   # green: lambda
col_bg     <- 'grey55'    # grey: background (contact-call) rate
col_pois   <- '#2166ac'   # blue, dashed: Poisson stand-in (schematic's contact colour)

# Commercial lease outline, dissolved as in 09b_caseStudyMap.R
read_lease_outline <- function(path = 'data/ne_wea.shp') {
  st_read(path, quiet = TRUE) |>
    subset(LEASE_TYPE == 'Commercial' & LEASE_NUMB != 'OCS-A 0506') |>
    st_transform(26919) |>
    st_make_valid() |>
    st_union() |>
    st_buffer(100, joinStyle = 'MITRE', mitreLimit = 5) |>
    st_buffer(-100, joinStyle = 'MITRE', mitreLimit = 5)
}

# Static map pieces in UTM 19N. Returns the layers, the coord, and site
# positions in projected metres (x, y) for the per-frame layers. The 25 km
# buffer brings in the south shores of Nantucket and Martha's Vineyard.
make_basemap <- function(sites, coast = NULL, lease_areas = NULL, buffer_km = 25,
                         crs = 26919) {
  pts <- st_transform(st_as_sf(sites, coords = c('lon', 'lat'), crs = 4326), crs)
  xy  <- st_coordinates(pts)
  sites_xy <- data.frame(site = sites$site, label = sites$label, x = xy[, 1], y = xy[, 2])
  bb <- st_bbox(pts) + c(-1, -1, 1, 1) * buffer_km * 1e3

  if (is.null(coast)) {
    coast <- rnaturalearth::ne_states(country = 'united states of america', returnclass = 'sf')
  }
  coast <- st_transform(coast, crs)

  layers <- list(
    geom_sf(data = coast, fill = 'grey85', colour = 'grey55', linewidth = 0.3,
            inherit.aes = FALSE),
    if (!is.null(lease_areas))
      geom_sf(data = st_transform(st_as_sf(lease_areas), crs), fill = NA,
              colour = 'grey45', linewidth = 0.45, linetype = 'dashed', inherit.aes = FALSE)
  )
  coord <- coord_sf(crs = crs, default_crs = NULL, xlim = bb[c('xmin', 'xmax')],
                    ylim = bb[c('ymin', 'ymax')], expand = FALSE, datum = NA)
  list(layers = layers, coord = coord, sites_xy = sites_xy[order(sites_xy$x), ])
}

# `now` and `calls$t_min` are minutes since t0. `ymax` is shared across frames;
# lambda above it is clipped. `caption` (e.g. the takeaway) is drawn when given.
# A `poisson` column in `rate` adds the dashed Poisson line.
draw_frame <- function(now, rate, calls, basemap, t0, win_min, ymax,
                       tz = 'America/New_York', caption = NULL, ring_min = 1.5) {
  sxy  <- basemap$sites_xy
  lv   <- sxy$site                                     # west -> east
  r    <- rate[rate$t_min >= 0 & rate$t_min <= now, ]
  cs   <- calls[calls$t_min >= 0 & calls$t_min <= now, ]
  cur  <- do.call(rbind, lapply(split(rate, rate$site), function(d)
    d[which.min(abs(d$t_min - now)), c('site', 'lambda')]))
  node <- merge(sxy, cur)
  ring <- merge(sxy, cs[now - cs$t_min < ring_min, c('site', 't_min')])
  ring$r <- (now - ring$t_min) / ring_min
  r$site  <- factor(r$site, lv); cs$site <- factor(cs$site, lv)

  map <- ggplot() + basemap$layers +
    geom_point(data = ring, aes(x, y, size = 6 + 22 * r, alpha = 1 - r),
               shape = 1, colour = col_call, stroke = 1.6) +
    geom_point(data = node, aes(x, y, size = 4 + 14 * pmin(lambda, ymax) / ymax,
                                fill = pmin(lambda, ymax)), shape = 21) +
    geom_text(data = sxy, aes(x, y, label = label), nudge_y = 15000, size = 5.5,
              fontface = 'bold') +
    scale_fill_viridis_c(limits = c(0, ymax), name = 'calls per hour',
                         guide = guide_colourbar(title.position = 'top', title.hjust = 0.5)) +
    scale_size_identity() + scale_alpha_identity() +
    basemap$coord + theme_void(base_size = 17) +
    theme(legend.position = 'bottom', legend.key.width = unit(2, 'cm'),
          plot.title = element_text(face = 'bold', size = 22)) +
    labs(title = format(t0 + now * 60, '%d %b %Y  %H:%M %Z', tz = tz))

  has_pois <- !is.null(r$poisson)
  subtitle <- c('Grey: calls that start a conversation.',
                'Green: plus calls answering one heard minutes earlier.',
                if (has_pois) 'Dashed: a Poisson model, one smooth rate with no answering.')

  ts_p <- ggplot(r, aes(t_min)) +
    geom_line(aes(y = pmin(mu, ymax)), colour = col_bg, linewidth = 1) +
    (if (has_pois) geom_line(aes(y = pmin(poisson, ymax)), colour = col_pois,
                             linewidth = 1, linetype = 'dashed')) +
    geom_line(aes(y = pmin(lambda, ymax)), colour = col_hawkes, linewidth = 1.1) +
    geom_segment(data = cs, aes(x = t_min, xend = t_min, y = 0, yend = ymax * 0.25),
                 colour = col_call, linewidth = 0.55) +
    facet_grid(site ~ ., switch = 'y', drop = FALSE) +
    scale_x_continuous(limits = c(0, win_min), expand = c(0, 0), name = 'minutes') +
    scale_y_continuous(limits = c(0, ymax), name = 'calls per hour') +
    theme_minimal(base_size = 17) +
    theme(strip.text.y.left = element_text(angle = 0, face = 'bold', size = 18),
          strip.placement = 'outside', panel.grid.minor = element_blank()) +
    labs(subtitle = paste(subtitle, collapse = '\n'))

  p <- map + ts_p + plot_layout(widths = c(1, 1.5))
  if (is.null(caption)) return(p)
  cap <- grid::textGrob(caption, gp = grid::gpar(fontsize = 19, fontface = 'bold'))
  wrap_elements(p) / wrap_elements(full = cap) + plot_layout(heights = c(1, 0.13))
}

# Companion clip: per site, a row of real call ticks over a row of Poisson
# call ticks, with running counts. Real ticks show up to `now_real`, Poisson
# up to `now_pois` (minutes since t0; < 0 hides a row's ticks). `real` and
# `pois` have site and t_min. `highlight` (site, from, to) shades one span.
draw_compare_frame <- function(now_real, now_pois, real, pois, sites, t0, win_min,
                               tz = 'America/New_York', highlight = NULL,
                               title = NULL, caption = NULL) {
  rows  <- c('Real calls', 'Poisson calls')
  ticks <- rbind(
    data.frame(site = real$site, t_min = real$t_min, row = rows[1])[real$t_min <= now_real, ],
    data.frame(site = pois$site, t_min = pois$t_min, row = rows[2])[pois$t_min <= now_pois, ])
  ticks$y <- match(ticks$row, rev(rows))
  ticks$site <- factor(ticks$site, sites)

  n_shown <- expand.grid(site = factor(sites, sites), row = rows, stringsAsFactors = FALSE)
  n_shown$y <- match(n_shown$row, rev(rows))
  n_shown$n <- mapply(function(s, rw) sum(ticks$site == s & ticks$row == rw),
                      n_shown$site, n_shown$row)
  n_shown$label <- sprintf('%s  %d', n_shown$row, n_shown$n)

  cursor <- data.frame(now = c(now_real, now_pois)[c(now_real, now_pois) >= 0 &
                                                    c(now_real, now_pois) < win_min])
  hl <- if (!is.null(highlight)) data.frame(site = factor(highlight$site, sites),
                                            from = highlight$from, to = highlight$to)

  p <- ggplot(ticks) +
    (if (!is.null(hl)) list(
      geom_rect(data = hl, aes(xmin = from, xmax = to, ymin = 0.45, ymax = 2.55),
                fill = 'gold', alpha = 0.25, inherit.aes = FALSE),
      geom_text(data = hl, aes(x = (from + to) / 2, y = 2.75, label = 'burst'),
                size = 5, fontface = 'bold', colour = 'goldenrod4', inherit.aes = FALSE))) +
    geom_segment(aes(x = t_min, xend = t_min, y = y - 0.38, yend = y + 0.38, colour = row),
                 linewidth = 0.6) +
    geom_vline(data = cursor, aes(xintercept = now), colour = 'grey30', linewidth = 0.6) +
    geom_text(data = n_shown, aes(x = win_min + 2, y = y, label = label, colour = row),
              hjust = 0, size = 5.5, fontface = 'bold') +
    facet_grid(site ~ ., switch = 'y', drop = FALSE) +
    scale_colour_manual(values = setNames(c(col_call, col_pois), rows), guide = 'none') +
    scale_x_continuous(limits = c(0, win_min * 1.3), breaks = seq(0, win_min, 30),
                       expand = c(0, 0), name = 'minutes') +
    scale_y_continuous(limits = c(0.4, 2.9), breaks = NULL, name = NULL) +
    theme_minimal(base_size = 17) +
    theme(strip.text.y.left = element_text(angle = 0, face = 'bold', size = 18),
          strip.placement = 'outside', panel.grid.minor = element_blank(),
          panel.spacing.y = unit(1, 'lines'),
          plot.title = element_text(face = 'bold', size = 22)) +
    labs(title = title,
         subtitle = paste0(format(t0, '%d %b %Y  %H:%M', tz = tz), ' to ',
                           format(t0 + win_min * 60, '%H:%M %Z', tz = tz),
                           '. About the same number of calls in each row; only the timing differs.'))
  if (is.null(caption)) return(p)
  cap <- grid::textGrob(caption, gp = grid::gpar(fontsize = 19, fontface = 'bold'))
  wrap_elements(p) / wrap_elements(full = cap) + plot_layout(heights = c(1, 0.13))
}
