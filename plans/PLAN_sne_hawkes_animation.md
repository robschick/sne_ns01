# Plan: SNE upcall animation + Hawkes schematic for NARWC 2026 talk

Goal: two slide assets for the talk intro (~30 s total on screen).

1. **`sne_hawkes.mp4`**: a ~20–25 s clip of real Southern New England upcall arrivals, with sound. Each site's calling rate jumps after every call and then decays, drawn over a grey contact-call background.
2. **`hawkes_schematic.png/.pdf`**: a formula-free "family tree" showing contact calls (start a sequence) vs countercalls (respond to a call just heard).

The template is `hawkes_intro_anim.R`, built for Cape Cod Bay 2010 from bokgyeong/WhaleCallHawkes. This plan adapts it to SNE and splits it into pipeline functions.

---

## 1. What changes from the CCB template

| CCB template | SNE version | Why |
|---|---|---|
| 10 MARUs, ~5–20 km apart; one joint spatial model | Sites ~40 km apart; **one temporal Hawkes model per site** | At ~40 km spacing there's no cross-site excitation, so the fits are separate |
| Excitation spreads to neighbors with a sound-travel delay (`phi`, `distmat`, `v`) | **Removed.** Each call excites only its own site | Simpler code; no distance matrix needed |
| One `eta` and per-MARU `zeta` | **Per-site `alpha_k` (jump size) and `eta_k` (decay)** | Separate fits give separate parameters |
| Background rebuilt from `beta0`, `beta`, harmonics, noise; GP omitted | **Background exported directly from each fit** as a rate on a time grid (GP included if the model has one) | Avoids re-coding the design matrix and fixes the grey line sitting too low when the GP is left out |
| Hard-coded time origin (`2010-04-02`, EDT = UTC−4) | All times stored as POSIXct UTC; converted to local time only for labels | No hand-coded offsets, no DST mistakes |
| Grey NHPP clip + Hawkes clip | **Hawkes clip only**; the grey background *is* the "independent calls" comparison | Time budget |
| Synthetic sweep audio | Real SNE upcall clip if available, synthetic sweep otherwise | Authenticity |

Per-site rate (calls/min) used for drawing:

```
lambda_k(t) = mu_k(t) + sum over earlier calls i at site k of  alpha_k * exp(-eta_k * (t - t_i))
```

Talk-friendly numbers to compute per site:
- Response half-life = `log(2) / eta_k` (minutes)
- Expected responses per call (branching ratio) = `alpha_k / eta_k`
- Expected fraction of calls that are countercalls ≈ `alpha_k / eta_k`, if the process is stationary and the ratio is below 1. Prefer the model-based split from the fit (step 4f) when you have it.

Check the parameterization of your fits before using these. In the WhaleCallHawkes code the kernel is `zeta * exp(-eta * lag)` with no normalization, so the branching ratio is `zeta / eta`. If your SNE fits use a normalized kernel (`alpha * eta * exp(-eta * lag)`), the branching ratio is `alpha` itself.

---

## 2. Input contract

Put raw/derived inputs wherever the repo keeps them. The functions below only assume these shapes.

**`sites`**: one row per recorder
| col | type | notes |
|---|---|---|
| `site` | chr | stable ID used everywhere |
| `lat`, `lon` | dbl | WGS84 |
| `label` | chr | short on-slide label (optional) |

**`calls`**: one row per detected upcall
| col | type | notes |
|---|---|---|
| `site` | chr | |
| `time_utc` | POSIXct (UTC) | detection time |
| `validated` | lgl | keep `TRUE` only, if available |

**`effort`**: recording coverage, one row per continuous recording block
| col | type | notes |
|---|---|---|
| `site` | chr | |
| `start_utc`, `end_utc` | POSIXct | handles duty cycling and deployment gaps |

**`fits`**: one row per site (posterior means or medians are enough for the animation)
| col | type | notes |
|---|---|---|
| `site` | chr | |
| `alpha` | dbl | jump size, per min |
| `eta` | dbl | decay rate, per min |
| `kernel` | chr | `"unnormalized"` (`alpha*exp(-eta*lag)`) or `"normalized"` (`alpha*eta*exp(-eta*lag)`) |

**`background`**: fitted contact-call rate, exported from each site's fit
| col | type | notes |
|---|---|---|
| `site` | chr | |
| `time_utc` | POSIXct | regular grid; 1–5 min is fine |
| `mu` | dbl | calls/min; posterior mean of the baseline incl. covariates and GP |

