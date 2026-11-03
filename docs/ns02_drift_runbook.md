# Runbook: is NS02's 100k–150k chain drifting in what we report? (2026-11-03)

The NS02 log-likelihood over 100k–150k (job 60538834) is still climbing: about
+300 log L units, with steps near 137k and 148k. It's slower than over 50k–100k,
but not flat. Before spending ~2.5 weeks on another extension, check whether the
reported quantities (α, η, answers per call, noise, SST) are still moving.
`03_driftCheck.R` prints their means in 10k blocks straight from the fit file.

**Decision rule:**
- α, η, answers per call, noise and SST flat across the blocks (changes within
  about one posterior SD) → keep 100k–150k, burn 100000.
- η or answers per call trending the way NS01's did over 50k–100k
  (0.70 → 0.64 → 0.58) → extend NS02.

## 1. Update code (login node)

```bash
cd /hpc/group/schicklab/sne_dev
```

Check for leftover local edits first. The NS02 log-likelihood job was
submitted with a temporary `burn = 100000` edit to `src/config.R`, which was
meant to be reverted once the job logged its first line:

```bash
git status --short
```

If `src/config.R` shows as modified, revert it:

```bash
git checkout -- src/config.R
```

```bash
git pull
```

## 2. Start an interactive session with enough memory

At 150k the NS02 fit needs more than 64 GB in RAM.

```bash
srun --mem=128G --time=2:00:00 --pty bash
```

```bash
cd /hpc/group/schicklab/sne_dev
```

## 3. Run the drift check (compute node)

Blocks from 50k, so the table shows both the September and the new 50k:

```bash
module load R/4.1.1-rhel8
```

```bash
Rscript 03_driftCheck.R --buoy=ns02
```

The first lines should say `Seasonal spline for ns02: FALSE`. The table ends
with ten rows, `50k-60k` through `140k-150k`. Paste the table to Claude. It's
also saved to `out/drift_ns02.csv`.

## 4. Leave the session

```bash
exit
```

Do this before any `sbatch`: jobs submitted from inside the interactive
session die with "Unable to satisfy cpu bind request".
