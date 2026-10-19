#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH --time=0-02:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=anim_export
#SBATCH --output=out/anim_export_%A_%x.log

# =============================================================================
# aci_anim_export.sh — Export the talk-animation inputs from one buoy's LGCPSE
# fit (10a_animExport.R): parameters, background on a 5-min grid, per-call
# branching. Writes out/anim/<buoy>_anim.rds (~1-2 MB); rsync it to the laptop
# and run 10_hawkesAnim.R there. NS01 peaked at ~20 GB; NS02 is larger.
#
# Usage (one job per buoy):
#   sbatch --export=ALL,BUOY=ns02  aci_anim_export.sh
#   sbatch --export=ALL,BUOY=cox01 aci_anim_export.sh
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

srun Rscript 10a_animExport.R
