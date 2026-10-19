# Animated upcall arrivals + conditional calling rate (NHPP vs Hawkes), with sound.
# Uses CCB 2010 data and posterior means from bokgyeong/WhaleCallHawkes.
# Output: hawkes_<mode>.mp4 for mode in c("nhpp", "hawkes")

library(ggplot2)
library(patchwork)

repo   <- "WhaleCallHawkes"            # local clone of github.com/bokgyeong/WhaleCallHawkes
t0     <- 2650                         # window start (min since 2010-04-02 00:00 UTC)
win    <- 120                          # window length (min)
secs   <- 60                           # video length (s)
fps    <- 15
pitch  <- 3                            # audio pitch-shift factor for upcalls
outdir <- "frames"

# ---- data + parameters -------------------------------------------------------
load(file.path(repo, "real/data/ccb.RData"))            # data, distmat, noise
p <- new.env(); load(file.path(repo, "sim/data/ccbfitLGCPSE.RData"), p)

K  <- 10
v  <- 1.5 * 60                                          # sound speed, km/min
ts <- data$ts
mk <- data$marks + 1                                    # MARU 1..10
maru <- unique(data.frame(k = mk, lat = data$Latitude, lon = data$Longitude))
maru <- maru[order(maru$k), ]

# ---- background (contact-call) rate: NHPP part, GP omitted ------------------
tg <- seq(t0 - 30, t0 + win, by = 0.1)                  # fine time grid (min)
nz <- scale(as.matrix(noise[, paste0("maru_", 0:9)]))
kn <- noise$ts %% 20 == 0                               # model uses noise on a 20-min grid
nz <- apply(nz, 2, function(z) approx(noise$ts[kn], z[kn], tg, rule = 2)$y)
hm <- function(h) 2 * pi * h * (tg + 15 * 60 + 1) / (24 * 60)
X  <- cbind(sin(hm(3)), cos(hm(3)), sin(hm(2)), cos(hm(2)), sin(hm(1)), cos(hm(1)))
mu <- sapply(1:K, function(k) exp(p$beta0[k] + p$beta[1, k] * nz[, k] + X %*% p$beta[-1, k]))

# ---- excitement (countercall) rate ------------------------------------------
ex <- matrix(0, length(tg), K)
for (i in which(ts > t0 - 60 & ts < t0 + win)) {
  lag <- outer(tg - ts[i], distmat[mk[i], ] / v, "-")   # time since arrival at each MARU
  amp <- p$zeta[mk[i]] * exp(-p$phi * distmat[mk[i], ])
  ex  <- ex + (lag > 0) * sweep(exp(-p$eta * pmax(lag, 0)), 2, amp, "*")
}

calls <- data.frame(t = ts, k = mk)
calls <- calls[calls$t >= t0 & calls$t <= t0 + win, ]

# "Naive NHPP" for the first video: same diel/noise shape, rescaled per MARU so its
# expected count over the window equals that MARU's observed count (no history)
inw  <- tg >= t0
cfac <- tabulate(calls$k, K) / (colSums(mu[inw, ]) * 0.1)

rate <- data.frame(t = rep(tg, K), k = rep(1:K, each = length(tg)),
                   nhpp = 60 * as.vector(sweep(mu, 2, cfac, "*")),                # calls/h
                   bg = 60 * as.vector(mu), hawkes = 60 * as.vector(mu + ex))
ymax  <- max(rate$hawkes[rate$t >= t0])

# ---- one frame ---------------------------------------------------------------
draw <- function(now, mode) {
  r  <- rate[rate$t >= t0 & rate$t <= now, ]
  cs <- calls[calls$t <= now, ]
  cur <- rate[abs(rate$t - now) < 0.05, ]
  cur$val <- cur[[mode]]
  r$base <- if (mode == "nhpp") r$nhpp else r$bg
  m <- merge(maru, cur[, c("k", "val")])
  ring <- merge(maru, cs[now - cs$t < 1.5, ])           # expanding ring for ~1.5 min
  ring$r <- (now - ring$t) / 1.5

  map <- ggplot(m, aes(lon, lat)) +
    geom_point(data = ring, aes(size = 6 + 20 * r, alpha = 1 - r),
               shape = 1, colour = "#d95f02", stroke = 1.2) +
    geom_point(aes(size = 2 + 10 * val / ymax, fill = val), shape = 21) +
    geom_text(aes(label = k), nudge_y = 0.012, size = 3) +
    scale_fill_viridis_c(limits = c(0, ymax), name = "calls/h") +
    scale_size_identity() + scale_alpha_identity() +
    coord_quickmap() + theme_void() +
    theme(legend.position = "bottom", legend.key.width = unit(1.2, "cm")) +
    labs(title = format(as.POSIXct("2010-04-02", tz = "UTC") + now * 60 - 4 * 3600,
                        "%d %b %H:%M EDT"))

  ts_p <- ggplot(r, aes(t - t0)) +
    geom_line(aes(y = base), colour = "grey55") +
    { if (mode == "hawkes") geom_line(aes(y = hawkes), colour = "#1b7837") } +
    geom_segment(data = cs, aes(x = t - t0, xend = t - t0, y = 0, yend = ymax * 0.3),
                 colour = "#d95f02") +
    facet_grid(k ~ ., switch = "y") +
    scale_x_continuous(limits = c(0, win), expand = c(0, 0), name = "minutes") +
    scale_y_continuous(limits = c(0, ymax), breaks = NULL, name = NULL) +
    theme_minimal(base_size = 11) +
    theme(strip.text.y.left = element_text(angle = 0), panel.grid.minor = element_blank()) +
    labs(subtitle = if (mode == "nhpp") "Calling rate: depends on time of day and noise only"
                    else "Each call raises the rate nearby, then it decays (grey = contact-call background)")

  map + ts_p + plot_layout(widths = c(1, 1.6))
}

# ---- audio: synthetic upcall at each arrival --------------------------------
sr  <- 44100
dur <- 0.6                                               # s per call in the audio
f0  <- 80 * pitch; f1 <- 180 * pitch
tt  <- seq(0, dur, length.out = round(sr * dur))
ph  <- 2 * pi * (f0 * tt + (f1 - f0) * tt^2 / (2 * dur))
upcall <- sin(ph) * sin(pi * tt / dur)^2
audio <- numeric(sr * secs + length(upcall))
for (s in (calls$t - t0) / win * secs) {
  j <- round(s * sr) + seq_along(upcall)
  audio[j] <- audio[j] + upcall
}
audio <- audio / max(abs(audio)) * 0.9
con <- file("upcalls.raw", "wb"); writeBin(as.integer(audio * 32767), con, size = 2); close(con)

# ---- render ------------------------------------------------------------------
for (mode in c("nhpp", "hawkes")) {
  unlink(outdir, recursive = TRUE); dir.create(outdir)
  nows <- t0 + seq(0, win, length.out = secs * fps)
  parallel::mclapply(seq_along(nows), function(i)
    ggsave(sprintf("%s/f%05d.png", outdir, i), draw(nows[i], mode),
           width = 10, height = 5.6, dpi = 100, bg = "white"),
    mc.cores = parallel::detectCores())
  system(sprintf(paste("ffmpeg -y -loglevel error -framerate %d -i %s/f%%05d.png",
                       "-f s16le -ar %d -ac 1 -i upcalls.raw -shortest",
                       "-c:v libx264 -pix_fmt yuv420p -c:a aac hawkes_%s.mp4"),
                 fps, outdir, sr, mode))
}
