#!/bin/bash
# Run Phase 1 timing for all 8 combos with 1-month subset
#
# Usage:
#   bash run_laptop_benchmark.sh              # defaults to ns01
#   bash run_laptop_benchmark.sh --buoy=ns02

# Default to --months=1 unless caller already passed --months=N
EXTRA_ARGS="${@}"
if [[ ! "${EXTRA_ARGS}" =~ --months ]]; then
  MONTHS_FLAG="--months=1"
else
  MONTHS_FLAG=""
fi

for combo in 1 2 3 4 5 6 7 8; do
  echo "========================================="
  echo "Running combo ${combo}..."
  echo "========================================="
  Rscript src/benchmark_fit.R --combo=${combo} ${MONTHS_FLAG} ${EXTRA_ARGS}
  echo ""
done

echo "All combos complete. Generating summary..."
Rscript src/benchmark_laptop_summary.R ${EXTRA_ARGS}
