# Choosing the modeling domain for seasonally-structured point-process models

**A practitioner reference.** How to decide when to extend or truncate the
temporal modeling domain when fitting intensity models (LGCP / self-exciting /
Hawkes) to acoustic detection data that has seasonal structure — and how to use
random-time-change (RTC) goodness-of-fit diagnostics to assess that choice.

Written 2026-06-27, abstracted from the COX01 end-of-window decline seen in this
project's RTC diagnostics. It is intentionally model-agnostic so it can be
lifted into a methods paper or its own repo later; a COX01 worked example and a
map to this repo's scripts are at the end. Companion file:
[`qq_diagnostics_findings.md`](qq_diagnostics_findings.md).

> **Status / scope.** This is the conceptual reference. Two concrete follow-ups
> are planned *from* this document and are not yet built:
> 1. a **PRD + implementation plan for a domain sensitivity test** (fit a ladder
>    of candidate domains, compare estimands and diagnostics);
> 2. **expanded practitioner inference guidance** for this dataset.
> Keep those as separate planning artifacts; this file is their source.

---

## TL;DR

- Domain choice is **not** a data-trimming convenience — with global basis
  functions it changes the parameter estimates everywhere, including the
  interior you care about.
- Reframe the decision: not *"extend or truncate?"* but **"is the temporal
  structure at the boundary inside the expressive range of my model?"**
- The **compensator budget** (`Σ dᵢ = ∫λ ≈ n`) turns that question into a
  testable one: an unrepresentable boundary produces a specific RTC signature
  (a few huge boundary increments → deflated, under-dispersed interior →
  positive serial correlation).
- Decide with a **sensitivity ladder** (several candidate domains) judged on
  *both* the scientific estimands and the diagnostics, plus **temporal
  localization** of the worst RTC outliers.
- Default: **enrich the model to represent a biologically meaningful boundary**
  before truncating it away.

---

## 1. The reframe: can my basis represent the boundary?

The instinct is to treat the domain `[0, T]` as a trimming decision. The more
useful frame comes from the compensator budget. Over the fit domain,

```
Σ_i d_i = ∫_0^T λ̂(u) du ≈ n,
```

so the model holds a **fixed budget of intensity** to distribute across the
window. When you extend `T` into a tail where calling has decayed, one of two
things happens:

- **The basis can follow the decline** (a seasonal GP, a long-period harmonic, a
  trend term) → the model assigns low intensity there, the budget is spent
  correctly, the diagnostics stay clean, and you have *learned the phenology*.
  The decline is signal.
- **The basis cannot follow it** (harmonics too coarse, GP range too short) →
  the model keeps predicting calls into the quiet tail → a few enormous `dᵢ` at
  the boundary → the budget forces the *interior* increments below 1 → an
  under-dispersed bulk with positive serial correlation.

So the real question is **"is the boundary structure inside the expressive range
of my model?"** If yes, extend (more data, learned phenology). If no, two honest
options: **enrich the basis** to represent it, or **truncate** to the regime the
basis handles and report that as scope. Trimming purely to make the Q–Q look
nice — without either justification — is fitting the diagnostic.

---

## 2. Look at the raw data first

Three plots, each answering one question, *before* any model:

1. **Daily/weekly call counts over the full available record, with a smoother
   (GAM/loess).** Shows the phenological envelope: the on-ramp, plateau, and
   off-ramp. You want to see where the rate rises out of, and decays back
   toward, baseline.
2. **Rate vs. the detector noise floor / false-positive rate.** Past the point
   where the call rate approaches the false-positive rate, "calls" are
   increasingly detector artifacts. Including that tail injects *structured
   noise* the point process will try to explain — often the real reason to
   truncate.
3. **Hour-of-day aggregated across the season (and sub-seasons).** Tells you
   whether a diel rhythm exists, whether it is stable, and over what span a 24-h
   harmonic is warranted.

The start of the window deserves the same scrutiny as the end — the on-ramp has
the identical issue, and (for harmonic models) the phase anchor interacts with
the start.

---

## 3. Classify the boundary

The decision differs by *why* the record ends:

| Boundary type | Description | Choice? |
|---------------|-------------|---------|
| **Hard data limit** | recorder retrieved, battery died | None — `T` is forced; report it |
| **Soft biological decline** | rate decays toward ~0 but data continues | **Yes** — the interesting case |
| **Regime change / discontinuity** | behavioral shift, deployment move | Candidate hard break, not a smooth boundary |

Only the soft-decline case requires the budget reasoning. There the key question
is whether the decline belongs *inside* the modeled process (signal to learn) or
is a *boundary* to exclude (out of scope).

---

## 4. Decide with a sensitivity ladder

Do not pick one `T` and defend it. Fit a small ladder of candidate domains and
examine **two** things:

- **Do the scientific estimands move?** Peak timing, seasonal amplitude, the
  self-excitement parameters — whatever you report. Stable across reasonable `T`
  ⇒ the boundary is innocuous: report the choice and move on. Swinging ⇒ the
  boundary is *influential* and the burden of justification is high. (This is a
  specification-curve / multiverse check applied to the domain.)
- **Do the diagnostics improve?** RTC MSD, the upper tail, `acf1_U`,
  Ljung–Box `Q`.

The persuasive statement is the combination: *"estimates stable and diagnostics
clean across the Mar–Apr cuts"* is strong robustness; *"estimates move and the
tail degrades when we extend"* says the boundary is doing real damage.

---

