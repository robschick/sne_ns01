#!/bin/bash
#SBATCH --partition=common
#SBATCH --array=1-8
#SBATCH --cpus-per-task=1
#SBATCH --mem=128GB
#SBATCH --time=5-00:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=bench_gp
#SBATCH --output=out/bench_%A-%a.log

# =============================================================================
# aci_benchmark.sh — SLURM array job for GP resolution benchmarking
#
# Submits 8 jobs (one per rho/sback combo).
#
# Usage:
#   Phase 1 only (timing):   sbatch aci_benchmark.sh
#   Phase 2 (full chain):    sbatch aci_benchmark.sh --full
#
# Combo mapping (from benchmark_config.R):
#   1: rho=60, sback=30    5: rho=30, sback=15
#   2: rho=60, sback=60    6: rho=30, sback=30
#   3: rho=60, sback=120   7: rho=30, sback=60
#   4: rho=60, sback=180   8: rho=30, sback=90
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

# Pass --full through if provided as script argument
EXTRA_ARGS="${@}"

srun Rscript src/benchmark_fit.R --combo=${SLURM_ARRAY_TASK_ID} ${EXTRA_ARGS}