### Mapping from the per-site `fitLGCPSE()` output (confirmed against `RcppFtns.cpp`)

- **Kernel:** `comph()` = `exp(-eta * lag)`, and the rate is `mu + alpha * sum(...)`. So it's **unnormalized**: jump = `alpha` (per min), responses per call = `alpha / eta`, half-life = `log(2) / eta`.
- **`postSamples` columns:** `1:p` = beta, `p+1` = **log** delta, `p+2` = alpha, `p+3` = eta (R indexing). Drop burn-in rows.
- **`background`:** build it with `compLamt(t, ts, knts, maxT, indlam0t, Xm, beta, delta, Wm, alpha, eta)` on a 1-min grid over the chosen window. `resBack` is the background with the GP included. It returns quantiles at P = (0.025, 0.5, 0.975); use the median for `mu`.
  - **Pass `exp(postSamples[, p+1])` as `delta`**: `compLamt` multiplies `Wm` by `delta` directly, but the sampler stores log delta.
  - `indlam0t = which(knts >= t)[1] - 2` (0-based knot index, as in `fitLGCPSE.R`).
  - `ts` must be sorted, because the excitation loop assumes `find(ts < t)` is a prefix.
- **`postBranching`** (niter × n): `0` = contact (background) call; `j > 0` = countercall whose parent is call `j` (1-based). From it:
  - `p_counter_i = mean(postBranching[, i] > 0)`: per-call probability that call *i* is a countercall. Use it in `site_summary()`, and optionally to shade call ticks in the animation.
  - Modal parent per call: draw the schematic family tree from **real SNE calls** instead of a simulation (see 4g).

```r
export_background <- function(fit, ts, Xm, knts, maxT, grid, burn) {
  keep  <- -(1:burn); p <- ncol(Xm)
  S     <- fit$postSamples[keep, ]
  beta  <- S[, 1:p]; delta <- exp(S[, p + 1]); alpha <- S[, p + 2]; eta <- S[, p + 3]
  Wm    <- fit$postWm[keep, ]
  mu <- vapply(grid, function(t) {
    i0 <- which(knts >= t)[1] - 2
    as.vector(compLamt(t, ts, knts, maxT, i0, Xm, beta, delta, Wm, alpha, eta)$resBack)[2]
  }, numeric(1))
  data.frame(t_min = grid, mu = mu)
}
```
(`compLamt` prints three lines per call; comment out its `Rprintf`s before running it on a grid.)

Optional:
- `noise` (site, time_utc, level_db): only if you want a noise strip on the slide
- `upcall_wav`: path to a clean upcall recording for the audio
- `coast`, `lease_areas`: `sf` objects for the map

---

## 3. File layout (slots into an existing `targets` repo)

```
R/
  anim_inputs.R      # read_sne_sites(), read_sne_calls(), read_sne_effort(),
                     # read_sne_fits(), read_sne_background()
  anim_window.R      # pick_window()
  anim_rate.R        # rate_grid()
  anim_draw.R        # draw_frame(), make_basemap()
  anim_audio.R       # build_audio()
  anim_render.R      # render_frames(), encode_video()
  anim_schematic.R   # simulate_family_tree(), draw_family_tree()
  anim_checks.R      # check_inputs(), check_rate()
_targets_anim.R      # or append the targets below to _targets.R
output/talk/         # sne_hawkes.mp4, hawkes_schematic.pdf/png, site_summary.csv
```

---

## 4. Functions (spec)

### a. `pick_window(calls, effort, win_min = 120, step_min = 10, sites = NULL)`
- Slide a `win_min` window across the deployment and count calls per site.
- Keep only windows fully inside `effort` for **every** site shown, so there are no recording gaps on screen.
- Score windows by total calls, with a bonus for the number of sites with at least 3 calls. You want bursts at more than one site.
- Return the top 5 windows (`start_utc`, `n_calls`, `n_sites_active`) so you can listen or look and choose.

