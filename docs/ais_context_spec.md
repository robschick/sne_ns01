# Spec — AIS vessel-traffic context at the three hydrophones

Settled in a grilling session on 2026-11-04; revised 2026-11-05 after GFW
paused gridded 4Wings reports (see Further Notes). For the NARWC talk (two
weeks out), so the scope is fast and cheap. Built so it can later grow into a
detection-confounder check (see Out of Scope).

## Problem Statement

The talk (and later the research paper) presents call-rate models at three
buoys — COX01, NS01, NS02 — in and around the Southern New England Wind Energy
Areas, which were being surveyed and prepared for construction during the
analysis window. There is currently nothing in the project that says what
vessel traffic looked like at each hydrophone: how busy each site is, what
kinds of vessels pass, and whether the 2021–22 winter was busier than usual
(e.g. from wind-farm survey and support vessels). Without that, the audience
has no site context for comparing the buoys, and the obvious question — "is
shipping driving what you hear?" — has no picture to point to.

## Solution

A small, self-contained side analysis, kept outside the Hawkes model pipeline,
built from two sources:

- **Numbers** — Global Fishing Watch (GFW) AIS vessel presence, as daily
  vessel-hours inside each buoy's 10 km circle, by vessel type, for the
  analysis winter and the prior winter.
- **Map backdrop** — Northeast Ocean Data monthly AIS transit-count rasters,
  summed over the same months. If these prove too heavy a lift, the map falls
  back to the existing case-study map with the 10 km circles and no traffic
  layer.

Outputs:

1. a per-buoy table of mean vessel-hours per day by vessel group, for both
   winters, with their ratio;
2. a weekly time-series panel of vessel-hours within 10 km of each buoy —
   analysis winter solid, prior winter dashed, smoothed;
3. a regional map of AIS transits over the analysis winter, with the buoys,
   their 10 km circles and the wind lease outlines;
4. a difference map (analysis winter minus prior winter) — first to drop.

Everything is framed as *AIS-tracked traffic*, never as noise. The recorded
ambient (RMS) at each buoy remains the better noise measure.

## User Stories

