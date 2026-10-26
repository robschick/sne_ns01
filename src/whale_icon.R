# =============================================================================
# whale_icon.R — Right whale silhouette for talk-figure markers.
#
# Traced from the NOAA Fisheries illustration (public domain, US Government):
# opaque pixels -> largest connected blob (drops the "NOAA Fisheries" credit)
# -> holes filled -> 0.5 contour of a lightly blurred mask -> smoothed, simplified ring.
# whale_polygon() returns the outline scaled to unit length, centered on 0,
# so callers place and size it with whale_at().
#
# Rscript src/whale_icon.R   re-traces into src/whale_polygon.csv and writes fig/talk/images/whale_{outline,filled}.{png,svg}
# =============================================================================

whale_src <- 'fig/640x427-North-Atlantic-Right-Whale-NOAAFisheries.png'
whale_csv <- 'src/whale_polygon.csv'   # tracked; fig/ (and the source PNG) is not

trace_whale <- function(src = whale_src, tol = 0.4) {
  img  <- png::readPNG(src)
  lab  <- imager::label(imager::as.cimg(t(img[, , 4] > 0.5)))   # imager is x-by-y
  big  <- as.integer(names(which.max(table(lab[lab > 0]))))
  m    <- t(as.matrix(lab)) == big                                # back to row-by-col
  bg   <- t(as.matrix(imager::label(imager::as.cimg(t(!m)))))   # fill interior holes
  edge <- unique(c(bg[1, ], bg[nrow(bg), ], bg[, 1], bg[, ncol(bg)]))
  m    <- m | !(bg %in% edge & !m)
  blur <- t(as.matrix(imager::isoblur(imager::as.cimg(t(m * 1)), 1.5)))
  iso  <- isoband::isolines(seq_len(ncol(blur)), -seq_len(nrow(blur)), blur, 0.5)[[1]]
  ring <- split(data.frame(x = iso$x, y = iso$y), iso$id)
  ring <- ring[[which.max(sapply(ring, nrow))]]
  sm   <- function(v) as.vector(stats::filter(v, rep(1 / 5, 5), circular = TRUE))
  ring <- data.frame(x = sm(ring$x), y = sm(ring$y))        # soften the pixel steps
  poly <- sf::st_simplify(sf::st_polygon(list(as.matrix(rbind(ring, ring[1, ])))),
                          dTolerance = tol)
  xy   <- as.data.frame(sf::st_coordinates(poly)[, 1:2])
  names(xy) <- c('x', 'y')
  len  <- diff(range(xy$x))
  data.frame(x = (xy$x - mean(range(xy$x))) / len, y = (xy$y - mean(range(xy$y))) / len)
}

whale_polygon <- function() {
  if (file.exists(whale_csv)) return(read.csv(whale_csv))
  w <- trace_whale()
  write.csv(round(w, 5), whale_csv, row.names = FALSE)
  w
}

# One whale per row of `at` (columns x, y, plus any columns to carry along),
# `size` = body length in x data units. `aspect` = y data units per x data unit
# of equal printed length, for plots without coord_equal().
whale_at <- function(at, size, aspect = 1, w = whale_polygon()) {
  extra <- setdiff(names(at), c('x', 'y'))
  do.call(rbind, lapply(seq_len(nrow(at)), function(i)
    cbind(at[rep(i, nrow(w)), extra, drop = FALSE],
          x = at$x[i] + w$x * size, y = at$y[i] + w$y * size * aspect, id = i)))
}

if (sys.nframe() == 0) {
  library(ggplot2)
  if (file.exists(whale_src) && file.exists(whale_csv)) file.remove(whale_csv)   # re-trace
  dir.create('fig/talk/images', recursive = TRUE, showWarnings = FALSE)
  w <- whale_polygon()
  cat('whale polygon:', nrow(w), 'vertices\n')
  for (style in c('outline', 'filled')) {
    p <- ggplot(w, aes(x, y)) +
      geom_polygon(fill = if (style == 'filled') 'grey15' else NA,
                   colour = 'grey15', linewidth = 1, linejoin = "round") +
      coord_equal() + theme_void()
    for (ext in c('png', 'svg'))
      ggsave(sprintf('fig/talk/images/whale_%s.%s', style, ext), p,
             width = 8, height = 8 * diff(range(w$y)) + 0.2, dpi = 200, bg = 'transparent')
  }
}
