# Spec — NARWC talk figures for the fitted parameters (figs 2, 4, 6, 7)

Settled in a grilling session on 2026-10-23. Four candidate figures for a
1–2 minute slot in a 10-minute talk; Rob picks which to use after seeing them.
Build and polish in the order 4 → 6 → 2 → 7.

## Common ground

- **Fits:** the current production fits only — clean COX01 (Aug, burn 75k) and
  the Sep NS01/NS02 100k fits (burn 50k). All use the 5-month window
  (Oct 1 2021 – Mar 1 2022), five harmonics (1 d, 1 wk, 2 wk, 1 mo, 2 mo) and no
  spline. Nothing reads the June tables (`fig/combined/`), which predate the
  daily harmonic.
- **Re-runnable:** every figure is a script; the final 150k NS01/NS02 numbers
  come from re-running the cluster export and the laptop scripts.
- **Style:** `theme_talk` (as in `13_branchShare.R`), `col_contact` /
  `col_counter` from `src/anim_schematic.R`, buoys ordered COX01 → NS01 → NS02,
  output to `fig/talk/` as PNG (dpi 200) + cairo PDF. Season slides 13.33 × 7.5 in.
- **Language:** the model sees *detected* calls only. Say "detected", "what we
  hear", never "what whales do", for anything driven by noise.

## Cluster export: `10b_paramExport.R` (+ `aci_param_export.sh`)

A sibling of `10a_animExport.R` rather than an edit to it: it doesn't need
`postBranching` per call, and it leaves the animation export untouched.

- Reads the fit from `PARAM_FIT_FILE` when set. **NS01/NS02 must point at the
  `*.100k.RData` backups on /hpc** while the 150k extensions are running: the
  live /work files are rewritten every 1,000 iterations.
- Thins to 2,000 post-burn draws (`PARAM_THIN`).
- Writes `out/anim/<buoy>_params.rds`:
  - `draws`: β (named), δ, α, η per draw.
  - `knots`: per 20-min knot — `ts`, standardized noise `x_noise` (Xm col 2),
    the deployment-scaled noise `noise_dep` (for the dB calibration), SST °C,
    and median + 95% quantiles of each log-scale contribution: intercept,
    noise, SST, harmonic sum, δW (GP).
  - `quiet`: the noise cap (10th percentile of `x_noise` over the knots), and
    per day (model day 0 = Oct 1) the median + 95% quantiles across draws of
    expected background calls (actual, quiet), the contact-call gap, and the
    whole-exchange gap = contact gap / (1 − α/η) — all computed per draw.
  - `season`: the same four totals over the whole window, per draw summarised.
- Checks: knots reproduce `lam0 = exp(Xβ + δW)` from the components;
  season background total agrees with `num/` within a few %.

## Fig 4 — the volume knob (`14_volumeKnob.R`)

- **Message:** turn the ocean up 5 dB and we detect about half the calls
  (fewer at NS01).
- Same **+5 dB** at all three buoys. Retention = exp(β_noise · 5 / dB_per_SD),
  where dB_per_SD is the SD of RMS (dB re 1 µPa) across that buoy's knots,
  calibrated on the laptop from `data/<buoy>_rms_data.rds`.
- One row per buoy of 10 filled circles; the lost share greyed out (fractional
  last circle allowed), with the % detected and its 95% interval as text.
- Title says *detect*. Static, not a build.
- **Accept:** retention per buoy within its 95% interval matches
  exp(β · 5 / dB_per_SD) by hand; the dB calibration regression has R² > 0.999.

## Fig 6 — calls missing on noisy days (`15_quietSeason.R`)

- Counterfactual: noise **capped** at each buoy's quietest-10% level; times
  already quieter are unchanged.
- Daily expected calls, actual vs quiet. Dark band = missing contact calls;
  lighter band = whole exchanges (contact gap × 1/(1 − α/η)). The headline
  number is the whole-exchange total ("≈ N calls, X% of what we'd have heard").
