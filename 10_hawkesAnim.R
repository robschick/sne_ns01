# =============================================================================
# 10_hawkesAnim.R — NARWC 2026 talk assets: SNE upcall animation + Hawkes
# "family tree" schematic. Plan: plans/PLAN_sne_hawkes_animation.md
#
# Needs out/anim/<buoy>_anim.rds for each site to show, from 10a_animExport.R
# (cluster: aci_anim_export.sh). Sites without an export are left out.
#
# Usage:
#   Rscript 10_hawkesAnim.R                 # windows, checks, 3 stills, schematic
#   Rscript 10_hawkesAnim.R --video         # ... plus the full mp4
#   Rscript 10_hawkesAnim.R --window=2      # use the 2nd-ranked window
#   Rscript 10_hawkesAnim.R --t0="2022-01-15 18:00"   # explicit start (UTC)
#   Rscript 10_hawkesAnim.R --wav=path.wav  # real upcall for the audio
#   FFMPEG=/path/to/ffmpeg Rscript 10_hawkesAnim.R --video   # non-PATH ffmpeg
#
# Output (fig/talk/): sne_hawkes.mp4, hawkes_schematic.pdf/.png,
#   still_{start,busiest,end}.png, windows.csv, site_summary.csv, rate_check.csv
# =============================================================================

rm(list = ls())
for (f in list.files('src', pattern = '^anim_.*\\.R$', full.names = TRUE)) source(f)

# ── Settings ───────────────────────────────────────────────────────────────
# Hours added to a logger stamp to get true UTC. The stamps are true UTC
# (confirmed 2026-10-19), so 0; only on-screen clock labels depend on it.
clock_offset_h <- 0
tz        <- 'America/New_York'
win_min   <- 120
secs      <- 22
fps       <- 15
hold_secs <- 3
out_dir   <- 'fig/talk'
takeaway  <- paste('Calls aren\'t independent: counting them as if they were mixes up',
                   'how many whales are calling\nwith how much they\'re answering each other.')

args <- commandArgs(trailingOnly = TRUE)
arg  <- function(name) {
  hit <- grep(paste0('^--', name, '='), args, value = TRUE)
  if (length(hit)) sub(paste0('^--', name, '='), '', hit[1]) else NULL
}
do_video <- '--video' %in% args
wav      <- arg('wav')
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)


# ── Inputs ─────────────────────────────────────────────────────────────────
exports    <- read_anim_exports('out/anim')
fits       <- read_sne_fits(exports)
background <- read_sne_background(exports, clock_offset_h)
branching  <- read_sne_branching(exports, clock_offset_h)
sites      <- read_sne_sites()
calls      <- read_sne_calls(clock_offset_h = clock_offset_h)
effort     <- read_sne_effort(clock_offset_h = clock_offset_h)

missing <- setdiff(sites$site, fits$site)
if (length(missing)) message('No fit export for ', paste(missing, collapse = ', '),
                             '; showing ', paste(fits$site, collapse = ', '))
sites <- sites[sites$site %in% fits$site, ]
calls <- attach_branching(calls[calls$site %in% fits$site, ], branching)
check_inputs(sites, calls, effort, fits, background)

# Release calls should line up one-to-one with the fitted calls in the fit window
for (s in fits$site) {
  b <- range(branching$time_utc[branching$site == s])
  inwin <- calls$site == s & calls$time_utc >= b[1] & calls$time_utc <= b[2]
  cat(sprintf('%s: %d of %d release calls in the fit window matched a fitted call\n',
              s, sum(!is.na(calls$fit_i[inwin])), sum(inwin)))
}


# ── Window ─────────────────────────────────────────────────────────────────
# Restrict to times where every shown site has a fitted background
bounds  <- c(max(tapply(background$time_utc, background$site, min)),
             min(tapply(background$time_utc, background$site, max)))
bounds  <- as.POSIXct(c(ceiling(bounds[1] / 60), floor(bounds[2] / 60)) * 60,
                      origin = '1970-01-01', tz = 'UTC')     # whole minutes
windows <- pick_window(calls, effort, win_min = win_min, sites = fits$site, bounds = bounds)
write.csv(windows, file.path(out_dir, 'windows.csv'), row.names = FALSE)
print(windows)

