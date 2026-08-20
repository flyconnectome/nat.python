# Python environment engine.
#
# The mechanics of environment provisioning, ported near-verbatim from fafbseg's
# simple_python family (utils.R). fafbseg keeps its exported simple_python()
# front-end and delegates the mechanics here; seatabler and others depend on
# nat.python and call simple_python() / check_module() directly. Messaging uses
# cli rather than fafbseg's usethis ui_* helpers; the fafbseg.condaenv option is
# generalised to nat.python.condaenv (default "r-reticulate").

# The conda environment nat.python manages by default. Consumers may override
# with options(nat.python.condaenv = ...).
np_condaenv <- function() getOption("nat.python.condaenv", "r-reticulate")

#' Install a managed Python environment for R
#'
#' @description Sets up (and optionally populates) a dedicated miniconda Python
#'   environment for use from R via reticulate. This is the ecosystem's shared
#'   provisioning entry point: packages such as fafbseg, bancr and seatabler all
#'   route their Python installation through it, so users have one command to
#'   run and one environment to manage.
#'
#' @details With `miniconda = TRUE` (the default and recommendation) a private
#'   miniconda install and `r-reticulate` conda environment are created/updated,
#'   independent of any system Python. The `pyinstall` bundles install a curated
#'   set of packages used across the FlyWire/connectomics ecosystem:
#'   `"minimal"` installs just pandas -- nat.python's own baseline, needed by
#'   [pandas2df()], with numpy coming in as its dependency; `"basic"` adds
#'   cloud-volume, seatable_api and CAVEclient on top; `"full"` adds navis +
#'   fafbseg; `"extra"` additionally installs skeletonisation tooling (skeletor,
#'   meshparty and friends). `"none"` provisions the environment but installs
#'   no bundle, which is what you want when passing your own `pkgs`.
#'   `"cleanenv"` and `"blast"` only print the (destructive) commands needed to
#'   remove an environment; they never delete anything themselves.
#'
#'   After any installation the cached module versions
#'   ([forget_module_version()]) and the [check_module()] memoise cache are
#'   cleared so that subsequent checks reflect the new environment.
#'
#' @param pyinstall Which package bundle to install. One of `"basic"`, `"full"`,
#'   `"extra"`, `"minimal"`, `"cleanenv"`, `"blast"` or `"none"`.
#' @param pkgs Optional character vector of additional Python packages (pip
#'   specifications) to install into the environment.
#' @param miniconda Whether to use the managed miniconda environment (strongly
#'   recommended). When `FALSE` your current Python is used as-is.
#'
#' @return Invisibly `NULL`. Called for its side effect of provisioning Python.
#' @export
#' @examples
#' \dontrun{
#' simple_python("basic")                          # the common case
#' simple_python("minimal")                        # just pandas (+ numpy)
#' simple_python("minimal", pkgs = "seatable_api") # pandas baseline + one pkg
#' simple_python("none", pkgs = "seatable_api")    # just one package
#' }
simple_python <- function(pyinstall = c("basic", "full", "extra", "minimal",
                                        "cleanenv", "blast", "none"),
                          pkgs = NULL, miniconda = TRUE) {

  check_reticulate(check_python = FALSE)
  check_python(initialize = FALSE)
  ourpip <- function(...)
    reticulate::py_install(..., pip = TRUE,
                           pip_options = "--upgrade --prefer-binary")

  # since we may well change installed modules, clear cached module versions and
  # the check_module() memoise cache so later checks reflect the new environment
  on.exit({
    forget_module_version()
    forget_check_module()
  })
  pyinstall <- match.arg(pyinstall)
  if (pyinstall != "none")
    simple_python_base(pyinstall, miniconda)
  if (pyinstall %in% c("cleanenv", "blast")) return(invisible(NULL))

  if (pyinstall %in% c("minimal", "basic", "full", "extra")) {
    # nat.python's own baseline: pandas2df() needs pandas, and numpy rides in
    # with it. Every richer bundle builds on top of this.
    cli::cli_inform("Installing pandas (brings numpy)")
    ourpip("pandas")
  }
  if (pyinstall %in% c("basic", "full", "extra")) {
    cli::cli_inform("Installing cloudvolume")
    ourpip("cloud-volume")
    cli::cli_inform("Installing seatable_api (access flytable metadata service)")
    # 2.6.3 had a problem, see
    # https://github.com/seatable/seatable-api-python/issues/76
    ourpip("seatable_api!=2.6.3")
    cli::cli_inform("Installing CAVEclient (access to extended FlyWire/FANC APIs)")
    ourpip("caveclient")
  }
  if (pyinstall %in% c("full", "extra")) {
    cli::cli_inform("Installing navis+fafbseg (python access to FlyWire/FANC data)")
    ourpip("fafbseg")
  }
  if (pyinstall %in% c("extra")) {
    cli::cli_inform("Installing skeletor (Philipp Schlegel mesh skeletonisation)")
    ourpip("skeletor")
    cli::cli_inform("Installing skeletor addons (for faster skeletonisation)")
    ourpip(c("fastremap", "ncollpyde"))
    cli::cli_inform("Installing meshparty (includes Seung lab mesh skeletonisation)")
    ourpip("meshparty")
    cli::cli_inform(paste("Installing pyembree (so meshparty can give skeletons",
                          "radius estimates)"))
    # not sure this will always work, but definitely optional
    tryCatch(reticulate::conda_install(packages = "pyembree"),
             error = function(e) cli::cli_warn(conditionMessage(e)))
  }
  if (!is.null(pkgs)) {
    cli::cli_inform("Installing user-specified packages")
    ourpip(pkgs)
  }
  invisible(NULL)
}

