# =============================================================================
# 09_buoyMap.R — Manuscript map of the three buoy deployments (COX01, NS01,
# NS02) on the ESRI World Ocean Base tile layer.
#
# Usage:   Rscript 09_buoyMap.R
# Output:  fig/buoy_map.pdf, fig/buoy_map.png
# =============================================================================

rm(list = ls())
library(tidyverse)
library(sf)
library(ggspatial)
library(rnaturalearth)
library(patchwork)

esri_ocean <- paste0(
  'https://services.arcgisonline.com/arcgis/rest/services/',
  'Ocean/World_Ocean_Base/MapServer/tile/${z}/${y}/${x}.jpeg'
)

# The Lon column contains Unicode minus signs (U+2212) and trailing spaces;
# normalize before parsing or as.numeric() returns NA.
buoys <- read.csv(
  'data/buoy_locs.csv',
  strip.white = TRUE,
  colClasses = 'character'
) %>%
  rename_with(str_trim) %>%
  mutate(across(c(Lat, Lon), ~ as.numeric(str_replace_all(.x, '−', '-')))) %>%
  st_as_sf(coords = c('Lon', 'Lat'), crs = 4326)

# Pad the extent around the buoys, then express the limits in Web Mercator
# (EPSG:3857) so coord_sf matches the tile projection.
bb <- st_bbox(buoys)
pad_x <- 0.45
pad_y <- 0.30
lims <- st_bbox(
  c(
    xmin = bb[['xmin']] - pad_x,
    xmax = bb[['xmax']] + pad_x,
    ymin = bb[['ymin']] - pad_y,
    ymax = bb[['ymax']] + pad_y
  ),
  crs = st_crs(4326)
) %>%
  st_as_sfc() %>%
  st_transform(3857) %>%
  st_bbox()

plot.map <- ggplot() +
  annotation_map_tile(type = esri_ocean, zoomin = 1, progress = 'none') +
  layer_spatial(
    buoys,
    size = 2.5,
    shape = 21,
    fill = 'firebrick',
    colour = 'black',
    stroke = 0.6
  ) +
  geom_sf_text(
    data = buoys,
    aes(label = DeployID),
    nudge_y = 4000,
    size = 3.2,
    fontface = 'bold'
  ) +
  annotation_scale(location = 'br', width_hint = 0.25) +
  annotation_north_arrow(
    location = 'tl',
    which_north = 'true',
    style = north_arrow_fancy_orienteering(),
    height = unit(1.2, 'cm'),
    width = unit(1.2, 'cm')
  ) +
  coord_sf(
    crs = 3857,
    xlim = c(lims[['xmin']], lims[['xmax']]),
    ylim = c(lims[['ymin']], lims[['ymax']]),
    expand = FALSE
  ) +
  labs(x = NULL, y = NULL) +
  theme_bw()

# ── Locator inset: US Northeast coast with the main-map extent boxed ────────
coast <- ne_states(
  country = c('united states of america', 'canada'),
  returnclass = 'sf'
)

extent_box <- st_bbox(
  c(
    xmin = bb[['xmin']] - pad_x,
    xmax = bb[['xmax']] + pad_x,
    ymin = bb[['ymin']] - pad_y,
    ymax = bb[['ymax']] + pad_y
  ),
  crs = st_crs(4326)
) %>%
  st_as_sfc()

plot.inset <- ggplot() +
  geom_sf(data = coast, fill = 'grey85', colour = 'grey55', linewidth = 0.2) +
  geom_sf(data = extent_box, fill = NA, colour = 'firebrick', linewidth = 0.6) +
  coord_sf(xlim = c(-77.5, -66.5), ylim = c(37.5, 45.5), expand = FALSE) +
  theme_void() +
  theme(
    panel.background = element_rect(fill = '#cfe1ee', colour = NA),
    panel.border = element_rect(fill = NA, colour = 'grey30', linewidth = 0.5)
  )

plot.full <- plot.map +
  inset_element(
    plot.inset,
    left = 0.015,
    bottom = 0.02,
    right = 0.27,
    top = 0.33,
    align_to = 'panel'
  )

ifelse(!dir.exists('fig'), dir.create('fig'), FALSE)
ggsave('fig/buoy_map.pdf', plot.full, width = 7, height = 5.5, bg = 'white')
ggsave('fig/buoy_map.png', plot.full, width = 7, height = 5.5, dpi = 330,
       bg = 'white')
