# Assembling manuscript results across the three buoys

A reference for regenerating the coefficient table, the intensity
estimates/plots, and the expected call-count decomposition (total /
background / counter) for **NS01, NS02, COX01**.

> **Terminology:** "counter-calls" ≡ the model's **self-excitement**
> component (the Hawkes triggering term). Background calls are the
> non-excited (LGCP) component. Total = background + self-excitement.

The analysis window is shared across all buoys: **2021-10-01 → 2022-03-01**
(5 months), set in `src/config.R` (`std`, `analysis_end`).

---

## Where the results live

Fit objects and derived quantities are produced **on the cluster** and are
*not* tracked in git. On a fresh laptop checkout, `fit/`, `lam/`, `num/`,
`rtct/`, and `fig/` are empty. `config.R` resolves fit paths with a
three-tier fallback:

1. `/work/rss10/sne_ns01` — primary cluster scratch (75-day wipe)
2. `/hpc/group/schicklab/sne_ns01` — persistent lab share
3. local `./` — laptop after `rsync`

So the laptop steps below only work once you have rsync'd the cluster
outputs down.

---

## The pipeline (stages 4 → 5)

| Stage | Where   | Scripts                                              | Produces                              |
|-------|---------|------------------------------------------------------|---------------------------------------|
| 2–3   | cluster | `02_fitLGCPSE.R`, `03_loglikLGCPSE.R`                | the MCMC fit (`fit/<buoy>/`)          |
| 4     | cluster | `04_lamLGCPSE.R`, `04_numLGCPSE.R`, `04_rtctLGCPSE.R`| intensity, counts, GOF compensator    |
| 5     | laptop  | `05_sum*.R`                                          | figures (PDF) + LaTeX/CSV tables      |

The **coefficient table** is the exception — it reads the fit directly via
`src/load_fit.R` and needs no Stage-4 output, only the `fit/` RData.

---

## Stage 4 — derived posterior quantities (cluster)

No inter-dependencies, so submit all at once:

```bash
for b in ns01 ns02 cox01; do
  for s in aci_lam.sh aci_num.sh aci_rtct.sh; do   # rtct only if you want GOF
    sbatch --export=ALL,BUOY=$b $s
  done
done
```

**Outputs** on `/work/rss10/sne_ns01/`:

- `lam/<buoy>/LGCPSE_lam.RData` — posterior intensity on a 2,000-point grid:
  `postBack` (background), `postSE` (self-excitement / counter),
  `postLam` (total), each as `(lb, median, ub)`.
- `num/<buoy>/<buoy>LGCPSEnum.RData` — `postNum`: col 1 = background count,
  col 2 = self-excitement (counter) count.
- `rtct/<buoy>/...` — random-time-change compensator (goodness-of-fit only).

---

## Stage 5 — tables and figures (laptop)

Pull Stage-4 outputs (and the fits, for the coefficient table) down:

```bash
rsync -avz $CLUSTER:/work/rss10/sne_ns01/lam/ ./lam/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/num/ ./num/
rsync -avz $CLUSTER:/work/rss10/sne_ns01/fit/ ./fit/
```

Then render. Per-buoy scripts (each writes into `fig/<buoy>/`):

```bash
for b in ns01 ns02 cox01; do
  Rscript 05_sumEstM4.R --buoy=$b   # coefficient table + CI plot
  Rscript 05_sumNum.R   --buoy=$b   # total / background / counter counts
  Rscript 05_sumLam.R   --buoy=$b   # intensity plots
  Rscript 05_sumXB.R    --buoy=$b   # harmonic-only effect plot (optional)
done
```

Cross-buoy combined tables (writes into `fig/combined/`):

```bash
Rscript 05_sumCombined.R            # run WITHOUT --buoy; it loops all three
```

---

## Mapping to the three manuscript asks

### 1. Coefficient table — `05_sumEstM4.R` (per buoy) / `05_sumCombined.R` (combined)

Parameters reported, with posterior mean + 95% HPD (and a `*` when the 95%
HPD excludes 0):

- **Covariates:** Noise, SST
- **Harmonics:** sin + cos for each period in `harm_periods_lgcp`
  (1 wk, 2 wk, 1 mo, 2 mo)
- **Self-excitement block:**
  - `alpha` — excitement (Hawkes branching magnitude)
  - `delta` — GP scale on the background log-intensity
  - `eta`  — decay rate of the excitement kernel

Per-buoy outputs: `fig/<buoy>/background_excitement_coeffs_table.tex`,
`fig/<buoy>/CI.pdf`. Combined wide table: `fig/combined/`.

### 2. Intensity estimates / plots — `05_sumLam.R` (needs `lam/`)

- `fig/<buoy>/Lam.pdf` — three stacked panels: Background, Excitement, Total.
- `fig/<buoy>/LamTotalRug.pdf` — total intensity with a rug of raw call times.
- X-axis is wall-clock UTC anchored at `std` (2021-10-01), **not** the
  deployment time.

### 3. Expected counts (total / background / counter) — `05_sumNum.R` (needs `num/`)

- `fig/<buoy>/Num.tex` — rows Total, Background, SelfExcitement (= counter),
  each posterior mean + HPD.
- Combined across buoys via `05_sumCombined.R` → `fig/combined/`. The combined
  counts table prepends an **Observed** row (raw in-window calls, `nrow(data)`)
  so the modeled Total can be compared directly against the observed count.

---

## Quick checklist

- [ ] Burn-in confirmed per buoy (`03_sumLoglik.R` traceplots; `buoy_cfg$burn`).
- [ ] Stage-4 jobs (`lam`, `num`) finished on the cluster for all three buoys.
- [ ] `rsync` of `lam/`, `num/`, `fit/` down to the laptop.
- [ ] `05_sumCombined.R` run without `--buoy` (it iterates all three internally).