- Title **"Calls missing on noisy days"**. Caption: **"Missing = missed by
  the detector, or never made"**, then (1) masking and (2) behaviour as
  numbered lines (text, not icons: emoji/glyph icons don't render reliably in
  the cairo PDFs), then "Detections alone cannot tell these apart." The
  Lombard effect goes in Q&A notes, not on the slide.
- Two versions: **(i)** NS01 in detail plus a strip of season totals for all
  three buoys; **(ii)** three panels on a shared y-axis.
- **Accept:** gap ≥ 0 everywhere (the cap only lowers noise and β_noise < 0);
  actual daily background summed ≈ `num/` background total.

## Fig 2 — same conversation, different crowds (`16_sameConversation.R`)

- **Left:** exchange-size distribution, P(1, 2, 3, 4, 5+ calls), per buoy from
  α/η. Each call has Poisson(α/η) answers, so the size is Borel(α/η):
  P(n) = e^(−mn) (mn)^(n−1) / n!. Credible band from the draws.
- **Right:** exchanges started per day = background calls / 151 days, from
  `num/`.
- Message: the same kind of exchange everywhere; NS02 just has more.
- Laptop only (anim exports + `num/`); does not wait for the cluster.
- **Accept:** the Borel probabilities sum to 1; mean size = 1/(1 − α/η).

## Fig 7 — what moved the call rate (`17_rateDrivers.R`)

- Per buoy, daily small multiples: noise, SST, seasonal cycles, leftover (GP),
  and answering (λ/μ from the calls via `excite_grid()`).
- Each background piece as exp(daily mean of its log contribution − season
  mean), on one shared log axis labelled "× typical". Answering is the daily
  ratio of total to background expected calls, left uncentred so 1x = no
  answers that day (centring would put call-free days below 1x).
- NS01 main slide; COX01 and NS02 backups.
- **Accept:** product of the four background factors × intercept reproduces
  the daily background (up to the daily-averaging of logs).

## Out of scope

- The paper tables and `05_sumCombined.R` (rebuilt after the 150k fits).
- Any causal claim about noise or SST.

## Running it

### Cluster (once per fit version)

The NS01/NS02 150k extensions are running out of the same checkout. `git pull`
only adds files they don't use, but run it on master after this PR merges, not
by switching branches.

```bash
cd /hpc/group/schicklab/sne_dev
git status --short          # must be clean
git pull                    # on master, after the PR merges
ls -la /hpc/group/schicklab/sne_ns01/fit/ns0{1,2}/ns0?LGCPSE.100k.RData   # backups exist

# NS01/NS02 read the 100k backups, never the live /work files the running
# 150k jobs rewrite every 1,000 iterations
sbatch --mem=32G --export=ALL,BUOY=cox01 aci_param_export.sh
sbatch --mem=64G --export=ALL,BUOY=ns01,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns01/ns01LGCPSE.100k.RData aci_param_export.sh
sbatch --mem=96G --export=ALL,BUOY=ns02,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns02/ns02LGCPSE.100k.RData aci_param_export.sh

# Each log ends with the season totals, the num/ cross-check and "Wrote ..."
tail -n 15 out/param_export_*_param_export.log
```

Check in each log: `chain 100000 iterations, 2000 draws`, and the background
total within a few % of `num/`.

After the 150k fits are final: drop `PARAM_FIT_FILE`, and set `PARAM_BURN`
to the burn chosen from the new trace.

### Laptop

```bash
CL=rss10@dcc-login.oit.duke.edu
rsync -av "$CL:/hpc/group/schicklab/sne_dev/out/anim/*_params.rds" out/anim/
Rscript 14_volumeKnob.R
Rscript 15_quietSeason.R
Rscript 16_sameConversation.R     # needs only the anim exports and num/
Rscript 17_rateDrivers.R
```
