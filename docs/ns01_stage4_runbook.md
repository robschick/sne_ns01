# Runbook: NS01 stage 4 and summaries on the 150k fit (2026-10-27)

The NS01 chain was extended to 150k (job 59422333, finished 10-24). The −2 log L
trace is flat over 100k–150k, so the final burn is **100000** (keep the last
50k). That is set in `src/config.R` on master. NS02's fit is still running
(job 59422334); none of this touches it.

Order: update code → trim the loglik trace → back up the September outputs →
submit `lam`, `num`, `rtct` → summaries gated on all three → talk export.

Run everything from the cluster repo:

```bash
cd /hpc/group/schicklab/sne_dev
```

## 1. Update code

```bash
git status --short
```

This must print nothing. If it doesn't, stop and snapshot to a `node-wip`
branch first.

```bash
git pull
```

```bash
grep -n "burn = 100000" src/config.R
```

One line, in the ns01 block. NS02's running fit already read config.R on
10-23, so the pull doesn't affect it.

## 2. Make the loglik trace cover only 100k–150k

The loglik pass on 10-25 ran with burn 50000 (the temporary edit didn't take),
so the file holds 100,000 values: iterations 50k–150k. `05_sumDIC.R` averages
every value in the file regardless of burn, so it has to be trimmed to the
last 50,000. Check the length first:

```bash
Rscript -e 'load("loglik/ns01/ns01LGCPSE_loglik.RData"); length(postLogLik)'
```

If it prints `100000`, keep a copy, then trim:

```bash
cp loglik/ns01/ns01LGCPSE_loglik.RData loglik/ns01/ns01LGCPSE_loglik.50-150k.RData
```

```bash
Rscript -e 'f <- "loglik/ns01/ns01LGCPSE_loglik.RData"; load(f); postLogLik <- tail(postLogLik, 50000); save(postLogLik, file = f); length(postLogLik)'
```

It should print `50000`. (If the first check printed `50000`, skip the trim.)

## 3. Back up the September (100k) outputs

The new jobs overwrite these files. Keep them with a `.100k` suffix:

```bash
cp lam/ns01/LGCPSE_lam.RData lam/ns01/LGCPSE_lam.100k.RData
```

```bash
cp num/ns01/ns01LGCPSEnum.RData num/ns01/ns01LGCPSEnum.100k.RData
```

```bash
cp rtct/ns01/ns01LGCPSE_rtct.RData rtct/ns01/ns01LGCPSE_rtct.100k.RData
```

```bash
cp -r fig/ns01 fig/ns01.100k
```

```bash
ls -la lam/ns01/ num/ns01/ rtct/ns01/
```

## 4. Submit the three stage-4 jobs

They're independent, so all three can run at once. Note each job ID.

```bash
sbatch --export=ALL,BUOY=ns01 aci_lam.sh
```

```bash
sbatch --export=ALL,BUOY=ns01 aci_num.sh
```

```bash
sbatch --export=ALL,BUOY=ns01 aci_rtct.sh
```

`rtct` is the long one: several days for NS01's 13k calls (NS02's 33.6k took
13.6 days). If it dies partway, resume with
`sbatch --export=ALL,BUOY=ns01,RTCT_RESUME=true aci_rtct.sh`.

## 5. Queue the summaries behind all three

Put the three job IDs from step 4 in place of `LAM:NUM:RTCT`. `ALL_BUOY=false`
skips the cross-buoy figures (`05_sumCombined.R`, `05c`, `08`) so they don't
mix the new NS01 with the old NS02; those run once NS02 is done too.

```bash
sbatch --dependency=afterok:LAM:NUM:RTCT --export=ALL,BUOYS=ns01,ALL_BUOY=false aci_sum.sh
```

`squeue -u rss10` shows it as `PENDING (Dependency)` until all three finish.
If any of them fails, the summary job never starts; cancel it with
`scancel <jobid>`, fix, and resubmit.

## 6. Talk parameter export (can run now)

The fit file is final, so this needn't wait for stage 4. It reads burn 100000
from config.R:

```bash
sbatch --mem=64G --export=ALL,BUOY=ns01 aci_param_export.sh
```

Then, from the laptop:

```bash
rsync -av "rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/out/anim/ns01_params.rds" out/anim/
```

and rebuild scripts 14–17 and `13_branchShare.R` (see
`docs/param_export_runbook.md` step 4).

## 7. When the summary job is COMPLETED

```bash
tail -n 30 out/lgcp_sum_<jobid>_lgcp_sum.log
```

Copy `fig/ns01/` to the laptop into a suffixed folder (e.g. `fig/ns01.150k/`)
so nothing from the September fit is overwritten by accident. Claude will
compare the new Table 3 numbers (α, η, answers per call, δ) with the 100k ones
before anything goes to Overleaf.
