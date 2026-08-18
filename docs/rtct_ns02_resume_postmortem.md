# NS02 rtct resume — false-alarm postmortem

**Date:** 2026-07-27 · **Scope:** the NS02 rtct timeout, the resume, and a
false "data mismatch" alarm I raised and then had to retract. Written so the
reasoning trail (and the mistake) is on record.

## One-line summary

A diagnostic command I wrote **hardcoded an assumed event count (33,611)**
taken from the laptop's *stale* copy of the NS02 data. When the cluster's real
count (**36,481**) surfaced in the resume log, I misread the discrepancy as "the
cluster data changed" and told the user to kill a **valid** job. The cluster had
been 36,481 all along; the resume was correct.

## What was actually true (established only at the end)

- Cluster `data/ns02.RData`: **36,481 events, dated Jun 24** — stable since then.
- NS02 fit (`ns02LGCPSE.RData`, Jul 12) trained on that 36,481 data.
- Original rtct (job 49745856, started ~Jul 13) ran on 36,481; timed out at the
  14-day walltime with 31,290/36,481 events checkpointed.
- Resume (job 50818928) loaded 36,481 and correctly reported `31290 of 36481`.
- The **laptop** copies (`data/ns02.RData` = 33,611; `rtct/ns02/…May23` =
  33,611; the earlier `08_qqDispersion` NS02 row = 33,611) are a **superseded,
  pre-Jun-24 vintage**. That is the only place 33,611 was ever real.

So: fit, original rtct, and resume were **all consistent at 36,481**. There was
no data mismatch on the cluster.

## Timeline: what I thought, what I said, what the evidence was

**1. Timeout reported.** User: NS02 rtct failed, 14-day timeout, 7-month run.
- *Thought:* NS02 is the highest-event buoy, single-threaded rtct is
  O(n_events × niters), so it blew the walltime.
- *Said/did:* read `04_rtctLGCPSE.R` (checkpoints every 10 events; has a
  commented resume line; loads `foreach` but runs a serial loop) and
  `aci_rtct.sh` (1 cpu, 14-day walltime). Recommended thinning; found
  `load_fit.R` already had a `thin` branch; added an `RTCT_THIN` env knob.
- *Evidence:* correct and uncontroversial.

**2. Progress check — THE ERROR.** To see how far the failed run got, I ran:
```r
Rscript -e 'e<-new.env();load(".../rtct/ns02/ns02LGCPSE_rtct.RData",envir=e);
            cat(nrow(e$postCompen),"of 33611\n")'
```
- *Thought:* NS02 has 33,611 events (from the laptop data + the `08` table).
- *Mistake:* I **hardcoded the string `"of 33611"`** rather than reading
  `length(ts)` from the cluster's own data. 33,611 was the laptop's stale count.
- *Evidence I ignored:* I never verified n_events against the cluster.

**3. "31290 of 33611" → pivot to resume.** User reported the output.
- *Thought:* 31,290/33,611 = 93% done — so close.
- *Said/did:* recommended **resume** over thinned restart (finishes in ~1 day,
  keeps full posterior, consistent with cox01/ns01). Added an `RTCT_RESUME` env
  knob with a guard against resume+thin. Committed both knobs (`f6f80bc`). Traced
  the resume logic **assuming 33,611 total** and concluded it was sound.
- *Evidence:* the 93% and the trace were both built on the wrong denominator,
  but internally consistent, so nothing flagged the error.

**4. Resume log shows 36,481.** First log line: `Resuming rtct from 31290 of
36481 events`.
- *Thought (WRONG):* 36,481 ≠ 33,611 ⇒ the cluster NS02 data **changed** since
  the original run (33,611 → 36,481). Therefore (a) the checkpoint can't be
  spliced — the Hawkes term `rtctSumIntHi(ts[i], ts, …)` integrates over the
  whole `ts`, so a changed `ts` invalidates prior rows; and (b) the data no
  longer matches the fit.
- *Said/did:* told the user to **`scancel 50818928`**, gave investigation
  commands, and floated rsync-ing the laptop's 33,611 data up to the cluster.
- *Why the wrong call felt right:* the laptop genuinely *was* 33,611, and the
  `08` table genuinely showed 33,611 — so a real-looking two-vintage discrepancy
  existed. But I'd anchored on 33,611 as the cluster truth, which it never was.

**5. Investigation exposes the error.** User ran `ls -l` + a count:
`data/ns02.RData` = **36,481 events, dated Jun 24**, untracked in git, no `.bak`.
- *Realization:* Jun 24 **predates** the fit (Jul 12) and the original rtct
  (~Jul 13). The cluster data didn't change — it has been 36,481 the whole time.
  The 33,611 was purely my hardcoded literal (from the stale laptop copy). The
  resume was valid; the `scancel` was unnecessary.

**6. Correction.** Re-submit the same resume (checkpoint intact, ~1 day). Do NOT
push the laptop's 33,611 data up — that would have been the *actual* corruption.
Flagged the laptop's NS02 as a stale vintage in `local_disk_inventory.md`.

## Root cause + contributing factors

- **Root cause:** hardcoding an assumed value (`"of 33611"`) into a diagnostic
  instead of reading it from the source (`length(ts)` on the cluster).
- **Contributing:** a *real* two-vintage discrepancy existed (laptop 33,611 vs
  cluster 36,481), so the phantom mismatch looked plausible; and the earlier
  `08_qqDispersion` NS02 row (also 33,611, also the stale vintage) reinforced the
  wrong anchor.
- **Cost:** one unnecessary `scancel` (minimal — checkpoint intact, job had just
  started) and a round of alarm.

## Preventions

1. **Never bake an expected number into a check** — compute it:
   `cat(nrow(postCompen), "of", length(ts), "\n")`.
2. **Resume hardening (proposed, not yet done):** on resume, `04_rtctLGCPSE.R`
   `load()`s the checkpoint's `ts`, which would silently mask a *genuine* data
   change. Add a guard comparing the checkpoint's `length(ts)` to the current
   data's before continuing.
3. **Confirm cross-buoy data vintage:** verify cox01 (8,806) and ns01 (22,784)
   share the Jun-24-era prep that produced NS02's 36,481.

## Current state

- Re-submit: `sbatch --export=ALL,BUOY=ns02,RTCT_RESUME=true aci_rtct.sh`.
- Laptop NS02 artifacts (data/rtct 33,611 + the 33,611 dispersion row) are stale;
  the 36,481 rtct + `aci_sum.sh` supersede them.
- Related: `docs/local_disk_inventory.md` (NS02 vintage note),
  `docs/manuscript_file_assembly_checklist.md` (rtct resume/thin knobs).
