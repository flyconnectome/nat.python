# Can we import a given Python module? Tests that need Python are skipped when
# it (or the module) is unavailable, so the suite still runs with no Python.
py_module_ok <- function(module) {
  requireNamespace("reticulate", quietly = TRUE) &&
    !inherits(try(reticulate::import(module), silent = TRUE), "try-error")
}

skip_if_no_module <- function(module) {
  testthat::skip_if_not(py_module_ok(module),
                        paste0("Python module '", module, "' not available"))
}