1. As the speaker, I want a single headline number per buoy — mean vessel-hours per day within 10 km — so that I can compare sites in one sentence.
2. As the speaker, I want traffic split into Cargo & tanker, Passenger, Fishing, Seismic / survey, and Support & other, so that I can say what kind of traffic dominates each site.
3. As the speaker, I want Seismic / survey as its own group, so that the loudest vessels with the largest acoustic footprint aren't hidden inside a catch-all.
4. As the speaker, I want group labels to say they come from the AIS vessel type (e.g. "Seismic / survey (AIS type)"), so that I don't overclaim what broadcast type codes can tell us.
5. As the speaker, I want a total that includes vessels with insufficient or inactive type data, so that the headline number isn't silently undercounted.
6. As the speaker, I want the same numbers for the prior winter (Oct 2020 – Feb 2021), so that I can say whether 2021–22 was busier than usual.
7. As the speaker, I want the ratio of analysis winter to prior winter per buoy and group, so that "3× the prior winter" is a number I can read off a table.
8. As the speaker, I want the ratio blank rather than infinite when the prior winter had no traffic in a group, so that the table never shows a misleading value.
9. As the speaker, I want the number of distinct vessels alongside vessel-hours, so that I can tell "two ships parked for weeks" from "forty boats passing".
10. As the speaker, I want a weekly time series of vessel-hours within 10 km per buoy, so that I can show timing, such as the Sep–Nov 2021 survey season.
11. As the speaker, I want that series smoothed with a 3-week rolling mean and the raw weekly values shown faintly behind it, so that it reads cleanly on a slide without hiding the data.
12. As the speaker, I want the prior winter drawn dashed on the same panel, so that the two winters compare at a glance.
13. As the speaker, I want the weekly values aligned by week-of-season, so that week 1 of each winter is the first week of October in both.
14. As the speaker, I want the smoothed line to span the whole season, so that it doesn't stop short a week from each end.
15. As the speaker, I want a regional map of AIS traffic around the three buoys, so that the audience sees where the shipping lanes and ferry routes sit relative to each hydrophone.
16. As the speaker, I want the wind lease outlines and each buoy's 10 km circle on the map, so that I can point to wind-energy activity and to what "at the hydrophone" means.
17. As the speaker, I want the map on a log color scale, so that open-shelf traffic is visible alongside lanes that are orders of magnitude busier.
18. As the speaker, I want the map to match the case-study map and the talk figures, so that the slides read as one set.
19. As the speaker, I want a difference map (analysis minus prior winter), so that I can show *where* traffic increased — e.g. whether the lease areas light up.
20. As the speaker, I want the map's source and unit (transits) labeled separately from the numbers' source and unit (vessel-hours), so that nobody reads one as the other.
21. As the speaker, I want the slides to carry GFW and Northeast Ocean Data attribution, so that the licences are honored.
22. As the analyst, I want days with no AIS presence counted as zero, so that the means aren't inflated by GFW returning nothing for empty days.
23. As the analyst, I want the season end date excluded (Mar 1 not counted), so that both winters are exactly 151 days and match the model's window.
24. As the analyst, I want the 10 km circle built in a metric projection around each buoy, so that the buffer is honest at this latitude.
25. As the analyst, I want an unknown GFW vessel type to stop the summary with an error, so that a new or renamed category is never silently dropped.
26. As the analyst, I want every GFW request cached locally, including empty ones, so that re-running the summaries and figures never hits the API again.
27. As the analyst, I want the download to fail with a clear message when the API token is missing, so that the one manual setup step is obvious.
28. As the analyst, I want the buoy positions read from the released site metadata, so that the coordinates have one source of truth.
29. As the analyst, I want the per-buoy table committed as a small data file, so that the numbers are reviewable without re-running anything.
30. As the analyst, I want the summary logic covered by tests on a hand-built fixture, so that I can trust the numbers without checking API output by hand.
31. As the maintainer, I want this analysis kept outside the numbered model pipeline, so that the future Hawkes-only release can leave it out cleanly.
32. As the maintainer, I want raw downloads kept out of git, so that the repo stays small and the licensed data isn't redistributed.
33. As the maintainer, I want a follow-up note listing what was deferred, so that the path to the confounder analysis is written down.
34. As a future reader of the paper, I want the caveats (one baseline year, COVID-era 2020, AIS coverage, small vessels missing) stated alongside the numbers, so that the comparison isn't read as causal.

## Implementation Decisions

**Numbers: GFW area-total reports**
- GFW AIS vessel presence (`public-global-presence`, v5.0; all vessel types,
  satellite + terrestrial AIS). Units are vessel-hours (one position per
  vessel per hour).
- Requests go straight to the 4Wings report endpoint with
  `spatial-aggregation=true` — gfwr 3.0 doesn't expose that option, and
  gridded reports are paused. The endpoint requires a grouping, so requests
  group by flag; the download sums over flags.
- One request per buoy × winter × vessel type (3 × 2 × 11 = 66), DAILY,
  polygon = the buoy's 10 km circle, filter = one vessel type. Each response
  gives, per day and flag, vessel-hours and a distinct-vessel count.
- Free GFW API token in the user's environment as `GFW_TOKEN`. Licence
  CC BY-NC 4.0; attribution on slides and in the analysis folder's README.

**Map backdrop: Northeast Ocean Data monthly transit counts**
- Monthly AIS vessel transit counts (100 m, all vessels), derived from
  MarineCadastre / USCG AIS, read with GDAL's OpenFileGDB raster driver
  (available: GDAL 3.8.5). Needs the 2020, 2021 and 2022 monthly files to sum
  Oct–Feb for both winters.
