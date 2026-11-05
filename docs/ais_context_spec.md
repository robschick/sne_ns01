# Spec — AIS vessel-traffic context at the three hydrophones

Settled in a grilling session on 2026-11-04. For the NARWC talk (two weeks
out), so the scope is fast and cheap. Built so it can later grow into a
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
that pulls Global Fishing Watch (GFW) daily AIS vessel-presence rasters for the
region and produces:

1. a regional map of mean daily vessel-hours over the analysis season, with the
   buoys, their 10 km circles and the wind lease outlines;
2. a difference map (analysis season minus the prior winter);
3. a weekly time-series panel of vessel-hours within 10 km of each buoy —
   analysis season solid, prior winter dashed, smoothed;
4. a per-buoy table of mean vessel-hours per day by vessel group, for both
   seasons, with their ratio.

Everything is framed as *AIS-tracked traffic*, never as noise. The recorded
ambient (RMS) at each buoy remains the better noise measure.

## User Stories

1. As the speaker, I want a regional map of vessel traffic around the three buoys, so that the audience sees where the shipping lanes and ferry routes sit relative to each hydrophone.
2. As the speaker, I want the wind lease outlines on the same map, so that I can point to wind-energy activity in the same frame as the traffic.
3. As the speaker, I want each buoy's 10 km circle drawn on the map, so that the audience sees what "at the hydrophone" means in the numbers.
4. As the speaker, I want the map on a log color scale, so that open-shelf traffic is visible alongside lanes that are orders of magnitude busier.
5. As the speaker, I want the map to match the look of the existing case-study map and talk figures, so that the slides read as one set.
6. As the speaker, I want a single headline number per buoy — mean vessel-hours per day within 10 km — so that I can compare sites in one sentence.
7. As the speaker, I want traffic split into Cargo & tanker, Passenger, Fishing, and Support & other, so that I can say what kind of traffic dominates each site.
8. As the speaker, I want "Support & other" labeled as where wind-related vessels would appear (not as "wind vessels"), so that I don't overclaim what AIS type codes can tell us.
9. As the speaker, I want a total that includes vessels with insufficient type data, so that the headline number isn't silently undercounted.
10. As the speaker, I want the same numbers for the prior winter (Oct 2020 – Feb 2021), so that I can say whether 2021–22 was busier than usual.
11. As the speaker, I want the ratio of analysis season to prior winter per buoy and group, so that "3× the prior winter" is a number I can read off a table.
12. As the speaker, I want the ratio to be blank rather than infinite when the prior winter had no traffic in a group, so that the table never shows a misleading value.
13. As the speaker, I want a difference map (analysis minus prior winter), so that I can show *where* traffic increased — e.g. whether the lease areas light up.
14. As the speaker, I want a weekly time series of vessel-hours within 10 km per buoy, so that I can show timing, such as the Sep–Nov 2021 survey season.
15. As the speaker, I want that series smoothed with a 3-week rolling mean and the raw weekly values shown faintly behind it, so that it reads cleanly on a slide without hiding the data.
16. As the speaker, I want the prior winter drawn dashed on the same panel, so that the two seasons compare at a glance.
17. As the speaker, I want the weekly values aligned by week-of-season, so that week 1 of each season is the first week of October in both.
18. As the speaker, I want the smoothed line to span the whole season, so that it doesn't stop short a week from each end.
19. As the speaker, I want the slides to carry the GFW attribution, so that the CC BY-NC licence is honored.
20. As the analyst, I want days with no AIS rows counted as zero traffic, so that the means aren't inflated by GFW omitting empty cells.
21. As the analyst, I want the season end date excluded (Mar 1 not counted), so that both seasons are exactly 151 days and match the model's window.
22. As the analyst, I want "within 10 km" decided by geodesic distance from each cell center to the buoy, so that the buffer is honest at this latitude.
23. As the analyst, I want an unknown GFW vessel type to stop the summary with an error, so that a new or renamed category is never silently dropped.
24. As the analyst, I want the GFW download cached locally, so that re-running the summaries and figures never hits the API again.
25. As the analyst, I want the download to fail with a clear message when the API token is missing, so that the one manual setup step is obvious.
26. As the analyst, I want the buoy positions read from the released site metadata, so that the coordinates have one source of truth.
27. As the analyst, I want the per-buoy table committed as a small data file, so that the numbers are reviewable without re-running anything.
28. As the analyst, I want the summary logic covered by tests on a hand-built fixture, so that I can trust the numbers without inspecting rasters cell by cell.
29. As the maintainer, I want this analysis kept outside the numbered model pipeline, so that the future Hawkes-only release can leave it out cleanly.
30. As the maintainer, I want raw downloads kept out of git, so that the repo stays small and the licensed data isn't redistributed.
31. As the maintainer, I want a follow-up note listing what was deferred, so that the path to the confounder analysis is written down.
32. As a future reader of the paper, I want the caveats (one baseline year, COVID-era 2020, AIS receiver coverage, small vessels missing) stated alongside the numbers, so that the comparison isn't read as causal.

