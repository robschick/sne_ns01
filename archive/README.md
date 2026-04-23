# Archived scripts

Retired during the LGCPSE pipeline refactor (2026-04). See
`plans/lgcpse-refactor.md` for context.

## NHPPSE pipeline

A legitimate parallel investigation that did not fit the upcall data as well
as LGCPSE. Kept for provenance; not part of the current workflow.

- `fitNHPPSE_parallel.R`, `loglikNHPPSE.R`, `rtctNHPPSE.R`, `numNHPPSE.R`
- `src/RcppFtns_parallel.cpp` — C++ kernels used only by the parallel NHPPSE fit

## Sweep-era `sum*` duplicates

When the model was being developed we swept over `(n_cycles, GP effective range)`
combinations and compared four model variants (NHPP / LGCP / NHPPSE / LGCPSE).
The `_harmonics_rho` variants in the repo root superseded these plain-name
versions; the sweep and multi-model comparison are no longer the focus.

- `sumRTCT.R`, `sumEst.R`, `sumEstM4.R`, `sumXB.R`, `sumDIC.R`

## Unrelated / legacy

- `sumData.R` — 2009 Cape Cod manuscript figure (study-region map + NOPP noise
  and call descriptives). Does not ingest cluster output from the SNE buoy
  pipeline. If an analogous descriptive figure for NS01 / NS02 / COX01 is
  wanted, that is a new figure, not a port.
- `sumPlot.R` — NHPPSE/`nopp2/`-era exploratory plotting.
- `check.R` — scratch.
- `src/test.cpp` — unused test kernel.