#' Check that a working Python is available via reticulate
#'
#' @description reticulate is a hard dependency of nat.python, so this really
#'   just checks that a usable Python is set up, guiding the user to
#'   [simple_python()] when it is not. The name is kept for continuity with the
#'   ecosystem's `check_reticulate()` entry point.
#'
#' @param check_python Whether to check that a working Python is available. When
#'   `FALSE` the function is a no-op returning `TRUE`.
#' @return Invisibly `TRUE` when the check passes, `FALSE` otherwise.
#' @export
check_reticulate <- function(check_python = TRUE) {
  if (check_python) check_python() else invisible(TRUE)
}

# Check for a usable Python, guiding the user to simple_python() when missing.
check_python <- function(initialize = TRUE) {
  # if python is already running, then we're fine
  if (reticulate::py_available())
    return(invisible(TRUE))

  nopython <- c(
    "!" = "You do not have Python set up for R.",
    "i" = "We recommend installing it with {.run nat.python::simple_python()}.",
    "i" = paste("Alternatively point the {.envvar RETICULATE_PYTHON} environment",
                "variable at a Python you manage; see {.help simple_python}."))

  if (!ownpythonrequested()) {
    pyfound <- try(reticulate::use_miniconda(np_condaenv(), required = TRUE),
                   silent = TRUE)
    if (inherits(pyfound, "try-error")) {
      cli::cli_inform(nopython)
      return(invisible(FALSE))
    }
  }

  pyavail <- reticulate::py_available(initialize = initialize)
  if (!initialize || pyavail) return(invisible(TRUE))
  cli::cli_inform(nopython)
  invisible(FALSE)
}

ownpythonrequested <- function() {
  nzchar(Sys.getenv("RETICULATE_PYTHON"))
}

checkownpython <- function(miniconda) {
  if (ownpythonrequested() || !miniconda)
    cli::cli_abort("You have specified a non-standard Python. Sorry you're on your own!")
}

current_python <- function() {
  conf <- reticulate::py_discover_config()
  pypath <- conf$python
  if (!isTRUE(nzchar(pypath)) || !isTRUE(try(file.exists(pypath))))
    structure(NA, .Names = "unknown_python")
  else
    structure(file.mtime(conf$python), .Names = conf$python)
}

