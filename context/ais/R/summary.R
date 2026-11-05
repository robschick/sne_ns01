# =============================================================================
# context/ais/R/summary.R — Summaries of the normalized GFW presence rows.
#
# Pure functions; the one tested seam (context/ais/tests/). Input rows follow
# the cache schema written by 01_download.R:
#   buoy, season ('analysis' / 'baseline'), date, vessel_type, hours, vessels
# Absent rows mean zero traffic. See docs/ais_context_spec.md.
# =============================================================================

# Winters, end exclusive (matches the model's 5-month window).
ais_seasons <- list(analysis = as.Date(c('2021-10-01', '2022-03-01')),
                    baseline = as.Date(c('2020-10-01', '2021-03-01')))

# GFW vessel type -> talk group. NA = counted in Total only. The names are the
# dataset's full vessel_type enum (checked 2026-11-05).
vessel_groups <- c(cargo             = 'Cargo & tanker',
                   bunker            = 'Cargo & tanker',
                   carrier           = 'Cargo & tanker',
                   passenger         = 'Passenger',
                   fishing           = 'Fishing',
                   gear              = 'Fishing',
                   seismic_vessel    = 'Seismic / survey',
                   support           = 'Support & other',
                   other_non_fishing = 'Support & other',
                   insufficient_data = NA,
                   inactive          = NA)

# West to east, as in the paper.
buoy_order <- c('COX01', 'NS01', 'NS02')

season_days <- function(s) as.numeric(diff(s))

# Per buoy x group (5 groups + Total), for each season: mean vessel-hours per
# day and mean distinct vessels per day over all days of the season (so empty
# days count as zero), and ratio = analysis / baseline vessel-hours (NA when
# the baseline is zero). Columns: buoy, group, hours_<season>,
# vessels_<season>, ratio.
buoy_table <- function(rows, groups = vessel_groups, seasons = ais_seasons) {
  unknown <- setdiff(rows$vessel_type, names(groups))
  if (length(unknown))
    stop('Unknown GFW vessel type(s): ', paste(unknown, collapse = ', '),
         '. Add them to vessel_groups.', call. = FALSE)
  rows$group <- unname(groups[rows$vessel_type])
  buoys  <- c(intersect(buoy_order, rows$buoy), setdiff(unique(rows$buoy), buoy_order))
  levels <- c(unique(na.omit(groups)), 'Total')
  out <- data.frame(buoy  = rep(buoys, each = length(levels)),
                    group = rep(levels, times = length(buoys)))
  for (s in names(seasons)) {
    r <- rows[rows$season == s & rows$date >= seasons[[s]][1] & rows$date < seasons[[s]][2], ]
    total <- r; total$group <- rep('Total', nrow(r))
    r <- rbind(r[!is.na(r$group), ], total)
    key <- paste(r$buoy, r$group)
    for (v in c('hours', 'vessels')) {
      tot <- as.vector(tapply(r[[v]], key, sum)[paste(out$buoy, out$group)])
      out[[paste0(v, '_', s)]] <- ifelse(is.na(tot), 0, tot) / season_days(seasons[[s]])
    }
  }
  out$ratio <- ifelse(out$hours_baseline > 0, out$hours_analysis / out$hours_baseline, NA)
  out
}

# Centered 3-point mean; at each end, the mean of the two points that exist.
rolling_mean3 <- function(x) {
  n <- length(x)
  sapply(seq_len(n), \(i) mean(x[max(1, i - 1):min(n, i + 1)]))
}

# Per buoy x season x week-of-season (week 1 starts on the season's first day,
# Oct 1 in both winters): mean vessel-hours per day within the week, all vessel
# types (the Total). The last week is short (4 days for a 151-day season) and
# divides by its own length, so it's comparable. smooth = centered 3-week
# rolling mean of hours; the first and last weeks average the two weeks that
# exist, so the line spans the season. Columns: buoy, season, week, hours,
# smooth.
weekly_series <- function(rows, seasons = ais_seasons) {
  buoys <- c(intersect(buoy_order, rows$buoy), setdiff(unique(rows$buoy), buoy_order))
  out <- list()
  for (s in names(seasons)) {
    r <- rows[rows$season == s & rows$date >= seasons[[s]][1] & rows$date < seasons[[s]][2], ]
    n_days  <- season_days(seasons[[s]])
    n_weeks <- ceiling(n_days / 7)
    week_days <- pmin(7, n_days - 7 * (seq_len(n_weeks) - 1))
    week <- as.numeric(r$date - seasons[[s]][1]) %/% 7 + 1
    grid <- data.frame(buoy = rep(buoys, each = n_weeks), season = s,
                       week = rep(seq_len(n_weeks), times = length(buoys)))
    tot <- as.vector(tapply(r$hours, paste(r$buoy, week), sum)[paste(grid$buoy, grid$week)])
    grid$hours <- ifelse(is.na(tot), 0, tot) / week_days[grid$week]
    grid$smooth <- ave(grid$hours, grid$buoy, FUN = rolling_mean3)
    out[[s]] <- grid
  }
  do.call(rbind, unname(out))
}
