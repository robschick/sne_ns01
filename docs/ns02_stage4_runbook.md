# Runbook: NS02 stage 4 on the 150k fit, then the 200k extension (2026-11-03)

The NS02 chain was extended to 150k (job 59422334, finished 10-29). The final
burn is **100000** (keep the last 50k), set in `src/config.R` on master. The
drift check (`03_driftCheck.R`, PR #30) showed α, noise and SST flat over
100k–150k, while answers per call is still easing (0.564 → 0.547, about one
posterior SD). So: stage 4 on 100k–150k now for the talk and paper (part A),
then extend to 200k in case a reviewer asks (part B).

**Part B must wait until part A is completely done.** The extension rewrites
the fit file every 1,000 iterations, and every stage-4 job and summary reads
that file.

Run everything from the cluster repo, on a **login node** unless a step says
otherwise:

```bash
cd /hpc/group/schicklab/sne_dev
```

---

# Part A: stage 4 and summaries on 100k–150k

## A1. Update code

```bash
git status --short
```

This must print nothing.

```bash
git pull
```

```bash
grep -n "burn = 100000" src/config.R
```

Two lines now: one in the ns01 block, one in the ns02 block.

## A2. Check the loglik trace covers only 100k–150k

The 10-29 loglik job ran with the temporary burn 100000, so the file should
already hold 50,000 values:

```bash
Rscript -e 'load("loglik/ns02/ns02LGCPSE_loglik.RData"); length(postLogLik)'
```

It should print `50000`. If it prints `100000`, stop and ask Claude.

## A3. Keep a copy of the 150k fit on /hpc

`/work` is scratch, and part B overwrites this file. First find it:

```bash
ls -la /work/rss10/sne_ns01/fit/ns02/
```

```bash
cp /work/rss10/sne_ns01/fit/ns02/ns02LGCPSE.RData /hpc/group/schicklab/sne_ns01/fit/ns02/ns02LGCPSE.150k.RData
```

```bash
ls -la /hpc/group/schicklab/sne_ns01/fit/ns02/
```

The `.150k` copy should be the same size as the `/work` file.

## A4. Back up the September (100k) outputs

The new jobs overwrite these. Check the file names first:

```bash
ls lam/ns02/ num/ns02/ rtct/ns02/
```

Then, adjusting names if they differ from the listing:

```bash
cp lam/ns02/LGCPSE_lam.RData lam/ns02/LGCPSE_lam.100k.RData
```

```bash
cp num/ns02/ns02LGCPSEnum.RData num/ns02/ns02LGCPSEnum.100k.RData
```

```bash
cp rtct/ns02/ns02LGCPSE_rtct.RData rtct/ns02/ns02LGCPSE_rtct.100k.RData
```

```bash
cp -r fig/ns02 fig/ns02.100k
```

## A5. Submit the three stage-4 jobs

They're independent, so all three can run at once. Note each job ID.

```bash
sbatch --export=ALL,BUOY=ns02 aci_lam.sh
```

```bash
sbatch --export=ALL,BUOY=ns02 aci_num.sh
```

```bash
sbatch --export=ALL,BUOY=ns02 aci_rtct.sh
```

`rtct` is the long one. In September NS02's rtct took 13.6 days against a
14-day limit. If it hits the limit or dies, resume it:

```bash
sbatch --export=ALL,BUOY=ns02,RTCT_RESUME=true aci_rtct.sh
```

## A6. Talk parameter export (can run now)

The 150k fit is final for part A, so this needn't wait for stage 4:

```bash
sbatch --mem=128G --export=ALL,BUOY=ns02 aci_param_export.sh
```

When it finishes, from the laptop:

```bash
rsync -av "rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/out/anim/ns02_params.rds" out/anim/
```

Claude then rebuilds `18_paramTable.R`, `13_branchShare.R` and scripts 14–17.

## A7. Queue the summaries behind all three

All three buoys are now on their final fits, so this run **includes** the
cross-buoy tables and figures (`05_sumCombined.R`, `05c`, `08`): the
consistent Table 3 for the paper. Put the three job IDs from A5 in place of
`LAM:NUM:RTCT`:

```bash
sbatch --dependency=afterok:LAM:NUM:RTCT --export=ALL,BUOYS=ns02 aci_sum.sh
```

`aci_sum.sh` now stops at the first failing script (PR #29), so a `FAILED`
state means a real failure. If an rtct resume was needed, use the resumed job's
ID in place of the first rtct ID.

## A8. When the summary job is COMPLETED

```bash
tail -n 30 out/lgcp_sum_<jobid>_lgcp_sum.log
```

From the laptop, pull into suffixed folders so nothing older is overwritten:

```bash
rsync -av "rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/fig/ns02/" fig/ns02.150k/
```

```bash
rsync -av "rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/fig/combined/" fig/combined.final/
```

Claude compares Table 3 against the 100k numbers before anything goes to
Overleaf.

---

# Part B: extend NS02 to 200k (after part A)

Start only when `squeue -u rss10` shows none of the part-A jobs.

## B1. Check memory headroom

The 150k run's peak memory:

```bash
sacct -j 59422334 -o JobID,State,Elapsed,MaxRSS
```

If MaxRSS is above about 140 GB, use `--mem=256G` in B2 instead of 192G.

## B2. Resume to 200k

The chain resumes from the saved 150k state (the `.150k` copy from A3 is the
fallback):

```bash
sbatch --mem=192G --export=ALL,BUOY=ns02,FIT_RESUME=true,FIT_NITERS=200000,EXPECTED_BRANCH=master aci_fit.sh
```

Check the first lines of its log for
`=== resuming ...: 150000 -> 200000 iterations ===`:

```bash
grep -h "resuming" out/lgcp_fit_<jobid>_lgcp_fit.log
```

Expect about 7 days. After it finishes: loglik over 150k–200k, then
`03_driftCheck.R --buoy=ns02` with `DRIFT_FROM=100000`. Only if a reviewer
asks does the 200k chain go through stage 4.
