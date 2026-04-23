rm(list=ls())
library(Rcpp); library(RcppArmadillo)
library(tidyverse); library(readr)
library(foreach)
library(sf); library(tigris)
library(gridExtra)
options(tigris_use_cache = TRUE)


# =============================================================================-
# CCB and location of MARU ----
# =============================================================================-

counties_sf <- counties(cb = TRUE)
ccb = counties_sf %>% filter(NAME %in% c('Plymouth', 'Barnstable'), STATE_NAME == 'Massachusetts')
# coord = read_csv("ccb/data/CCB_2010.csv")
# 
# ccb_maru = coord %>% 
#   dplyr::select(Latitude, Longitude, Site) %>% 
#   mutate(Site = paste0('MARU ', Site))

single_channel <- data.frame(Longitude = -70.2719, Latitude = 42.066)  %>%
  mutate(label = "Single MARU")


map.hp = ggplot() + 
  geom_sf(data = ccb) + 
  # geom_point(aes(x = Longitude, y = Latitude)) +
  coord_sf(xlim = c(-70.7, -69.98), ylim = c(41.7, 42.1)) +
  geom_point(aes(x = Longitude, y = Latitude), data = single_channel, size = 3, colour = '#386cb0') +
  geom_text(aes(x = Longitude, y = Latitude, label = label), data = single_channel, nudge_y = -0.03, nudge_x = -0.03, size = 2.5) +
  # labs(x = '', y = '', title = '(b)') +
  labs(x = '', y = '', title = '') +
  theme_bw() +
  theme(plot.margin = margin(l = -1, b = -10))
map.hp


library(mapproj)


# Load world coastlines and US states
states_sf <- states(cb = TRUE)

ggplot() +
  geom_sf(data = states_sf) +
  # coord_sf(xlim = c(-83, -68), ylim = c(27, 46), crs = st_crs('+proj=moll'))
  coord_sf(crs = st_crs('+proj=moll'), xlim = c(-120, -60), expand = F)


world_map = map_data("world")

distinct(world_map, region) %>% 
  ggplot(aes(map_id = region)) +
  geom_map(map = world_map) +
  expand_limits(x = world_map$long, y = world_map$lat) +
  coord_map("moll")


# Load world coastlines and US states
library(rnaturalearth)
world <- ne_countries(scale = "medium", returnclass = "sf")
us_states <- ne_states(country = "united states of america", returnclass = "sf")
proj_albers <- "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=37.5 +lon_0=-96 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"


# Filter for the Northwest Atlantic region
# You might need to adjust the bounding box coordinates to better fit your area of interest
nw_atlantic_bbox <- st_bbox(c(xmin = -80, xmax = -60, ymin = 35, ymax = 50), crs = st_crs(world))
nw_atlantic_prj <- st_bbox(c(xmin = -80, xmax = -60, ymin = 35, ymax = 50), crs = st_crs(proj_albers))


# Transform spatial data to Albers equal-area conic projection
# Note: You may need to adjust the parameters for your specific region of interest
world_proj <- st_transform(world, proj_albers)
us_states_proj <- st_transform(us_states, proj_albers)

# Plot
ploc <- ggplot() +
  geom_sf(data = world_proj, fill = "antiquewhite", color = "gray") + # World coastline
  geom_sf(data = us_states_proj, fill = NA, color = "black") + # US state boundaries
  annotate("text", x = 2100000, y = 850002, label = "CCB", size = 3, hjust = "left") + # Annotation for Cape Cod Bay
  coord_sf(xlim = c(1100000, 2359794), 
           ylim = c(-900000, 1300201)) + # Adjusting view to bounding box
  # labs(x = '', y = '', title = '(a)')+
  labs(x = '', y = '', title = '')+
  theme_bw() +
  theme(plot.margin = margin(r = -1, b = -10))
ploc


p_both = grid.arrange(ploc, map.hp, nrow = 1, widths = c(1, 2.2))

ggsave(plot = p_both, width = 6.32, height = 3.06, filename = 'nopp/fig/noppHP.pdf')




# =============================================================================-
# Calls and noise ----
# =============================================================================-
library(RColorBrewer)
library(zoo)


## noise ----
noise = readRDS('nopp/data/2009_noise.rds') %>% 
  mutate(EST = as.POSIXct(as.character(UTC), "%Y-%m-%d %H:%M:%OS", tz = "EST")) %>% 
  dplyr::select(EST, RMS)

# continuous noise data between the following days
# 2009-03-28 15:01:00 100.3619
# 2009-04-03 08:45:00  98.6896

