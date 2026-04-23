#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=20
#SBATCH --mem=128GB
#SBATCH --time=21-00:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=lgcp_fit
#SBATCH --output=out/lgcp_fit_%A_%x.log

# =============================================================================
# aci_fit.sh — MCMC fit of LGCPSE model for one buoy.
#
# Usage (one job per buoy):
#   sbatch --export=ALL,BUOY=ns01  aci_fit.sh
#   sbatch --export=ALL,BUOY=ns02  aci_fit.sh
#   sbatch --export=ALL,BUOY=cox01 aci_fit.sh
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK}"
cd $SLURM_SUBMIT_DIR

srun Rscript 02_fitLGCPSE.R
