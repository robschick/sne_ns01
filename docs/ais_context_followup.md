# AIS vessel-traffic context — follow-up

What the AIS side analysis (`context/ais/`, spec `docs/ais_context_spec.md`)
found, the caveats that go with it on a slide, and what was deferred, in the
order it's worth picking up. Written 2026-11-05, after chunks 0–5 (PRs #34–#41).

## What it found

Mean AIS vessel-hours per day within 10 km (GFW; `context/ais/buoy_table.csv`):

| | COX01 | NS01 | NS02 |
|---|---|---|---|
| 2021–22, all types | 2.4 | 8.3 | 1.4 |
| 2020–21, all types | 11.2 | 6.8 | 0.8 |
| 2021–22 ÷ 2020–21 | 0.2× | 1.2× | 1.7× |
| Biggest group, 2021–22 | Fishing (1.3) | Seismic / survey (3.9) | Fishing (1.3) |

- **NS01 is the busiest site**, and the only one where seismic / survey-type
  vessels lead (3.9 vessel-hours/day, ~6× the prior winter). On the transit map,
  a regular grid of tracks just west of NS01 in 2021–22 looks like survey lines.
- **COX01 was much busier in the prior winter**: ~50 vessel-hours/day in early
  October 2020, down to the 2021–22 level by late November. Most of it is one
  Netherlands-flagged seismic-type vessel (783 h over 39 days, Oct 1 –
  Nov 18, 2020) — the survey vessel DEEP HELDER (below) — plus fishing.
- **NS02 is quiet** (~1 vessel-hour/day, mostly fishing).
- **Cargo and tankers are almost absent** within 10 km of every buoy
  (≤ 0.02 vessel-hours/day). Large ships use the east–west lane at ~40.55° N,
  south of all three buoys. The NW–SE lane through NS01 and NS02 on the map
  carries tens to ~100 transits a winter, which is well under an hour a day in
  the circles.
- The two sources agree: GFW vessel-hours and Northeast Ocean Data transits
  (difference map) both show COX01 down and NS01 up.

## The survey vessels

GFW's seismic-type hours, named from MarineCadastre raw AIS (USCG) on the
days each flag was inside the circle longest (`context/ais/05_vessel_ids.R`,
output `context/ais/vessel_ids.csv`). Each matches a published survey notice.

| Buoy | Vessel | Flag | MMSI | IMO | Days sampled (h in circle) | Work |
|---|---|---|---|---|---|---|
| COX01 | DEEP HELDER | NLD | 244780813 | 9690872 | 2020-10-04 (24), 10-26 (24) | MMT geophysical seabed survey, Revolution Wind / South Fork sites (from June 2020) |
| NS01 | MINERVA UNO | MHL | 538009086 | 9262077 | 2021-10-21 (24), 12-29 (17), 2022-01-27 (9) | Geophysical survey, northern Vineyard Wind lease (OCS-A 0501) and cable corridors, ~2021-06-28 to early June 2022 |
| NS01 | ARTEMIS ANGLER | NOR | 259959000 | 9181467 | 2021-11-06 (22), 11-20 (20) | Ultra-high-resolution 3D geophysical survey, northern Vineyard Wind lease, from ~2021-10-31 (16 towed streamers, ~600 ft spread) |

- DEEP HELDER broadcast no name or type on the days sampled; the MMSI resolves
  to it in public registries. Its track is east–west lines ~10 km long at
  ~3.8 kn, turning at each end: a survey pattern.
- MINERVA UNO broadcasts a malformed IMO (`IMO926209700`); registries give
  9262077.
- Also inside COX01's circle on 2020-10-04 for 24 h: HORIZON GEOBAY (PAN,
  AIS type 95, 86 m), another geophysical survey vessel. GFW has no PAN
  seismic-type hours at COX01 that winter, so it sits in another GFW group.
- So the "Seismic / survey" hours at both busy sites are **offshore-wind site
  surveys** (high-resolution geophysical), not oil-and-gas airgun seismic.

Sources: MarineTraffic / registry entries for MMSI 244780813; offshorewind.biz,
2020-06-30 and 2020-11-23 (DEEP HELDER at Revolution Wind / South Fork);
Vineyard Wind mariners' updates #44 (MINERVA UNO) and #53 (ARTEMIS ANGLER);
Alpine Ocean (RV Minerva Uno).

## Caveats for any slide

- One prior winter can't separate a wind-development effect from ordinary
  year-to-year variation.
- Late 2020 may still carry COVID-era shipping effects.
- AIS misses most small recreational and fishing boats; GFW's satellite
  coverage varies by year and is weaker near busy coasts.
- Vessel groups are GFW's classification of broadcast AIS type, not
  identification ("Seismic / survey (AIS type)").
- The map is transits (tracks crossing a 100 m cell); the table and weekly
  panel are vessel-hours. Not the same unit.
- AIS-tracked traffic is not noise exposure. The recorded RMS at each buoy is
  the noise measure, and no causal claim is made either way.

## Deferred work

1. ~~**Name the seismic-type vessels.**~~ **Done 2026-11-05** — see "The
   survey vessels" above. Still open: check GO PURSUIT (MMSI 367191410,
   Sep–Nov 2021), and whether the smaller seismic-type flags (GBR, MHL, BHS,
   USA at COX01; PAN at NS01) are further survey vessels.
2. **Traffic vs recorded noise.** Daily GFW vessel-hours (already cached,
   `context/ais/cache/presence.parquet`) against daily RMS per buoy. This is
   the first step toward asking whether traffic explains NS01's stronger noise
   sensitivity (`fig/talk/param_figs_guide.md`, Fig 4).
3. **Detection-confounder check.** Whether vessel presence explains residual
   variation in detected call rate beyond RMS. Needs a design decision first;
   traffic is not a covariate in the Hawkes model.
4. **More baseline winters**, to set 2021–22 against normal year-to-year
   variation. GFW presence goes back to 2012; Northeast Ocean Data publishes
   monthly transits for earlier years too. `01_download.R` and `04_map.R` take
   seasons from `ais_seasons` in `R/summary.R`.
5. **Per-type transit maps.** The downloaded databases already hold Cargo,
   Tanker, Fishing, Passenger, Tug-Tow, Pleasure/Sailing and Other layers
   (`<Type>VesselTransitCounts<yyyy>_<mm>`), so this is a small change to
   `04_map.R`.
6. **Nested buffers** (5 / 10 / 20 km), to show how the numbers depend on the
   circle.
7. **GFW gridded presence**, if GFW restores gridded 4Wings reports (404 since
   2026-11-03). That would give a map in vessel-hours, the same unit as the
   table.
8. **Per-vessel tracks and closest approach** to each hydrophone.
9. Two unrelated issues found while writing the spec: a stale "EST" comment in
   the config (timestamps are true UTC), and the buoy-map script reading a
   missing file.

## Regenerating

From the repo root (figures go to the gitignored `fig/context/ais/`):

```sh
Rscript context/ais/01_download.R   # needs GFW_TOKEN; cached after the first run
Rscript context/ais/02_table.R
Rscript context/ais/03_weekly.R
Rscript context/ais/04_map.R        # ~3 GB download on first run
Rscript -e 'testthat::test_dir("context/ais/tests")'
```
