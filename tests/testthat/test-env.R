# Pure-R helpers in env.R. The provisioning machinery itself (install_miniconda,
# conda_install, ...) has real side effects and is not unit-tested here; these
# cover the option/env plumbing and the non-destructive "print the command"
# branches of simple_python_base().

test_that("np_condaenv honours the option and defaults to r-reticulate", {
  withr::local_options(nat.python.condaenv = NULL)
  expect_identical(np_condaenv(), "r-reticulate")
  withr::local_options(nat.python.condaenv = "my-env")
  expect_identical(np_condaenv(), "my-env")
})

test_that("resolve_python_version honours the precedence chain", {
  withr::local_options(nat.python.python_version = NULL)
  withr::local_envvar(RETICULATE_MINICONDA_PYTHON_VERSION = "")
  # nothing set anywhere -> built-in default
  expect_identical(resolve_python_version(), "3.12")
  # a pre-set env var wins over the default (so CI's matrix pin is respected)
  withr::local_envvar(RETICULATE_MINICONDA_PYTHON_VERSION = "3.9")
  expect_identical(resolve_python_version(), "3.9")
  # the option beats the env var
  withr::local_options(nat.python.python_version = "3.11")
  expect_identical(resolve_python_version(), "3.11")
  # an explicit argument beats everything
  expect_identical(resolve_python_version("3.13"), "3.13")
})

test_that("resolve_python_version treats NA/empty as 'do not pin'", {
  withr::local_options(nat.python.python_version = NULL)
  withr::local_envvar(RETICULATE_MINICONDA_PYTHON_VERSION = "3.9")
  # NA at the arg level defers even when an env var is set
  expect_identical(resolve_python_version(NA), NA_character_)
  # "" at the option level likewise defers
  withr::local_options(nat.python.python_version = "")
  expect_identical(resolve_python_version(), NA_character_)
  # a bad (length != 1) value errors
  expect_error(resolve_python_version(c("3.11", "3.12")), "single value")
})

test_that("ownpythonrequested reflects RETICULATE_PYTHON", {
  withr::local_envvar(RETICULATE_PYTHON = "")
  expect_false(ownpythonrequested())
  withr::local_envvar(RETICULATE_PYTHON = "/opt/python/bin/python")
  expect_true(ownpythonrequested())
})

test_that("checkownpython aborts for a non-standard Python", {
  withr::local_envvar(RETICULATE_PYTHON = "")
  # miniconda = FALSE means the user asked for their own Python
  expect_error(checkownpython(miniconda = FALSE), "on your own")
  withr::local_envvar(RETICULATE_PYTHON = "/opt/python/bin/python")
  expect_error(checkownpython(miniconda = TRUE), "on your own")
  # standard managed setup: no abort
  withr::local_envvar(RETICULATE_PYTHON = "")
  expect_silent(checkownpython(miniconda = TRUE))
})

test_that("check_reticulate is a no-op when check_python = FALSE", {
  expect_true(check_reticulate(check_python = FALSE))
  expect_invisible(check_reticulate(check_python = FALSE))
})

test_that("simple_python_base blast only prints and deletes nothing", {
  withr::local_envvar(RETICULATE_PYTHON = "")
  # the blast branch just prints the (destructive) unlink command; it must
  # never touch the filesystem itself, and returns invisibly
  existed <- dir.exists(reticulate::miniconda_path())
  expect_invisible(res <- simple_python_base("blast", miniconda = TRUE))
  expect_null(res)
  # the miniconda directory is left exactly as it was
  expect_identical(dir.exists(reticulate::miniconda_path()), existed)
})
