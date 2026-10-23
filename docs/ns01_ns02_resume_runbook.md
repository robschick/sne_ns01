# Runbook — extend the NS01 and NS02 chains by 50k (100k → 150k)

**Why (2026-10-23).** The Sep-08 5-month refits have not converged: −2 log L
falls across the whole retained 50k–100k for both buoys (~900 for NS01, ~1,000
for NS02). At NS01, α is stable but η drifts (0.310 → 0.353 → 0.382 over 25k
blocks), so answers per call (α/η) goes 0.70 → 0.64 → 0.58 and δ and the GP
level rise with it. COX01 (Aug clean refit) is flat and needs nothing.

**How.** `02_fitLGCPSE.R` resumes when `FIT_RESUME=true`: it reloads the saved
chain with its end-state (β, W, adapted proposal covariances, σ²) and appends,
so the chain continues rather than restarting. `FIT_NITERS` sets the new total
length for that run only. Without `FIT_RESUME` the script is unchanged.

**Memory.** In RAM the saved chain is ~19 GB for NS01 and ~36 GB for NS02 at
100k (`postBranching` is iterations × calls, `postWm` is iterations × knots).
Each 1,000-iteration append briefly holds two copies, so NS02 would peak near
110 GB at 150k: request **192 GB for NS02**. 128 GB is fine for NS01.

## 1. Cluster: update code

```bash
cd /hpc/group/schicklab/sne_dev
git status --short     # must be clean; if not, snapshot to a node-wip branch first
git checkout master
git pull
bash -n aci_fit.sh
```

## 2. Cluster: back up the 100k chains

The fit overwrites its file every 1,000 iterations, the archive step at the end
overwrites the /hpc copy, and /work is wiped after 75 days. Keep the backups on
/hpc:

```bash
for b in ns01 ns02; do
  cp /work/rss10/sne_ns01/fit/$b/${b}LGCPSE.RData /hpc/group/schicklab/sne_ns01/fit/$b/${b}LGCPSE.100k.RData
done
ls -la /hpc/group/schicklab/sne_ns01/fit/ns01/ /hpc/group/schicklab/sne_ns01/fit/ns02/
```

## 3. Cluster: submit

```bash
sbatch --mem=128G --export=ALL,BUOY=ns01,FIT_RESUME=true,FIT_NITERS=150000,EXPECTED_BRANCH=master aci_fit.sh
sbatch --mem=192G --export=ALL,BUOY=ns02,FIT_RESUME=true,FIT_NITERS=150000,EXPECTED_BRANCH=master aci_fit.sh
```

`--mem` on the command line overrides the script's `#SBATCH --mem=128GB`.

## 4. Check it resumed (first ~hour)

```bash
grep -h "provenance\|data window\|resuming" out/lgcp_fit_*_lgcp_fit.log | tail -6
```

Each job's log must show `=== resuming ...: 100000 -> 150000 iterations ===`.
If it shows an error instead, nothing was overwritten (the check runs before the
first save). Expected run time from September: **~2 days NS01, ~7 days NS02**.

## 5. After the fits finish

Don't chain these until the trace is checked.

1. **Loglik on the new 50k only.** Temporarily set `burn = 100000` for the buoy
   in `src/config.R` and run `03_loglikLGCPSE.R` (a full 50k–150k pass would
   roughly double NS02's 4.7-day run). Compare with the existing 50k–100k trace
   (`loglik/<buoy>/<buoy>LGCPSE_loglik.RData`, keep a copy first).
2. **Flat?** Set the final burn per buoy in `src/config.R` from the trace. Still
   trending: extend again (`FIT_NITERS=200000`) before anything else.
3. **Re-run stage 4** with that burn: `lam`, `num`, `rtct` (NS02 rtct took 13.6
   days; it is resumable with `RTCT_RESUME=true`). Then `sbatch aci_sum.sh`, pull
   `fig/` to the laptop, and update Overleaf (Table 3, coefficient table, Figs 3,
   4, 6; Fig 6 text on the daily harmonic; Fig 1 caption).
