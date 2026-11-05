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
