# =============================================================================
# 00_wrangle_calls.R — Build the shareable right-whale upcall dataset
#
# Reads the NEFSC "narwlog" manual-detection CSVs (one per deployment, three
# sites: NS01, NS02, COX01) plus the deployment metadata sheet, and writes
# three Parquet files under data/release/:
#
#   upcalls.parquet      one row per North Atlantic right whale upcall
#   deployments.parquet  one row per instrument deployment
#   sites.parquet        one row per site (position, ts origin, counts)
#
# Column definitions: docs/data_dictionary.md
#
# This replaces ~/Documents/_research/rrr/hawkes_kp/src/
# 2025-05-05_Wrangle-NEFSC-Call-Data.R. Differences from that script:
#   * driven by a file table, not twelve copy-pasted blocks;
#   * the seconds-since-origin time base is READ FROM EACH FILE'S HEADER
#     (start_time.start_date) instead of being hand-typed per file;
#   * the data block is located by finding the column-name row, not skip = 45;
#   * precision / duplicate-stamp guards from docs/cox01_timestamp_provenance.md
#     run on every file, so an Excel-mangled delivery fails loudly;
#   * difftime columns are dropped in favour of plain numeric seconds/minutes;
#   * output is Parquet (language-neutral, typed UTC timestamps).
#
# `ts_min` is kept identical to the legacy `ts` (minutes from the site's first
# detection) so the modeling pipeline (01_data.R onward) can switch to the
# Parquet file without changing any downstream number. The script checks this
# against the legacy RDS files if they are present.
#
# Usage:  Rscript 00_wrangle_calls.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(arrow)
})

raw_dir     <- "data/raw_calls"
release_dir <- "data/release"
dir.create(release_dir, showWarnings = FALSE, recursive = TRUE)

# Analysis filter: NARW (species code 7 in the NEFSC header), upcall (call_type 1).
keep_species   <- 7L
keep_call_type <- 1L

# ── File table ────────────────────────────────────────────────────────────────
# One row per delivered narwlog CSV. `deployment_id` matches PROJECT in the
# deployment metadata sheet. Nothing about the time base is stated here on
# purpose: it is parsed from the file header below.
files <- tribble(
  ~site,   ~deployment_id,             ~file,
  "COX01", "NEFSC_MA-RI_202102_COX01", "NEFSC_MA-RI_202102_COX01_narwlog.csv",
  "COX01", "NEFSC_MA-RI_202107_COX01", "NEFSC_MA-RI_202107_COX01_narwlog.csv",
  "COX01", "NEFSC_MA-RI_202111_COX01", "NEFSC_MA-RI_202111_COX01_narwlog.csv",
  "COX01", "NEFSC_MA-RI_202202_COX01", "NEFSC_MA-RI_202202_COX01_narwlog_ST.csv",
  "NS01",  "NEFSC_MA-RI_202103_NS01",  "NEFSC_MA-RI_202103_NS01_narwlog.csv",
  "NS01",  "NEFSC_MA-RI_202107_NS01",  "NEFSC_MA-RI_202107_NS01_narwlog.csv",
  "NS01",  "NEFSC_MA-RI_202110_NS01",  "NEFSC_MA-RI_202110_NS01_narwlog.csv",
  "NS01",  "NEFSC_MA-RI_202202_NS01",  "NEFSC_MA-RI_202202_NS01_narwlog_ST.csv",
  "NS02",  "NEFSC_MA-RI_202103_NS02",  "NEFSC_MA-RI_202103_NS02_narwlog.csv",
  "NS02",  "NEFSC_MA-RI_202107_NS02",  "NEFSC_MA-RI_202107_NS02_narwlog.csv",
  "NS02",  "NEFSC_MA-RI_202110_NS02",  "NEFSC_MA-RI_202110_NS02_narwlog.csv",
  "NS02",  "NEFSC_MA-RI_202202_NS02",  "NEFSC_MA-RI_202202_NS02_narwlog_ST.csv",
)
stopifnot(all(file.exists(file.path(raw_dir, files$file))))

# ── Reader for one narwlog CSV ────────────────────────────────────────────────
# Layout: N comment lines beginning "#", then a column-name row, a
# description row, a units row, then data. The comment block declares the
# time base as e.g. "# start_time.start_date: 01/01/21 00:00:00".
header_value <- function(lines, key) {
  hit <- str_subset(lines, fixed(paste0("# ", key, ":")))
  if (length(hit) != 1) stop("expected exactly one header line for ", key)
  # Excel-resaved files pad comment lines with trailing commas; strip them.
  str_trim(str_remove(str_remove(hit, fixed(paste0("# ", key, ":"))), ",+$"))
}

