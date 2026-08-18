# Runbook — resume-and-extend the COX01 `LGCPSEspl` fit

**Context (2026-07-09).** The first real COX01 seasonal-spline fit (SLURM
49258734, `aci_fit.sh`, `COMPLETED` after 1d 8h — clean exit, not a walltime kill)
did **not** converge: the `03_sumLoglik` trace is still climbing across the
retained post-burn half (postLogLik ~−6800 → ~−5900, not flat at 100k). The
`08_qqDispersion.R` gate therefore came back essentially at the pre-spline baseline
(`var_drop` 19.25 vs ~21.9; `acf1_U` 0.49 vs ~0.51; `ks_D` 0.356) — **scored off
non-stationary samples, so it can't be read yet.**

This is **not** a spline failure. `05_sumEstM4` shows large, non-zero spline
coefficients (Spline 3 ≈ +7.5 with a tight CI; S1/S2 ≈ +2–4; S4 ≈ −2.5), so the
design is active and being used. The problem is the cold `beta = rnorm(p)` start
(`02_fitLGCPSE.R:71`): with the wider spline design and the 7-month window, the
burn-in climb doesn't finish in 100k iterations. (The old 5-month fit converged
fast because the posterior was easier.)

**The fix is to resume the existing chain**, warm-starting from its own end-state —
which carries not just `beta` near the mode but the adapted `COVbeta`, `Wm`,
`sigma2`, and the Hawkes parameters. That is strictly better than a cold restart or
a GLM-MAP warm start (both of which reset `COVbeta` to `diag(p)` and re-adapt).

> Branch: `seasonal-spline-phase3`. Cluster repo: `/hpc/group/schicklab/sne_dev`,
> fit outputs in `/work/rss10/sne_ns01/`. Spline ON ⇒ tag `LGCPSEspl`.

---

## The three edits

### 1. `src/config.R` — extend the chain

```r
niters_lgcp <- 250000    # was 100000; adds 150k iterations (~2 more days at 1d8h/100k)
```

### 2. `02_fitLGCPSE.R:120` — turn on the resume

The resume line is already in the file, commented out. Uncomment it:

```r
# before
# load(filename); start = which(outers == nrow(postSamples))

# after
load(filename); start = which(outers == nrow(postSamples))
```

Why this is safe/correct here:

- `filename` (set on line 15) already resolves to `cox01LGCPSEspl.RData` — the fit
  you just finished. No path edit needed.
- There is **no MCMC thinning** (`RcppFtns.cpp:552` writes one row per iteration),
  so `nrow(postSamples) == 100000`, and `which(outers == 100000)` picks the right
  restart chunk. The loop then runs chunks 102 → 250 and *appends* to the existing
  `postSamples` — continuing the **same** chain, no re-burn.
- `load(filename)` overwrites the cold-start `beta`/`Wm` from lines 71/87 with the
  saved end-state, so the chain restarts near the mode with its adapted covariance.

### 3. Back up, then resubmit

```bash
# cluster
cp /work/rss10/sne_ns01/fit/cox01/cox01LGCPSEspl.RData \
   /work/rss10/sne_ns01/fit/cox01/cox01LGCPSEspl.RData.100k.bak   # safety net
unset BUOY
sbatch --export=ALL,BUOY=cox01,EXPECTED_BRANCH=seasonal-spline-phase3 aci_fit.sh
```

The backup lets you inspect the 100k state later, and gives you a rollback if the
resume indexing ever misbehaves.

---

## After the resume completes

The re-run order matters — **fix the burn-in before re-reading the gate**, or you
will score the same non-stationary samples again:

```bash
# 1. recompute loglik over the now-longer chain, find where it plateaus
Rscript 03_loglikLGCPSE.R --buoy=cox01
Rscript 03_sumLoglik.R    --buoy=cox01     # inspect trace; note the plateau iteration
```

The first ~100k iterations are the cold-start climb — all non-stationary. Set the
burn to the new plateau (likely **≥150k**, not 50k):

```r
# src/config.R, in buoy_settings
cox01 = list(..., burn = 150000)           # or wherever 03_sumLoglik shows it flatten
```

Then recompute the RTC compensator (reads post-burn samples) and re-read the gate:

```bash
Rscript 04_rtctLGCPSE.R --buoy=cox01       # rewrites cox01LGCPSEspl_rtct.RData
Rscript 08_qqDispersion.R                  # no --buoy; picks up LGCPSEspl via config
```

**Pass = `var_drop` falls from ~21.9 toward ~1** (and `acf1_U`, `ks_D` drop too).

**If it still climbs** after another 150k with the adapted `COVbeta`, the issue is
Metropolis step-efficiency at p=16, not burn-in — consider a block reparameterization
*before* reaching for the Phase-4 P-spline fallback.

---

## Submitting safely from a login node (branch guard + preflight)

