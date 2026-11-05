# =============================================================================
# context/ais/04_map.R — Regional map of AIS vessel transits around the buoys.
#
# Northeast Ocean Data monthly AIS vessel transit counts (all vessels, 100 m,
# Web Mercator; from MarineCadastre / USCG AIS tracks), summed over Oct–Feb for
# the analysis winter and the prior winter. A cell's value is the number of
# vessel tracks crossing it — transits, not vessel-hours, so the map is not on
# the same scale as the GFW numbers in the table and weekly panel.
#
# (i)  transits over 2021–22, log color scale, with the buoys, their 10 km
#      circles and the wind lease outlines;
# (ii) difference, 2021–22 minus 2020–21, on a signed log scale.
#
# Usage:   Rscript context/ais/04_map.R      (from the repo root)
# Needs:   ~3 GB download on first run (cached in cache/ned/, gitignored)
# Input:   data/release/sites.parquet, data/ne_wea.shp
# Output:  fig/context/ais/ais_map.{png,pdf}, fig/context/ais/ais_map_diff.{png,pdf},
#          cache/ned/winter_<season>.tif (the summed, cropped winters)
# =============================================================================

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(arrow)
  library(ggplot2)
})
source('context/ais/R/summary.R')   # ais_seasons, buoy_order
source('src/talk_figs.R')           # theme_talk

