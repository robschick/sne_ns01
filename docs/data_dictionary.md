# Data dictionary: SNE right whale upcall release

Shareable, language-neutral version of the raw detection data behind the
LGCPSE analysis of three Southern New England (Nantucket Shoals) buoys:
**NS01**, **NS02**, **COX01**. Built by `00_wrangle_calls.R`; written to
`data/release/` as three Parquet files. Regenerate with:

```sh
Rscript 00_wrangle_calls.R
```

The script checks that the result is identical to the legacy RDS inputs
(`data/*_all.rds`) when those are present, so the Parquet files reproduce
every number in the paper's pipeline.

## Provenance

- **Source.** Manual detections of North Atlantic right whale (NARW) calls
  from NOAA NEFSC Low-Frequency Detection and Classification System (LFDCS)
  logs ("narwlog" CSVs). Originator: Molly Martin; analysts named in each
  file header. Delivered 2025-05-05 by Gen Davis and Hanna Kolipali (NEFSC).
- **Re-export.** The COX01 Feb 2022 log
  (`NEFSC_MA-RI_202202_COX01_narwlog_ST.csv`) was re-exported at full
  precision and received 2026-08-19. The original copy had been re-saved in
  Excel, collapsing timestamps to 3 significant figures
  (see `docs/cox01_timestamp_provenance.md`). Only the clean re-export is
  used here.
- **Recorders.** SoundTrap, continuous recording, 48 kHz (early deployments)
  or 64 kHz (from Oct/Nov 2021). Twelve deployments, four per site, spanning
  Feb 2021 to May 2022. Positions and depths come from the NEFSC deployment
  metadata sheet.
- **Filter.** Only rows with `species == 7` (NARW) and `call_type == 1`
  (upcall) are released. The raw logs also contain "No call" placeholder
  rows (`species == 999`) and a handful of other NARW call types; these are
  excluded. No other rows are dropped, deduplicated, or edited.

## Files

| File | Rows | One row per |
|---|---:|---|
| `upcalls.parquet` | 78,364 | NARW upcall detection (NS01 29,663; NS02 38,324; COX01 10,377) |
| `deployments.parquet` | 12 | instrument deployment |
| `sites.parquet` | 3 | site |

All timestamps are Parquet `timestamp[us, tz=UTC]`. See the timezone note
below before treating them as true UTC.

## `upcalls.parquet`

| Column | Type | Description |
|---|---|---|
| `site` | string | `NS01`, `NS02`, or `COX01`. |
| `deployment_id` | string | NEFSC project id, e.g. `NEFSC_MA-RI_202110_NS01`. Joins to `deployments`. |
| `source_file` | string | Delivered CSV the row came from. |
| `time_base_utc` | timestamp | The origin the source file measured seconds from (declared in its header as `start_time.start_date`). One of 2006-01-01, 2021-01-01, 1970-01-01. Kept so `start_time_s + time_base_utc == start_utc` can be verified. |
| `start_time_s` | double | Raw call start, seconds since `time_base_utc`, exactly as delivered. |
| `end_time_s` | double | Raw call end, seconds since `time_base_utc`, exactly as delivered. |
| `start_utc` | timestamp | Call start (`time_base_utc + start_time_s`). |
| `end_utc` | timestamp | Call end (`time_base_utc + end_time_s`). |
| `mid_utc` | timestamp | Midpoint of start and end. The event time used in the point-process model. |
| `duration_s` | double | `end_time_s - start_time_s`. |
| `start_freq_hz` | double | Start frequency of the call in Hz, from the analyst log. |
| `end_freq_hz` | double | End frequency of the call in Hz. |
| `species` | int32 | NEFSC species code. Always 7 (NARW) in this release. |
| `call_type` | int32 | NEFSC within-species call type. Always 1 (upcall) in this release. |
| `ts_min` | double | Minutes from `sites.ts_origin_utc` to `mid_utc`. This is the `ts` variable consumed by the model code; it equals the legacy RDS `ts` to floating-point precision. |

