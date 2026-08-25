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