### b. `rate_grid(calls, background, fits, t0, win_min, burn_min = 60, dt = 0.1)`
- Fine grid: `seq(t0 - burn_min, t0 + win_min, by = dt)` minutes. The burn-in lets calls before `t0` contribute excitation at the start.
- Interpolate `mu` from `background` onto the grid for each site.
- Excitation: for each call at site k, add `a_k * exp(-eta_k * lag) * (lag > 0)`, with `a_k = alpha` or `alpha*eta` depending on `kernel`.
- Return a long data frame: `site, t_min, time_utc, mu, excite, lambda`, with rates in **calls/h** for display.

### c. `make_basemap(sites, coast = NULL, lease_areas = NULL)`
- A static ggplot layer list: coastline, lease outlines (thin, light), site points and labels.
- Bounding box = site extent plus ~15 km buffer.
- At ~40 km spacing, `coord_sf` with a projected CRS reads better than `coord_quickmap`.

### d. `draw_frame(now, rate, calls, sites, basemap, t0, win_min, ymax, tz = "America/New_York")`
Adapted from the template's `draw()`, with these changes:
- **Map:** site node size and fill = current `lambda`. Orange expanding ring for ~1.5 min after each call at that site. No spread to neighbors.
- **Right panel:** one facet per site (ordered west→east or by activity). Grey `mu` line, green `lambda` line, orange ticks for calls.
- Only one mode (`"hawkes"`); drop the `nhpp` branch.
- Title: local time from `time_utc` via `format(..., tz = tz)`.
- Subtitle: *"Grey: expected calling if calls were independent. Green: each call raises the chance of another, then it fades."*
- Shared `ymax` across frames; consider `pmin(lambda, cap)` so one huge burst doesn't flatten the other sites.

### e. `build_audio(calls_in_window, t0, win_min, secs, upcall_wav = NULL, pitch = 3, sr = 44100)`
- Map each call to video time `(t - t0) / win_min * secs`.
- If `upcall_wav` is given: decode it with ffmpeg to mono s16le at `sr` (`ffmpeg -i in.wav -ac 1 -ar sr -f s16le -`), read with `readBin`, and pitch-shift with ffmpeg `asetrate=sr*pitch,aresample=sr` so it's audible on room speakers.
- Otherwise use the synthetic sweep from the template (template lines 96–109).
- Normalize and write `upcalls.raw`. Return the path.

### f. Optional `site_summary(fits, calls, window)`: one table for a backup slide
- Per site: half-life, responses per call, number of calls in the window. If available from the fit, include the share of calls that are contact vs countercalls (posterior branching probabilities).

### g. `simulate_family_tree(mu = 0.05, alpha = 0.15, eta = 0.25, horizon = 90, seed)` and `draw_family_tree(tree)`
- Simulate one site's Hawkes process with a cluster/branching algorithm so each event has a known `parent`: immigrants come from a Poisson(`mu`) process, and each event spawns Poisson(`alpha/eta`) children at Exp(`eta`) delays.
- Pick a seed giving ~3 immigrants and ~8–12 total calls.
- Draw:
  - Timeline at the bottom; calls as ticks.
  - **Contact calls:** filled circles in one color.
  - **Countercalls:** open circles in a second color, with curved arrows from their parent.
  - Bottom row (optional): the same calls with the rate curve underneath, so the audience sees the bumps line up with the arrows.
  - No equations. Two text labels: "starts a conversation", "answers a call heard minutes earlier".
- Use the SNE parameters when available, so the cartoon's time scale matches the real data.
- **Preferred alternative:** build the tree from real calls in the chosen window. Take each call's modal parent from `postBranching` (keeping only links with posterior probability > 0.5), and draw contact vs countercall from `p_counter_i`. Same picture, but it's the data, not a cartoon.

### h. `render_frames()` / `encode_video()`
- As in the template: `parallel::mclapply` over frames, `ggsave(..., dpi = 100)`, then ffmpeg mux with `-shortest`. Return file paths so `targets` can track them (`format = "file"`).
- Defaults: `secs = 22`, `fps = 15` (~330 frames). Increase fps only for the final render.

---

## 5. targets

