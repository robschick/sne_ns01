# Local disk inventory — what's on the laptop

**Snapshot:** 2026-08-06 (was 2026-07-25) · **Repo:** `/Users/rob/Documents/_research/git_repos/sne_ns01`

> ## ⛔ CORRECTION 2026-08-06 — the NS02 "7-month" label below was WRONG
>
> This doc (and `rtct_ns02_resume_postmortem.md`) labelled the laptop's NS02
> `data/` + `rtct/` as **"7-mo (33,611) — STALE"**. They are **5-MONTH**:
> `ts`max = 215,995 min ≈ **day 150 (Mar 1)**, not 305k/day 211.
>
> **33,611 is the 5-month NS02 count. 36,481 is the 7-month count.** The
> postmortem anchored on 33,611 as a stale *7-month* vintage; in fact the two
> numbers are different *windows*, not different vintages of the same window.
> (The postmortem's action — don't rsync the laptop data up — was still right.)
>
> **Consequence:** the claim repeated across these docs that there is *"no
> 5-month ns02 rtct anywhere"* is **false**. There is one, on this laptop, and it
> is the source of the near-ideal NS02 5-month dispersion row. This removes the
> principal obstacle to a 5-month-primary manuscript.
>
> **Lesson (same as the postmortem's):** verify a window by reading `max(ts)`,
> never by inferring it from an event count or a file date.

> ## Tree is now uniformly 5-MONTH (2026-08-06)
>
> Canonical paths (`data/<buoy>.RData`, `rtct/<buoy>/<buoy>LGCPSE_rtct.RData`,
> `fig/`) all hold **5-month** artifacts. Both windows are kept, window-suffixed,
> so an rsync from the node can no longer silently clobber the other window:
>
> | canonical (5-mo, active) | parked |
> |---|---|
> | `data/{ns01,ns02,cox01}.RData` | `data/cox01.RData.7mo`; `*.5mo` labelled copies of all three |
> | `rtct/<b>/<b>LGCPSE_rtct.RData` | `.5mo` + `.7mo` suffixed copies; `cox01LGCPSEspl_rtct.RData` (7-mo spline) |
> | `fig/cox01/QQband*.pdf`, `QQmsd.tex` | `fig/cox01/*.7mo-spline.*` |
> | `fig/combined/qq_dispersion.*` | `fig/combined/qq_dispersion.MIXED.*` |
>
> `src/config.R` `seasonal_spline_by_buoy['cox01']` set **FALSE** (the spline is a
> 7-month-only object). ⚠️ `analysis_end` in config is still **2022-04-30** — it
> only matters if `01_data.R` is re-run, which would require a re-fit anyway.

A window-tagged census of manuscript-relevant artifacts on **this machine**, so
we know what can be assembled locally vs. what must come from the node. Windows
verified by event count / `ts` axis, not just file dates:
**5-month** = Oct 1 → ~Mar 1 (`ts`max ≈ 217k min; cox01 6098 / ns01 13017 ev),
**7-month** = Oct 1 → Apr 30 (`ts`max ≈ 305k min; cox01 8806 / ns01 22784 / ns02 33611 ev).

## TL;DR

- **No production fit objects are local** (only April benchmark runs). All four
  production fits live on the node (`/work` + `/hpc` mirror) — see
  `manuscript_file_assembly_checklist.md`.
- **`fig/`, `fig/combined/`, and `data/` are all a 5-mo / 7-mo MIX.** Assembling
  straight from them risks combining windows. Make each uniform before building.
- **5-month parameter outputs exist** (Jun 22, all buoys) — a 5-mo paper needs no
  re-fit. **7-month parameter outputs do not exist** — they'd be regenerated from
  the (existing) 7-mo fits on the node.
- `loglik/`, `lam/`, `num/` directories are **absent locally**.

## Per-buoy coverage (local only)

| buoy | data | rtct | fit | params (DIC/XB/coeffs/Lam/Num/CI) | Q-Q |
|---|---|---|---|---|---|
| **ns01** | 5-mo (13017) | 5-mo `.5mo` + 7-mo `.7mo`/base | none (benchmark only) | 5-mo (Jun 22) | 5-mo (Jun 22) + 5v7 windowCompare (Jul 14) |
| **ns02** | **5-mo (33611)** | **5-mo (33611)** | none | 5-mo (Jun 22) | 5-mo (Jun 22) |

> **✅ NS02 resolved (2026-08-06)** — supersedes the 07-27 "vintage mismatch" note.
> The laptop's ns02 `data` + `rtct` are **5-month (33,611 ev, `ts`max day 150)**,
> verified by `max(ts)`. They are not a stale 7-month vintage. The cluster's
> 36,481 is the **7-month** NS02 — a different window, not a newer vintage of the
> same one. Both are valid; they answer different questions. NS02 is therefore
> **fully covered at 5-month locally** (data + rtct + params + Q-Q).
| **cox01** | 7-mo (8806) + 5-mo bak | 7-mo (8806, spline+non-spline); 5-mo in `cmp_old/` (6098) | none | 5-mo (Jun 22) | **7-mo (Jul 24)** + 5-mo in `cmp_old/` |

**Coherence notes (rewritten 2026-08-06)**
- **5-month is internally consistent for all three buoys.** data + rtct + params
  + Q-Q are present locally for ns01, ns02 and cox01, and each buoy's `data` and
  `rtct` event counts match exactly (13017 / 33611 / 6098).
- The Jun-22 params were built at **sback = 20**, confirmed structurally: each
  `fig/<buoy>/xb.RData` has exactly `3 × (maxT/20 + 1)` rows against that buoy's
  own 5-month `maxT` (10873 / 10801 / 10762). `knts` is read from the fit file by
  `src/load_fit.R`, not rebuilt from config, so the row count reflects the **fit's**
  sback — i.e. the 5-month fits themselves were sback = 20.
- cox01's `fig/` self-inconsistency is **resolved**: the 5-mo Q-Q from `cmp_old/`
  is now at the canonical path; the Jul-24 7-mo spline Q-Q is parked as
  `*.7mo-spline.*`.

## Directory detail

### `fit/` — no production fits
Only `fit/*/benchmark/**` (April GP-resolution sweep, `phase2_fit.RData` etc.).
No `fit/<buoy>/<buoy>LGCPSE.RData`. Production fits are node-only.

### `rtct/`
| file | n_ev | window |
|---|---|---|
| `cox01/cox01LGCPSE_rtct.RData` | 8806 | 7-mo (non-spline) |
| `cox01/cox01LGCPSEspl_rtct.RData` | 8806 | 7-mo (spline) |
| `ns01/ns01LGCPSE_rtct.5mo.RData` | 13017 | 5-mo |
| `ns01/ns01LGCPSE_rtct.7mo.RData` / base | 22784 | 7-mo |
| `ns02/ns02LGCPSE_rtct.RData` | 33611 | 7-mo |

### `loglik/`, `lam/`, `num/` — ABSENT
Not present locally. `fig/` has `Lam.pdf`/`Num.tex` (Jun 22, 5-mo), so the *5-mo*
lam/num figures were rendered, but the source `lam/`,`num/` RData were never kept
locally. 7-mo lam/num do not exist here at all.

### `fig/<buoy>/`
- **5-month (Jun 22):** `DIC.*`, `XB_*.pdf`, `xb.RData`, `Lam.pdf`,
  `LamTotalRug_*.pdf`, `Num.tex`, `CI.pdf`, `background_excitement_coeffs_table.tex`,
  and (ns01/ns02) `QQband.pdf`/`QQmsd.tex`.
- **7-month:** cox01 `QQband*`/`QQmsd.tex` (Jul 24, spline).
- **Both-window compare:** ns01 `QQband_windowCompare*.pdf` (Jul 14).

### `fig/combined/`
- **5-mo:** `combined_coeffs.{csv,tex}`, `combined_counts.{csv,tex}` (Jun 22),
  `QQband_allbuoys.pdf` (Jun 26).
- **7-mo:** `qq_dispersion.{csv,tex}` (Jul 24).

### `data/`
| file | n_ev | window |
|---|---|---|
| `cox01.RData` | 8806 | 7-mo (current) |
| `cox01.RData.oldwindow.bak` | 6098 | 5-mo (backup) |
| `ns01.RData` | 13017 | **5-mo (stale vs 7-mo fit)** |
| `ns02.RData` | 33611 | 7-mo |

Plus raw inputs (`*_all.rds`, `*_rms_data.rds`, `*_start_dates.rds`), `nopp.RData`.
**Gotcha:** local ns01 data is 5-mo — a *local* 7-mo ns01 summarize would be wrong;
pull 7-mo ns01 data from the node (or run summaries on the node).

### `cmp_old/` — 5-month cox01 snapshot (kept for comparison)
`rtct/cox01/...RData` (6098) + `fig/cox01/QQband*` + `fig/combined/*` (dispersion,
coverage, gap). This is the **5-mo non-spline cox01** reference.

### `cmp_new/` — 7-month spline cox01 snapshot
`rtct/cox01/...RData` (8806) + `fig/cox01/QQband*` + `fig/combined/*`. The **7-mo
spline cox01** reference.

### `archive/`
Old R scripts (`fitNHPPSE_parallel.R`, `sumEstM4.R`, `rtctLGCPSE.R`, …) — prior
code generations, not manuscript data.

## What's missing locally (by window)

- **Production fits:** all (node-only; safe on `/hpc` mirror).
- **7-month params:** DIC/XB/coeffs/Lam/Num/CI for all buoys — regenerate from
  7-mo fits on the node, pull `fig/`.
- **5-month ns02:** no 5-mo data or rtct locally (5-mo params exist but are
  non-regenerable here).
- **`loglik/`, `lam/`, `num/`** for either window.

## Node holdings (`/hpc/group/schicklab/sne_dev/`, verified 2026-07-25)

**All derived outputs on the node are 7-month** (each postdates its 7-mo fit:
cox01 Jun 27 / ns01 Jul 2 / ns02 Jul 12). The node is the mirror image of the
laptop: it has the 7-mo *derived layer*, the laptop has the 5-mo *figures*.

| type | cox01 | ns01 | ns02 |
|---|---|---|---|
| loglik | LGCPSE (Jun 27) + spl (Jul 15) | Jul 4 | Jul 18 |
| lam | LGCPSE (Jun 27) + spl (Jul 17) | Jul 3 | Jul 14 |
| num | LGCPSE (Jun 27) + spl (Jul 15) | Jul 2 | Jul 13 |
| rtct | LGCPSE (Jul 24) + spl (Jul 24) | Jul 13 | **Jul 25** (fresh) |

- **Node `fig/` is essentially empty** — only a stale `fig/combined/qq_dispersion`
  (Jul 9). Summaries have always been rendered on the laptop.
- So **7-month assembly is tractable with no re-fit and no re-run of lam/num/loglik**:
  run `05_sumLam`/`05_sumNum`/`05_sumDIC` against the existing 7-mo derived files,
  and `05_sumEstM4`/`05_sumXB` against the 7-mo fits (present), on the node → pull `fig/`.

**Two flags (2026-07-25):**
1. **ns02 7-mo rtct is now done** (`ns02LGCPSE_rtct.RData`, Jul 25 12:00; old one
   kept as `.May23`). Ready to pull.
2. **⚠️ Regenerated cox01 non-spline rtct looks broken** —
   `cox01LGCPSE_rtct.RData` on the node is Jul 24, **38K** (vs spline 1.1M, vs the
   good *local* 624K/8806-ev copy). Likely a truncated `postCompen`. Verify
   `nrow(postCompen)==8806` before pulling; do NOT overwrite the good local copy.
   The local Jun-29 624K non-spline rtct (dated after the Jun-27 fit) is very
   likely already the matched control.

## Still open (minor)
- Node per-buoy DATA window, esp. ns01 (local is stale 5-mo):
  ```bash
  Rscript -e 'for (b in c("cox01","ns01","ns02")) {
    e <- new.env(); load(paste0("data/", b, ".RData"), envir = e)
    cat(b, nrow(e$data), "\n") }'
  ```
  (Fits confirmed present on `/work` + `/hpc` mirror — see the checklist doc.)

## Related docs
- `docs/manuscript_file_assembly_checklist.md` — preservation + per-table needs + window decision.
- `docs/cox01_nonspline_rtct_regen.md` — the matched non-spline rtct run.
- `docs/rtct_ll_pulldown_runbook.md` — pull-down + summarize + footguns.
