library(suncalc)
library(readr)

buoys <- read.csv(
  'data/buoy_locs.csv',
  strip.white = TRUE,
  colClasses = 'character'
) %>%
  rename_with(str_trim) %>%
  mutate(across(c(Lat, Lon), ~ as.numeric(str_replace_all(.x, '−', '-'))))

gap_vs_coverage <- read_csv("fig/combined/gap_vs_coverage.csv")

gap_vs_coverage <- gap_vs_coverage |>
  dplyr::mutate(
    lon = case_when(
      Buoy == "NS01" ~ buoys$Lon[buoys$DeployID == "NS01"],
      Buoy == "NS02" ~ buoys$Lon[buoys$DeployID == "NS02"],
      Buoy == "COX01" ~ buoys$Lon[buoys$DeployID == "COX01"]
    ),
    lat = case_when(
      Buoy == "NS01" ~ buoys$Lat[buoys$DeployID == "NS01"],
      Buoy == "NS02" ~ buoys$Lat[buoys$DeployID == "NS02"],
      Buoy == "COX01" ~ buoys$Lat[buoys$DeployID == "COX01"]
    ),
    date = lubridate::date(when)
  )

sne_times <- getSunlightTimes(
  data = gap_vs_coverage,
  tz = "UTC",
  keep = c("sunrise", "nauticalDawn")
)
