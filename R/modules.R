# Python module introspection.
#
# Discover which modules are installed in the active Python environment and at
# what version, without importing heavy modules just to find out. Ported from
# fafbseg's py_module_info / module_version (see nat.python-plan.md §3b), but
# using the metadata (no-import) approach as the single introspector.

#' Report on installed Python modules
#'
#' @description Reports which of the named Python modules are installed and at
#'   what version *without importing* them — cheap, and safe for modules with
#'   heavy or side-effecting imports.
#'
#' @details Reads Python distribution metadata via `importlib.metadata` (or the
#'   `importlib_metadata` backport) together with `packages_distributions()` to
#'   map top-level import names onto installed distributions, so the target
#'   modules are never imported. Modules installed without standard distribution
#'   metadata (namespace packages, some editable installs) can therefore report
#'   as unavailable here even when they are importable; [module_version()] falls
#'   back to importing in that case.
#'
#' @param modules Character vector of Python module (import) names.
#'
#' @return A data frame with one row per unique module and columns `module`,
#'   `available`, `version`.
#' @export
#' @examples
#' \dontrun{
#' py_module_info(c("numpy", "pandas"))
#' }
py_module_info <- function(modules) {
  im <- tryCatch(
    reticulate::import("importlib.metadata", convert = FALSE),
    error = function(e)
      tryCatch(reticulate::import("importlib_metadata", convert = FALSE),
               error = function(e) NULL))

  if (is.null(im)) {
    modules <- unique(modules)
    return(data.frame(module = modules,
                      available = rep(FALSE, length(modules)),
                      version = rep("", length(modules)),
                      stringsAsFactors = FALSE))
  }

  modules <- unique(modules)
  versions <- character(length(modules))
  names(versions) <- modules
  available <- logical(length(modules))
  names(available) <- modules

  pkg_map <- tryCatch(reticulate::py_to_r(im$packages_distributions()),
                      error = function(e) NULL)

  for (m in modules) {
    dists <- character()
    if (!is.null(pkg_map) && !is.null(pkg_map[[m]]))
      dists <- unlist(pkg_map[[m]], use.names = FALSE)
    dists <- unique(c(dists, m))

    for (d in dists) {
      v <- tryCatch(reticulate::py_to_r(im$version(d)), error = function(e) "")
      if (!nzchar(v))
        next
      available[m] <- TRUE
      versions[m] <- v
      break
    }
  }

  df <- data.frame(module = modules,
                   available = available,
                   version = versions,
                   stringsAsFactors = FALSE)
  row.names(df) <- NULL
  df
}

#' The installed version of a Python module
#'
#' @description Returns the version string of an installed Python module, or
#'   `NA` if it is not available. The result is cached for the session; call
#'   `forget_module_version()` after installing or upgrading modules to clear it.
#'
#' @param module A single Python module (import) name.
#'
#' @return A version string, or `NA_character_` if the module is not installed.
#' @export
#' @examples
#' \dontrun{
#' module_version("numpy")
#' if (!is.na(module_version("pandas"))) message("pandas is available")
#' }
module_version <- function(module) {
  key <- paste0("modver_", module)
  cached <- .nat_python_cache[[key]]
  if (!is.null(cached))
    return(cached)
  pmi <- try(py_module_info(module), silent = TRUE)
  v <- if (!inherits(pmi, "try-error") && !is.null(pmi) && nrow(pmi) >= 1L &&
           nzchar(pmi$version))
    pmi$version
  else
    # metadata gave nothing (namespace/editable install, or importlib.metadata
    # unavailable): fall back to importing and reading __version__.
    module_version_by_import(module)
  .nat_python_cache[[key]] <- v
  v
}

# Import a module and read its __version__, for the cases where distribution
# metadata does not yield a version. Returns NA if it can't be imported.
module_version_by_import <- function(module) {
  mod <- tryCatch(reticulate::import(module), error = function(e) NULL)
  if (is.null(mod)) return(NA_character_)
  v <- tryCatch(mod$`__version__`, error = function(e) "")
  if (isTRUE(nzchar(v))) v else NA_character_
}

#' @description `forget_module_version()` clears the [module_version()] cache.
#' @rdname module_version
#' @return `forget_module_version()` returns `NULL` invisibly.
#' @export
forget_module_version <- function() {
  keys <- grep("^modver_", ls(.nat_python_cache, all.names = TRUE), value = TRUE)
  if (length(keys))
    rm(list = keys, envir = .nat_python_cache)
  invisible(NULL)
}

#' Check whether a Python module is available
#'
#' @description Tests whether a Python module can be imported, optionally warning
#'   or erroring with an install hint when it cannot. Generalises the per-package
#'   `*_available()` checks (e.g. fafbseg's `dracopy_available()`), which become
#'   thin wrappers that supply their own `install_hint`.
#'
#' @param module A single Python module (import) name.
#' @param action What to do when the module is missing: `"none"` (the default,
#'   just return `FALSE`), `"warning"`, or `"stop"`.
#' @param install_hint Optional character vector of extra lines appended to the
#'   warning/error message, e.g. how to install the module.
#'
#' @return `TRUE` or `FALSE`, invisibly when `action != "none"`.
#' @export
#' @examples
#' \dontrun{
#' module_available("numpy")
#' module_available("DracoPy", action = "stop",
#'   install_hint = "Install with fafbseg::simple_python('basic').")
#' }
module_available <- function(module, action = c("none", "warning", "stop"),
                             install_hint = NULL) {
  action <- match.arg(action)
  available <- isTRUE(reticulate::py_module_available(module))
  if (!available && action != "none") {
    FUN <- match.fun(action)
    FUN("The Python module '", module, "' is required but is not available.",
        if (!is.null(install_hint)) c("\n", install_hint) else NULL,
        call. = FALSE)
  }
  if (action == "none") available else invisible(available)
}