## 5. Use the diagnostics to localize the problem in time

RTC diagnostics don't just say *whether* the fit is off — used well they say
*where* and *why*:

- **Where do the largest `dᵢ` fall?** If they cluster at the **end** of the
  window → boundary/domain problem (truncate or enrich). If **scattered** →
  genuine intermittent silences (biology, not domain). This temporal
  localization is the single most useful test.
- **Interior vs. boundary calibration.** Clean in the interior but degrading in
  the last ~10–15% of the window ⇒ a boundary diagnosis, not a global misfit.
- **The sign of `acf1_U`** (lag-1 autocorrelation of the PIT residual; see
  `qq_diagnostics_findings.md`). **Positive** + outliers-at-the-end = the model
  over-predicts into a decline it cannot represent (domain too long for the
  basis). **Negative** instead points at over-adaptive intensity — a different
  fix (shrink the GP / self-excitement, not the domain).

---

## 6. The crucial subtlety: global bases contaminate the interior

With **global basis functions** (harmonics), a bad boundary does not stay at the
boundary. The harmonic coefficients are estimated from the *whole* domain, so a
misrepresented tail biases the seasonal estimate **everywhere**, including the
interior you care about. You therefore **cannot** fully rescue a bad domain by
restricting interpretation to the good interior after the fact — the
contamination is already baked into the global parameters. (A purely *local*
model — e.g. intensity that is only a GP — would be far more forgiving.) This is
the strongest argument for either truncating the fit itself or adding a flexible
local term, rather than fitting wide and interpreting narrow.

---

## 7. Default: enrich before you truncate

When the boundary structure is **biologically meaningful** — and a seasonal
decline usually *is* the phenology of interest — prefer **adding a term that can
represent it** (a low-frequency seasonal GP or trend, so the model can spend
budget on the decline locally) over discarding the data. Truncation is the right
call when the boundary is genuinely **out of scope**: a false-positive-dominated
tail, a different behavioral regime, or structure the model family fundamentally
cannot describe. Truncating to make diagnostics pretty risks deleting the very
ecological signal — the end of the season — that motivated the study.

---

## 8. Decision checklist (practitioner box)

1. **Plot raw counts + smoother** over the full record. Mark the on-ramp,
   plateau, off-ramp, and where rate meets the false-positive floor.
2. **Classify the boundary**: hard limit / soft decline / regime change.
3. If soft decline, **ask the budget question**: can my basis represent this
   shape? (period long enough? GP range wide enough? trend term present?)
4. **Fit a ladder** of candidate domains.
5. For each, record **(a) the reported estimands** and **(b) the RTC
   diagnostics** (MSD, upper-tail outlier times, `acf1_U`, Ljung–Box `Q`).
6. **Localize** the worst `dᵢ` in time: end-clustered → domain issue;
   scattered → biology.
7. **Choose**: estimands stable + diagnostics clean ⇒ extend and report;
   boundary representable but currently misfit ⇒ **enrich**; boundary
   out-of-scope ⇒ **truncate** and state the scope explicitly.
8. **Report** the domain as a justified modeling decision with the sensitivity
   evidence, not a silent default.

---

## 9. Worked example: COX01

- **What we see.** COX01 has the worst RTC fit of the three buoys (the largest
  compensator increments cluster in late Feb 2022), a deflated/under-dispersed
  interior, and `acf1_U = +0.189` (positive) — the boundary-mismatch signature
  from §5. Raw COX01 calling declines through spring and the data run to
  mid-May 2022.
- **Why the boundary is contested.** The Mar-1 → Apr-30 cuts were chosen for
  **cross-buoy comparability** (a shared window aligned to the NS01/NS02 data
  limit), *not* for COX01's own biology. COX01 therefore sits between two
  legitimate goals: a **common** window for comparability vs. a **per-site**
  window matched to each buoy's phenology. State this explicitly rather than
  letting the shared window silently double as the scientific domain.
- **Likely signal, not nuisance.** The spring decline is probably real
  phenology (right whales leaving SNE), which argues *against* discarding it.
- **The clean test (post-refit).** If extending to Apr-30 *with* the diel
  harmonic (and possibly a seasonal trend) relaxes COX01's tail and pulls
  `acf1_U` toward 0, the decline was representable and the extension was correct.
  If it does not, that tail is genuinely outside the basis and COX01 wants
  either a longer-period seasonal term or its own shorter domain.

---

## 10. Map to this repo's tooling

| Need | Script / artifact |
|------|-------------------|
| RTC Q–Q (full + bulk-zoom, per buoy / all buoys) | `05_sumRTCT.R`, `05b_sumRTCTzoom.R`, `05c_sumRTCTzoomAll.R` |
| Temporal localization of upper-tail `dᵢ` (§5) | `06_qqOutliers.R` → `fig/combined/qq_outliers.csv` |
| Rule out recording gaps vs. biological silence | `07_gapVsCoverage.R` |
| Dispersion + serial-correlation stats (`mean/var/drop`, `bulk_slope`, `acf1_U`, Ljung–Box) | `08_qqDispersion.R` → `fig/combined/qq_dispersion.csv` |
| Domain definition (the lever this doc is about) | `src/config.R` — `std`, `analysis_end`, `harm_periods_lgcp` |

**Not yet built (the planned follow-ups):** a script/PRD to fit the §4
sensitivity ladder across multiple `analysis_end` values and tabulate estimands
+ diagnostics side by side. That is the natural next artifact from this doc.
