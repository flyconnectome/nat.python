# Python module introspection.
#
# Discover which modules are installed in the active Python environment and at
# what version, without importing heavy modules just to find out. Ported from
# fafbseg's py_module_info / module_version (see nat.python-plan.md §3b), but
# using the metadata (no-import) approach as the single introspector.
# check_module() is the generic install/load gate abstracted from fafbseg's
# check_seatable / check_cloudvolume_reticulate; the environment engine it uses
# (check_reticulate / simple_python) lives in env.R.

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

#' Ensure a Python module is installed and importable
#'
#' @description A generic gate for code that needs a particular Python module:
#'   it checks the module is installed, imports it, optionally enforces a minimum
#'   version, and — when it is missing — either installs it (interactively or on
#'   request) or errors with actionable guidance. Package-specific checks (such
#'   as fafbseg's `check_seatable()` / `check_cloudvolume_reticulate()`) become
#'   thin wrappers over this.
#'
#' @details The check is deliberately ordered **installed-first, load-second**,
#'   because the two failure modes need different advice. Installation is
#'   detected from Python distribution metadata via [py_module_info()] (which
#'   does not import the module), falling back to `reticulate::py_module_available()`
#'   for namespace/local packages that lack metadata. Only once the module is
#'   known to be installed is it actually imported, so an import that fails then
#'   is reported as a *load* problem (a broken or mismatched environment),
#'   distinct from the package simply being absent — with the underlying Python
#'   error surfaced.
#'
#'   The result is memoised for the session, so repeated calls for the same
#'   module are cheap and hand back the already-imported module object. Any
#'   installation via [simple_python()] clears this cache (as well as the
#'   [module_version()] cache), so the next call re-checks and picks up the
#'   newly installed package. Because of this, package-specific wrappers need
#'   not memoise themselves.
#'
#' @param module A single Python module (import) name, e.g. `"seatable_api"`.
#' @param package The pip package (distribution) name to install if `module` is
#'   missing. Defaults to `module`; supply it when they differ (e.g. import
#'   `"cv2"` from package `"opencv-python"`).
#' @param min_version Optional minimum acceptable version (character or
#'   [numeric_version]). Checked on every call via [module_version()].
#' @param install How to handle a missing module: `"ask"` (the default) prompts
#'   in an interactive session and otherwise errors; `"never"` always errors with
#'   install instructions; `"always"` installs without prompting.
#' @param install_cmd The bundle argument passed to [simple_python()] when
#'   installing (default `"none"`, i.e. install only `package`). Use e.g.
#'   `"basic"` to pull a whole ecosystem bundle instead.
#' @param docs_url Optional documentation URL added to the failure message.
#' @param cache Whether to use (and populate) the session cache of results
#'   (default `TRUE`). Pass `FALSE` to force a fresh check — e.g. after
#'   installing or upgrading the module out of band.
#'
#' @return The imported module (a reticulate object), invisibly.
#' @export
#' @examples
#' \dontrun{
#' seatable_api <- check_module("seatable_api")
#' cv <- check_module("cloudvolume", install_cmd = "basic", min_version = "5.0",
#'                    docs_url = "https://github.com/seung-lab/cloud-volume#setup")
#' }
check_module <- function(module,
                         package = module,
                         min_version = NULL,
                         install = c("ask", "never", "always"),
                         install_cmd = "none",
                         docs_url = NULL,
                         cache = TRUE) {
  stopifnot(is.character(module), length(module) == 1L)
  install <- match.arg(install)
  # Route through the memoised copy or the raw guts. Keeping the guts in a plain
  # function (check_module_impl) means cache = FALSE never touches the memoise
  # store, and this wrapper keeps real formals for its documentation.
  FUN <- if (isTRUE(cache)) check_module_memoised else check_module_impl
  FUN(module, package, min_version, install, install_cmd, docs_url)
}

# The guts of check_module(). Kept un-memoised so check_module(cache = FALSE)
# can call it directly; check_module_memoised is the cached copy used by
# default.
check_module_impl <- function(module, package, min_version,
                              install, install_cmd, docs_url) {
  check_reticulate()

  installed <- module_installed(module)
  if (!installed) {
    do_install <- switch(install,
      always = TRUE,
      never = FALSE,
      ask = interactive() &&
        tolower(readline(sprintf(
          "Install the Python '%s' package now (y/n)? ", package))) == "y")
    if (do_install) {
      simple_python(pyinstall = install_cmd, pkgs = package)
      installed <- module_installed(module)
    }
    if (!installed) module_missing_abort(module, package, install_cmd, docs_url)
  }

  # Installed, so import it. A failure here is a load problem, not absence.
  mod <- tryCatch(reticulate::import(module),
                  error = function(e) module_load_abort(module, e, docs_url))

  if (!is.null(min_version)) {
    v <- module_version(module)
    if (is.na(v) || !isTRUE(numeric_version(v) >= min_version))
      cli::cli_abort(c(
        "The Python module {.pkg {module}} is too old.",
        "x" = "Need version {min_version} but found {if (is.na(v)) 'unknown' else v}.",
        "i" = "Update with {.run nat.python::simple_python(pkgs = \"{package}\")}."))
  }
  invisible(mod)
}

# The cached copy of check_module_impl(). Caches the imported module for the
# session; simple_python() calls forget_check_module() after installing so a
# fresh check picks up newly installed packages. Only successful returns are
# cached (errors propagate uncached), so a failed check is retried.
check_module_memoised <- memoise::memoise(check_module_impl)

# Clear the check_module() memoise cache. Called by simple_python() after an
# install, and by tests between cases.
forget_check_module <- function() {
  memoise::forget(check_module_memoised)
  invisible(NULL)
}

# Is the module installed, per distribution metadata (no import), with a
# find_spec fallback for namespace/local packages that lack metadata?
module_installed <- function(module) {
  info <- try(py_module_info(module), silent = TRUE)
  if (!inherits(info, "try-error") && !is.null(info) && isTRUE(info$available[1]))
    return(TRUE)
  isTRUE(reticulate::py_module_available(module))
}

module_missing_abort <- function(module, package, install_cmd, docs_url) {
  cli::cli_abort(c(
    "The Python module {.pkg {module}} is required but not installed.",
    "i" = "Install it with {.run nat.python::simple_python(pkgs = \"{package}\")}.",
    if (!identical(install_cmd, "none"))
      c("i" = "Or install the bundle: {.run nat.python::simple_python(\"{install_cmd}\")}.")
    else NULL,
    if (!is.null(docs_url)) c("i" = "See {.url {docs_url}}.") else NULL))
}

module_load_abort <- function(module, e, docs_url) {
  cli::cli_abort(c(
    "The Python module {.pkg {module}} is installed but failed to load.",
    "x" = conditionMessage(e),
    "i" = paste("This is usually an environment problem, not a missing package:",
                "R may be pointing at the wrong Python."),
    "i" = "Check/point {.envvar RETICULATE_PYTHON} via {.run usethis::edit_r_environ()}, e.g.",
    " " = "{.code RETICULATE_PYTHON=\"/opt/miniconda3/envs/r-reticulate/bin/python\"}",
    if (!is.null(docs_url)) c("i" = "See {.url {docs_url}}.") else NULL))
}
