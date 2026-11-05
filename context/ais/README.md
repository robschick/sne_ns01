# AIS vessel-traffic context

Side analysis for the NARWC talk: how much AIS-tracked vessel traffic passes
within 10 km of each hydrophone, in the analysis winter (Oct 2021 – Feb 2022)
and the prior winter. Not part of the Hawkes model pipeline. Leave this folder
out of a model-only release.

Spec and build plan: `docs/ais_context_spec.md`.

## Run

From the repo root, with `GFW_TOKEN` set in `~/.Renviron`:

```sh
Rscript context/ais/01_download.R   # GFW requests -> cache/
Rscript context/ais/02_table.R      # slide tables -> fig/context/ais/buoy_table{,_simple}.{rds,html,png}
Rscript context/ais/03_weekly.R     # weekly panel -> fig/context/ais/weekly_panel.{png,pdf}
Rscript context/ais/04_map.R        # transit maps -> fig/context/ais/ais_map{,_diff}.{png,pdf}
```

`buoy_table.{csv,parquet}` here are the committed numbers behind the slide table.

Responses are cached in `cache/` (gitignored). Reruns only fetch what's missing.
The map's first run downloads ~3 GB (the 2020–2022 monthly databases) into
`cache/ned/` and unzips them (~9 GB); the summed winters are cached there as
`winter_<season>.tif`.

Summaries live in `R/summary.R` (`buoy_table()`: per-buoy mean vessel-hours
and vessels per day by group, both winters, and their ratio; `weekly_series()`:
total vessel-hours per day by week-of-season, with a 3-week rolling mean).
Tests:

```sh
Rscript -e 'testthat::test_dir("context/ais/tests")'
```

## Data sources and attribution

- **Global Fishing Watch**, AIS vessel presence (`public-global-presence`,
  v5.0), via the 4Wings API. Licence CC BY-NC 4.0. Slide and paper credit:
  "Vessel presence: Global Fishing Watch (globalfishingwatch.org)."
- **Northeast Ocean Data**, monthly AIS vessel transit counts (all vessels,
  100 m), 2020–2022, derived from MarineCadastre / USCG AIS tracks. Map units
  are transits (tracks crossing a cell), not vessel-hours. Credit: "Northeast
  Regional Ocean Council (NROC). Northeast Ocean Data Portal,
  www.northeastoceandata.org." Not for navigation.
