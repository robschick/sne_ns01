# Tests for the AIS summary module (R/summary.R). Run from the repo root:
#   Rscript -e 'testthat::test_dir("context/ais/tests")'

source(testthat::test_path('..', 'R', 'summary.R'))

# One normalized presence row (the cache schema from 01_download.R).
pres <- function(buoy = 'NS01', season = 'analysis', date = '2021-10-15',
                 vessel_type = 'fishing', hours = 10, vessels = 1)
  data.frame(buoy = buoy, season = season, date = as.Date(date),
             vessel_type = vessel_type, hours = hours, vessels = vessels)

row_of <- function(tab, buoy, group)
  tab[tab$buoy == buoy & tab$group == group, ]

test_that('mean vessel-hours per day divides by the 151 days in the season', {
  tab <- buoy_table(pres(hours = 151))
  expect_equal(row_of(tab, 'NS01', 'Fishing')$hours_analysis, 1)
})

test_that('a season with no rows counts as zero traffic, not missing', {
  tab <- buoy_table(pres(season = 'baseline', date = '2020-10-15', hours = 151))
  r <- row_of(tab, 'NS01', 'Fishing')
  expect_equal(nrow(r), 1)
  expect_equal(r$hours_analysis, 0)
  expect_equal(r$hours_baseline, 1)
})

test_that('only days inside the season count: Oct 1 and Feb 28 in, Sep 30 and Mar 1 out', {
  rows <- rbind(pres(date = '2021-09-30', hours = 1000),
                pres(date = '2021-10-01', hours = 100),
                pres(date = '2022-02-28', hours = 51),
                pres(date = '2022-03-01', hours = 1000))
  expect_equal(row_of(buoy_table(rows), 'NS01', 'Fishing')$hours_analysis, 1)
})

test_that('vessel types map to talk groups; Total also counts insufficient_data and inactive', {
  types <- c(cargo = 151, bunker = 151, carrier = 151, passenger = 151,
             fishing = 151, gear = 151, seismic_vessel = 151,
             support = 151, other_non_fishing = 151,
             insufficient_data = 151, inactive = 151)
  rows <- do.call(rbind, Map(\(t, h) pres(vessel_type = t, hours = h), names(types), types))
  tab <- buoy_table(rows)
  got <- setNames(tab$hours_analysis, tab$group)
  expect_equal(got[c('Cargo & tanker', 'Passenger', 'Fishing', 'Seismic / survey',
                     'Support & other', 'Total')],
               c(`Cargo & tanker` = 3, Passenger = 1, Fishing = 2,
                 `Seismic / survey` = 1, `Support & other` = 2, Total = 11))
  expect_setequal(tab$group, c('Cargo & tanker', 'Passenger', 'Fishing',
                               'Seismic / survey', 'Support & other', 'Total'))
})

test_that('an unknown vessel type stops with an error naming it', {
  expect_error(buoy_table(pres(vessel_type = 'tanker')), 'tanker')
})

test_that('mean distinct vessels per day is reported alongside vessel-hours', {
  rows <- rbind(pres(date = '2021-10-01', hours = 100, vessels = 100),
                pres(date = '2021-10-02', hours = 51,  vessels = 51))
  r <- row_of(buoy_table(rows), 'NS01', 'Fishing')
  expect_equal(r$vessels_analysis, 1)
  expect_equal(r$vessels_baseline, 0)
})

test_that('ratio is analysis / baseline vessel-hours, NA when the baseline is zero', {
  rows <- rbind(pres(vessel_type = 'fishing', hours = 300),
                pres(vessel_type = 'fishing', season = 'baseline', date = '2020-10-15', hours = 100),
                pres(vessel_type = 'seismic_vessel', hours = 50))
  tab <- buoy_table(rows)
  expect_equal(row_of(tab, 'NS01', 'Fishing')$ratio, 3)
  expect_true(is.na(row_of(tab, 'NS01', 'Seismic / survey')$ratio))   # 50 / 0
  expect_true(is.na(row_of(tab, 'NS01', 'Passenger')$ratio))          #  0 / 0
})

