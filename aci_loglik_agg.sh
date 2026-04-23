#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH --time=1:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=bench_ll_agg
#SBATCH --output=out/bench_ll_agg_%j.log

# =============================================================================
# aci_loglik_agg.sh — Aggregate cross-combo LL outputs
#
# Run AFTER aci_loglik.sh has populated all per-combo phase2_loglik.RData
# files. Reads them, computes ESS/Geweke per combo, and writes:
#   fig/<buoy>/benchmark/loglik_traces.RData
#   fig/<buoy>/benchmark/loglik_traces.pdf
#   fig/<buoy>/benchmark/loglik_diagnostics.csv
#
# Usage (chained on the array job):
#   sbatch --dependency=afterok:<JOBID> aci_loglik_agg.sh --buoy=ns01
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

EXTRA_ARGS="${@}"

srun Rscript src/benchmark_loglik.R ${EXTRA_ARGS}
