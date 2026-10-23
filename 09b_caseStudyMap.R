# =============================================================================
# 09b_caseStudyMap.R — Two-panel manuscript map of the recorder locations for
# the three case studies on the ESRI World Ocean Base tile layer:
#   (a) Cape Cod Bay — Case Study 1 (single MARU, NEFSC SBNMS 2009-03, ch. 10)
#                      Case Study 3 (2009 CCB MARU array)
#   (b) Southern New England — Case Study 2 (COX01, NS01, NS02 buoys), with
#       the BOEM wind energy lease areas (data/ne_wea.shp, copied from the
#       sne_displacement repo; see data/ne_wea.qmd)
# Styled after 09_buoyMap.R.
#
# Usage:   Rscript 09b_caseStudyMap.R
# Output:  fig/case_study_map.pdf, fig/case_study_map.png
#          fig/talk/sne_map_slide.pdf/.png — panel (b) alone, sized for slides
# =============================================================================

rm(list = ls())
library(tidyverse)
library(sf)
library(ggspatial)
library(rnaturalearth)
library(patchwork)
library(jsonlite)

esri_ocean <- paste0(
  'https://services.arcgisonline.com/arcgis/rest/services/',
  'Ocean/World_Ocean_Base/MapServer/tile/${z}/${y}/${x}.jpeg'
)
maru_dir <- 'data/MARU_information'

cs_levels <- c('Case Study 1', 'Case Study 2', 'Case Study 3')
cs_fill <- c(
  'Case Study 1' = '#CC79A7',
  'Case Study 2' = 'firebrick',
  'Case Study 3' = '#F0E442'
)
cs_shape <- c('Case Study 1' = 24, 'Case Study 2' = 21, 'Case Study 3' = 21)

# ── Locations ───────────────────────────────────────────────────────────────
cs1_meta <- fromJSON(file.path(maru_dir, 'NEFSC_SBNMS_200903_NOPP6_CH10.json'))
cs1 <- tibble(
  label = 'SBNMS - Ch 10',
  Lat = as.numeric(cs1_meta$DEPLOYMENT$DEPLOY_LAT),
  Lon = as.numeric(cs1_meta$DEPLOYMENT$DEPLOY_LON),
  case_study = 'Case Study 1'
)

# Header carries a UTF-8 BOM; read with fileEncoding so Site.ID parses cleanly.
cs3 <- read.csv(
  file.path(maru_dir, 'ccb_array_coords.csv'),
  fileEncoding = 'UTF-8-BOM'
) %>%
  filter(year == 2009) %>%
  transmute(
    label = paste('MARU', Site.ID),
    Lat = Latitude,
    Lon = Longitude,
    case_study = 'Case Study 3'
  )

cs2 <- read.csv(
  file.path(maru_dir, 'sne_buoy_locs.csv'),
  strip.white = TRUE,
  colClasses = 'character'
) %>%
  rename_with(str_trim) %>%
  mutate(across(c(Lat, Lon), ~ as.numeric(str_replace_all(.x, '−', '-')))) %>%
  transmute(label = DeployID, Lat, Lon, case_study = 'Case Study 2')

to_sf <- function(df) {
  df %>%
    mutate(case_study = factor(case_study, levels = cs_levels)) %>%
    st_as_sf(coords = c('Lon', 'Lat'), crs = 4326)
}
ccb_pts <- to_sf(bind_rows(cs1, cs3))
sne_pts <- to_sf(cs2)

# Keep commercial lease blocks only: the easements (South Fork, Vineyard Wind)
# and the OCS-A 0506 right-of-way grant are export-cable corridors that draw as
# trailing lines. Dissolve the leases into one outline, working in UTM 19N so
# the union is planar; the +/-100 m buffer closes slivers where adjacent lease
# edges don't quite coincide, which otherwise draw as stray interior dashes.
wea <- st_read('data/ne_wea.shp', quiet = TRUE) %>%
  filter(LEASE_TYPE == 'Commercial', LEASE_NUMB != 'OCS-A 0506') %>%
  st_transform(26919) %>%
  st_make_valid() %>%
  st_union() %>%
  st_buffer(100, joinStyle = 'MITRE', mitreLimit = 5) %>%
  st_buffer(-100, joinStyle = 'MITRE', mitreLimit = 5) %>%
  st_sf(geometry = .) %>%
  st_transform(4326)