read_narwlog <- function(path) {
  lines <- read_lines(path)
  hdr   <- lines[str_starts(lines, "#")]

  # Time base (both start_time and end_time must agree).
  base_txt <- header_value(hdr, "start_time.start_date")
  stopifnot(identical(base_txt, header_value(hdr, "end_time.start_date")))
  stopifnot(identical(header_value(hdr, "start_time.units"), "seconds since start date"))
  time_base <- as.POSIXct(base_txt, format = "%m/%d/%y %H:%M:%S", tz = "UTC")
  if (is.na(time_base)) stop("could not parse time base '", base_txt, "' in ", path)

  # Data block starts three rows after the column-name row.
  name_row <- which(str_starts(lines, "start_time,end_time,"))
  stopifnot(length(name_row) == 1)
  col_names <- str_split_1(lines[name_row], ",")
  stopifnot(identical(col_names, c("start_time", "end_time", "start_freq",
                                   "end_freq", "species", "call_type")))

  # Precision guard: an Excel re-save writes times as e.g. 3.61E+07 (3 sig
  # figs). Genuine exports carry ~15. Check before parsing to numeric.
  data_lines <- lines[(name_row + 3):length(lines)]
  data_lines <- data_lines[nzchar(data_lines)]
  raw_start  <- str_split_fixed(data_lines, ",", 6)[, 1]
  sig_digits <- nchar(str_remove_all(str_remove(raw_start, "[eE].*$"), "[^0-9]"))
  if (any(sig_digits < 10)) {
    stop(sprintf("%s: %d of %d start_time values have < 10 significant digits ",
                 basename(path), sum(sig_digits < 10), length(sig_digits)),
         "(Excel-mangled delivery?). See docs/cox01_timestamp_provenance.md")
  }

  dat <- read_csv(I(data_lines), col_names = col_names,
                  col_types = cols(start_time = col_double(), end_time = col_double(),
                                   start_freq = col_double(), end_freq = col_double(),
                                   species = col_integer(), call_type = col_integer()),
                  progress = FALSE)

  dat %>%
    mutate(time_base_utc = time_base,
           start_utc     = time_base + start_time,
           end_utc       = time_base + end_time,
           .before = 1)
}

# ── Read everything ───────────────────────────────────────────────────────────
all_rows <- files %>%
  rowwise() %>%
  mutate(data = list(read_narwlog(file.path(raw_dir, file)))) %>%
  ungroup() %>%
  tidyr::unnest(data)

cat("\nRows read per file (all species / call types):\n")
all_rows %>%
  count(site, file, time_base = format(time_base_utc, "%Y-%m-%d"), name = "n_rows") %>%
  print(n = Inf)

# ── Filter to NARW upcalls and build the release table ───────────────────────
upcalls <- all_rows %>%
  filter(species == keep_species, call_type == keep_call_type) %>%
  arrange(site, start_utc)

# ts origin per site: the site's earliest upcall start. This reproduces the
# legacy `ts` exactly (it used the earliest call of the first deployment,
# which is the same instant).
sites_origin <- upcalls %>%
  group_by(site) %>%
  summarise(ts_origin_utc = min(start_utc), .groups = "drop")

upcalls <- upcalls %>%
  left_join(sites_origin, by = "site") %>%
  mutate(
    duration_s = end_time - start_time,
    mid_utc    = start_utc + duration_s / 2,
    ts_min     = as.numeric(difftime(mid_utc, ts_origin_utc, units = "mins"))
  ) %>%
  transmute(
    site, deployment_id, source_file = file,
    time_base_utc,
    start_time_s = start_time, end_time_s = end_time,
    start_utc, end_utc, mid_utc, duration_s,
    start_freq_hz = start_freq, end_freq_hz = end_freq,
    species, call_type,
    ts_min
  )

# ── Guards ────────────────────────────────────────────────────────────────────
stopifnot(!any(is.na(upcalls$start_utc)), all(upcalls$duration_s >= 0))

# Duplicate-stamp guard: a handful of benign rounding pairs is normal; a stamp
# shared by many rows means collapsed timestamps.
dup_max <- upcalls %>% count(site, start_utc) %>% group_by(site) %>%
  summarise(max_per_stamp = max(n), n_dup_rows = sum(n[n > 1]), .groups = "drop")
print(dup_max)
stopifnot(all(dup_max$max_per_stamp <= 2))

# Every detection should fall within its own deployment window (with slack for
# clock differences between the log and the metadata sheet).
meta <- read_csv(file.path(raw_dir, "MA-RI_Deployment_Metadata.csv"),
                 show_col_types = FALSE)
