test_that("module_version caches and forgets", {
  skip_if_no_module("numpy")
  forget_module_version()
  v <- module_version("numpy")
  expect_true(is.character(v) && !is.na(v))
  # a bogus module is NA
  expect_true(is.na(module_version("nat_python_definitely_not_a_module")))
  forget_module_version()
})

test_that("py_module_info reports availability and version", {
  skip_if_no_module("numpy")
  info <- py_module_info(c("numpy", "nat_python_definitely_not_a_module"))
  expect_s3_class(info, "data.frame")
  expect_identical(info$module,
                   c("numpy", "nat_python_definitely_not_a_module"))
  expect_true(info$available[1])
  expect_false(info$available[2])
})

test_that("module_available honours action", {
  skip_if_not(requireNamespace("reticulate", quietly = TRUE))
  expect_false(module_available("nat_python_definitely_not_a_module"))
  expect_error(
    module_available("nat_python_definitely_not_a_module", action = "stop",
                     install_hint = "pip install something"),
    "not available")
})