Rows are sorted by `site`, then `start_utc`.

## `deployments.parquet`

| Column | Type | Description |
|---|---|---|
| `deployment_id` | string | NEFSC project id. Primary key. |
| `site` | string | Site code. |
| `recorder` | string | Recording device (`SoundTrap`). |
| `sampling_rate_hz` | double | Sampling rate in Hz. |
| `deployed_utc` | timestamp | Date and drop time from the metadata sheet. |
| `retrieved_utc` | timestamp | Date and retrieval time from the metadata sheet. |
| `lat`, `lon` | double | Mooring position, decimal degrees (WGS84 assumed). |
| `water_depth_m` | double | Water depth in metres. |
| `recording_schedule` | string | `continuous` for all deployments. |
| `soundfile_tz` | string | Timezone label carried in the metadata sheet (`GMT` or `UTC`). |
| `location` | string | `Nantucket Shoals`. |
| `gap_before_h` | double | Hours between the previous deployment's retrieval and this deployment's drop, within site. `NA` for the first deployment. |
| `n_upcalls` | int32 | Number of `upcalls` rows attributed to this deployment. |

## `sites.parquet`

| Column | Type | Description |
|---|---|---|
| `site` | string | Site code. Primary key. |
| `lat`, `lon` | double | Position of the first deployment (all deployments at a site share a position). |
| `location` | string | `Nantucket Shoals`. |
| `first_deployed_utc`, `last_retrieved_utc` | timestamp | Span of instrument coverage. |
| `n_deployments` | int32 | Always 4. |
| `ts_origin_utc` | timestamp | Origin for `upcalls.ts_min`: the site's earliest upcall start. |
| `n_upcalls` | int32 | Upcalls at the site. |
| `first_upcall_utc`, `last_upcall_utc` | timestamp | Span of detections. |

## Notes and known quirks

- **Timezone.** All origins were applied with `tz = "UTC"`, so the stored
  times inherit whatever clock the analyst logs used. The metadata sheet
  labels the sound files as GMT/UTC, but the model code has long treated
  the times as behaving like EST (see the note at the top of `01_data.R`).
  The stamps are internally consistent and are used only for relative
  timing and diel covariates; treat absolute clock time with caution until
  this is resolved with NEFSC.
- **Analysis window is not applied here.** The release holds every upcall in
  the delivered logs. The paper fits a single 5-month window,
  2021-10-01 to 2022-03-01, defined in `src/config.R`; apply it downstream.
- **Log coverage is narrower than deployment coverage.** Analyst logs start
  and stop when calls were heard, not at drop and retrieval. Large
  leads/lags (for example COX01 Jul 2021 has 13 detections in a
  four-month deployment) reflect seasonal absence, not missing data.
- **One early NS01 row.** One upcall in `NEFSC_MA-RI_202107_NS01` is stamped
  2021-07-20 20:42:48, about 20 h before that deployment's recorded drop
  time and before the previous deployment's retrieval. It is retained as
  delivered.
- **Benign duplicate stamps.** NS01 has one pair and NS02 three pairs of
  rows sharing an identical start time. They have distinct frequencies and
  are second-rounding coincidences of distinct calls, not duplicates. COX01
  has none. Any file in which a stamp is shared by more than two rows fails
  the build (that was the signature of the Excel corruption).
- **Precision guard.** The build refuses any file whose raw `start_time`
  values carry fewer than 10 significant digits.

## Reading the files

R:

```r
library(arrow)
upcalls <- read_parquet("data/release/upcalls.parquet")
```

Python:

```python
import pandas as pd
upcalls = pd.read_parquet("data/release/upcalls.parquet")
```

DuckDB:

```sql
SELECT site, count(*) FROM 'data/release/upcalls.parquet' GROUP BY site;
```