# ── Extents (lon/lat), then limits in Web Mercator to match the tiles ───────
pad_bbox <- function(pts, pad_x, pad_y) {
  bb <- st_bbox(pts)
  st_bbox(
    c(
      xmin = bb[['xmin']] - pad_x,
      xmax = bb[['xmax']] + pad_x,
      ymin = bb[['ymin']] - pad_y,
      ymax = bb[['ymax']] + pad_y
    ),
    crs = st_crs(4326)
  )
}
ccb_ext <- pad_bbox(ccb_pts, pad_x = 0.25, pad_y = 0.10)
sne_ext <- pad_bbox(sne_pts, pad_x = 0.45, pad_y = 0.30)

# 'CCB array' label sits just south of the array, clear of the MARUs.
array_lab <- st_sf(
  label = 'CCB array',
  geometry = st_sfc(st_point(c(-70.33, 41.845)), crs = 4326)
)

# ── Panel builder ───────────────────────────────────────────────────────────
# `under` takes optional layers drawn between the tiles and the points. The
# size arguments default to the manuscript figure; the slide version passes
# larger ones.
make_panel <- function(pts, ext, title, under = NULL, pt_size = 2.5, base_size = 11,
                       arrow_cm = 1.0, scale_cex = 1, legend_nrow = 1) {
  lims <- ext %>% st_as_sfc() %>% st_transform(3857) %>% st_bbox()
  ggplot() +
    annotation_map_tile(type = esri_ocean, zoomin = 1, progress = 'none') +
    under +
    layer_spatial(
      pts,
      aes(fill = case_study, shape = case_study),
      size = pt_size,
      colour = 'black',
      stroke = 0.6 * pt_size / 2.5,
      show.legend = c(fill = TRUE, shape = TRUE, colour = FALSE)
    ) +
    # Each panel holds only some case studies; show.legend + override.aes keep
    # every key drawn so the single collected legend is complete.
    scale_fill_manual(
      values = cs_fill,
      limits = cs_levels,
      name = NULL,
      guide = guide_legend(
        nrow = legend_nrow,
        override.aes = list(fill = unname(cs_fill), shape = unname(cs_shape))
      )
    ) +
    scale_shape_manual(values = cs_shape, limits = cs_levels, guide = 'none') +
    annotation_scale(location = 'br', width_hint = 0.25, text_cex = 0.7 * scale_cex,
                     height = unit(0.25 * scale_cex, 'cm')) +
    annotation_north_arrow(
      location = 'tl',
      which_north = 'true',
      style = north_arrow_fancy_orienteering(text_size = 10 * arrow_cm),
      pad_y = unit(0.6 * arrow_cm - 0.35, 'cm'),   # 0.25 cm (default) at 1 cm; room for the 'N'
      height = unit(arrow_cm, 'cm'),
      width = unit(arrow_cm, 'cm')
    ) +
    coord_sf(
      crs = 3857,
      xlim = c(lims[['xmin']], lims[['xmax']]),
      ylim = c(lims[['ymin']], lims[['ymax']]),
      expand = FALSE
    ) +
    labs(x = NULL, y = NULL, title = title) +
    theme_bw(base_size = base_size) +
    theme(plot.title = element_text(size = base_size, face = 'bold'))
}

plot.ccb <- make_panel(ccb_pts, ccb_ext, '(a) Cape Cod Bay') +
  geom_sf_text(
    data = filter(ccb_pts, case_study == 'Case Study 1'),
    aes(label = label),
    nudge_y = 2500,
    size = 3.2,
    fontface = 'bold'
  ) +
  geom_sf_text(
    data = array_lab,
    aes(label = label),
    size = 3.2,
    fontface = 'bold'
  )

# WEA outline styled as in sne_displacement (orange, unfilled). Mapping colour
# to a constant gives it its own key in the collected legend.
wea_layers <- list(
  geom_sf(
    data = wea,
    aes(colour = 'Wind energy lease areas'),
    fill = NA,
    linewidth = 0.5
  ),
  scale_colour_manual(
    values = c('Wind energy lease areas' = 'orange'),
    name = NULL
  )
)

plot.sne <- make_panel(
  sne_pts,
  sne_ext,
  '(b) Southern New England',
  under = wea_layers
) +
  geom_sf_text(
    data = sne_pts,
    aes(label = label),
    nudge_y = 5500,
    size = 3.2,
    fontface = 'bold'
  ) +
  # Case-study keys come from panel (a); keep only the WEA key here.
  guides(fill = 'none')

