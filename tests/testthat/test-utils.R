# Internal utility helpers in utils.R. check_suggested is pure R; py_np needs
# numpy and is skipped when Python is unavailable.

test_that("check_suggested passes for an installed package", {
  # reticulate is a hard dependency, so it is always present
  expect_true(check_suggested("reticulate"))
  expect_invisible(check_suggested("reticulate"))
})

test_that("check_suggested errors for a missing package with instructions", {
  nope <- "a.package.that.does.not.exist"
  expect_error(check_suggested(nope), "is required")
  expect_error(check_suggested(nope), "install.packages")
  # the purpose string is woven into the message when supplied
  expect_error(check_suggested(nope, "for the widget path"),
               "for the widget path")
})

test_that("py_np imports and caches the numpy module", {
  skip_if_no_module("numpy")
  # clear any cached handle so we exercise the import branch
  rm(list = ls(.nat_python_cache), envir = .nat_python_cache)
  np1 <- py_np()
  expect_s3_class(np1, "python.builtin.module")
  # second call is served from the session cache -- same object handle
  np2 <- py_np()
  expect_identical(np1, np2)
  # convert = TRUE is cached under a separate key
  np3 <- py_np(convert = TRUE)
  expect_s3_class(np3, "python.builtin.module")
})
