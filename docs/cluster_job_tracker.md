# Cluster job tracker: what's running, what's done, what's next (2026-10-24)

Jobs submitted 2026-10-23:

| Job | Script | Expected run time | Status as of 10-24 |
|---|---|---|---|
| NS01 fit, 100k → 150k | `aci_fit.sh` (`lgcp_fit`) | ~2 days | running |
| NS02 fit, 100k → 150k | `aci_fit.sh` (`lgcp_fit`) | ~7 days | running |
| Parameter export, ×3 buoys | `aci_param_export.sh` (`param_export`) | minutes | done; figs 4/6/2/7 built from them |

Every script has `--mail-type=ALL`, so you also get an email at rss10@duke.edu
when each job ends or fails.

Run everything from the cluster repo:

```bash
cd /hpc/group/schicklab/sne_dev
```

## 1. What's running right now

```bash
squeue -u rss10 -o "%.10i %.14j %.8T %.12M %.12l %R"
```

Columns: job ID, name, state, time used, time limit, node or reason waiting.

## 2. Everything submitted in the last 3 days, finished or not

```bash
sacct -u rss10 -S now-3days -X -o JobID,JobName%16,State,Elapsed,MaxRSS,End
```

`State` is the answer: `COMPLETED` = done; `RUNNING`/`PENDING` = not yet;
`FAILED`, `OUT_OF_MEMORY`, `TIMEOUT`, `CANCELLED` = needs attention (send the log
to Claude). For memory use of a finished job, drop `-X` so the step rows show
`MaxRSS`.

## 3. How far along each fit is

The log names are `out/lgcp_fit_<jobid>_lgcp_fit.log`. Use the job IDs from
step 1:

```bash
tail -n 5 out/lgcp_fit_<NS01 jobid>_lgcp_fit.log
```

```bash
tail -n 5 out/lgcp_fit_<NS02 jobid>_lgcp_fit.log
```

The fit saves every 1,000 iterations, so the file's timestamp shows it is
still moving:

```bash
ls -la --time-style=long-iso /work/rss10/sne_ns01/fit/ns01/ /work/rss10/sne_ns01/fit/ns02/
```

## 4. When a fit finishes: check the new 50k before anything else

Don't chain stage 4 yet. First see whether the chain has flattened.

Do this per buoy as each finishes (NS01 first, ~Oct 25; NS02 ~Oct 30).
Shown for NS01; swap `ns01` → `ns02` later.

a. Confirm it ran to 150k and archived to /hpc:

```bash
tail -n 20 out/lgcp_fit_<NS01 jobid>_lgcp_fit.log
```

```bash
ls -la --time-style=long-iso /hpc/group/schicklab/sne_ns01/fit/ns01/
```

b. Keep the old 50k–100k loglik trace (the new run overwrites it):

```bash
cp loglik/ns01/ns01LGCPSE_loglik.RData loglik/ns01/ns01LGCPSE_loglik.50-100k.RData
```

c. Temporarily set `burn = 100000` in the **ns01** block of `src/config.R`
(line ~43) so the loglik pass only covers the new 100k–150k:

```bash
nano src/config.R
```

d. Submit the loglik pass:

```bash
sbatch --export=ALL,BUOY=ns01 aci_ll.sh
```

e. Once its log shows it has started (R has read config.R by then), revert
the edit so the repo is clean:

```bash
git checkout src/config.R
```

```bash
git status --short
```

f. When the loglik job is `COMPLETED`, copy both trace files to the laptop:

```bash
ls -la loglik/ns01/
```

Claude will plot 50k–100k and 100k–150k together and decide:

- **Flat:** set the final `burn` for that buoy in `src/config.R` (a PR from the
  laptop), then re-run stage 4: `aci_lam.sh`, `aci_num.sh`, `aci_rtct.sh` (NS02
  rtct took 13.6 days; resumable with `RTCT_RESUME=true`), then `aci_sum.sh`.
- **Still trending:** extend again with `FIT_NITERS=200000`, as in
  `docs/ns01_ns02_resume_runbook.md` step 3 (back up the 150k chain first).

## 5. After stage 4 (both buoys)

1. Pull `fig/`, `num/`, `lam/`, `rtct/` for NS01/NS02 to the laptop (into
   suffixed files, e.g. `*.150k.RData`, so no window overwrites another).
2. Re-run the talk parameter export without `PARAM_FIT_FILE` (so it reads the
   150k fits) and rebuild scripts 14–17 and `13_branchShare.R`.
3. Update Overleaf: Table 3, the coefficient table, Figs 3, 4, 6 (and the Fig 6
   daily-harmonic text), Fig 1 caption.
