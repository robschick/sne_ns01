# Laptop dry-run guide — LGCPSE pipeline

End-to-end smoke test of the refactored pipeline against all three buoys
(NS01, NS02, COX01) on a laptop, using a deliberately short MCMC chain so
the whole loop completes in minutes rather than days. The goal is to
*exercise every stage*, not to produce publishable fits.

"Cluster" stages (02, 03 loglik, 04) all just run as `Rscript` locally — the
only difference is that the `path.fit` three-tier fallback resolves to
`./fit/<buoy>/` (since `/work/rss10/...` and `/hpc/group/schicklab/...`
don't exist), and `02_fitLGCPSE.R`'s auto-archive prints `SKIPPED`. That's
expected.

---

## Prep (once, before any buoy)

Temporarily edit `src/config.R`:

- `niters_lgcp <- 1500` (was 150000)
- In each of the three `buoy_settings` entries, set `burn = 500` (was 50000)

**Do not commit these.** Revert with `git checkout src/config.R` when the
dry run is done.

---

## Per-buoy sequence (12 scripts in order)

Walk `ns01` through all 12 steps first, so you see the full loop before
repeating. For steps 2–12, the prior step's output is the input — don't
reorder them.

| #  | Script                                       | Stage             | What it produces                                              | What to look at |
|----|----------------------------------------------|-------------------|---------------------------------------------------------------|-----------------|
| 1  | `Rscript 01_data.R --buoy=ns01`              | local prep        | `data/ns01.RData` (calls + noise + SST)                       | Console prints a count of events; `Rplots.pdf` is a noise-scatter artifact — ignore |
| 2  | `Rscript 02_fitLGCPSE.R --buoy=ns01`         | "cluster" fit     | `fit/ns01/ns01LGCPSE.RData`; prints `Archive ... SKIPPED`     | MCMC chatter every 1000 iters; should finish (1500 iters) |
| 3  | `Rscript 03_loglikLGCPSE.R --buoy=ns01`      | "cluster" loglik  | `loglik/ns01/ns01LGCPSE_loglik.RData`                         | Prints `Computed Nth iteration` |
| 4  | `Rscript 03_sumLoglik.R --buoy=ns01`         | local diagnostic  | `fig/ns01/NegTwoLogLikTrace.pdf`, `...Hist.pdf`, `...Summary.tex` | **Open the trace PDF.** This is the burn-in feedback loop — if the retained chain is still trending, you bump `buoy_settings$ns01$burn` and re-run step 3 |
| 5  | `Rscript 04_rtctLGCPSE.R --buoy=ns01`        | "cluster"         | `rtct/ns01/ns01LGCPSE_rtct.RData`                             | Prints per-event progress |
| 6  | `Rscript 04_lamLGCPSE.R --buoy=ns01`         | "cluster"         | `lam/ns01/LGCPSE_lam.RData`                                   | Prints per-grid progress |
| 7  | `Rscript 04_numLGCPSE.R --buoy=ns01`         | "cluster"         | `num/ns01/ns01LGCPSEnum.RData`                                | Prints per-iter progress |
| 8  | `Rscript 05_sumDIC.R --buoy=ns01`            | local figures     | `fig/ns01/DIC.RData`, `DIC.tex`                               | Table of DIC / pD |
| 9  | `Rscript 05_sumEstM4.R --buoy=ns01`          | local figures     | `fig/ns01/CI.pdf`, `background_excitement_coeffs_table.tex`   | **Predictor labels** — should read `Noise / SST / 1 wk sine / 1 wk cosine / 2 wk … / 1 mo … / 2 mo …` (the `fmt_period()` fix) |
| 10 | `Rscript 05_sumRTCT.R --buoy=ns01`           | local figures     | `fig/ns01/QQband.pdf`, `QQmsd.tex`                            | Q-Q plot of compensator |
| 11 | `Rscript 05_sumXB.R --buoy=ns01`             | local figures     | `fig/ns01/xb.RData`, `XB.pdf`                                 | Harmonic-only component over time |
| 12 | `Rscript 05_sumLam.R --buoy=ns01`            | local figures     | `fig/ns01/Lam.pdf`, `LamTotalRug.pdf`                         | **UTC axis** — should span Oct 2021 → Apr 2022 (the analysis window), not start at the NS01 deploy date |

---

## Repeat for NS02 and COX01

Once you've walked NS01 through end-to-end and sanity-checked the outputs,
loop the remaining two buoys:

```bash
for b in ns02 cox01; do
  for s in 01_data 02_fitLGCPSE 03_loglikLGCPSE 03_sumLoglik \
           04_rtctLGCPSE 04_lamLGCPSE 04_numLGCPSE \
           05_sumDIC 05_sumEstM4 05_sumRTCT 05_sumXB 05_sumNum 05_sumLam; do
    Rscript ${s}.R --buoy=$b || { echo "FAIL: $s --buoy=$b"; break 2; }
  done
done
```

The `break 2` bails out of both loops on first failure.

---

## After all three buoys

1. **Revert the config** so the real iteration/burn values come back:

   ```bash
   git checkout src/config.R
   ```

2. **(Optional) wipe the throwaway outputs** — they were built from a
   1500-iter chain and are not meaningful:

   ```bash
   rm -rf fit/ loglik/ rtct/ lam/ num/ fig/
   ```

   (These directories are all gitignored, so nothing in git history is lost.)

---

## Things to verify across the three buoys

Per the refactor goals, these should all be true after the dry run:

- **Per-buoy output isolation:** `fig/ns01/`, `fig/ns02/`, `fig/cox01/`
  each contain the same set of filenames, with no filename collisions
  between buoys (folder conveys buoy, filenames no longer carry a `nopp`
  or `LGCPSE_5c4h` prefix).
- **UTC axes are buoy-agnostic:** `LamTotalRug.pdf` for all three buoys
  spans the same Oct 2021 → Apr 2022 window (driven by `std` in
  `config.R`, not a per-buoy deploy time).
- **Harmonic labels are derived, not hardcoded:** `CI.pdf` in all three
  buoys shows `1 wk / 2 wk / 1 mo / 2 mo` predictors — if you change
  `harm_periods_lgcp` in `config.R`, these labels move with it.
- **No sweep-era artifacts:** no `runID`, `comb`, or `_5c4h` strings in
  any output filename.

---

## If anything fails

Paste the error + which step. Common failure modes to look for:

- **Rcpp compile failure** — rare on macOS with Xcode CLT installed. If
  you see a missing `Boost` or `RcppArmadillo` error, that's an env issue
  (not the pipeline).
- **Missing raw data** — `01_data.R` expects the rds files in `data/` and
  the SST CSV in `data/sst/`. The filenames are pinned in `buoy_settings`
  in `src/config.R`.
- **Path resolution surprises** — if `path.fit` ever resolves somewhere
  unexpected, check the three-tier fallback in `src/config.R` (lines
  ~139–146). On the laptop with no `/work/rss10` and no
  `/hpc/group/schicklab` mount, it should fall through to `./fit/<buoy>/`.
- **Short-chain math edge cases** — with only 1000 retained draws, the
  HPD intervals and batch-means SEs are crude. If a script errors on an
  empty chain or zero-variance column, that's likely a short-chain
  artifact, not a real refactor bug. Bumping `niters_lgcp` slightly
  should resolve it.
