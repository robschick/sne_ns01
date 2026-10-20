# Plan: Poisson-vs-Hawkes comparison for the NARWC 2026 talk

Goal: justify the Hawkes model to a non-statistical audience by showing what a
Poisson (no-answering) model would look like on the same calls. This builds on
the talk animation in `plans/PLAN_sne_hawkes_animation.md` (PR #12).

Build three things:

1. **Poisson line in the animation:** a dashed third line in each site's panel.
2. **Real vs Poisson calls, seen and heard:** a short companion clip.
3. **Gap-distribution backup slide:** real vs Poisson time between calls.

A formal fitted comparison (option 4: an LGCP fit with no self-excitation,
then DIC and time-rescaling Q-Q plots) is deferred to the paper. It is a full
cluster run.

---

## Current state (2026-10-20)

- The pipeline works for all three sites. `out/anim/{cox01,ns01,ns02}_anim.rds`
  are on the laptop, exported on the cluster and rsynced back.
- Run with:
  `FFMPEG=~/opt/miniconda3/bin/ffmpeg Rscript 10_hawkesAnim.R --window=2 --video`.
  Homebrew ffmpeg is broken (dylib mismatch after `brew upgrade` of its deps),
  so use the miniconda binary until it's fixed.
- Chosen window: `--window=2`, which is 2022-01-10 19:11 UTC (14:11 EST). All
  three sites are active: COX01 56, NS01 66, NS02 215 calls. Rank 1 has COX01
  silent.
- Timestamps are true UTC (`clock_offset_h = 0`).
- PR #12 (pipeline) is merged. PR #13 (branch `feat/talk-animation-av`) adds
  the real-clip stereo audio, 1080p/30 fps render, projector-sized text, the
  `--wav/--pitch/--mono/--audio-preview` flags and this plan. Before pushing
  more work, check whether #13 is still open (`gh pr view 13 --json state`);
  if it has merged, branch fresh off master.

## Implemented (2026-10-20, branch `feat/poisson-comparison`)

All three items are built. The subtitle change is done too.

- `src/anim_rate.R`: `smooth_rate()`, `poisson_rate()`, `sim_poisson()`,
  `pick_poisson_seed()`. `rate$poisson` is always computed, so the dashed line
  is in every still and in `sne_hawkes.mp4`.
- `src/anim_render.R`: `render_frames(draw, n, ...)` now takes a frame
  function; `sweep_times()` gives the frame times.
- `src/anim_draw.R`: dashed blue Poisson line and three-line subtitle in
  `draw_frame()`; new `draw_compare_frame()` for the clip.
- `src/anim_gaps.R`: `gap_stats()`, `compare_gaps()` (20 replicates),
  `plot_gap_distribution()`. Runs on every invocation (~1 s).
- `--poisson-clip`: `sne_poisson_vs_real.mp4` (28 s: 12 s real with sound,
  1 s pause, 12 s Poisson with sound, 3 s hold with caption),
  `still_poisson_vs_real.png`, `audio/real.wav`, `audio/poisson.wav`. Seeds
  7 / 6 / 72 give exactly 56 / 66 / 215 calls. NS02 minutes 50–100 are shaded.

Notes:

- In window 2 the dashed line integrates to 0.98 / 0.84 / 0.87 of the
  observed count (COX01 / NS01 / NS02), not ~1. The window was picked for
  being busy, and the 60-min kernel spreads its calls into quieter time
  outside it. Over the whole fit window, the integral matches by construction.
- `gap_summary.csv` reproduces the evidence table. The real values match
  exactly. The Poisson values are the mean of 20 replicates, so they differ
  from the seed-1 numbers by about 0.01.
- The clip runs 28 s, not 10–15 s, because it plays the two tracks one after
  the other. For a shorter clip, lower `clip_secs` in `10_hawkesAnim.R`.

## Why the grey line is not the Poisson line

Grey is the Hawkes background `mu(t)`, which accounts for only ~40% of calls
(the excitation is 59–64% of lambda in window 2). A Poisson model must put
all calls into a smooth rate. So its line runs higher than grey overall: too
high in quiet gaps and far too low inside bursts. That mismatch is the visual.

## Evidence already computed

Whole 5-month fit window. The Poisson comparison simulates calls from the
observed per-minute counts smoothed with a Gaussian kernel, sd = 60 min (about
the GP scale; rho = 60 min, effective range 180 min). Seed 1.

| site | calls | gaps < 1 min real / Poisson | gaps < 2 min real / Poisson | var/mean 5-min counts real / Poisson |
|---|---|---|---|---|
| COX01 | 6098 | 0.55 / 0.37 | 0.73 / 0.53 | 5.7 / 3.7 |
| NS01 | 13017 | 0.58 / 0.41 | 0.76 / 0.61 | 6.1 / 3.9 |
| NS02 | 33611 | 0.61 / 0.41 | 0.77 / 0.61 | 5.6 / 3.1 |

The Poisson var/mean is above 1 only because the smoothed rate varies.

## Specs

### 1. `poisson_rate()` and the dashed line

- New function in `src/anim_rate.R`:
  `poisson_rate(calls, t0, win_min, burn_min, dt, sd_min = 60)`. It gives the
  per-site smooth rate (calls/h) on the same grid as `rate_grid()`: per-minute
  counts convolved with a Gaussian kernel (sd 60 min, ±4 sd), evaluated
  outside the displayed window too, so the edges aren't biased low. Add it to
  `rate` as a `poisson` column.
- This is a **stand-in, not a fitted model**. Say so in a code comment and in
  the speaker notes. Option 4 would replace it with a fitted LGCP background.
- `draw_frame()`: add a dashed line (colour suggestion `#2166ac` blue, matching
  the schematic's contact colour, or a neutral dark grey), linewidth ~1.
- Update the subtitle to three lines: grey = start a conversation, green =
  plus answering, dashed = "a Poisson model: one smooth rate, no answering".
  Keep it legible at 1080p (base_size 17).
- `check_rate()`: also report the Poisson line's integral vs the observed
  count. It should be near 1 by construction; that's a useful sanity check.

### 2. Real vs Poisson companion clip (`sne_poisson_vs_real.mp4`)

- Simulate one Poisson call set for window 2 from the `poisson` rate (thinning
  or per-bin Poisson with uniform times; fixed seed; pick a seed whose total
  count is close to the observed count, so only the *arrangement* differs).
- Layout: per site, two tick rows ("Real calls" / "Poisson calls"), plus
  optional running cumulative counts. Show the NS02 burst minutes 50–100
  prominently. Keep it ~10–15 s.
- Audio: the same `build_audio()` settings. Either play the real track then
  the Poisson track, or two separate clips. Write both as `.wav` too
  (`fig/talk/audio/real.wav`, `poisson.wav`) for auditioning.
- Wire it in through a driver flag (`--poisson-clip`) and reuse
  `render_frames()`/`encode_video()` (they may need a `draw` function
  argument).

### 3. Gap-distribution backup slide (`gap_distribution.pdf/.png`)

- New function in a new `src/anim_gaps.R` (or the schematic file). For each
  site, over the whole fit window: the distribution of time between
  consecutive calls, real vs Poisson (simulated as above; several
  replicates, with the Poisson shown as a band).
- Suggested form: a histogram or density of gaps on 0–10 min with the
  Poisson overlay, facets by site, annotated with the "% of gaps < 1 min"
  numbers from the table. Keep it to one slide at 16:9 and readable at
  projector size.
- Write the numbers table to `fig/talk/gap_summary.csv`.

## Speaker-note points (agreed)

- Ticks are calls; grey changes slowly (time of day, season, conditions);
  green jumps at every call and fades within ~2 min.
- Half-life 1.4–2.0 min; ~0.6 responses per call at all three sites.
- NS02 burst: green peaks ~310/h vs grey ~95/h. Most of the burst is
  answering, but grey also rises (17→95/h), so don't claim "only a few whales".
- Neither line counts whales; green is a rate given past calls, not a
  forecast.
- The dashed line is a stand-in, not a fitted model: the observed counts
  smoothed over about an hour. A fitted version is in the paper.
- The Poisson line can't follow minute-scale clustering. Real data have ~1.5×
  more short gaps than Poisson allows, at every site.

## Intro blurbs for `sne_hawkes.mp4` (pick one per audience)

The main talk uses `sne_hawkes.mp4`. The companion clip and the gap slide are
held in reserve: the gap slide answers quantitative questions, and the clip
answers "why not just use a Poisson model?". Each blurb is said aloud while the
clip plays (about 25 s plus the lead-in).

### Quantitative ecologist

"These are two hours of verified right whale upcalls from three recorders
south of Martha's Vineyard and Nantucket, on 10 January 2022. Each orange tick
is one call, and you'll hear each one as it lands.

We model each site as a self-exciting point process, a Hawkes process. The
grey line is the background rate: a smooth log-Gaussian Cox process that tracks
time of day, season and conditions. The green line adds the excitation term.
Every call bumps the rate up, and the bump decays with a half-life of 1.4 to 2
minutes. On average each call triggers about 0.6 responses, at all three
sites.

The dashed line is what a Poisson model has to do: put every call into one
smooth rate. It's too high in the quiet stretches and far too low inside the
NS02 burst. Across the whole season, real gaps under a minute are about 1.5
times as common as a Poisson model allows. That clustering isn't noise to
average away. It's structure, and if you leave it out, your estimates of the
rate and its uncertainty are wrong."

### Field biologist

"This is two hours of right whale upcalls on a January afternoon, recorded at
three sites south of the islands. Each orange tick is one call, and you'll hear
them as they happen.

Listen to how they arrive. They aren't spread evenly. They come in runs: one
call, then another within a minute or two, then another. That's what
countercalling looks like in the acoustic record, with whales answering a call
they've just heard.

The grey line is the rate of calls that start an exchange. The green line adds
the answers. Each call raises the chance of another, and that effect fades
within a couple of minutes. Watch NS02 near the end. The green line climbs to
about 300 calls an hour while grey sits near 95. Most of that burst is
answering. But grey rises too, so it isn't just a few animals talking.

What the model gives us is a way to separate two things the raw counts blur
together: how often whales start calling, and how much they respond to each
other."

### Resource manager

"Passive acoustic monitoring is one of our main tools for tracking right
whales in and around the wind lease areas, outlined here. Detections often
feed into decisions like vessel slowdowns or construction mitigation. This
clip shows why a raw count of calls can mislead.

Each orange tick is a detected upcall, and you'll hear them. They come in
bursts, because whales answer each other. At NS02 near the end, the call rate
jumps to about 300 an hour. But most of those calls are responses to calls made
a minute or two earlier, not new animals arriving.

The grey line is the rate of calls that start an exchange. The green line adds
the answers. The dashed line is what you'd assume if every call were
independent, and it misses the bursts entirely.

Neither line is a whale count. The point is that treating calls as independent
mixes up how many whales are calling with how much they're talking to each
other. A spike in detections isn't automatically a spike in animals, and a
model that separates the two gives a steadier, more defensible signal to
manage against."

Follow-up to expect after the manager version: "Then how many whales were
there?" Answer with NS02: the background rose too (~17 to 95/h), so more
calling did start. The model just stops you reading the whole burst as new
animals.

## Q&A: "You can't see whales. How do you know it's countercalling?"

**Short answer.** "You're right, and it's a fair challenge. The hydrophone
gives us call times, nothing more. We don't know who called or who answered.
What the model finds is a statistical fact: a call makes another call more
likely within about two minutes, more than any slowly changing rate can
explain. 'Contact call' and 'countercall' are our biological reading of that
pattern. They aren't something we observed directly. The main message, that
calls aren't independent and counts overstate independent calling, holds
whatever the mechanism."

**What the model actually separates.** Two time scales, not two behaviours:

- background: variation slower than the GP scale (rho 60 min, effective range
  ~180 min);
- excitation: extra calling in the minutes after each call (half-life 1.4–2.0
  min).

"Countercall" means "a call the model attributes to the short-lag, triggered
component." It does not mean a confirmed exchange between two animals.

**Other mechanisms that leave the same signature.** Name them before the
questioner does:

1. **One whale calling in bouts.** A single animal repeating itself also
   produces self-excitation. A single hydrophone can't tell repetition from
   reply. For the counting message this makes no difference: either way, a
   burst isn't many animals.
2. **Fast changes the background can't follow.** A whale or group passing
   close to the recorder, or a short window of good listening conditions, adds
   short-scale clustering. With a 60-min GP, anything faster than about an hour
   is absorbed by the excitation term. Clustering from a varying rate versus
   contagion from past events is a known identifiability problem for point
   processes. Event times alone can't fully settle it.
3. **The detection process.** Calls masked by noise pile up in quiet windows,
   and analysts reviewing around a found call may catch more nearby. Both
   cluster detections without the whales doing anything.

**Why we still read it as answering.**

- The lag is minutes, matching the call-and-response timing that tag and
  focal-follow studies describe. (Check the source and the exact latency
  before quoting a number.)
- Three sites ~40 km apart, with very different call volumes (6k to 34k calls),
  give nearly the same structure: ~0.6 responses per call, half-life 1.4–2.0
  min. Noise or passing-animal artefacts would be expected to vary much more
  by site.
- A smoothly varying rate can't reproduce the gap distribution (55–61% of real
  gaps < 1 min vs 36–42% Poisson; reserve gap slide).

**What would settle it.** Name it as future work, not a weakness to hide:

- localisation within a site (a multi-element array or bearings), to see
  whether a triggered call comes from a different position than its parent;
- acoustic tags, to attribute calls to known animals;
- adding received level or SNR as a mark, to check whether parent and child
  calls look like different callers.

**Wording to adjust if pressed.** The blurbs say "whales answering". In Q&A,
step back to "calls triggered by a recent call, which we interpret as
answering".
