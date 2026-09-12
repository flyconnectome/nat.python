# Classify a Python module's availability in the active environment. We keep the
# three cases apart on purpose (see skip_if_no_module):
#   * "ok"      -- importable, run the test;
#   * "absent"  -- no Python, or the module simply isn't installed -> skip;
#   * "broken"  -- the module *is* installed (per distribution metadata) but
#                  importing it fails -> a broken environment, not absence.
# The old helper collapsed "broken" into "absent", so an installed-but-
# unimportable module (e.g. a conda pandas built against an incompatible numpy)
# silently skipped and quietly dropped coverage instead of being noticed.
py_module_status <- function(module) {
  if (!requireNamespace("reticulate", quietly = TRUE))
    return(list(state = "absent", error = NA_character_))
  if (!isTRUE(try(reticulate::py_available(initialize = TRUE), silent = TRUE)))
    return(list(state = "absent", error = NA_character_))

  # Try importing first: a clean import is the fast path, and it also covers
  # stdlib/namespace modules that carry no distribution metadata (e.g. datetime).
  imported <- try(reticulate::import(module), silent = TRUE)
  if (!inherits(imported, "try-error"))
    return(list(state = "ok", error = NA_character_))

  err <- conditionMessage(attr(imported, "condition"))

  # Import failed. Is the module nonetheless installed, per distribution
  # metadata (which does not import it)? If so, this is a broken environment.
  installed <- tryCatch(isTRUE(nat.python::py_module_info(module)$available[1]),
                        error = function(e) FALSE)

  list(state = if (installed) "broken" else "absent", error = err)
}

# Skip a test when a Python module is unavailable, but fail loudly when it is
# installed yet unimportable -- nat.python's job is to provision a working
# Python, so a broken module must never masquerade as a benign skip.
skip_if_no_module <- function(module) {
  st <- py_module_status(module)
  if (identical(st$state, "ok"))
    return(invisible(TRUE))
  if (identical(st$state, "broken"))
    stop(sprintf("Python module '%s' is installed but failed to import: %s",
                 module, st$error), call. = FALSE)
  testthat::skip(paste0("Python module '", module, "' not available"))
}
