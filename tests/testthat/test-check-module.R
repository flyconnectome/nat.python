# check_module() decision logic, exercised entirely offline by mocking the
# pieces that would otherwise touch Python (check_reticulate, module_installed,
# reticulate::import, module_version, simple_python).
#
# check_module() is memoised, so each test clears the cache first to keep cases
# independent (otherwise an earlier success for a module would be handed back).

test_that("missing module with install='never' errors with instructions", {
  forget_check_module()
  local_mocked_bindings(check_reticulate = function(...) invisible(TRUE),
                        module_installed = function(module) FALSE)
  expect_error(check_module("nope", install = "never"),
               "not installed")
})

test_that("missing module in non-interactive 'ask' errors (no prompt)", {
  forget_check_module()
  # tests run non-interactively, so 'ask' cannot prompt and must fall through
  local_mocked_bindings(check_reticulate = function(...) invisible(TRUE),
                        module_installed = function(module) FALSE)
  expect_error(check_module("nope", install = "ask"), "not installed")
})

test_that("install='always' installs then errors if still absent", {
  forget_check_module()
  installed_called <- 0L
  called <- FALSE
  local_mocked_bindings(
    check_reticulate = function(...) invisible(TRUE),
    module_installed = function(module) { installed_called <<- installed_called + 1L; FALSE },
    simple_python = function(...) { called <<- TRUE; invisible(NULL) })
  expect_error(check_module("nope", install = "always"), "not installed")
  expect_true(called)                 # it tried to install
  expect_equal(installed_called, 2L)  # checked before and after install
})

test_that("installed + importable returns the module", {
  forget_check_module()
  stub <- structure(list(), class = "python.builtin.module")
  local_mocked_bindings(check_reticulate = function(...) invisible(TRUE),
                        module_installed = function(module) TRUE)
  local_mocked_bindings(import = function(module, ...) stub, .package = "reticulate")
  expect_identical(check_module("pandas"), stub)
})

test_that("installed but unloadable is reported as a load failure", {
  forget_check_module()
  local_mocked_bindings(check_reticulate = function(...) invisible(TRUE),
                        module_installed = function(module) TRUE)
  local_mocked_bindings(import = function(module, ...) stop("boom: bad build"),
                        .package = "reticulate")
  expect_error(check_module("pandas"), "failed to load")
  expect_error(check_module("pandas"), "boom: bad build")
})

test_that("min_version enforced", {
  forget_check_module()
  stub <- structure(list(), class = "python.builtin.module")
  local_mocked_bindings(check_reticulate = function(...) invisible(TRUE),
                        module_installed = function(module) TRUE,
                        module_version = function(module) "1.0.0")
  local_mocked_bindings(import = function(module, ...) stub, .package = "reticulate")
  expect_error(check_module("pandas", min_version = "2.0.0"), "too old")
  expect_identical(check_module("pandas", min_version = "0.9.0"), stub)
})

test_that("memoisation returns the cached module and forget clears it", {
  forget_check_module()
  calls <- 0L
  local_mocked_bindings(
    check_reticulate = function(...) invisible(TRUE),
    module_installed = function(module) { calls <<- calls + 1L; TRUE })
  local_mocked_bindings(import = function(module, ...) structure(list(), class = "python.builtin.module"),
                        .package = "reticulate")
  m1 <- check_module("numpy")
  m2 <- check_module("numpy")          # served from cache, no re-check
  expect_identical(m1, m2)
  expect_equal(calls, 1L)
  check_module("numpy", cache = FALSE)  # bypasses cache, checks again
  expect_equal(calls, 2L)
  forget_check_module()
  check_module("numpy")                # cache cleared, checks again
  expect_equal(calls, 3L)
})
