# =============================================================================
# context/ais/01_download.R — GFW AIS vessel presence within 10 km of each buoy.
#
# Daily vessel-hours inside each buoy's 10 km circle, one request per
# buoy x winter x vessel type (3 x 2 x 11 = 66), for the analysis winter and
# the prior winter. See docs/ais_context_spec.md.
#
# Calls the 4Wings report endpoint directly with spatial-aggregation=true:
# gfwr 3.0 doesn't expose that option, and gridded reports are paused upstream
# (HTTP 404, since 2026-11-03). The endpoint insists on a grouping, so we group
# by flag and sum over flags.
#
# Each response is cached (empty ones too) as cache/<buoy>_<season>_<type>.rds,
# so a rerun only fetches what's missing. Delete a file to refetch it.
#
# Usage:   Rscript context/ais/01_download.R      (from the repo root)
# Needs:   GFW_TOKEN in ~/.Renviron (free, non-commercial; CC BY-NC 4.0)
# Input:   data/release/sites.parquet             (buoy positions)
# Output:  context/ais/cache/*.rds, context/ais/cache/presence.parquet
#          (normalized: buoy, season, date, vessel_type, hours, vessels)
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(httr2)
  library(arrow)
})

token <- Sys.getenv('GFW_TOKEN')
if (!nzchar(token))
  stop('GFW_TOKEN is not set. Add GFW_TOKEN=<token> to ~/.Renviron and restart R.',
       call. = FALSE)

cache_dir <- 'context/ais/cache'
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

radius_m <- 10000
seasons  <- list(analysis = c('2021-10-01', '2022-03-01'),   # end exclusive
                 baseline = c('2020-10-01', '2021-03-01'))
# The dataset's own vessel_type enum (GET /v3/datasets/public-global-presence:latest)
vessel_types <- c('fishing', 'other_non_fishing', 'passenger', 'cargo', 'carrier',
                  'insufficient_data', 'bunker', 'seismic_vessel', 'gear',
                  'support', 'inactive')

sites <- as.data.frame(read_parquet('data/release/sites.parquet'))[, c('site', 'lat', 'lon')]

# 10 km circle around a buoy, built in UTM 19N (all three buoys are in zone 19),
# as a GeoJSON FeatureCollection for the request body.
circle_geojson <- function(lon, lat) {
  pt  <- st_sfc(st_point(c(lon, lat)), crs = 4326)
  buf <- st_transform(st_buffer(st_transform(pt, 32619), radius_m), 4326)
  tf  <- tempfile(fileext = '.geojson')
  st_write(st_sf(geometry = buf), tf, quiet = TRUE)
  fc  <- jsonlite::fromJSON(tf, simplifyVector = FALSE)
  list(type = 'FeatureCollection', features = fc$features)
}

# One area-total request -> data.frame(date, flag, hours, vessels); 0 rows if none.
fetch_presence <- function(geojson, start, end, vessel_type) {
  resp <- request('https://gateway.api.globalfishingwatch.org/v3/4wings/report') |>
    req_url_query(`datasets[0]`          = 'public-global-presence:latest',
                  `date-range`           = paste(start, end, sep = ','),
                  `spatial-resolution`   = 'HIGH',
                  `temporal-resolution`  = 'DAILY',
                  `spatial-aggregation`  = 'true',
                  `group-by`             = 'FLAG',
                  `filters[0]`           = sprintf("vessel_type in ('%s')", vessel_type),
                  format                 = 'JSON') |>
    req_auth_bearer_token(token) |>
    req_body_json(list(geojson = geojson)) |>
    req_retry(max_tries = 5, is_transient = \(r) resp_status(r) %in% c(429, 503, 524)) |>
    req_timeout(600) |>
    req_perform()
  entries <- resp_body_json(resp)$entries[[1]][[1]]
  if (is.null(entries) || length(entries) == 0)
    return(data.frame(date = character(), flag = character(),
                      hours = numeric(), vessels = integer()))
  do.call(rbind, lapply(entries, function(e)
    data.frame(date = e$date, flag = e$flag, hours = e$hours, vessels = e$vesselIDs)))
}

for (i in seq_len(nrow(sites))) {
  b  <- sites$site[i]
  gj <- circle_geojson(sites$lon[i], sites$lat[i])
  for (s in names(seasons)) for (vt in vessel_types) {
    f <- file.path(cache_dir, sprintf('%s_%s_%s.rds', tolower(b), s, vt))
    if (file.exists(f)) next
    cat(sprintf('%-5s %-8s %-17s ', b, s, vt))
    d <- fetch_presence(gj, seasons[[s]][1], seasons[[s]][2], vt)
    saveRDS(d, f)
    cat(sprintf('%4d rows, %7.0f h\n', nrow(d), sum(d$hours)))
  }
}

# Normalize: sum over flags -> one row per buoy x season x day x vessel type.
rows <- do.call(rbind, lapply(list.files(cache_dir, '\\.rds$', full.names = TRUE), function(f) {
  d <- readRDS(f)
  if (nrow(d) == 0) return(NULL)
  key <- strsplit(sub('\\.rds$', '', basename(f)), '_')[[1]]
  d$buoy        <- toupper(key[1])
  d$season      <- key[2]
  d$vessel_type <- paste(key[-(1:2)], collapse = '_')
  d
}))
presence <- aggregate(cbind(hours, vessels) ~ buoy + season + date + vessel_type,
                      data = rows, FUN = sum)
presence$date <- as.Date(presence$date)
presence <- presence[order(presence$buoy, presence$season, presence$date,
                           presence$vessel_type), ]
write_parquet(presence, file.path(cache_dir, 'presence.parquet'))

# Hand check (chunk 1 "done when"): date range, rows per buoy x season,
# total vessel-hours per type.
cat('\nDate range by season:\n')
print(do.call(rbind, lapply(split(presence$date, presence$season), \(x)
  data.frame(first = min(x), last = max(x)))))
cat('\nRows by buoy x season:\n');  print(table(presence$buoy, presence$season))
cat('\nVessel-hours by type x season:\n')
print(round(xtabs(hours ~ vessel_type + season, presence)))
