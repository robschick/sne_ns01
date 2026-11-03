# =============================================================================
# 03_driftCheck.R — Is a chain still drifting in the quantities we report?
#
# Prints posterior means of alpha, eta, answers per call (alpha/eta), log delta,
# the mean GP level, and the intercept / noise / SST coefficients in blocks of
# DRIFT_BLOCK iterations from DRIFT_FROM to the end of the chain. A flat
# -2 log L is not required if these are flat; a drifting eta (as NS01 showed
# over 50k-100k) means the chain needs extending.
#
# Usage:   Rscript 03_driftCheck.R --buoy=ns02      (compute node: NS02 needs ~64G)
# Env:     DRIFT_FROM   first iteration to keep (default 50000)
#          DRIFT_BLOCK  block length (default 10000)
# Output:  printed table; also out/drift_<buoy>.csv
# =============================================================================

rm(list = ls()); invisible(gc())

source('src/config.R')

from  <- as.integer(Sys.getenv('DRIFT_FROM', 50000))
block <- as.integer(Sys.getenv('DRIFT_BLOCK', 10000))

fiti <- fiti_lgcp
burn <- from                 # load_fit.R drops the first `burn` iterations
source('src/load_fit.R')     # postSamples, postWm, Xm, betaInd, deltaInd, alphaInd, etaInd

cn  <- colnames(Xm)
col <- function(nm, fallback) if (!is.null(cn) && nm %in% cn) which(cn == nm) else fallback
it  <- from + seq_len(nrow(postSamples))
grp <- from + block * ((it - from - 1) %/% block)

summ <- function(rows) {
  s <- postSamples[rows, , drop = FALSE]
  c(alpha     = mean(s[, alphaInd]),
    eta       = mean(s[, etaInd]),
    answers   = mean(s[, alphaInd] / s[, etaInd]),
    log_delta = mean(s[, deltaInd]),
    gp_level  = mean(postWm[rows, ]),
    intercept = mean(s[, betaInd[1]]),
    noise     = mean(s[, betaInd[col('noise', 2)]]),
    sst       = mean(s[, betaInd[col('sst', 3)]]))
}

tab <- do.call(rbind, lapply(split(seq_along(it), grp), summ))
tab <- data.frame(block = sprintf('%dk-%dk', as.integer(rownames(tab)) / 1000,
                                  (as.integer(rownames(tab)) + block) / 1000),
                  round(tab, 3))

cat(sprintf('\n%s: iterations %d-%d in blocks of %d\n\n', buoy, from + 1, max(it), block))
print(tab, row.names = FALSE)

dir.create('out', showWarnings = FALSE)
write.csv(tab, file.path('out', paste0('drift_', buoy, '.csv')), row.names = FALSE)
cat('\nWrote out/drift_', buoy, '.csv\n', sep = '')
