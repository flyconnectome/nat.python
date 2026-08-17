# Python module introspection.
#
# Discover which modules are installed in the active Python environment and at
# what version, without importing heavy modules just to find out. Ported from
# fafbseg's py_module_info / py_module_info2 / module_version / python_module_path
# (see nat.python-plan.md §3b). py_report is deliberately deferred to Phase 2,
# because it depends on the environment engine (check_reticulate /
# ownpythonrequested) and carries a consumer-curated package list.

#' Report on installed Python modules
#'
#' @description `py_module_info()` imports each module and reads its version and
#'   filesystem path. `py_module_info2()` answers the same "is it installed and
#'   what version" question *without* importing the modules, by reading Python
#'   distribution metadata — much cheaper, and safe for heavy modules, at the
#'   cost of no path column.
#'
#' @details `py_module_info()` imports each module (so a module with import side
#'   effects will run them) and is the only variant that can report the on-disk
#'   `path`. `py_module_info2()` uses `importlib.metadata` (or the
#'   `importlib_metadata` backport) together with `packages_distributions()` to
#'   map top-level import names onto installed distributions, so it never imports
#'   the target module.
#'
#' @param modules Character vector of Python module (import) names.
#'
#' @return A data frame with one row per unique module. `py_module_info()` has
#'   columns `module`, `available`, `version`, `path`; `py_module_info2()` has
#'   `module`, `available`, `version`. Returns `NULL` if reticulate is not
#'   installed.
#' @export
#' @examples
#' \dontrun{
#' py_module_info(c("numpy", "pandas"))
#' py_module_info2(c("numpy", "pandas"))   # without importing them
#' }
py_module_info <- function(modules) {
  if (!requireNamespace("reticulate", quietly = TRUE))
    return(NULL)
  modules <- unique(modules)
  paths <- character(length(modules))
  names(paths) <- modules
  versions <- character(length(modules))
  names(versions) <- modules
  available <- logical(length(modules))
  names(available) <- modules

  for (m in modules) {
    mod <- tryCatch(reticulate::import(m), error = function(e) NULL)
    available[m] <- !is.null(mod)
    if (!available[m])
      next
    paths[m] <- python_module_path(mod)
    versions[m] <- tryCatch(mod$`__version__`, error = function(e) "")
  }
  df <- data.frame(module = modules,
                   available = available,
                   version = versions,
                   path = paths,
                   stringsAsFactors = FALSE)
  row.names(df) <- NULL
  df
}

#' @rdname py_module_info
#' @export
py_module_info2 <- function(modules) {
  if (!requireNamespace("reticulate", quietly = TRUE))
    return(NULL)

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
  v <- if (inherits(pmi, "try-error") || is.null(pmi) || nrow(pmi) < 1L)
    NA_character_
  else if (nzchar(pmi$version)) pmi$version else NA_character_
  .nat_python_cache[[key]] <- v
  v
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

# Extract a module's filesystem path, coping with namespace packages whose
# __path__ is a _NamespacePath repr rather than a plain character vector.
python_module_path <- function(mod) {
  tryCatch({
    path <- mod$`__path__`
    if (!is.character(path)) {
      # e.g. "_NamespacePath(['/Users/paulbrooks/igneous', ''])"
      path <- as.character(path)
      path2 <- sub(".+?\\[(.+)\\].+?", "\\1", path)
      scan(what = "", sep = ",", text = path2, quiet = TRUE)
    } else path
  }, error = function(e) "")
}