test_that('buoys come back west to east and groups in slide order, Total last', {
  rows <- rbind(pres(buoy = 'NS02'), pres(buoy = 'COX01'), pres(buoy = 'NS01'))
  tab <- buoy_table(rows)
  expect_equal(unique(tab$buoy), c('COX01', 'NS01', 'NS02'))
  expect_equal(tab$group[tab$buoy == 'NS02'],
               c('Cargo & tanker', 'Passenger', 'Fishing', 'Seismic / survey',
                 'Support & other', 'Total'))
})

# --- weekly_series() ---------------------------------------------------------

week_of <- function(ws, week, season = 'analysis', buoy = 'NS01')
  ws[ws$buoy == buoy & ws$season == season & ws$week == week, ]

test_that('week 1 is Oct 1-7 in both seasons; Oct 8 starts week 2', {
  rows <- rbind(pres(date = '2021-10-01', hours = 7),
                pres(date = '2021-10-07', hours = 7),
                pres(date = '2021-10-08', hours = 70),
                pres(season = 'baseline', date = '2020-10-01', hours = 14),
                pres(season = 'baseline', date = '2020-10-08', hours = 70))
  ws <- weekly_series(rows)
  expect_equal(week_of(ws, 1)$hours, 2)
  expect_equal(week_of(ws, 2)$hours, 10)
  expect_equal(week_of(ws, 1, 'baseline')$hours, 2)
  expect_equal(week_of(ws, 2, 'baseline')$hours, 10)
})

test_that('the final week is Feb 25-28 and divides by its 4 days, not 7', {
  rows <- rbind(pres(date = '2022-02-24', hours = 70),
                pres(date = '2022-02-25', hours = 8),
                pres(date = '2022-02-28', hours = 4))
  ws <- weekly_series(rows)
  expect_equal(max(ws$week[ws$season == 'analysis']), 22)
  expect_equal(week_of(ws, 21)$hours, 10)
  expect_equal(week_of(ws, 22)$hours, 3)
})

test_that('smooth is the centered 3-week mean of the weekly values in the interior', {
  rows <- rbind(pres(date = '2021-10-22', hours = 21),   # week 4: 3/day
                pres(date = '2021-10-29', hours = 42))   # week 5: 6/day
  ws <- weekly_series(rows)
  expect_equal(week_of(ws, 4)$smooth, 3)   # (0 + 3 + 6) / 3
  expect_equal(week_of(ws, 5)$smooth, 3)   # (3 + 6 + 0) / 3
  expect_equal(week_of(ws, 6)$smooth, 2)   # (6 + 0 + 0) / 3
})

test_that('at the first and last week smooth averages only the neighbors that exist', {
  rows <- rbind(pres(date = '2021-10-01', hours = 14),   # week 1: 2/day
                pres(date = '2021-10-08', hours = 28),   # week 2: 4/day
                pres(date = '2022-02-18', hours = 7),    # week 21: 1/day
                pres(date = '2022-02-25', hours = 12))   # week 22: 3/day (4 days)
  ws <- weekly_series(rows)
  expect_equal(week_of(ws, 1)$smooth, 3)    # (2 + 4) / 2
  expect_equal(week_of(ws, 22)$smooth, 2)   # (1 + 3) / 2
  expect_false(anyNA(ws$smooth))
})

test_that('every buoy gets a full season of weeks, even one with no traffic at all', {
  ws <- weekly_series(pres(buoy = 'NS01'))
  expect_equal(unique(ws$buoy), c('COX01', 'NS01', 'NS02'))
  ns02 <- ws[ws$buoy == 'NS02' & ws$season == 'analysis', ]
  expect_equal(ns02$week, 1:22)
  expect_true(all(ns02$hours == 0 & ns02$smooth == 0))
})
