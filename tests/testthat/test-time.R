# ts2pydatetime: the early-return for an already-converted datetime is pure R;
# the conversion path needs the Python datetime module.

test_that("ts2pydatetime returns an existing python datetime unchanged", {
  # a value already carrying the datetime.datetime class is passed straight
  # back, no Python needed
  fake <- structure(list(), class = "datetime.datetime")
  expect_identical(ts2pydatetime(fake), fake)
})

test_that("ts2pydatetime converts an R time to a UTC python datetime", {
  skip_if_no_module("datetime")
  t <- as.POSIXct("2020-01-02 03:04:05", tz = "UTC")
  py <- ts2pydatetime(t)
  expect_s3_class(py, "datetime.datetime")
  # tzinfo is made explicit (UTC), and the instant round-trips exactly
  expect_true(reticulate::py_to_r(py$tzinfo == reticulate::import("datetime")$timezone$utc))
  back <- as.numeric(reticulate::py_to_r(py$timestamp()))
  expect_equal(back, as.numeric(t))
})