```r
list(
  tar_target(sites_file, "data/sne/sites.csv", format = "file"),
  # ... same for calls_file, effort_file, fits_file, background_file
  tar_target(sites,      read_sne_sites(sites_file)),
  tar_target(calls,      read_sne_calls(calls_file)),
  tar_target(effort,     read_sne_effort(effort_file)),
  tar_target(fits,       read_sne_fits(fits_file)),
  tar_target(background, read_sne_background(background_file)),
  tar_target(input_ok,   check_inputs(sites, calls, effort, fits, background)),

  tar_target(windows, pick_window(calls, effort)),
  tar_target(t0, windows$start_utc[1]),          # override after review
  tar_target(rate, rate_grid(calls, background, fits, t0, win_min = 120)),
  tar_target(rate_ok, check_rate(rate, calls, t0, win_min = 120)),

  tar_target(basemap, make_basemap(sites)),
  tar_target(audio,   build_audio(calls, t0, 120, secs = 22), format = "file"),
  tar_target(video,   encode_video(render_frames(rate, calls, sites, basemap, t0),
                                   audio, "output/talk/sne_hawkes.mp4"),
             format = "file"),

  tar_target(tree,      simulate_family_tree(seed = 7)),
  tar_target(schematic, draw_family_tree(tree, "output/talk/hawkes_schematic"),
             format = "file"),
  tar_target(summary_tbl, site_summary(fits, calls, t0))
)
```

---

## 6. Checks (`anim_checks.R`)

- `check_inputs`:
  - Every `calls$site` is in `sites` and `fits`.
  - All times are UTC POSIXct.
  - No calls fall outside `effort`.
  - `background` covers the deployment, and `mu > 0`.
  - `eta > 0`; flag any site with branching ratio ≥ 1 (non-stationary).
- `check_rate`:
  - Per site, `sum(lambda) * dt` over the window should be in the same range as the observed call count. A large mismatch usually means a units error (per min vs per h) or the wrong kernel type.
  - Spot-check that `lambda` jumps by `a_k` exactly at each call time.
- Visual: render 3 still frames (start, busiest moment, end) before the full render.

---

## 7. On-slide script (~30 s)

1. *(Schematic, ~10 s)* "Some calls start a conversation; others answer a call heard minutes earlier."
2. *(Clip, ~20 s)* "This is two hours at [N] sites in Southern New England, sped up. The grey line is what we'd expect if calls were independent. Every call raises the chance of another at that site, and that boost fades over a few minutes."
3. *Takeaway line on the last frame:* "Calls aren't independent, so counting them as if they were mixes up how many whales are calling with how much they're answering each other."

---

## 8. Open items

- [x] Where the SNE fits and data live: calls/sites/effort from `data/release/*.parquet`; fits on the cluster (NS01 also local). `10a_animExport.R` pulls a ~1.5 MB `out/anim/<buoy>_anim.rds` per buoy (`aci_anim_export.sh` on the cluster)
- [x] Background export: `compLamt()`, see section 2. Arma `quantile()` = R type 5; the export matches `compLamt()` to 1e-4
- [x] Kernel: unnormalized (`alpha * exp(-eta * lag)`)
- [x] Callers of `compLogLik()`, `compLam0i()` and `rtctIntLam0i()`: delta is applied correctly. `03_loglikLGCPSE.R` and `05_sumDIC.R` build `lam0m` with `exp(logdelta) * Wm` before `compLogLiki()`; `04_rtctLGCPSE.R` passes `deltaWm = exp(logdelta) * postWm`. `compLogLik()` and `compLam0i()` have no R callers
- [x] Effort: `deployments.parquet` (continuous recording), with each block trimmed 6 h at both ends for clock slack
- [ ] Clean SNE upcall `.wav` for the audio (`--wav=`; synthetic sweep until then)
- [x] Coastline (`rnaturalearth` states) and lease outline (`data/ne_wea.shp`, dissolved as in `09b_caseStudyMap.R`)
- [x] Sites: all three (COX01, NS01, NS02, ordered west to east)
- [ ] NS02 and COX01 exports (cluster). Until they exist the driver shows NS01 only
- [x] Clock: stamps are true UTC (confirmed 2026-10-19); `clock_offset_h = 0` in `10_hawkesAnim.R`

### Implementation notes (2026-10-19)

- No `targets` here: the functions live in `src/anim_*.R` and `10_hawkesAnim.R` runs the steps in order. Outputs go to `fig/talk/`.
- Real-call family tree: only ~6% of NS01 calls have a modal parent with posterior probability > 0.5 (median 0.19 among likely countercalls). The fit is confident that a call *is* a countercall but rarely confident *which* call it answers. So the driver uses the real tree only if some 5–30-min span has ≥ 4 confident links. Otherwise it draws the simulated tree with the median SNE `alpha`/`eta` (real time scale).
