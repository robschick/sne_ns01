# Runbook — parameter export for the talk figures (figs 4, 6, 7)

Exports what `14_volumeKnob.R`, `15_quietSeason.R` and `17_rateDrivers.R`
need from each buoy's fit. Spec: `docs/talk_figures_spec.md`.

## 0. Before you start

The scripts are on master (PR #20). The cluster gets them with a plain
`git pull` on master, with no branch switching while the 150k fits run.

## 1. Cluster: update code

```bash
cd /hpc/group/schicklab/sne_dev
```

```bash
git status --short
```

This must print nothing. If it doesn't, stop and snapshot to a `node-wip`
branch first.

```bash
git pull
```

```bash
ls -la /hpc/group/schicklab/sne_ns01/fit/ns01/ns01LGCPSE.100k.RData /hpc/group/schicklab/sne_ns01/fit/ns02/ns02LGCPSE.100k.RData
```

Both backups must exist. NS01/NS02 read these and never the live `/work`
files, because the running 150k jobs rewrite those every 1,000 iterations.

## 2. Cluster: submit (one job per buoy)

```bash
sbatch --mem=32G --export=ALL,BUOY=cox01 aci_param_export.sh
```

```bash
sbatch --mem=64G --export=ALL,BUOY=ns01,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns01/ns01LGCPSE.100k.RData aci_param_export.sh
```

```bash
sbatch --mem=96G --export=ALL,BUOY=ns02,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns02/ns02LGCPSE.100k.RData aci_param_export.sh
```

Each takes well under an hour; most of the time is loading the fit.

## 3. Cluster: check the logs

```bash
tail -n 15 out/param_export_*_param_export.log
```

For each buoy, check that:

- the last line reads `Wrote .../out/anim/<buoy>_params.rds (chain 100000 iterations, 2000 draws; ...)`;
- `Background total: here X, num/ Y` differs by no more than a few %;
- there's no `Killed` (out of memory: resubmit with more `--mem`) and no `Error`.

## 4. Laptop: pull the exports and draw

```bash
cd ~/Documents/_research/git_repos/sne_ns01
```

```bash
git checkout master && git pull
```

```bash
rsync -av "rss10@dcc-login.oit.duke.edu:/hpc/group/schicklab/sne_dev/out/anim/*_params.rds" out/anim/
```

```bash
Rscript 14_volumeKnob.R
```

```bash
Rscript 15_quietSeason.R
```

```bash
Rscript 17_rateDrivers.R
```

Figures land in `fig/talk/`:

- `volume_knob.png`
- `quiet_season_ns01.png`
- `quiet_season_all.png`
- `rate_drivers_{cox01,ns01,ns02}.png`

Each has a matching `.pdf`.

## If figure 6's "missing" total looks implausibly large

Re-run the export with the median as the quiet level (rerun step 2 with this
variable added, then steps 3–4):

```bash
sbatch --mem=64G --export=ALL,BUOY=ns01,PARAM_QUIET_Q=0.5,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns01/ns01LGCPSE.100k.RData aci_param_export.sh
```

Do the same for the other two buoys. The figure subtitle currently says
"quietest 10% of times", so it needs editing to match.

## After the 150k fits are final

Re-run step 2 without `PARAM_FIT_FILE`, adding `PARAM_BURN=<burn chosen from
the new trace>`, then step 4.