default_pyenv <- function() {
  conf <- reticulate::py_discover_config()
  sub(":.*", "", conf$pythonhome)
}

# my own update function so that I can check if it actually updated anything
update_miniconda_base <- function() {
  path <- reticulate::miniconda_path()
  exe <- if (identical(.Platform$OS.type, "windows"))
    "condabin/conda.bat" else "bin/conda"
  conda <- file.path(path, exe)

  res <- system2(conda, c("update", "--yes", "--json", "--name", "base", "conda"),
                 stdout = TRUE)
  if (!jsonlite::validate(res)) {
    print(res)
    cli::cli_abort("Unable to parse results of conda update")
  }
  js <- jsonlite::fromJSON(res)
  # true when updated
  length(js$actions) > 0
}

simple_python_base <- function(what, miniconda) {
  if (what == "cleanenv") {
    checkownpython(miniconda)
    e <- default_pyenv()
    cli::cli_inform(c(
      paste("If you really want to clean the packages in your existing",
            "miniconda for R virtual env at:"),
      " " = "{e}",
      "do:",
      " " = "{.code reticulate::conda_remove(\"{e}\")}"))
    return(invisible(NULL))
  } else if (what == "blast") {
    checkownpython(miniconda)
    mp <- reticulate::miniconda_path()
    cli::cli_inform(c(
      "If you really want to blast your whole existing miniconda for R install at:",
      " " = "{mp}",
      "do:",
      " " = "{.code unlink(reticulate::miniconda_path(), recursive = TRUE)}",
      "!" = paste("Don't do this without verifying that the path above correctly",
                  "identifies your installation!")))
    return(invisible(NULL))
  }

  py_was_running <- reticulate::py_available()

  pychanged <- FALSE
  if (miniconda) {
    if (nzchar(Sys.getenv("RETICULATE_PYTHON")))
      cli::cli_abort(c(
        "You have chosen a specific Python via {.envvar RETICULATE_PYTHON}.",
        "i" = paste("simple_python does not recommend this; unset it, e.g. with",
                    "{.run usethis::edit_r_environ()}."),
        "i" = "If you are sure, use {.code simple_python(miniconda = FALSE)}."))

    cli::cli_inform("Installing/updating a dedicated miniconda Python environment for R")
    tryCatch({
      reticulate::install_miniconda()
      pychanged <- TRUE
    },
    error = function(e) {
      if (grepl("already installed", conditionMessage(e)))
        pychanged <<- update_miniconda_base()
    })
    condaenv <- np_condaenv()
    if (nzchar(condaenv) && condaenv != "r-reticulate")
      reticulate::conda_create(envname = condaenv,
                               conda = reticulate::miniconda_path())
    if (py_was_running && pychanged) {
      cli::cli_abort(c(
        "You have just updated your version of Python on disk.",
        "i" = "But there was already a different Python version attached to this R session.",
        ">" = "{.strong Restart R} and run {.code simple_python()} again to use your new Python!"))
    }
    cli::cli_inform("Ensuring pip is available in conda environment {.val {condaenv}}")
    reticulate::conda_install(envname = condaenv, packages = "pip")
    reticulate::use_miniconda(condaenv)
  } else {
    cli::cli_inform(c(
      "Using the following existing Python install. I hope you know what you're doing!"))
    print(reticulate::py_config())
    if (!nzchar(Sys.getenv("RETICULATE_PYTHON"))) {
      cli::cli_warn(c(
        paste("When using a non-standard Python setup, we recommend telling R",
              "exactly which install to use via {.envvar RETICULATE_PYTHON}."),
        "i" = "Set it with {.run usethis::edit_r_environ()}, adding a line like:",
        " " = "{.code RETICULATE_PYTHON=\"/opt/miniconda3/envs/r-reticulate/bin/python\"}"))
    }
  }
  invisible(pychanged)
}
