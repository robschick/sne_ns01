# Manuscript scope & analysis-window decisions

*Decision memo — last updated 2026-07-05*

Captures the reasoning behind (a) how the point-process work is split into papers,
(b) whether/how to run the full 7-month seasonal fits, and (c) the principled way
to set the analysis window and treat onset vs. decline. Companion to
`plans/seasonal-spline-phase1.md` (the Phase-1→4 implementation plan).

---

## 1. Manuscript scope: two papers, not one

**Decision.** Split the work into two papers rather than a single multi-vignette
case-study paper.

1. **Research paper — the three long deployments (NS01, NS02, COX01).**
   Self-exciting (LGCPSE / Hawkes) point-process models fit across a full season.
   The *soul* is Hawkes applied to a long, non-stationary deployment: how the
   components (background, harmonics, GP, self-excitation) behave and trade off
   over months. The seasonal increase/decline is reported as a result, not the
   thesis.
2. **Short note — the 4-day spatiotemporal Hawkes model.** Findings-first,
   method-in-service. Not a how-to/software paper (no appetite for maintaining a
   reusable tool).

**Why not one paper.** "They're all Hawkes" is a *framework* commonality, not a
thesis — too thin to unify a paper. The real fault line is **research (a claim
about the world) vs. methods (a reusable tool)**, not temporal extent.

**Why not a methods paper for the long deployments.** The deliverable is a claim
about NARW calling dynamics, with the method in service of it. Code is released as
a reproducibility artifact alongside the research paper — that does *not* make it a
methods paper.

### 1a. The seasonal correction is load-bearing, not a detachable module

The tempting move — "leave the seasonal fix out to keep the research paper clean"
— is a trap:

- The length is only intellectually interesting *because* it introduces the
  non-stationarity (the seasonal arc) that over-disperses the compensator. Strip
  the seasonal handling out and "Hawkes on a long dataset" collapses into "Hawkes
  on a 5-month dataset with more rows and tighter posteriors" — an application, not
  a contribution.
- Publishing the naive harmonics+GP model at 7 months means publishing a fit your
  **own diagnostics flag as misfit** (the RTC over-dispersion). A reviewer runs
  straight into it.

So the research paper needs *a* seasonal correction as the minimum viable
correctness of its central model. What can be deferred to a future methods paper is
the **comparison of alternative corrections** (spline vs. P-spline vs. latent-state
HMM benchmarked by compensator calibration) — the "state later" half of the
roadmap.

### 1b. Keeping it research, not a methods bake-off

- **"How do we know the spline is good enough?"** The RTC / compensator machinery
  is the judge: increments should be i.i.d. Exp(1). `08_qqDispersion.R` gives
  `var_drop → 1` plus serial-structure checks. "Good enough" is the gate, not a
  vibe. If it fails, **swap** the basis (Phase-4 P-spline) — don't hold a
  referendum.
- **"When does with-vs-without become a methods paper?"** Only if you present a
  *menu*. The discipline: fit → diagnose misfit → apply **one** minimal,
  interpretable correction → re-diagnose. One before, one after, one diagnostic =
  model criticism (research). Enumerating and benchmarking formulations = methods.
  Same model, different rhetoric; the rhetoric is a choice.
- Rule for the research paper: **one correction, no menu; if it fails the gate,
  swap don't compare; HMM stays out entirely.**

---

## 2. Run decision: wait for COX01, then fan out

**Decision.** Do **not** launch all three 7-month seasonal fits at once. Let the
running COX01 pilot (SLURM 49258734, `cox01LGCPSEspl`) finish and clear the gate
first.

