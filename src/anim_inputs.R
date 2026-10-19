# =============================================================================
# anim_inputs.R — Readers for the talk animation (10_hawkesAnim.R)
#
# Every reader returns times as POSIXct in true UTC (`time_utc`).
# `clock_offset_h` is the hours added to a logger stamp to get UTC; the stamps
# are true UTC, so 10_hawkesAnim.R passes 0. Use the same value for every reader.
# =============================================================================

stamp_to_utc <- function(x, clock_offset_h) {
  as.POSIXct(as.numeric(x) + clock_offset_h * 3600, origin = '1970-01-01', tz = 'UTC')
}

# One row per recorder: site, lat, lon, label
read_sne_sites <- function(path = 'data/release/sites.parquet') {
  s <- as.data.frame(arrow::read_parquet(path))
  data.frame(site = s$site, lat = s$lat, lon = s$lon, label = s$site)
}

# One row per upcall: site, time_utc (call midpoint, the model's event time),
# validated. All release rows are analyst-verified upcalls.
read_sne_calls <- function(path = 'data/release/upcalls.parquet', clock_offset_h) {
  u <- as.data.frame(arrow::read_parquet(path, col_select = c('site', 'mid_utc')))
  out <- data.frame(site = u$site, time_utc = stamp_to_utc(u$mid_utc, clock_offset_h),
                    validated = TRUE)
  out[order(out$site, out$time_utc), ]
}

# One row per continuous recording block (all deployments record continuously,
# so a block is one deployment). The deployment sheet's clock is not certain to
# match the call logs, so each block is trimmed by `trim_h` at both ends.
read_sne_effort <- function(path = 'data/release/deployments.parquet', clock_offset_h,
                            trim_h = 6) {
  d <- as.data.frame(arrow::read_parquet(path))
  data.frame(site = d$site,
             start_utc = stamp_to_utc(d$deployed_utc, clock_offset_h) + trim_h * 3600,
             end_utc   = stamp_to_utc(d$retrieved_utc, clock_offset_h) - trim_h * 3600)
}

# Exports written by 10a_animExport.R, one per buoy
read_anim_exports <- function(dir = 'out/anim') {
  f <- list.files(dir, pattern = '_anim\\.rds$', full.names = TRUE)
  if (!length(f)) stop('No exports in ', dir, '; run 10a_animExport.R --buoy=<buoy> first')
  lapply(setNames(f, toupper(sub('_anim\\.rds$', '', basename(f)))), readRDS)
}

# One row per site: site, alpha, eta (per min), kernel, plus quantiles
read_sne_fits <- function(exports) {
  do.call(rbind, lapply(exports, `[[`, 'fit'))
}

# Fitted background: site, time_utc, mu (calls/min), mu_lo, mu_hi
read_sne_background <- function(exports, clock_offset_h) {
  do.call(rbind, lapply(exports, function(e) {
    b <- e$background
    data.frame(site = b$site, time_utc = stamp_to_utc(b$stamp, clock_offset_h),
               mu = b$mu, mu_lo = b$mu_lo, mu_hi = b$mu_hi)
  }))
}

# Per-call branching summaries from the fit: site, i, time_utc, p_counter,
# parent (index i of the modal parent at the same site), parent_prob
read_sne_branching <- function(exports, clock_offset_h) {
  do.call(rbind, lapply(exports, function(e) {
    k <- e$calls
    data.frame(site = k$site, i = k$i, time_utc = stamp_to_utc(k$stamp, clock_offset_h),
               p_counter = k$p_counter, parent = k$parent, parent_prob = k$parent_prob)
  }))
}

# Attach p_counter / parent to release calls by nearest time within site.
# Calls outside the fit window get NA.
attach_branching <- function(calls, branching, tol_s = 2) {
  calls$fit_i <- NA_integer_; calls$p_counter <- NA_real_
  for (s in intersect(unique(calls$site), unique(branching$site))) {
    ic <- which(calls$site == s)
    b  <- branching[branching$site == s, ]
    tb <- as.numeric(b$time_utc); tc <- as.numeric(calls$time_utc[ic])
    j  <- findInterval(tc, tb, all.inside = TRUE)
    j  <- ifelse(abs(tc - tb[j]) <= abs(tc - tb[j + 1]), j, j + 1)
    ok <- abs(tc - tb[j]) <= tol_s
    calls$fit_i[ic[ok]]     <- b$i[j[ok]]
    calls$p_counter[ic[ok]] <- b$p_counter[j[ok]]
  }
  calls
}