- Fallback, if the rasters won't read or the download is impractical: the
  existing case-study map with circles and leases, no traffic layer.

**Seasons**
- Analysis: 2021-10-01 (inclusive) to 2022-03-01 (exclusive). Matches the
  model's 5-month window. 151 days.
- Baseline: 2020-10-01 to 2021-03-01, same rules. 151 days.
- GFW's date range is already end-exclusive.

**Vessel groups** (GFW type → talk group)
- Cargo & tanker: cargo, bunker, carrier
- Passenger: passenger
- Fishing: fishing, gear
- Seismic / survey: seismic_vessel
- Support & other: support, other_non_fishing
- insufficient_data, inactive: counted in Total only
- Any other type: error.

The type list comes from the dataset's own metadata (11 values, checked
2026-11-05).

**Modules**
- *Download step* (script, not tested): reads the token; builds each buoy's
  10 km circle in UTM 19N; sends the 66 requests one at a time; caches each
  response, including empty ones, so reruns skip it. Fails clearly if the
  token is missing.
- *Normalized cache schema* — the contract between download and summary:
  one row per buoy × day × vessel type with `buoy`, `season`
  (`"analysis"` / `"baseline"`), `date`, `vessel_type` (GFW string), `hours`,
  `vessels`. Absent rows mean zero.
- *Summary module* (pure functions, the one tested seam). Inputs: the
  normalized rows, group mapping, season definitions. Outputs:
  - **per-buoy table**: buoy × group (incl. Total) × season → mean
    vessel-hours per day and mean distinct vessels per day, plus the
    analysis/baseline ratio of vessel-hours (NA when baseline = 0);
  - **weekly series**: buoy × season × week-of-season → mean vessel-hours per
    day in that week (so the final partial week is comparable), plus a
    3-week centered rolling mean that averages whatever neighbors exist at the
    ends.
- *Map step* (script, not tested): sums the monthly transit rasters over each
  winter, crops to the region, and draws the map and difference map.
- *Figures step* (script, not tested): draws the weekly panel in the existing
  talk style (`theme_talk`, buoys ordered COX01 → NS01 → NS02, US spelling,
  slide-sized PNG + PDF), and writes the per-buoy table to CSV and parquet.

**Placement**
- A separate context folder for this analysis, outside the numbered pipeline,
  with its own README (attribution), gitignore (cache) and tests. Figures go to
  a context subfolder of `fig/` (gitignored, like all figures); the committed
  per-buoy table lives in the context folder.
- Buoy positions come from the released site metadata (parquet).

## Testing Decisions

- **Good tests here exercise the summary module's outputs from its inputs
  only** — given rows, mapping and seasons, check the returned table and
  weekly series. They don't check intermediate columns or helper functions.
- **One seam:** the summary module. The download (network), the map step and
  the figures (visual, checked by eye on the PNGs) are not tested.
- **Fixture:** a small hand-built set of normalized rows with known answers:
  an `insufficient_data` and an `inactive` row; rows on Sep 30, Oct 1,
  Feb 28 and Mar 1; a group with zero baseline traffic; a sparse series where
  zero-filling changes the mean; a final partial week.
- **Framework:** `testthat`, run from the command line. There is no prior test
  suite in this repo, so these are the first tests; keep them self-contained
  under the context folder.
- **Red-green-refactor:** each behavior below is one failing test first, then
  the smallest code to pass, then tidy. One test at a time, not all tests up
  front.

## Build plan — one PR per chunk

Each chunk is a branch off master → commit → push → PR. Check the previous PR
is merged before starting the next (PRs merge fast here).

**Chunk 0 — this spec.** Merged as PR #34.

**Chunk 1 — spec revision + scaffold + GFW download** (no tests; verified by
hand)
- This revision of the spec.
- Context folder, README with GFW attribution, gitignore for the cache.
- Download step as above.
- Done when: all 66 requests are cached; a printed check shows the date range,
  row counts per buoy × winter, and total vessel-hours per type.

