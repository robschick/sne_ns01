# =============================================================================
# anim_render.R — Frames to PNG, then mux with the soundtrack
#
# The ffmpeg binary is `ffmpeg` on the PATH unless the FFMPEG env var names one.
# =============================================================================

ffmpeg_bin <- function() Sys.getenv('FFMPEG', 'ffmpeg')

# Renders secs * fps frames spanning the window, plus hold_secs * fps copies of
# the final frame carrying `caption`. Returns the frame directory. The default
# 12.8 x 7.2 in at 150 dpi gives 1920 x 1080 (16:9, full HD).
render_frames <- function(rate, calls, basemap, t0, win_min, ymax, secs = 22, fps = 30,
                          hold_secs = 0, caption = NULL, outdir = 'frames',
                          width = 12.8, height = 7.2, dpi = 150,
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

# H.264 at CRF 18 (visually lossless for flat graphics) with stereo AAC;
# faststart so PowerPoint/Keynote can begin playback before the whole file loads.
encode_video <- function(frames, audio, out, fps = 30, sr = 44100, crf = 18) {
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  status <- system(sprintf(paste(
    '%s -y -loglevel error -framerate %d -i %s/f%%05d.png',
    '-f s16le -ar %d -ac 2 -i %s -shortest',
    '-c:v libx264 -preset slow -tune animation -crf %d -pix_fmt yuv420p',
    '-vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -movflags +faststart',
    '-c:a aac -b:a 192k %s'), shQuote(ffmpeg_bin()), fps, frames, sr, audio, crf,
    shQuote(out)))
  if (status != 0) stop('ffmpeg failed')
  out
}
