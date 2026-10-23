#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH --time=0-03:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=param_export
#SBATCH --output=out/param_export_%A_%x.log

# =============================================================================
# aci_param_export.sh — Export the parameter talk-figure inputs from one buoy's
# LGCPSE fit (10b_paramExport.R). Writes out/anim/<buoy>_params.rds (a few MB);
# rsync it to the laptop and run 14_–17_ there.
#
# Usage (one job per buoy; while the 150k NS01/NS02 chains are running, point
# PARAM_FIT_FILE at the 100k backups, never at the live /work file):
#   sbatch --mem=32G  --export=ALL,BUOY=cox01 aci_param_export.sh
#   sbatch --mem=64G  --export=ALL,BUOY=ns01,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns01/ns01LGCPSE.100k.RData aci_param_export.sh
#   sbatch --mem=128G --export=ALL,BUOY=ns02,PARAM_FIT_FILE=/hpc/group/schicklab/sne_ns01/fit/ns02/ns02LGCPSE.100k.RData aci_param_export.sh
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

srun Rscript 10b_paramExport.R
