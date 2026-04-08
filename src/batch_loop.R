# =============================================================================
# batch_loop.R — Generic checkpoint/resume batch loop
#
# run_batch(fn, n_items, batch_size, filename, result_name, start_row)
#
# Arguments:
#   fn          — function(idx) returning a matrix/vector of rows to accumulate
#   n_items     — total number of items (iterations or events) to process
#   batch_size  — how many items per save checkpoint
#   filename    — .RData file for intermediate saves; must save a variable
#                 whose name matches `result_name`
#   result_name — name of the accumulator variable (default "result")
#   start_row   — resume from this row (0 = start fresh; set by loading
#                 a previous run and checking nrow of the result)
#
# Returns the accumulated result matrix invisibly.
#
# Usage example (loglik):
#   postLogLik <- run_batch(
#     fn = function(idx) sapply(idx, function(iter) compLogLiki(...)),
#     n_items    = niters,
#     batch_size = 1000,
#     filename   = filename,
#     result_name = 'postLogLik'
#   )
# =============================================================================

run_batch <- function(fn, n_items, batch_size, filename,
                      result_name = 'result', start_row = 0) {

  aaa <- unique(c(0, seq(batch_size, n_items, by = batch_size), n_items))

  if (start_row > 0 && file.exists(filename)) {
    load(filename)
    result <- get(result_name)
    start  <- which(aaa == start_row)
    if (length(start) == 0) stop('start_row not found in batch breakpoints')
  } else {
    result <- NULL
    start  <- 1
  }

  for (aa in (start + 1):length(aaa)) {
    idx    <- (aaa[aa - 1] + 1):aaa[aa]
    chunk  <- fn(idx)
    result <- rbind(result, chunk)
    cat('Completed', aaa[aa], 'of', n_items, '\n')
    assign(result_name, result)
    save(list = result_name, file = filename)
  }

  assign(result_name, result)
  save(list = result_name, file = filename)
  invisible(result)
}
