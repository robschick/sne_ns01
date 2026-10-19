# =============================================================================
# anim_render.R — Frames to PNG, then mux with the soundtrack
#
# The ffmpeg binary is `ffmpeg` on the PATH unless the FFMPEG env var names one.
# =============================================================================

ffmpeg_bin <- function() Sys.getenv('FFMPEG', 'ffmpeg')

# Renders secs * fps frames spanning the window, plus hold_secs * fps copies of
# the final frame carrying `caption`. Returns the frame directory.
render_frames <- function(rate, calls, basemap, t0, win_min, ymax, secs = 22, fps = 15,
                          hold_secs = 0, caption = NULL, outdir = 'frames',
                          width = 12, height = 6.2, dpi = 100,
                          cores = parallel::detectCores(), ...) {
  unlink(outdir, recursive = TRUE); dir.create(outdir, recursive = TRUE)
  nows <- seq(0, win_min, length.out = secs * fps)
  nows <- c(nows, rep(win_min, round(hold_secs * fps)))
  last <- length(nows) - round(hold_secs * fps)
  res <- parallel::mclapply(seq_along(nows), function(i) {
    cap <- if (i > last) caption
    ggsave(sprintf('%s/f%05d.png', outdir, i),
           draw_frame(nows[i], rate, calls, basemap, t0, win_min, ymax, caption = cap, ...),
           width = width, height = height, dpi = dpi, bg = 'white')
  }, mc.cores = cores)
  errs <- vapply(res, inherits, logical(1), 'try-error')
  if (any(errs)) stop('Frame rendering failed: ', res[[which(errs)[1]]])
  outdir
}

encode_video <- function(frames, audio, out, fps = 15, sr = 44100) {
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  status <- system(sprintf(paste(
    '%s -y -loglevel error -framerate %d -i %s/f%%05d.png',
    '-f s16le -ar %d -ac 1 -i %s -shortest',
    '-c:v libx264 -pix_fmt yuv420p -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2"',
    '-c:a aac %s'), shQuote(ffmpeg_bin()), fps, frames, sr, audio, shQuote(out)))
  if (status != 0) stop('ffmpeg failed')
  out
}
