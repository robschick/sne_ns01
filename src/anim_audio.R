# =============================================================================
# anim_audio.R — Soundtrack: one upcall at each call's video time
#
# Output is always stereo s16le. Calls are summed at a fixed per-call gain and
# soft-limited (tanh), so an isolated call stays audible next to a dense burst
# instead of being scaled down by the burst's peak.
# =============================================================================

# Decode a recording to mono at `sr`, pitch-shifted by `pitch` (this also
# shortens it by the same factor). pitch = 1 uses the clip as is.
read_upcall_wav <- function(path, pitch, sr) {
  tmp <- tempfile(fileext = '.raw')
  af  <- if (pitch == 1) sprintf('aresample=%d', sr)
         else sprintf('aresample=%d,asetrate=%d,aresample=%d', sr, round(sr * pitch), sr)
  status <- system2(ffmpeg_bin(), c('-y', '-loglevel', 'error', '-i', shQuote(path), '-ac', '1',
                                    '-af', af, '-f', 's16le', '-ar', sr, shQuote(tmp)))
  if (status != 0) stop('ffmpeg could not decode ', path)
  x <- readBin(tmp, 'integer', n = file.size(tmp) / 2, size = 2, endian = 'little')
  unlink(tmp)
  x / max(abs(x))
}

# Synthetic upcall: an 80 -> 180 Hz sweep (x pitch) with a sin^2 envelope
synthetic_upcall <- function(pitch, sr, dur = 0.6) {
  f0 <- 80 * pitch; f1 <- 180 * pitch
  tt <- seq(0, dur, length.out = round(sr * dur))
  sin(2 * pi * (f0 * tt + (f1 - f0) * tt^2 / (2 * dur))) * sin(pi * tt / dur)^2
}

# Resample a clip by factor r (> 1 = higher and shorter)
shift_clip <- function(x, r) {
  approx(seq_along(x), x, seq(1, length(x), by = r))$y
}

# `calls$t_min` is minutes since t0; `calls$site` is used for panning.
#   pan     named vector site -> position in [-1 (left), 1 (right)]; NULL = centre
#   vary    per-call random pitch spread (0.05 = +/-5%); 0 = identical copies
#   gain    per-call amplitude before the tanh limiter (~0.5 keeps singles linear)
# The track runs `total_secs` (>= secs, to cover a held final frame). Writes raw
# stereo s16le and returns its path.
build_audio <- function(calls, win_min, secs, total_secs = secs, upcall_wav = NULL,
                        pitch = if (is.null(upcall_wav)) 3 else 1, sr = 44100,
                        pan = NULL, vary = 0.05, gain = 0.5, seed = 1,
                        path = 'upcalls.raw') {
  upcall <- if (!is.null(upcall_wav)) read_upcall_wav(upcall_wav, pitch, sr)
            else synthetic_upcall(pitch, sr)
  keep <- calls$t_min >= 0 & calls$t_min <= win_min
  tv   <- calls$t_min[keep] / win_min * secs
  site <- calls$site[keep]
  set.seed(seed)
  r <- if (vary > 0) runif(length(tv), 1 - vary, 1 + vary) else rep(1, length(tv))

  n <- round(sr * total_secs)
  lr <- matrix(0, n + ceiling(length(upcall) / (1 - vary)) + 1, 2)
  for (k in seq_along(tv)) {
    clip <- if (r[k] == 1) upcall else shift_clip(upcall, r[k])
    p <- if (is.null(pan) || is.na(pan[site[k]])) 0 else pan[[site[k]]]
    w <- c(cos((p + 1) * pi / 4), sin((p + 1) * pi / 4)) * sqrt(2)   # equal-power pan
    j <- round(tv[k] * sr) + seq_along(clip)
    lr[j, ] <- lr[j, ] + outer(clip, w)
  }
  lr <- tanh(gain * lr[seq_len(n), , drop = FALSE]) * 0.95
  con <- file(path, 'wb'); writeBin(as.integer(t(lr) * 32767), con, size = 2); close(con)
  path
}

# Listenable copy of a raw track (for auditioning audio settings)
raw_to_wav <- function(raw, out, sr = 44100) {
  status <- system2(ffmpeg_bin(), c('-y', '-loglevel', 'error', '-f', 's16le', '-ar', sr,
                                    '-ac', 2, '-i', shQuote(raw), shQuote(out)))
  if (status != 0) stop('ffmpeg failed')
  out
}
