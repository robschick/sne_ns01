#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=1
#SBATCH --mem=128GB
#SBATCH --time=14-00:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=lgcp_rtct
#SBATCH --output=out/lgcp_rtct_%A_%x.log

# =============================================================================
# aci_rtct.sh — Random time change theorem compensator for one buoy
# (04_rtctLGCPSE.R). Requires the fit from aci_fit.sh.
#
# Usage (one job per buoy):
#   sbatch --export=ALL,BUOY=ns01  aci_rtct.sh
#   sbatch --export=ALL,BUOY=ns02  aci_rtct.sh
#   sbatch --export=ALL,BUOY=cox01 aci_rtct.sh
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

srun Rscript 04_rtctLGCPSE.R