You want to `sbatch` from the login node and walk away, with a machine-checked
guarantee of *which branch ran*. `sbatch` is git-agnostic: the branch that matters
is whatever is checked out in `$SLURM_SUBMIT_DIR` **when the job starts** (the `.R`
scripts source `config.R` / compile `RcppFtns.cpp` at startup). So the guard lives
in the SLURM script itself.

Add this block to `aci_fit.sh` between `cd "$SLURM_SUBMIT_DIR"` and `srun`. It
**always logs** branch + commit + buoy + dirty-tree state into the job log, and
**asserts** the branch only when you opt in by passing `EXPECTED_BRANCH`:

```bash
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK}"
cd "$SLURM_SUBMIT_DIR"

# --- provenance + branch guard ---
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git rev-parse --short HEAD)
echo "=== provenance: buoy=${BUOY:-UNSET} branch=${BRANCH} commit=${COMMIT} dir=${PWD} ==="
git status --short
if [[ -n "${EXPECTED_BRANCH:-}" && "${BRANCH}" != "${EXPECTED_BRANCH}" ]]; then
  echo "ERROR: expected ${EXPECTED_BRANCH} but on ${BRANCH} -- aborting" >&2
  exit 1
fi
# --- end guard ---

srun Rscript 02_fitLGCPSE.R
```

Design notes: no branch name is hardcoded (so the same script is safe on `master` —
submit without `EXPECTED_BRANCH`); the abort is an explicit `exit 1`, so no
`set -euo pipefail` is needed (which can trip on `module`/`srun`). Keep it
**ASCII-only** — see the preflight below for why.

### Preflight — run BEFORE every `sbatch`

A smart/curly quote (`"` -> a curly variant) or a stray non-ASCII char pasted into
the script produces `unexpected EOF while looking for matching '"'` and the fit
never launches. Two checks catch it in seconds without touching the queue:

```bash
bash -n aci_fit.sh                     # syntax-check only; prints nothing if OK
grep -nP '[^\x00-\x7F]' aci_fit.sh     # flags any non-ASCII byte (curly quotes, em-dash, box-drawing)
```

Then submit through a guard so a broken script can't even reach the queue:

```bash
bash -n aci_fit.sh && \
sbatch --export=ALL,BUOY=cox01,EXPECTED_BRANCH=seasonal-spline-phase3 aci_fit.sh
```

A correct run stamps `branch=seasonal-spline-phase3` (not a garbled fragment) at
the top of `out/lgcp_fit_*.log`, with your uncommented resume line and `niters`
bump showing as `M` in the `git status --short` output — the intended record that
this was a scratch resume, not a clean-tree production fit.

---

## "Don't carry these edits to master" — what and why

All three edits above are **experiment-branch-only**. `master` is the production
line: `seasonal_spline = FALSE`, `niters_lgcp = 100000`, and the resume line
commented out. The whole Phase-1 isolation contract is that `master` stays pristine
and reproducible — a `git pull` on the cluster should only ever change *code*, never
silently change how a production fit runs. Here is why each edit must not land on
`master`:

**1. The uncommented resume line (`02_fitLGCPSE.R:120`) is the dangerous one.** It is
a *one-time* operation, not a permanent feature. If it ships uncommented, then **every
future fit** — including a fresh, from-scratch run — hits `load(filename)` on
startup:

- If a fit file already exists at that path, the "fresh" run silently **resumes a
  stale chain** instead of starting clean. You think you launched a new fit; you
  actually appended to an old one with whatever `beta`/`COVbeta`/window it was saved
  under. Results are quietly wrong and very hard to notice.
- If no fit file exists yet, `load(filename)` **errors out** ("cannot open the
  connection") and the job dies at line 120 before sampling.
- Either way it defeats the reproducibility guarantee: the same code no longer
  produces the same fit from the same inputs.

So this line must be **re-commented as soon as the resume run is submitted** — it is
scratch, not a merge candidate.

**2. `niters_lgcp = 250000`** is a per-fit tuning value for *this* hard COX01
posterior. On `master`, production runs are 100k; bumping the default to 250k would
silently 2.5× the walltime/cost of every buoy's fit, most of which don't need it.

**3. `seasonal_spline = TRUE`** is already the branch default (it switches the tag to
`LGCPSEspl` so spline outputs never collide with production `LGCPSE` files). On
`master` it stays `FALSE` so the design reproduces the 13-column production fit
bit-for-bit. This one you already know — it is listed in `config.R`'s own comment.

### Concrete git hygiene

- These edits live and stay on `seasonal-spline-phase3`. Do the resume run from
  this branch.
- Before any merge to `master`: **revert the resume line to commented**, and drop
  `niters_lgcp` back to `100000` (or gate it so only the spline path uses the larger
  budget). `seasonal_spline` should be `FALSE` on `master`.
- If you ever merge the spline *feature* to `master`, it goes in **OFF by default**
  with the resume line commented — the feature is the design knob, not this run's
  scratch settings.
- Sanity check before merging: `git diff master -- src/config.R 02_fitLGCPSE.R`
  should show the spline *machinery*, not `niters=250000` or a live `load(filename)`.
