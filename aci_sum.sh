#!/bin/bash
#SBATCH --partition=common
#SBATCH --cpus-per-task=1
#SBATCH --mem=192GB
#SBATCH --time=12:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rss10@duke.edu
#SBATCH --job-name=lgcp_sum
#SBATCH --output=out/lgcp_sum_%A_%x.log

# =============================================================================
# aci_sum.sh — Render all manuscript summaries/figures from EXISTING fits +
#              derived outputs (loglik/lam/num/rtct). NO re-fit, NO re-run of the
#              derived jobs — this only executes the 05_*/08 summary scripts.
#
# Submit from a login node:
#   sbatch aci_sum.sh                                   # if all rtcts are done
#   sbatch --dependency=afterok:49745856 aci_sum.sh     # gate on the ns02 rtct
#
# GOTCHAS:
#  * ns02 rtct (49745856) must be FINISHED — 05_sumRTCT/08/05c read it. A partial
#    file gives a corrupt read. Use the --dependency form above until it's done.
#  * COX01 spline flag: on `seasonal-spline-phase3`, config.R has cox01 = TRUE, so
#    cox01's 05_* summarize the SPLINE fit (LGCPSEspl outputs). For NON-spline
#    (production, cross-buoy-consistent) cox01 tables, set cox01 = FALSE first.
#  * Memory: 05_sumEstM4/05_sumXB load the full fits into RAM (cox01 spline = 24GB
#    on disk, more uncompressed). 192GB set to dodge OOM (cf. NS02/W-field OOM
#    history); bump if it still dies.
# =============================================================================

module purge
module load PROJ/6.3.2-rhel8
module load GDAL/3.2.1-rhel8
module load GEOS/3.9.1-rhel8
module load Boost/1.75-rhel8
module load R/4.1.1-rhel8

cd $SLURM_SUBMIT_DIR

# Per-buoy summaries (each takes --buoy). Override the list with e.g.
#   sbatch --export=ALL,BUOYS="cox01 ns01" aci_sum.sh
BUOYS="${BUOYS:-cox01 ns01 ns02}"

for b in $BUOYS; do
  echo "===== summaries: $b ====="
  Rscript 03_sumLoglik.R --buoy=$b   # burn-in traceplot   (reads loglik/)
  Rscript 05_sumDIC.R    --buoy=$b   # DIC                 (reads loglik/)
  Rscript 05_sumEstM4.R  --buoy=$b   # coefficient HPDs    (reads FIT)
  Rscript 05_sumXB.R     --buoy=$b   # background X*beta    (reads FIT)
  Rscript 05_sumLam.R    --buoy=$b   # lambda summaries    (reads lam/)
  Rscript 05_sumNum.R    --buoy=$b   # numeric summaries   (reads num/)
  Rscript 05_sumRTCT.R   --buoy=$b   # RTC compensator Q-Q (reads rtct/)
done

# All-buoy loops — run with NO --buoy (they set BUOY internally; a --buoy arg
# would pin every row to one buoy).
echo "===== all-buoy summaries ====="
Rscript 05_sumCombined.R
Rscript 05c_sumRTCTzoomAll.R
Rscript 08_qqDispersion.R
