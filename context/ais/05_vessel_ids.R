# =============================================================================
# context/ais/05_vessel_ids.R — Name the seismic-type vessels seen by GFW.
#
# GFW area totals give only flag and a daily distinct-vessel count, so the
# seismic-type presence near COX01 (fall 2020) and NS01 (2021–22) has no vessel
# IDs. MarineCadastre's raw AIS points (USCG Nationwide AIS, one national CSV
# per day) carry MMSI, name, IMO, call sign and AIS type. Rather than download
# every day of each window (~180 files, ~300 MB each), this samples the days
# when GFW had each flag inside the circle longest, keeps the points within
# 10 km, and summarizes them per vessel. The MMSI's first three digits (MID)
# give the flag, to match against GFW's.
#
# Usage:   Rscript context/ais/05_vessel_ids.R      (from the repo root)
# Input:   data/release/sites.parquet; MarineCadastre daily zips (cached in
#          cache/mc/, gitignored)
# Output:  context/ais/vessel_ids.csv  (buoy, date, one row per vessel)
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(arrow)
  library(data.table)
})

mc_dir <- 'context/ais/cache/mc'
dir.create(mc_dir, recursive = TRUE, showWarnings = FALSE)
radius_m <- 10000

# Peak-presence days per flag, from the cached GFW seismic_vessel responses.
samples <- data.frame(
  buoy = c('COX01', 'COX01', 'NS01', 'NS01', 'NS01', 'NS01', 'NS01'),
  gfw_flag = c('NLD', 'NLD', 'MHL', 'MHL', 'MHL', 'NOR', 'NOR'),
  date = as.Date(c('2020-10-04', '2020-10-26', '2021-10-21', '2021-12-29', '2022-01-27',
                   '2021-11-06', '2021-11-20')))

# MID -> flag for the flags in question (ITU maritime identification digits).
mid_flag <- c(`244` = 'NLD', `245` = 'NLD', `246` = 'NLD', `538` = 'MHL',
              `257` = 'NOR', `258` = 'NOR', `259` = 'NOR', `366` = 'USA',
              `367` = 'USA', `368` = 'USA', `369` = 'USA', `338` = 'USA',
              `308` = 'BHS', `309` = 'BHS', `311` = 'BHS', `232` = 'GBR',
              `233` = 'GBR', `234` = 'GBR', `235` = 'GBR', `351` = 'PAN',
              `352` = 'PAN', `353` = 'PAN', `354` = 'PAN', `355` = 'PAN',
              `356` = 'PAN', `357` = 'PAN', `370` = 'PAN', `371` = 'PAN',
              `372` = 'PAN', `373` = 'PAN')

sites <- as.data.frame(read_parquet('data/release/sites.parquet'))[, c('site', 'lat', 'lon')]

daily_zip <- function(d) {
  f <- file.path(mc_dir, format(d, 'AIS_%Y_%m_%d.zip'))
  if (!file.exists(f)) {
    options(timeout = 3600)
    download.file(sprintf('https://coast.noaa.gov/htdata/CMSP/AISDataHandler/%s/%s',
                          format(d, '%Y'), basename(f)), f, mode = 'wb')
  }
  f
}

# Points within 10 km of a buoy on one day. A lon/lat box prefilter in awk keeps
# the national file (~7M rows) out of memory; the circle is then exact (UTM 19N).
points_near <- function(buoy, d) {
  s  <- sites[sites$site == buoy, ]
  dl <- 0.13; dn <- 0.10                        # > 10 km at 41 N
  cmd <- sprintf("unzip -p '%s' | awk -F, 'NR == 1 || ($4 > %f && $4 < %f && $3 > %f && $3 < %f)'",
                 daily_zip(d), s$lon - dl, s$lon + dl, s$lat - dn, s$lat + dn)
  x <- fread(cmd = cmd, colClasses = list(character = c('MMSI', 'IMO', 'CallSign', 'VesselName')))
  if (!nrow(x)) return(x)
  p <- st_transform(st_as_sf(x, coords = c('LON', 'LAT'), crs = 4326, remove = FALSE), 32619)
  c0 <- st_transform(st_sfc(st_point(c(s$lon, s$lat)), crs = 4326), 32619)
  x[as.numeric(st_distance(p, c0)) <= radius_m]
}

mode_of <- function(v) { v <- v[!is.na(v) & v != '']; if (length(v)) names(which.max(table(v))) else NA_character_ }

out <- rbindlist(lapply(seq_len(nrow(samples)), function(i) {
  smp <- samples[i, ]
  x <- points_near(smp$buoy, smp$date)
  cat(sprintf('%s %s: %d points, %d vessels\n', smp$buoy, smp$date, nrow(x), uniqueN(x$MMSI)))
  if (!nrow(x)) return(NULL)
  x[, hour := substr(BaseDateTime, 1, 13)]
  x[, .(vessel_name = mode_of(VesselName), imo = mode_of(IMO), call_sign = mode_of(CallSign),
        ais_type = mode_of(VesselType), length_m = mode_of(Length),
        hours_present = uniqueN(hour), points = .N,
        first = min(BaseDateTime), last = max(BaseDateTime)),
    by = .(mmsi = MMSI)][
    , `:=`(buoy = smp$buoy, date = smp$date, gfw_flag = smp$gfw_flag,
           mid_flag = unname(mid_flag[substr(mmsi, 1, 3)]))][]
}))

setcolorder(out, c('buoy', 'date', 'gfw_flag', 'mmsi', 'mid_flag', 'vessel_name', 'imo',
                   'call_sign', 'ais_type', 'length_m', 'hours_present', 'points', 'first', 'last'))
setorder(out, buoy, date, -hours_present)
fwrite(out, 'context/ais/vessel_ids.csv')
cat('Wrote context/ais/vessel_ids.csv\n')

# The candidates: vessels whose MMSI flag matches the flag GFW reported.
print(out[mid_flag == gfw_flag, .(buoy, date, gfw_flag, mmsi, vessel_name, imo, call_sign,
                                  ais_type, length_m, hours_present)])
