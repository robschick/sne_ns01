#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=20
#SBATCH --mem=128GB
#SBATCH --time=28-00:00:00
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
cd "$SLURM_SUBMIT_DIR"

# --- Provenance + branch guard ----------------------------------------------
# Fits run for weeks, so record exactly what code produced them. The optional
# EXPECTED_BRANCH check aborts before burning walltime on the wrong branch:
#   sbatch --export=ALL,BUOY=cox01,EXPECTED_BRANCH=seasonal-spline-phase3 aci_fit.sh
#
# Use straight quotes only in the executable lines below. A pasted curly quote
# once broke this file with "unexpected EOF while looking for matching quote" --
# bash ignores comments, so em-dashes in prose are fine; smart quotes in code
# are not. Preflight before submitting:
#   bash -n aci_fit.sh && grep -nP "[\x{2018}\x{2019}\x{201C}\x{201D}]" aci_fit.sh
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git rev-parse --short HEAD)
echo "=== provenance: buoy=${BUOY:-UNSET} branch=${BRANCH} commit=${COMMIT} dir=${PWD} ==="
git status --short
if [[ -n "${EXPECTED_BRANCH:-}" && "${BRANCH}" != "${EXPECTED_BRANCH}" ]]; then
  echo "ERROR: expected ${EXPECTED_BRANCH} but on ${BRANCH} -- aborting" >&2
  exit 1
fi

# --- Data-window guard --------------------------------------------------------
# 02_fitLGCPSE.R uses data/${BUOY}.RData as-is; config.R's analysis_end only
# bites when 01_data.R is re-run. Print the data file's provenance and abort if
# it extends past the configured window (i.e. 01_data.R was skipped). This
# would have caught the Aug-2026 NS01/NS02 re-fits that ran on 7-month data.
Rscript src/check_data_window.R --buoy="${BUOY}" || {
  echo "ERROR: data window check failed for ${BUOY:-UNSET} -- aborting" >&2
  exit 1
}

srun Rscript 02_fitLGCPSE.R