t0 <- if (!is.null(arg('t0'))) {
  as.POSIXct(arg('t0'), tz = 'UTC')
} else {
  windows$start_utc[as.integer(if (is.null(arg('window'))) 1 else arg('window'))]
}
cat(sprintf('Window: %s to %s (%s)\n', format(t0, '%Y-%m-%d %H:%M', tz = tz),
            format(t0 + win_min * 60, '%H:%M %Z', tz = tz), tz))


# ── Rate ───────────────────────────────────────────────────────────────────
rate <- rate_grid(calls, background, fits, t0, win_min)
rate_ok <- check_rate(rate, calls, fits, t0, win_min)
write.csv(rate_ok, file.path(out_dir, 'rate_check.csv'), row.names = FALSE)
print(rate_ok)

calls$t_min <- mins_since(calls$time_utc, t0)
win_calls   <- calls[calls$t_min >= 0 & calls$t_min <= win_min, ]
ymax <- max(rate$lambda[rate$t_min >= 0])

summary_tbl <- site_summary(fits, calls, t0, win_min, branching)
write.csv(summary_tbl, file.path(out_dir, 'site_summary.csv'), row.names = FALSE)
print(summary_tbl)


# ── Stills: start, busiest moment, end ─────────────────────────────────────
basemap <- make_basemap(sites, lease_areas = read_lease_outline())
in_win  <- rate[rate$t_min >= 0, ]
stills  <- c(start = 0.5, busiest = in_win$t_min[which.max(in_win$lambda)], end = win_min)
for (nm in names(stills)) {
  ggsave(file.path(out_dir, paste0('still_', nm, '.png')),
         draw_frame(stills[[nm]], rate, win_calls, basemap, t0, win_min, ymax, tz = tz,
                    caption = if (nm == 'end') takeaway),
         width = 12, height = 6.2, dpi = 100, bg = 'white')
}


# ── Video ──────────────────────────────────────────────────────────────────
if (do_video) {
  audio  <- build_audio(win_calls, win_min, secs, total_secs = secs + hold_secs,
                        upcall_wav = wav, path = file.path(tempdir(), 'upcalls.raw'))
  frames <- render_frames(rate, win_calls, basemap, t0, win_min, ymax, secs = secs,
                          fps = fps, hold_secs = hold_secs, caption = takeaway,
                          outdir = file.path(tempdir(), 'frames'), tz = tz)
  video  <- encode_video(frames, audio, file.path(out_dir, 'sne_hawkes.mp4'), fps = fps)
  cat('Wrote', video, '\n')
}


# ── Schematic ──────────────────────────────────────────────────────────────
# Preferred: a family tree of real calls from the fit's branching structure, at
# the site and short span (5-30 min) inside the window with the most confident
# links. In dense bursts the fit is sure a call is a countercall but rarely sure
# which call it answers, so if fewer than `min_links` links clear P > 0.5, fall
# back to a simulated tree with the median SNE parameters (real time scale).
min_links <- 4
spans <- lapply(setNames(fits$site, fits$site), function(s)
  pick_tree_span(branching, s, t0, win_min))
spans <- Filter(function(sp) !is.null(sp) && sp$links >= min_links, spans)
if (length(spans)) {
  s_tree <- names(spans)[which.max(vapply(spans, `[[`, numeric(1), 'links'))]
  sp     <- spans[[s_tree]]
  tree   <- tree_from_fit(branching, s_tree, sp$start, sp$span_min)
  f      <- fits[fits$site == s_tree, ]
  b      <- background[background$site == s_tree, ]
  mu     <- approx(b$time_utc, b$mu, sp$start + sp$span_min * 30)$y
  cat(sprintf('Schematic: real calls at %s, %s + %g min (%d calls, %d links)\n', s_tree,
              format(sp$start, '%H:%M %Z', tz = tz), sp$span_min, nrow(tree),
              sum(!is.na(tree$parent))))
} else {
  f    <- data.frame(alpha = median(fits$alpha), eta = median(fits$eta), kernel = 'unnormalized')
  mu   <- 0.1                                     # ~3 contact calls in 30 min
  seed <- pick_tree_seed(mu = mu, alpha = jump_size(f), eta = f$eta, horizon = 30)
  tree <- simulate_family_tree(mu = mu, alpha = jump_size(f), eta = f$eta, horizon = 30,
                               seed = seed)
  cat(sprintf('Schematic: simulated tree (seed %d; best real span had < %d confident links)\n',
              seed, min_links))
}
draw_family_tree(tree, file.path(out_dir, 'hawkes_schematic'), mu = mu,
                 alpha = jump_size(f), eta = f$eta)
