#!/bin/bash
#SBATCH --partition=common
#SBATCH --array=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128G
#SBATCH --time=21-00:00:00 
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=sslN
#SBATCH --output=out/array_%A-%a_sslN.log

cd $SLURM_SUBMIT_DIR

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load R/4.1.1-rhel8
Rscript sumEstM4_harmonics_rho.R
