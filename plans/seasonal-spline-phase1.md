# Plan: Seasonal spline in Xm (Phase 1) — estimate the end-of-season calling decline

> Source PRD: GitHub issue [robschick/sne_ns01#1](https://github.com/robschick/sne_ns01/issues/1)
> Scope: **COX01 only**. Phases 2 (logistic ramp, C++) and 3 (HMM) are out of scope.

## Architectural decisions

Durable decisions that apply across all phases:

- **Deep module**: `build_design_matrix(knts, noise, sst, cfg) → Xm`, a new shared
  R function in `src/` (alongside `RFtns.R`). Single owner of the design: intercept,
  noise/sst columns, harmonic columns, the *conditionally dropped* 2-month harmonic,
  and the seasonal spline. De-duplicates the inline `Xm` block currently repeated in
  `02_fitLGCPSE.R`, `proto_spline/proto_fit_spline.R`, `proto_spline/proto_glm_probe.R`,
  and `src/benchmark_fit.R`.
- **Config knobs** (`src/config.R`): `seasonal_spline` on/off toggle (**default OFF**),
  `seasonal_spline_df`, boundary-knot control, and a fallback-method flag (`ns` vs
  `pspline`). When `seasonal_spline` is ON, the 2-month period is dropped from
  `harm_periods_lgcp` and the spline owns all sub-seasonal structure.
- **Sampler untouched**: `fitLGCPSE` sizes off `p = ncol(Xm)` and already priors all
  of `beta` with `N(0, 100·I)` (`MVN_logh(newbeta, zeros(p), diagmat(ones(p))/100)`),
  auto-sized to `p`. Widening the design is C++-free.
- **Acceptance gate**: full COX01 fit → `08_qqDispersion.R`. Pass = `var_drop`
  (top-5 removed) falls from ~21.9 toward ~1; secondary `acf1_U`, `ks_D` also drop.
  Judge with `var_drop` / central-95% MSD, **not** full-range MSD (dominated by ~5 points).

### Isolation contract (exploratory workflow must not disturb existing cluster work)

This is a **separate exploratory workflow**. It must be impossible for pulling or
running this code to overwrite or alter the existing production `LGCPSE` fits/outputs
on the cluster. Three independent guarantees, all required:

1. **`git pull` cannot touch outputs.** All output dirs (`data/ fit/ loglik/ lam/
   rtct/ num/ fig/`) are gitignored/untracked; a pull only changes *code*.
2. **Distinct model tag isolates every output.** Outputs are named `<datai><fiti>...`.
   When `seasonal_spline` is ON, `fiti_lgcp` auto-switches from `'LGCPSE'` to
   **`'LGCPSEspl'`**, so fit, loglik, lam, rtct, num, fig, and the schicklab archive
   copy all get distinct filenames and never collide with production `LGCPSE` files.
3. **Spline defaults OFF ⇒ bit-for-bit reproduction.** With the knob off, `config.R`
   and the builder reproduce the current 13-column design exactly (2-mo harmonic
   retained, tag stays `LGCPSE`), so existing runs are unaffected by the new code.
4. **Feature branch.** All Phase-1 work lands on branch `seasonal-spline`; the
   cluster's `master` stays pristine until the branch is explicitly checked out.

---

## Phase 1: Extract the design builder (no-op tracer bullet)

**User stories**: 5, 6

### What to build

Create `build_design_matrix()` and route `02_fitLGCPSE.R` through it, producing the
**identical** current 13-column `Xm` (spline off, 2-month harmonic retained, tag
`LGCPSE`). No behavior change — this slice establishes the seam end-to-end (config →
builder → sampler) and de-risks the plumbing. Create the `seasonal-spline` branch.

### Acceptance criteria

- [ ] `build_design_matrix()` exists in `src/` and returns an `Xm` byte-identical to
      the current inline construction on COX01 (same columns, same values, `ncol == 13`).
- [ ] `02_fitLGCPSE.R` calls the builder instead of building `Xm` inline; a short
      COX01 fit runs clean and writes to the `LGCPSE` tag (production namespace,
      unchanged) — confirming the refactor is a true no-op.
- [ ] Work is on branch `seasonal-spline`; `master` unchanged.

---

## Phase 2: Spline design + drop 2-mo harmonic, validated by the GLM probe

**User stories**: 1, 3, 4, 11

### What to build

Extend `build_design_matrix()` to append a fixed-knot natural-spline basis (`ns()`,
`seasonal_spline_df`, controlled boundary knots) and drop the 2-month harmonic when
`seasonal_spline` is ON; add the config knobs and the `fiti` auto-switch to `LGCPSEspl`.
Point `proto_spline/proto_glm_probe.R` at the builder. Validate the *design's* ability
to represent the decline with the fast Poisson-GLM probe — no full MCMC yet.

### Acceptance criteria

- [ ] Config knobs present; `seasonal_spline` defaults OFF (Phase-1 no-op invariant
      still holds: off ⇒ 13-col design + `LGCPSE` tag).
- [ ] With the spline ON, the builder drops the 2-mo harmonic and appends the spline
      block; `fiti_lgcp` becomes `LGCPSEspl`.
- [ ] GLM probe (spline vs harmonics-only) reproduces the decline: ΔAIC on the order
      of ~3226 for the spline params; both fits bend down through Mar–Apr.
- [ ] The design is full-rank (no collinearity blow-up from dropping/adding terms).

---

## Phase 3: Full COX01 fit + acceptance gate

**User stories**: 2, 7, 9, 10, 12

### What to build

Run the real `02_fitLGCPSE.R` COX01 fit with the spline ON (writing to the isolated
`LGCPSEspl` namespace), update the cosmetic column labels/counts in the `05_*`
summary scripts so downstream tables/figures render, then run the RTC pipeline and
`08_qqDispersion.R`. This is the authoritative acceptance test for Phase 1.

### Acceptance criteria

- [ ] A converged COX01 `LGCPSEspl` fit completes on the cluster; all outputs land in
      the isolated tag namespace — production `LGCPSE` files untouched (verify no
      `cox01LGCPSE.RData` etc. were modified).
- [ ] `05_*` summaries render with the new design (correct column labels/counts).
- [ ] `08_qqDispersion.R` on COX01 `LGCPSEspl`: `var_drop` falls from ~21.9 toward ~1;
      `acf1_U` and `ks_D` also drop materially.
- [ ] The posterior background bends down through the spring silence (visual: the
      seasonal decline is represented, not a floored intensity).

### Status — first COX01 fit (2026-07-09): gate INCONCLUSIVE, chain not converged

First real COX01 `LGCPSEspl` fit ran to completion (SLURM 49258734, `aci_fit.sh`,
`COMPLETED` after 1d 8h, clean exit — not a walltime kill). `08_qqDispersion.R`
came back **essentially unchanged from the pre-spline baseline**, and the reason
is under-convergence, not a spline failure:

- `08` on COX01 `LGCPSEspl`: `var_drop` **19.25** (baseline ~21.9), `acf1_U`
  **0.49** (baseline ~0.51), `ks_D` **0.356** (baseline 0.356), `mean_drop` 0.796.
  Barely moved on every metric.
- **Spline IS active** (rules out the ridge-shrinkage / identifiability worry):
  `05_sumEstM4` HPD plot shows large non-zero spline coefficients — Spline 3 ≈ +7.5
  (tight CI), Spline 1/2 ≈ +2–4, Spline 4 ≈ −2.5. The design is being used.
- **Chain is not converged** (the real cause): `03_sumLoglik` trace still climbing
  across the *retained* post-burn half (postLogLik ~−6800 → ~−5900, not flat at
  100k). Cold `beta = rnorm(p)` start (`02_fitLGCPSE.R:71`) + the wider spline
  design + 7-month window ⇒ the burn-in climb doesn't finish in 100k. The old
  5-month fit converged fast because the posterior was easier.

So `var_drop` was scored off non-stationary samples — the gate can't be read yet.

**Decision — resume-and-extend (not restart, not Phase 4).** Full step-by-step in
[`docs/cox01_resume_fit_runbook.md`](../docs/cox01_resume_fit_runbook.md) (the
edits, the post-resume re-run order, and the "don't carry to master" hygiene):
1. `src/config.R`: `niters_lgcp` 100000 → **250000** (+150k iters, ~2 days).
2. `02_fitLGCPSE.R:120`: uncomment `load(filename); start = which(outers ==
   nrow(postSamples))`. `filename` (line 15) already = `cox01LGCPSEspl.RData`;
   no thinning (`RcppFtns.cpp:552`, one row/iter) so `nrow(postSamples)==100000`
   indexes cleanly. Warm-starts `beta` + adapted `COVbeta` + `Wm`/`sigma2`/Hawkes
   → continues the *same* chain, no re-burn.
3. Backup first: `cp cox01LGCPSEspl.RData{,.100k.bak}`; resubmit `aci_fit.sh`.

**After the resume:**
- Burn-in must move up: first ~100k are the cold-start climb. Re-run
  `03_loglikLGCPSE` → `03_sumLoglik`, set `buoy_settings$cox01$burn` to the new
  plateau (likely ≥150k), **then** `04_rtctLGCPSE` → `08` to re-read the gate.
- If the resumed chain (with adapted `COVbeta`) *still* climbs slowly, the issue is
  MH step-efficiency at p=16, not burn-in → consider block reparam before Phase 4.
- **Do not carry to master:** revert the resume line after this run, and
  `niters=250000` / `seasonal_spline=TRUE` stay branch-only.

---

## Phase 4 (conditional): pre-scaled P-spline fallback

**User stories**: 8

> Only if Phase 3's boundary bends badly or the `var_drop` gate is not met.

### What to build

Implement the mixed-model reparameterization of a penalized B-spline behind the
`fallback-method` config flag: reparameterize into unpenalized-polynomial +
i.i.d.-penalized parts, then **pre-scale** the penalized columns R-side so the fixed
`1/100` prior precision encodes a smoothing level chosen by REML on the Poisson-GLM
probe. Still zero C++; smoothing fixed (not jointly estimated). Re-run the Phase-3 gate.

### Acceptance criteria

- [ ] `fallback-method = pspline` selects the reparameterized basis with a
      REML-chosen smoothing level; `ns` remains the default.
- [ ] The boundary bend is controlled (no runaway edge extrapolation).
- [ ] Re-running `08_qqDispersion.R` on COX01 `LGCPSEspl` meets the gate
      (`var_drop → ~1`).