ned_dir <- 'context/ais/cache/ned'
out_dir <- 'fig/context/ais'
dir.create(ned_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
radius_m <- 10000

# ── Download + unzip the yearly monthly databases (skipped once present) ──────
gdb_for <- function(year) {
  gdb <- file.path(ned_dir, sprintf('AIS%d_Monthly.gdb', year))
  zip <- paste0(sub('\\.gdb$', '', gdb), '.zip')
  if (!dir.exists(gdb)) {
    if (!file.exists(zip)) {
      options(timeout = 3600)
      download.file(paste0('https://services.northeastoceandata.org/downloads/AIS/', basename(zip)),
                    zip, mode = 'wb')
    }
    unzip(zip, exdir = ned_dir)
  }
  gdb
}

# ── Sites, circles, leases ────────────────────────────────────────────────────
sites <- as.data.frame(read_parquet('data/release/sites.parquet'))[, c('site', 'lat', 'lon')]
sites$site <- factor(sites$site, buoy_order)
pts <- st_as_sf(sites, coords = c('lon', 'lat'), crs = 4326)
circles <- st_transform(st_buffer(st_transform(pts, 32619), radius_m), 3857)
pts <- st_transform(pts, 3857)

# As in 09b_caseStudyMap.R: commercial leases only, dissolved into one outline.
wea <- st_read('data/ne_wea.shp', quiet = TRUE) |>
  subset(LEASE_TYPE == 'Commercial' & LEASE_NUMB != 'OCS-A 0506') |>
  st_transform(26919) |> st_make_valid() |> st_union() |>
  st_buffer(100, joinStyle = 'MITRE', mitreLimit = 5) |>
  st_buffer(-100, joinStyle = 'MITRE', mitreLimit = 5) |>
  st_transform(3857)

# Same extent as the case-study slide map (buoys +/- 0.45 deg lon, 0.30 deg lat).
ext_ll <- c(xmin = min(sites$lon) - 0.45, xmax = max(sites$lon) + 0.45,
            ymin = min(sites$lat) - 0.30, ymax = max(sites$lat) + 0.30)
ext_m <- st_bbox(st_transform(st_as_sfc(st_bbox(ext_ll, crs = st_crs(4326))), 3857))
region <- ext(ext_m[['xmin']], ext_m[['xmax']], ext_m[['ymin']], ext_m[['ymax']])

# ── Sum Oct–Feb per winter (cached as a cropped GeoTIFF) ──────────────────────
# Empty cells are NA in the source; count them as zero transits.
winter_sum <- function(season) {
  tif <- file.path(ned_dir, sprintf('winter_%s.tif', season))
  if (file.exists(tif)) return(rast(tif))
  months <- seq(ais_seasons[[season]][1], ais_seasons[[season]][2] - 1, by = 'month')
  layers <- lapply(months, function(m) {
    y <- as.integer(format(m, '%Y'))
    r <- crop(rast(gdb_for(y), subds = sprintf('AllVesselTransitCounts%d_%s', y, format(m, '%m'))),
              region)
    classify(r, cbind(NA, 0))
  })
  total <- Reduce(`+`, layers)
  names(total) <- season
  writeRaster(total, tif, overwrite = TRUE)
  total
}
now   <- winter_sum('analysis')
prior <- winter_sum('baseline')
cat(sprintf('Transits summed over the region: 2021–22 %s, 2020–21 %s (cells with any: %d, %d)\n',
            format(global(now, 'sum')[[1]], big.mark = ','),
            format(global(prior, 'sum')[[1]], big.mark = ','),
            global(now > 0, 'sum')[[1]], global(prior > 0, 'sum')[[1]]))

# 200 m cells for drawing, keeping each block's max so single tracks stay visible.
as_cells <- function(r) {
  d <- as.data.frame(aggregate(r, 2, 'max'), xy = TRUE)
  names(d)[3] <- 'value'
  d
}

# ── Shared map layers ─────────────────────────────────────────────────────────
esri_ocean <- paste0('https://services.arcgisonline.com/arcgis/rest/services/',
                     'Ocean/World_Ocean_Base/MapServer/tile/${z}/${y}/${x}.jpeg')
credit <- paste0('AIS vessel transits (tracks crossing each 100 m cell), all vessel types, ',
                 'October – February. AIS misses most small boats.\n',
                 'Transits: Northeast Ocean Data (northeastoceandata.org), from MarineCadastre / USCG AIS. ',
                 'Basemap: Esri, GEBCO, NOAA.')
overlay <- list(
  geom_sf(data = wea, aes(colour = 'Wind energy lease areas'), fill = NA, linewidth = 1.1),
  geom_sf(data = circles, aes(colour = '10 km around each hydrophone'), fill = NA,
          linewidth = 1, linetype = '22'),
  geom_sf(data = pts, shape = 21, size = 5, fill = 'firebrick', colour = 'black', stroke = 1),
  geom_sf_label(data = pts, aes(label = site), nudge_y = 15000, size = 6.5, fontface = 'bold',
                fill = alpha('white', 0.85), linewidth = 0, label.padding = unit(0.15, 'lines')),
  scale_colour_manual(values = c('Wind energy lease areas' = 'orange',
                                 '10 km around each hydrophone' = 'black'),
                      breaks = c('10 km around each hydrophone', 'Wind energy lease areas'),
                      name = NULL),
  coord_sf(crs = 3857, xlim = ext_m[c('xmin', 'xmax')], ylim = ext_m[c('ymin', 'ymax')],
           expand = FALSE),
  labs(x = NULL, y = NULL, caption = credit),
  theme_talk,
  theme(legend.position = 'right', legend.box = 'vertical', legend.justification = 'top',
        legend.key.width = unit(1.4, 'cm'), legend.text = element_text(size = 15),
        legend.title = element_text(size = 16),
        axis.text = element_text(size = 12),
        plot.subtitle = element_text(colour = 'grey35', size = 18),
        plot.caption = element_text(hjust = 0, size = 11, colour = 'grey30'),
        plot.caption.position = 'plot'))

base_map <- function() ggplot() +
  ggspatial::annotation_map_tile(type = esri_ocean, zoomin = 0, progress = 'none')

save_map <- function(p, name) {
  for (ext in c('png', 'pdf'))
    ggsave(file.path(out_dir, paste0(name, '.', ext)), p, width = 13.33, height = 7.5,
           dpi = 200, device = if (ext == 'pdf') cairo_pdf else NULL, bg = 'white')
  cat('Wrote ', out_dir, '/', name, '.{png,pdf}\n', sep = '')
}

# ── (i) Transits over 2021–22 ─────────────────────────────────────────────────
cells <- subset(as_cells(now), value > 0)
p <- base_map() +
  geom_raster(data = cells, aes(x, y, fill = value)) +
  # Light -> dark blue: single tracks fade into the basemap, lanes stand out,
  # and the orange lease outline stays distinct.
  scale_fill_viridis_c(option = 'mako', direction = -1, begin = 0.05, trans = 'log10',
                       labels = scales::comma, name = 'Transits',
                       guide = guide_colourbar(barheight = unit(7, 'cm'), order = 1)) +
  overlay +
  labs(title = 'Where AIS-tracked vessels went, October 2021 – February 2022')
save_map(p, 'ais_map')

# ── (ii) Difference, 2021–22 minus 2020–21 ────────────────────────────────────
diff  <- subset(as_cells(now - prior), value != 0)
lim   <- max(abs(diff$value))
p_diff <- base_map() +
  geom_raster(data = diff, aes(x, y, fill = value)) +
  scale_fill_distiller(palette = 'RdBu', limits = c(-lim, lim),
                       trans = scales::pseudo_log_trans(sigma = 1, base = 10),
                       breaks = c(-1000, -100, -10, 0, 10, 100, 1000), labels = scales::comma,
                       name = 'Change in\ntransits',
                       guide = guide_colourbar(barheight = unit(7, 'cm'), order = 1)) +
  overlay +
  labs(title = 'Change in AIS transits: winter 2021–22 minus winter 2020–21',
       subtitle = 'Red = more transits in 2021–22; blue = fewer')
save_map(p_diff, 'ais_map_diff')
