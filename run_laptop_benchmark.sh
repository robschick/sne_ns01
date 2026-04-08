#!/bin/bash
# Run Phase 1 timing for all 8 combos with 1-month subset

for combo in 1 2 3 4 5 6 7 8; do
  echo "========================================="
  echo "Running combo ${combo}..."
  echo "========================================="
  Rscript src/benchmark_fit.R --combo=${combo} --months=1
  echo ""
done

echo "All combos complete. Generating summary..."
Rscript src/benchmark_laptop_summary.R
