# sne_ns01 data flow

How data moves through the LGCPSE pipeline, from raw buoy files to
figures and tables. Everything is parallel over the buoy axis
(`ns01 | ns02 | cox01`); each box below runs once per buoy.

```mermaid
flowchart TD
    subgraph raw["Raw inputs — data/ (gitignored, laptop)"]
        calls["Upcall detections<br/>ns_01_all.rds / ns_02_all.rds / cox_01_all.rds"]
        noise["Noise RMS<br/>&lt;buoy&gt;_rms_data.rds"]
        sst["SST (shared CSV)<br/>data/sst/2025-11-20_SNE_buoys_sst-data.csv"]
    end

    subgraph laptop1["Stage 1 — laptop"]
        s01["01_data.R<br/>filter to analysis window (Oct 2021 – Apr 2022)"]
    end

    calls --> s01
    noise --> s01
    sst --> s01
    s01 --> bdata["data/&lt;buoy&gt;.RData"]

    bdata -- "rsync up" --> cluster2

    subgraph cluster2["Stage 2 — cluster (SLURM)"]
        fit["aci_fit.sh → 02_fitLGCPSE.R<br/>MCMC fit (~days, niters_lgcp = 100000)"]
        ll["aci_ll.sh → 03_loglikLGCPSE.R<br/>post-burn −2 log L trace<br/>(afterok dependency on fit)"]
        fit --> fitout["fit/&lt;buoy&gt;/&lt;buoy&gt;LGCPSE.RData<br/>on /work scratch, mirrored to<br/>/hpc/group/schicklab (persistent)"]
        fitout --> ll
        ll --> llout["loglik/&lt;buoy&gt;/&lt;buoy&gt;LGCPSE_loglik.RData"]
    end

    llout -- "rsync down" --> s03

    subgraph laptop3["Stage 3 — laptop, human-in-the-loop"]
        s03["03_sumLoglik.R"]
        s03 --> trace["fig/&lt;buoy&gt;/NegTwoLogLikTrace.pdf"]
        trace --> inspect{"Chain stationary?"}
        inspect -- "no: raise burn in src/config.R,<br/>commit, re-sync, re-run aci_ll.sh only" --> ll
    end

    inspect -- yes --> cluster4
    fitout -- "read via src/load_fit.R" --> cluster4

    subgraph cluster4["Stage 4 — cluster (SLURM, 3 independent jobs)"]
        rtct["aci_rtct.sh → 04_rtctLGCPSE.R"]
        lam["aci_lam.sh → 04_lamLGCPSE.R"]
        num["aci_num.sh → 04_numLGCPSE.R"]
        rtct --> rtctout["rtct/&lt;buoy&gt;/"]
        lam --> lamout["lam/&lt;buoy&gt;/"]
        num --> numout["num/&lt;buoy&gt;/"]
    end

    rtctout -- "rsync down" --> stage5
    lamout -- "rsync down" --> stage5
    numout -- "rsync down" --> stage5

    subgraph stage5["Stage 5 — laptop: figures + tables"]
        stage5scripts["05_sumDIC.R · 05_sumEstM4.R · 05_sumRTCT.R<br/>05_sumXB.R · 05_sumNum.R · 05_sumLam.R<br/>(+ 05b/c/d RTCT zoom & window comparisons)"]
    end

    stage5 --> figs["fig/&lt;buoy&gt;/<br/>PDFs + LaTeX tables"]

    rtctout -. "rsync down" .-> diag

    subgraph diag["Diagnostics — laptop"]
        diagscripts["06_qqOutliers.R · 07_gapVsCoverage.R · 08_qqDispersion.R<br/>(all read rtct/) · 09_buoyMap.R (standalone map)"]
    end

    diag --> figs

    subgraph shared["Shared by every script"]
        config["src/config.R — buoy_settings (filenames, SST column,<br/>per-buoy burn), path resolution incl. 3-tier fit fallback"]
        rftns["src/RFtns.R — post-processing helpers"]
        loadfit["src/load_fit.R — fit loading"]
        cpp["src/ C++ (Rcpp/RcppArmadillo) — likelihood kernels"]
    end
```

## Key mechanics

- **Buoy is the parallelism axis.** Every script takes `--buoy=<b>` or
  `BUOY=<b>`; per-buoy constants (raw filenames, SST column, burn) are
  pinned in `buoy_settings` in `src/config.R`.
- **The laptop/cluster split exists because of stage 3.** The burn-in
  traceplot is a human decision point: edit `burn` in `src/config.R`,
  re-sync, and re-run only the cheap loglik job — the fit itself is
  unaffected by a burn change.
- **Fit storage has a 75-day clock.** `/work/rss10/sne_ns01/` (scratch)
  is wiped after 75 days; `02_fitLGCPSE.R` mirrors finished fits to
  `/hpc/group/schicklab/sne_ns01/fit/<buoy>/`. `src/config.R` resolves
  `path.fit` scratch → share → local `./fit/`, so the same code runs
  anywhere. All other artifact dirs (`loglik/`, `rtct/`, `lam/`,
  `num/`, `fig/`, `data/`) are always local to the working directory
  and moved by rsync.
- **Side pipelines** not on the critical path: `benchmark_*` /
  `run_laptop_benchmark.sh` (GP-resolution benchmarking),
  `RScripts/` sun-time utilities (`calc_suntimes.R`,
  `plot_suntimes.R`, `minute_histogram.R`), and `proto_spline/`.