**Chunk 2 — per-buoy table** (TDD)
Red → green → refactor, in this order:
1. One buoy, one row, one season → mean vessel-hours/day = hours / 151.
2. Days without rows count as zero (zero-fill is in the denominator).
3. Rows on Sep 30 and Mar 1 are excluded; Oct 1 and Feb 28 included.
4. Types map to groups; Total = sum of groups + insufficient_data + inactive.
5. An unknown vessel type errors.
6. Mean distinct vessels per day is reported alongside vessel-hours.
7. Ratio = analysis / baseline; NA when baseline is 0.
8. Three buoys come back in COX01 → NS01 → NS02 order.
Done when: tests pass and the table runs on the real cache.

**Chunk 3 — weekly series** (TDD)
1. Week 1 starts on Oct 1 in both seasons.
2. Weekly value is mean vessel-hours per day within the week; the final
   4-day week divides by 4, not 7.
3. 3-week centered rolling mean in the interior.
4. At the first and last week the rolling mean uses the neighbors that exist.
Done when: tests pass and the series runs on the real cache.

**Chunk 4 — weekly panel + table export** (checked by eye)
- Weekly panel (solid analysis, dashed baseline, faint raw points).
- Per-buoy table to CSV + parquet, committed.
Done when: the PNG looks right on a slide and the table numbers match it.

**Chunk 5 — map** (checked by eye; drop to the fallback if heavy)
- Download the Northeast Ocean Data monthly files; sum Oct–Feb per winter.
- Map (log scale, buoys, 10 km circles, lease outlines, attribution).
- Difference map — the first thing to drop if time is short.

**Chunk 6 — follow-up note + talk pointer**
- A follow-up doc listing the deferred work (below) and the slide caveats.
- A pointer from the talk notes to the new figures.

## Out of Scope

- Call rates or RMS noise on these figures — comparing traffic to measured
  noise is the first follow-up, not part of the talk.
- Any use of vessel traffic as a covariate in the Hawkes model.
- GFW gridded (per-cell) presence — paused upstream; revisit if restored.
- MarineCadastre raw AIS points (AccessAIS clip), per-vessel tracks and
  closest-approach distances.
- Identifying individual vessels, including the seismic-type vessels near
  NS01 or known wind-survey vessels (e.g. GO PURSUIT, 367191410,
  Sep–Nov 2021) — needs per-vessel data; GFW's per-vessel reports are paused.
- Nested buffers (5 / 10 / 20 km).
- Any claim that AIS traffic equals noise exposure, or that wind development
  caused a change.
- The two unrelated issues found during the session (stale "EST" comment in
  the config; the buoy-map script reading a missing file).

## Further Notes

- **GFW status (2026-11-05):** GFW's 2026-11-03 platform update pauses
  vessel-level 4Wings reports and says other reports still work. In practice
  every gridded report (any resolution, region or dataset) returns 404
  "temporarily unavailable"; area-total reports (`spatial-aggregation=true`,
  grouped by flag) return 200. No restoration date.
- **First look:** NS01, 10 km, October 2021 = 389 vessel-hours — 180 from
  2 seismic-type vessels (Marshall Islands flag), 110 from 5
  other_non_fishing, 99 from 37 fishing vessels.
- **Caveats for the slide:** one prior winter cannot separate a wind effect
  from year-to-year variation; late 2020 may still carry COVID shipping
  effects; GFW's satellite AIS coverage varies by year and degrades near busy
  coasts; AIS misses most small recreational and fishing vessels.
- Vessel-type labels are GFW's classification of broadcast AIS, not
  identification; hence the "(AIS type)" labels.
- Ferries to Martha's Vineyard, Nantucket and Block Island will likely
  dominate Passenger near COX01.
- Buoy positions in the released site metadata agree with the older CSV and
  the SST extraction script to within ~50 m.