# ── Locator inset: both panel extents boxed and lettered ────────────────────
coast <- ne_states(
  country = c('united states of america', 'canada'),
  returnclass = 'sf'
)
boxes <- st_sf(
  panel = c('a', 'b'),
  geometry = c(st_as_sfc(ccb_ext), st_as_sfc(sne_ext))
)
box_labs <- tibble(
  panel = c('a', 'b'),
  x = c(ccb_ext[['xmax']], sne_ext[['xmax']]) + 0.45,
  y = c(mean(ccb_ext[c('ymin', 'ymax')]), mean(sne_ext[c('ymin', 'ymax')]))
)

plot.inset <- ggplot() +
  geom_sf(data = coast, fill = 'grey85', colour = 'grey55', linewidth = 0.2) +
  geom_sf(data = boxes, fill = NA, colour = 'firebrick', linewidth = 0.5) +
  geom_text(
    data = box_labs,
    aes(x, y, label = panel),
    size = 2.8,
    fontface = 'bold',
    colour = 'firebrick'
  ) +
  coord_sf(xlim = c(-76.5, -66.5), ylim = c(38.5, 45.5), expand = FALSE) +
  theme_void() +
  theme(
    panel.background = element_rect(fill = '#cfe1ee', colour = NA),
    panel.border = element_rect(fill = NA, colour = 'grey30', linewidth = 0.5)
  )

plot.sne <- plot.sne +
  inset_element(
    plot.inset,
    left = 0.015,
    bottom = 0.02,
    right = 0.26,
    top = 0.33,
    align_to = 'panel'
  )

plot.full <- (plot.ccb | plot.sne) +
  plot_layout(guides = 'collect') +
  plot_annotation(
    theme = theme(legend.position = 'bottom')
  )

ifelse(!dir.exists('fig'), dir.create('fig'), FALSE)
ggsave('fig/case_study_map.pdf', plot.full, width = 10, height = 4.6,
       bg = 'white')
ggsave('fig/case_study_map.png', plot.full, width = 10, height = 4.6,
       dpi = 330, bg = 'white')

# ── Slide version: panel (b) alone, large type ──────────────────────────────
# Same extent, lease outline and inset as the manuscript panel; the legend keys
# are renamed for a talk audience (no case-study numbering).
slide_size <- 8     # label size (mm) for the buoy names

# Heavier lease outline so it reads on a projector
wea_layers_slide <- wea_layers
wea_layers_slide[[1]] <- geom_sf(
  data = wea,
  aes(colour = 'Wind energy lease areas'),
  fill = NA,
  linewidth = 1.3
)

# Inset with only the SNE box, unlettered (there is no panel (a) on the slide)
plot.inset_slide <- ggplot() +
  geom_sf(data = coast, fill = 'grey85', colour = 'grey55', linewidth = 0.2) +
  geom_sf(data = boxes[boxes$panel == 'b', ], fill = NA, colour = 'firebrick',
          linewidth = 0.9) +
  coord_sf(xlim = c(-76.5, -66.5), ylim = c(38.5, 45.5), expand = FALSE) +
  theme_void() +
  theme(
    panel.background = element_rect(fill = '#cfe1ee', colour = NA),
    panel.border = element_rect(fill = NA, colour = 'grey30', linewidth = 0.8)
  )

plot.sne_slide <- make_panel(
  sne_pts,
  sne_ext,
  NULL,
  under = wea_layers_slide,
  pt_size = 6,
  base_size = 22,
  arrow_cm = 2.0,
  scale_cex = 2.5
) +
  geom_sf_text(
    data = sne_pts,
    aes(label = label),
    nudge_y = 8000,
    size = slide_size,
    fontface = 'bold'
  ) +
  scale_fill_manual(
    values = cs_fill['Case Study 2'],
    labels = 'Acoustic recorder',
    name = NULL,
    guide = guide_legend(override.aes = list(shape = 21, size = 6), order = 1)
  ) +
  theme(
    legend.position = 'bottom',
    legend.text = element_text(size = 22),
    legend.key.width = unit(1.4, 'cm'),
    axis.text = element_text(size = 16)
  ) +
  inset_element(
    plot.inset_slide,
    left = 0.015,
    bottom = 0.02,
    right = 0.26,
    top = 0.36,
    align_to = 'panel'
  )

dir.create('fig/talk', recursive = TRUE, showWarnings = FALSE)
ggsave('fig/talk/sne_map_slide.pdf', plot.sne_slide, width = 12, height = 8.6,
       bg = 'white')
ggsave('fig/talk/sne_map_slide.png', plot.sne_slide, width = 12, height = 8.6,
       dpi = 200, bg = 'white')
