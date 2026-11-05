# =============================================================================
# context/ais/02_table.R — Per-buoy AIS traffic table for the talk.
#
# Mean vessel-hours per day within 10 km of each buoy, by vessel group, for the
# analysis winter (Oct 2021 – Feb 2022) and the prior winter, with the change
# between them. One row per group, one block of columns per buoy, so it fits a
# 16:9 slide. Built from buoy_table() (R/summary.R).
#
# Change is shown only when both winters average at least 0.1 vessel-hours a
# day: below that a ratio is one or two boats and reads as a trend it isn't.
#
# Usage:   Rscript context/ais/02_table.R      (from the repo root)
# Input:   context/ais/cache/presence.parquet  (01_download.R)
# Output:  fig/context/ais/buoy_table.{rds,html,png}, and
#          buoy_table_simple.{rds,html,png} (analysis winter only, for pairing
#          with fig/talk/volume_knob.png); the .rds is the gt object (readRDS()
#          it and print, or gt::gtsave() it elsewhere);
#          context/ais/buoy_table.{csv,parquet} (committed numbers)
# =============================================================================

suppressPackageStartupMessages({
  library(gt)
  library(arrow)
})
source('context/ais/R/summary.R')   # buoy_table(), buoy_order

out_dir <- 'fig/context/ais'
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
min_rate <- 0.1                      # vessel-hours/day; below this, no change shown

tab <- buoy_table(as.data.frame(read_parquet('context/ais/cache/presence.parquet')))
write.csv(tab, 'context/ais/buoy_table.csv', row.names = FALSE)
write_parquet(tab, 'context/ais/buoy_table.parquet')

# Every printed number is >= min_rate, so a change shows exactly when both
# winters print a number.
fmt_rate   <- function(x) ifelse(x == 0, '0', ifelse(x < min_rate, '<0.1', sprintf('%.1f', x)))
fmt_change <- function(a, b) ifelse(a >= min_rate & b >= min_rate,
                                    sprintf(ifelse(a / b < 0.1, '%.2f×', '%.1f×'), a / b),
                                    '—')

# Wide: one row per group, <buoy>_now / <buoy>_prior / <buoy>_change per buoy.
groups <- unique(tab$group)
wide <- data.frame(group = groups)
for (b in buoy_order) {
  t <- tab[tab$buoy == b, ][match(groups, tab$group[tab$buoy == b]), ]
  wide[[paste0(b, '_now')]]    <- fmt_rate(t$hours_analysis)
  wide[[paste0(b, '_prior')]]  <- fmt_rate(t$hours_baseline)
  wide[[paste0(b, '_change')]] <- fmt_change(t$hours_analysis, t$hours_baseline)
}
wide$group[wide$group == 'Seismic / survey'] <- 'Seismic / survey (AIS type)'

g <- gt(wide, rowname_col = 'group') |>
  tab_header(title = 'AIS vessel traffic within 10 km of each hydrophone',
             subtitle = 'Mean vessel-hours per day, October – February') |>
  cols_label(.list = setNames(
    as.list(rep(c('2021–22', '2020–21', 'Change'), length(buoy_order))),
    as.vector(outer(c('_now', '_prior', '_change'), buoy_order, \(s, b) paste0(b, s))))) |>
  cols_align('center', columns = -group) |>
  tab_style(style = cell_text(weight = 'bold'),
            locations = list(cells_body(rows = group == 'Total'),
                             cells_stub(rows = group == 'Total'))) |>
  tab_style(style = cell_borders(sides = 'top', weight = px(2)),
            locations = list(cells_body(rows = group == 'Total'),
                             cells_stub(rows = group == 'Total'))) |>
  tab_style(style = cell_text(color = 'grey40'),
            locations = cells_body(columns = ends_with('_prior'))) |>
  tab_source_note(paste0(
    'Change = 2021–22 ÷ 2020–21, shown when both winters average at least ',
    min_rate, ' vessel-hours a day. Groups are Global Fishing Watch’s classification ',
    'of each vessel’s broadcast AIS type; AIS misses most small boats.')) |>
  tab_source_note('Vessel presence: Global Fishing Watch (globalfishingwatch.org), CC BY-NC 4.0.') |>
  opt_table_font(font = google_font('Roboto')) |>
  tab_options(table.font.size = px(16), heading.title.font.size = px(22),
              heading.align = 'left', data_row.padding = px(4),
              source_notes.font.size = px(12))
for (b in rev(buoy_order))
  g <- tab_spanner(g, label = b, columns = starts_with(paste0(b, '_')), id = b)

save_gt <- function(g, name) {
  f <- file.path(out_dir, name)
  saveRDS(g, paste0(f, '.rds'))
  gtsave(g, paste0(f, '.html'))
  gtsave(g, paste0(f, '.png'), zoom = 2, expand = 10)
  cat('Wrote ', f, '.{rds,html,png}\n', sep = '')
}
save_gt(g, 'buoy_table')

# Simple version, to pair with fig/talk/volume_knob.png: analysis winter only,
# one column per buoy, NS01's seismic / survey cell highlighted. Heading styled
# like the ggplot talk figures (bold black title, grey subtitle, Helvetica).
simple <- data.frame(group = groups)
for (b in buoy_order)
  simple[[b]] <- fmt_rate(tab$hours_analysis[tab$buoy == b][match(groups, tab$group[tab$buoy == b])])
simple$group[simple$group == 'Seismic / survey'] <- 'Seismic / survey (AIS type)'

source('src/anim_schematic.R')      # col_counter
s <- gt(simple, rowname_col = 'group') |>
  tab_header(title = md('**Vessel traffic within 10 km of each hydrophone**'),
             subtitle = 'Mean vessel-hours per day, October 2021 \u2013 February 2022') |>
  cols_align('center', columns = -group) |>
  tab_style(style = cell_text(weight = 'bold'),
            locations = list(cells_body(rows = group == 'Total'),
                             cells_stub(rows = group == 'Total'),
                             cells_column_labels())) |>
  tab_style(style = cell_borders(sides = 'top', weight = px(2)),
            locations = list(cells_body(rows = group == 'Total'),
                             cells_stub(rows = group == 'Total'))) |>
  tab_style(style = list(cell_fill(color = col_counter), cell_text(color = 'white', weight = 'bold')),
            locations = cells_body(columns = NS01, rows = grepl('^Seismic', group))) |>
  tab_style(style = cell_text(color = 'grey35'), locations = cells_title('subtitle')) |>
  tab_style(style = cell_text(color = 'black'), locations = cells_title('title')) |>
  tab_source_note(paste0('Groups are Global Fishing Watch\u2019s classification of broadcast AIS ',
                         'vessel type; AIS misses most small boats.')) |>
  tab_source_note('Vessel presence: Global Fishing Watch (globalfishingwatch.org), CC BY-NC 4.0.') |>
  opt_table_font(font = c('Helvetica', 'Arial', 'sans-serif')) |>
  tab_options(table.font.size = px(18), heading.title.font.size = px(26),
              heading.subtitle.font.size = px(18), heading.align = 'left',
              data_row.padding = px(6), source_notes.font.size = px(12),
              column_labels.font.size = px(20))
save_gt(s, 'buoy_table_simple')