**Why (value of information).** Each fit is ~a month. COX01 is the **hardest case**
— sparsest series (n = 10,377 vs. 29,663 / 38,324) and most silence — so it is the
right stress test: if the spline design passes the RTC gate on the thinnest,
silence-dominated series, it will almost certainly hold on the denser NS01/NS02. If
it fails (boundary blows up, or `var_drop` doesn't fall), better to learn that on
one job than after burning ~2 more months of parallel compute on a design that then
has to change.

**Gate → fan-out sequence.**
1. COX01 finishes → run `08_qqDispersion.R`.
2. Pass = `var_drop → ~1` **and** `XBspline.pdf` shows a sane (non-runaway) decline
   at the terminal edge.
3. On pass: **lock** `seasonal_spline_df`, boundary knots, and `ns`-vs-`pspline`,
   then submit NS01 + NS02 in parallel (independent SLURM jobs — wall-clock ≈ one
   fit-cycle, not additive).
4. On terminal-boundary trouble: pull the boundary knot inward or switch to the
   Phase-4 P-spline **on COX01 first**, re-gate, then fan out.

Cost of waiting = one extra fit-cycle of serialization (~a month). What it buys =
not committing ~2 months of compute to an unvalidated design.

---

## 3. Analysis window & boundaries: the principled approach

### 3a. Two layers — don't hand-pick biological boundaries

Picking onset/decline dates by eyeballing the detection raster is **circular** —
it hand-specifies the very phenomenon the spline exists to estimate. Split it:

- **Layer 1 — the analysis window is an *input*, chosen by a signal-independent
  rule:** common recording coverage across all three buoys, with both edges
  anchored on seasonal *minima*, applied with **identical calendar dates** to every
  buoy. Anchoring the start on the summer/early-autumn trough anchors on the OFF
  state — not the thing being estimated — so it isn't circular. A common window is
  also what makes the cross-site comparison legal.
- **Layer 2 — onset and decline are *outputs*, estimated from the fitted
  background:** define them as functionals of the posterior intensity — onset =
  date of steepest positive slope (or first upcrossing of e.g. 25% of seasonal
  peak); decline = steepest negative slope — each with a credible interval. "When
  does calling begin/end" becomes an estimated quantity comparable across buoys
  ("COX01 onset N days later than NS02, 95% CI …"), not a chosen number.

### 3b. Deployment date ranges (raw data extent)

| Buoy  | Start (UTC)           | End (UTC)             |
|-------|-----------------------|-----------------------|
| NS01  | 2021-03-18 06:27:59   | 2022-04-30 04:00:52   |
| NS02  | 2021-03-10 17:29:06   | 2022-04-28 02:41:01   |
| COX01 | 2021-02-26 21:03:38   | 2022-05-14 20:13:20   |

Detection counts over the full extent: COX01 n = 10,377; NS01 n = 29,663;
NS02 n = 38,324 (`fig/up-calls_All-SNE.png`).

### 3c. What the dates lock in

- **Start = 2021-10-01** sits in a confirmed trough for all three → the fall ramp
  is fully bracketed by quiet baseline. **Onset is cleanly identified** and can be
  reported as an estimated date + CI per buoy.
- **Common end is NS02-limited at 2022-04-28**, two days short of the config's
  Apr-30 cap. This is **immaterial**, because each buoy's fit ends at its own last
  event (`maxT = ceiling(max(ts))`); NS02 simply terminates at its last call. The
  only real effect of the Apr-30 cut is that it **discards COX01's 2021-05-01 →
  05-14 data**.
- **The decline is genuinely right-censored** — all three are still calling when
  recording ends, and nothing fixes that. So the decline is reported as a
  *slope / still-falling state at truncation*, **never a completed "end date."**
  Stating it asymmetrically (onset estimated; season still in decline at
  truncation) is the honest, defensible claim.

### 3d. Spline mechanics at the censored edge

- Set the **terminal boundary knot at the data edge, not beyond** — no
  extrapolation past the last observation.
- The **Phase-4 P-spline controls edge variance/wiggle, not censoring.** It keeps
  the unobserved region from flapping; it cannot manufacture information about a
  trough that was never observed. Censoring is censoring.

### 3e. COX01's extra fortnight = the one censoring lever

COX01 is the only buoy that recorded past the others (to 2022-05-14), so it is the
only one that can probe how hard the censoring bites.

- **Keep the running Apr-30 COX01 fit as the comparable primary** (same window as
  NS01/NS02 → stays in the cross-site comparison).
- **Optionally add a COX01-only fit to the full 2022-05-14 extent** as a
  censoring-sensitivity probe. If two extra weeks still don't reach a trough,
  that *quantifies* the decline as unresolved at this season's observation limit —
  a reportable finding, not a failure. Spend it only if the terminal boundary
  misbehaves or censoring depth becomes a reviewer pressure point; do **not** gate
  the main analysis on it.

---

## 4. Locked decisions (summary)

- **Two papers:** 3-deployment research paper + short spatiotemporal-Hawkes note.
- **Seasonal correction stays in the research paper** as load-bearing infrastructure
  (one spline, gate-validated, no formulation menu).
- **Window:** common start 2021-10-01 (confirmed trough); common cap ~2022-04-28/30
  (NS02-limited, immaterial given per-buoy `maxT`); boundary knots at each series'
  own edges.
- **Claims:** onset = estimated date + CI; decline = right-censored slope / ongoing.
- **Run order:** COX01 pilot → gate (`var_drop → ~1`, sane terminal bend) → lock
  design → NS01 + NS02 in parallel.
- **Held in reserve:** COX01-to-2022-05-14 censoring-sensitivity fit; Phase-4
  P-spline swap if the `ns` terminal boundary misbehaves.
