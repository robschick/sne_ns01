#!/bin/bash
#SBATCH --partition=common
#SBATCH --array=1-8
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH --time=2:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=bench_ll
#SBATCH --output=out/bench_ll_%A-%a.log

# =============================================================================
# aci_loglik.sh — SLURM array job for post-hoc LL replay across benchmark combos
#
# One task per combo (--combo=${SLURM_ARRAY_TASK_ID}). Each task replays its
# combo's saved postSamples + postWm through compLogLiki and writes
# fit/<buoy>/benchmark/<label>/phase2_loglik.RData (resumable; skips if
# already complete).
#
# Usage:
#   sbatch aci_loglik.sh --buoy=ns01            # combos 1-8
#   sbatch --array=9 aci_loglik.sh --buoy=ns01  # just combo 9 once it exists
#
# After the array completes, run the aggregation step (sequential, no array)
# to produce the cross-combo figures and CSV:
#   sbatch --dependency=afterok:<JOBID> aci_loglik_agg.sh --buoy=ns01
# OR run locally after rsyncing the per-combo phase2_loglik.RData files back:
#   Rscript src/benchmark_loglik.R --buoy=ns01
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

EXTRA_ARGS="${@}"

srun Rscript src/benchmark_loglik.R --combo=${SLURM_ARRAY_TASK_ID} ${EXTRA_ARGS}