noise = noise %>% 
  filter(
    EST >= strptime('2009-03-28 15:01:00.000', "%Y-%m-%d %H:%M:%OS", tz = "EST"),
    EST <= strptime('2009-04-03 08:45:00.000', "%Y-%m-%d %H:%M:%OS", tz = "EST")
  )



## call times ----
wcall = rbind(
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090328_upcall_detection_log.txt") %>% 
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-03-28', tz = "EST")),
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090329_upcall_detection_log.txt") %>% 
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-03-29', tz = "EST")),
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090330_upcall_detection_log.txt") %>% 
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-03-30', tz = "EST")),
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090331_upcall_detection_log.txt") %>%
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-03-31', tz = "EST")),
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090401_upcall_detection_log.txt") %>% 
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-04-01', tz = "EST")),
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090402_upcall_detection_log.txt") %>% 
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-04-02', tz = "EST")),
  read_table("nopp/data/NEFSC_SBNMS_200903_2_20090403_upcall_detection_log.txt") %>% 
    mutate(EST = as.POSIXct((BeginTimes + EndTimes) / 2, origin = '2009-04-03', tz = "EST"))
) %>% 
  filter(is.na(Notes)) %>% 
  dplyr::select(EST) %>% 
  add_column(MARU = as.factor(1)) %>% 
  as.data.frame() %>% 
  filter(
    EST >= strptime('2009-03-28 15:01:00.000', "%Y-%m-%d %H:%M:%OS", tz = "EST"),
    EST <= strptime('2009-04-03 08:45:00.000', "%Y-%m-%d %H:%M:%OS", tz = "EST")
  )


require(StreamMetabolism)
sunrs = sunrise.set(
  lat = single_channel$Latitude, 
  long = single_channel$Longitude, 
  date = '2009/03/28', timezone = "EST", num.days = 7)


# shade = data.frame(
#   dusk = seq.POSIXt(as.POSIXlt("2009-03-28 18:00:00", tz = 'EST', format = '%Y-%m-%d %H:%M:%S'), by = 'day', length.out = 6),
#   dawn = seq.POSIXt(as.POSIXlt("2009-03-29 06:00:00", tz = 'EST', format = '%Y-%m-%d %H:%M:%S'), by = 'day', length.out = 6),
#   top = Inf, bottom = -Inf
# )

shade = data.frame(
  dusk = sunrs$sunset[-length(sunrs$sunset)],
  dawn = sunrs$sunrise[-1],
  top = Inf, bottom = -Inf
)

p.call = wcall %>% 
  ggplot()+
  geom_rect(
    data = shade,
    aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
    fill = 'gray50', alpha = 0.2) +
  geom_segment(
    aes(x = EST, xend = EST, y = 0.9, yend = 1.1),
    alpha = 0.5, color = 'grey30', linewidth = 0.1
  ) +
  scale_x_datetime(date_breaks = "1 day", date_labels = "%b %d") +
  coord_cartesian(y = c(0.8, 1.2)) +
  labs(title = 'Occurence of up-calls',
  )+
  theme_minimal() +
  theme(
    legend.position = "none",
    axis.title = element_blank(),
    axis.text.y = element_blank(),
    # plot.margin = margin(t = -3))
    plot.margin = margin(t = 2)
    )


rolling_width <- 30
noise_rolling <- noise %>%
  arrange(EST) %>%
  mutate(RMS = zoo::rollapply(RMS, width = rolling_width, 
                                     FUN = mean, align = "right", 
                                     fill = NA, partial = TRUE))

p.noise = noise_rolling %>%
  ggplot() +
  geom_rect(data = shade,
            aes(xmin = dusk, xmax = dawn, ymin = bottom, ymax = top),
            fill = 'gray50', alpha = 0.2) +
  geom_line(aes(x = EST, y = RMS)) +
  labs(
    y = "Sound pressure level - dB",
    title = 'Ambient noise levels'
  ) +
  theme_minimal() +
  scale_x_datetime(date_breaks = "1 day", date_labels = "%b %d") +
  theme(
    legend.position = "none",
    axis.title.x = element_blank(),
    # plot.margin = margin(b = -10, t = 2))
    plot.margin = margin(t = 2)
  )

require(egg)
p_both = ggarrange(p.call, p.noise, ncol = 1)
ggsave(plot = p_both, width = 7.5, height = 3.7, filename = 'nopp/fig/noppCallNoise.pdf')


# ggsave(plot = plot.noise, width = 5, height = 2.8, device = cairo_ps,
#        filename = 'nopp/fig/nopp2009noise.eps')