deployments <- meta %>%
  transmute(
    deployment_id     = PROJECT,
    site              = Site,
    recorder          = Recording_Device,
    sampling_rate_hz  = `SamplingRate(Hz)`,
    deployed_utc      = as.POSIXct(paste(Date_Deployed, Drop_Time),
                                   format = "%Y%m%d %H:%M", tz = "UTC"),
    retrieved_utc     = as.POSIXct(paste(Date_Retrieved, Retrieval_Time),
                                   format = "%Y%m%d %H:%M", tz = "UTC"),
    lat               = Lat,
    lon               = Long,
    water_depth_m     = `Water_Depth(m)`,
    recording_schedule = Recording_Schedule,
    soundfile_tz      = Soundfiles_TimeZone,
    location          = Location_Specific
  ) %>%
  arrange(site, deployed_utc) %>%
  group_by(site) %>%
  mutate(gap_before_h = as.numeric(difftime(deployed_utc, lag(retrieved_utc), units = "hours"))) %>%
  ungroup()
stopifnot(!any(is.na(deployments$deployed_utc)), !any(is.na(deployments$retrieved_utc)))
stopifnot(setequal(deployments$deployment_id, files$deployment_id))

# Known exception: one NS01 upcall in the 202107 log is stamped 2021-07-20
# 20:42:48, ~20 h before that deployment's metadata drop time (2021-07-21
# 17:00). It is a genuine delivered row and is kept; see docs/data_dictionary.md.
outside <- upcalls %>%
  left_join(select(deployments, deployment_id, deployed_utc, retrieved_utc), by = "deployment_id") %>%
  mutate(lead_h = as.numeric(difftime(deployed_utc, start_utc, units = "hours")),
         lag_h  = as.numeric(difftime(end_utc, retrieved_utc, units = "hours"))) %>%
  filter(lead_h > 1 | lag_h > 1) %>%
  select(site, deployment_id, start_utc, deployed_utc, retrieved_utc, lead_h, lag_h)
if (nrow(outside) > 0) {
  warning(sprintf("%d upcall(s) fall outside their deployment window by > 1 h:", nrow(outside)),
          immediate. = TRUE)
  print(outside)
}
stopifnot(all(outside$lead_h < 48), all(outside$lag_h < 48))

# Add per-deployment upcall counts to the deployments table.
deployments <- deployments %>%
  left_join(count(upcalls, deployment_id, name = "n_upcalls"), by = "deployment_id") %>%
  mutate(n_upcalls = coalesce(n_upcalls, 0L))

sites <- deployments %>%
  group_by(site) %>%
  summarise(lat = first(lat), lon = first(lon), location = first(location),
            first_deployed_utc = min(deployed_utc),
            last_retrieved_utc = max(retrieved_utc),
            n_deployments = n(), .groups = "drop") %>%
  left_join(sites_origin, by = "site") %>%
  left_join(upcalls %>% group_by(site) %>%
              summarise(n_upcalls = n(), first_upcall_utc = min(start_utc),
                        last_upcall_utc = max(end_utc), .groups = "drop"),
            by = "site")

# ── Parity with the legacy RDS files (if present) ────────────────────────────
legacy <- c(NS01 = "data/ns_01_all.rds", NS02 = "data/ns_02_all.rds",
            COX01 = "data/cox_01_all.rds")
for (s in names(legacy)) {
  if (!file.exists(legacy[[s]])) { cat("legacy", legacy[[s]], "absent; skipping parity check\n"); next }
  old <- readRDS(legacy[[s]]) %>% arrange(start_datetime)
  new <- upcalls %>% filter(site == s)
  ok <- nrow(old) == nrow(new) &&
    isTRUE(all.equal(as.numeric(old$start_datetime), as.numeric(new$start_utc))) &&
    isTRUE(all.equal(old$ts, new$ts_min))
  cat(sprintf("Parity %-5s vs %s: %s (n = %d)\n", s, legacy[[s]],
              if (ok) "IDENTICAL" else "MISMATCH", nrow(new)))
  if (!ok) stop("legacy parity check failed for ", s)
}

# ── Write ─────────────────────────────────────────────────────────────────────
write_parquet(upcalls,     file.path(release_dir, "upcalls.parquet"))
write_parquet(deployments, file.path(release_dir, "deployments.parquet"))
write_parquet(sites,       file.path(release_dir, "sites.parquet"))

cat("\nWrote:\n")
for (f in c("upcalls", "deployments", "sites")) {
  p <- file.path(release_dir, paste0(f, ".parquet"))
  cat(sprintf("  %-32s %8.1f kB\n", p, file.size(p) / 1024))
}
cat("\nSites:\n"); print(as.data.frame(sites))
cat("\nSchema (upcalls):\n"); print(read_parquet(file.path(release_dir, "upcalls.parquet"), as_data_frame = FALSE)$schema)
