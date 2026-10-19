# =============================================================================
# anim_audio.R — Soundtrack: one upcall at each call's video time
# =============================================================================

# Decode a recording to mono s16le at `sr`, pitch-shifted by `pitch` (this also
# shortens it by the same factor) so it carries on room speakers.
read_upcall_wav <- function(path, pitch, sr) {
  tmp <- tempfile(fileext = '.raw')
  status <- system2(ffmpeg_bin(), c('-y', '-loglevel', 'error', '-i', shQuote(path), '-ac', '1',
                                '-af', sprintf('aresample=%d,asetrate=%d,aresample=%d', sr, round(sr * pitch), sr),
                                '-f', 's16le', '-ar', sr, shQuote(tmp)))
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

# `calls$t_min` is minutes since t0. The track runs `total_secs` (>= secs, to
# cover any held final frame). Writes raw mono s16le and returns its path.
build_audio <- function(calls, win_min, secs, total_secs = secs, upcall_wav = NULL,
                        pitch = 3, sr = 44100, path = 'upcalls.raw') {
  upcall <- if (!is.null(upcall_wav)) read_upcall_wav(upcall_wav, pitch, sr)
            else synthetic_upcall(pitch, sr)
  tv <- calls$t_min[calls$t_min >= 0 & calls$t_min <= win_min] / win_min * secs
  audio <- numeric(round(sr * total_secs) + length(upcall))
  for (s in tv) {
    j <- round(s * sr) + seq_along(upcall)
    audio[j] <- audio[j] + upcall
  }
  audio <- audio[seq_len(round(sr * total_secs))]
  if (any(audio != 0)) audio <- audio / max(abs(audio)) * 0.9
  con <- file(path, 'wb'); writeBin(as.integer(audio * 32767), con, size = 2); close(con)
  path
}
