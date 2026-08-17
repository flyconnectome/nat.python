# Internal utilities shared across nat.python.
#
# Kept dependency-light on purpose: reticulate and bit64 are the only hard
# Imports (see nat.python-plan.md §8.3), so caching that fafbseg did with
# memoise is done here with a plain environment instead.

# Session cache for expensive-to-recreate handles (the numpy module) and for
# module version lookups. Cleared with forget_module_version().
.nat_python_cache <- new.env(parent = emptyenv())

# Ensure a Suggested package is installed, with an actionable message. Used for
# the optional arrow / tibble code paths so the base install stays light.
check_suggested <- function(pkg, purpose = NULL) {
  if (!requireNamespace(pkg, quietly = TRUE))
    stop("The '", pkg, "' package is required",
         if (!is.null(purpose)) paste0(" ", purpose) else "",
         ". Install it with install.packages('", pkg, "').", call. = FALSE)
  invisible(TRUE)
}

# Import (and cache) numpy once per session. convert = FALSE keeps numpy arrays
# as Python objects so their dtype/size can be inspected before conversion.
py_np <- function(convert = FALSE) {
  key <- paste0("np_", isTRUE(convert))
  np <- .nat_python_cache[[key]]
  if (is.null(np)) {
    np <- reticulate::import("numpy", as = "np", convert = convert)
    .nat_python_cache[[key]] <- np
  }
  np
}
