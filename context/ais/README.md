# AIS vessel-traffic context

Side analysis for the NARWC talk: how much AIS-tracked vessel traffic passes
within 10 km of each hydrophone, in the analysis winter (Oct 2021 – Feb 2022)
and the prior winter. Not part of the Hawkes model pipeline. Leave this folder
out of a model-only release.

Spec and build plan: `docs/ais_context_spec.md`.

## Run

From the repo root, with `GFW_TOKEN` set in `~/.Renviron`:

```sh
Rscript context/ais/01_download.R
```

Responses are cached in `cache/` (gitignored). Reruns only fetch what's missing.

## Data sources and attribution

- **Global Fishing Watch**, AIS vessel presence (`public-global-presence`,
  v5.0), via the 4Wings API. Licence CC BY-NC 4.0. Slide and paper credit:
  "Vessel presence: Global Fishing Watch (globalfishingwatch.org)."