## Implementation Decisions

**Data source**
- GFW AIS vessel presence (all vessel types, satellite + terrestrial AIS), via
  the `gfwr` package's presence function, at HIGH spatial resolution (0.01°)
  and DAILY temporal resolution. Units are vessel-hours per cell per day.
- Free GFW API token in the user's environment as `GFW_TOKEN`. Licence is
  CC BY-NC 4.0; attribution goes on slides and in the analysis folder's README.
- One regional bounding box covering all three buoys with margin for lanes and
  leases is downloaded per season; the 10 km buffers are selected locally from
  it. No per-buoy API requests.

**Seasons**
- Analysis: 2021-10-01 (inclusive) to 2022-03-01 (exclusive). Matches the
  model's 5-month window. 151 days.
- Baseline: 2020-10-01 to 2021-03-01, same rules. 151 days.
- Each season fits within GFW's 366-day request limit.

**Vessel groups** (GFW type → talk group)
- Cargo & tanker: cargo, bunker_or_tanker, carrier
- Passenger: passenger
- Fishing: fishing, gear
- Support & other: support, other, seismic_vessel
- insufficient_data: counted in Total only
- Any other type: error.

**Modules**
- *Download step* (script, not tested): reads the token, requests presence per
  season (and per vessel type if the presence endpoint can't group by type —
  to be confirmed in chunk 1), and writes a normalized cache. Fails clearly if
  the token is missing. Skips requests whose cache already exists.
- *Normalized cache schema* — the contract between download and summary:
  one row per cell × day × vessel type with `lon`, `lat` (cell center),
  `date`, `vessel_type` (GFW string), `hours`, `season`
  (`"analysis"` / `"baseline"`). Absent rows mean zero.
- *Summary module* (pure functions, the one tested seam). Inputs: the
  normalized rows, buoy positions, radius (10 km), group mapping, season
  definitions. Outputs:
  - **per-buoy table**: buoy × group (incl. Total) × season → mean
    vessel-hours per day, plus the analysis/baseline ratio (NA when
    baseline = 0);
  - **weekly series**: buoy × season × week-of-season → mean vessel-hours per
    day in that week (so the final partial week is comparable), plus a
    3-week centered rolling mean that averages whatever neighbors exist at the
    ends;
  - **cell grids**: per cell × season → mean daily vessel-hours over the
    season (zero-filled), and their difference, for the two maps.
- *Figures step* (script, not tested): draws the map, difference map and
  weekly panel in the existing talk style (`theme_talk`, buoys ordered
  COX01 → NS01 → NS02, US spelling, slide-sized PNG + PDF), and writes the
  per-buoy table to CSV and parquet.

**Placement**
- A separate context folder for this analysis, outside the numbered pipeline,
  with its own README (attribution) and tests. Figures go to a context
  subfolder of `fig/`. The download cache is gitignored.
- Buoy positions come from the released site metadata (parquet).

## Testing Decisions

- **Good tests here exercise the summary module's outputs from its inputs
  only** — given rows, buoys, radius and mapping, check the returned table,
  weekly series and grids. They don't check intermediate columns, helper
  functions or how the buffer is computed.
- **One seam:** the summary module. The download (network) and figures
  (visual, checked by eye on the PNGs) are not tested.
- **Fixture:** a small hand-built set of normalized rows with known answers:
  cells just inside and just outside 10 km; an `insufficient_data` row;
  rows on Sep 30, Oct 1, Feb 28 and Mar 1; a group with zero baseline
  traffic; a sparse series where zero-filling changes the mean; a final
  partial week.
- **Framework:** `testthat`, run from the command line. There is no prior test
  suite in this repo, so these are the first tests; keep them self-contained
  under the context folder.
- **Red-green-refactor:** each behavior below is one failing test first, then
  the smallest code to pass, then tidy. One test at a time, not all tests up
  front.

## Build plan — one PR per chunk

Each chunk is a branch off master → commit → push → PR. Check the previous PR
is merged before starting the next (PRs merge fast here).

**Chunk 0 — this spec.** Commit `docs/ais_context_spec.md`. PR.

**Chunk 1 — scaffold + download + cache** (no tests; verified by hand)
- Context folder, README with GFW attribution, gitignore for the cache.
- Download step: token check, bounding box from the site metadata, both
  seasons, normalized cache.
- Discovery to record in the PR: can presence be grouped by vessel type, or is
  it one filtered request per type? Which type strings actually come back?
- Done when: cache exists for both seasons; a printed check shows the date
  range, row counts per season and the set of vessel types.

**Chunk 2 — per-buoy table** (TDD)
Red → green → refactor, in this order:
1. One buoy, one in-buffer row, one season → mean vessel-hours/day = hours / 151.
2. A row just outside 10 km is excluded; just inside is included.
3. Days without rows count as zero (zero-fill is in the denominator).
4. Rows on Sep 30 and Mar 1 are excluded; Oct 1 and Feb 28 included.
5. Types map to groups; Total = sum of groups + insufficient_data.
6. An unknown vessel type errors.
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

**Chunk 4 — cell grids** (TDD)
1. Per-cell season mean is zero-filled over 151 days.
2. Difference = analysis − baseline; a cell present in only one season gets
   the other as zero.
Done when: tests pass.

**Chunk 5 — figures + table export** (checked by eye)
- Map (log scale, buoys, 10 km circles, lease outlines, attribution).
- Weekly panel (solid analysis, dashed baseline, faint raw points).
- Difference map — the first thing to drop if time is short.
- Per-buoy table to CSV + parquet, committed.
Done when: PNGs look right on a slide and the table numbers match the figures.

**Chunk 6 — follow-up note + talk pointer**
- A follow-up doc listing the deferred work (below) and the slide caveats.
- A pointer from the talk notes to the new figures.

## Out of Scope

- Call rates or RMS noise on these figures — comparing traffic to measured
  noise is the first follow-up, not part of the talk.
- Any use of vessel traffic as a covariate in the Hawkes model.
- MarineCadastre raw AIS points (AccessAIS clip), per-vessel tracks and
  closest-approach distances.
- Matching known wind-survey vessel MMSIs (e.g. GO PURSUIT, 367191410,
  Sep–Nov 2021) — needs per-vessel data; GFW's per-vessel grouping is paused.
- Nested buffers (5 / 10 / 20 km).
- Any claim that AIS traffic equals noise exposure, or that wind development
  caused a change.
- The two unrelated issues found during the session (stale "EST" comment in
  the config; the buoy-map script reading a missing file).

## Further Notes

- **Caveats for the slide:** one prior winter cannot separate a wind effect
  from year-to-year variation; late 2020 may still carry COVID shipping
  effects; GFW's satellite AIS coverage varies by year and degrades near busy
  coasts; AIS misses most small recreational and fishing vessels.
- Vessel-type codes are a weak proxy for wind work: survey and support boats
  usually report "Other", "underwater operations" or "tug/tow", which GFW
  folds into support/other. Hence the careful label.
- Ferries to Martha's Vineyard, Nantucket and Block Island will likely
  dominate Passenger near COX01.
- Buoy positions in the released site metadata agree with the older CSV and
  the SST extraction script to within ~50 m.
