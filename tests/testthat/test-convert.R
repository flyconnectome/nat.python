test_that("null2na replaces NULLs", {
  expect_identical(null2na(list(1, NULL, 3)), c(1, NA, 3))
  expect_identical(null2na(list("a", NULL)), c("a", NA))
})

test_that("classify_object_values picks the natural R type", {
  # small integers -> numeric
  expect_identical(classify_object_values(c("1", "2", "3")), c(1, 2, 3))
  # big integers beyond 2^53 -> integer64
  big <- c("9007199254740993", "9007199254740994")
  out <- classify_object_values(big)
  expect_s3_class(out, "integer64")
  expect_identical(as.character(out), big)
  # floats -> numeric
  expect_identical(classify_object_values(c("1.5", "2.5")), c(1.5, 2.5))
  # genuine strings -> character
  expect_identical(classify_object_values(c("ab", "cd")), c("ab", "cd"))
  # all-NA -> NA vector
  expect_identical(classify_object_values(c(NA_character_, NA_character_)),
                   c(NA, NA))
  # NULL passes through
  expect_null(classify_object_values(NULL))
  # int64-overflowing values -> NULL (leave the column alone)
  expect_null(classify_object_values(c("18446744073709551615", "1")))
})

test_that("is_posixct_list recognises a list of scalar POSIXct", {
  now <- Sys.time()
  expect_true(is_posixct_list(list(now, now)))
  expect_true(is_posixct_list(list(now, as.POSIXct(character()))))
  expect_false(is_posixct_list(list(1, 2)))
  expect_false(is_posixct_list(data.frame(a = 1)))
})

test_that("flatten/normalise POSIXct list yields a UTC POSIXct vector", {
  now <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  flat <- flatten_posixct_list(list(now, as.POSIXct(character())))
  expect_s3_class(flat, "POSIXct")
  expect_length(flat, 2L)
  expect_identical(attr(normalise_posixct_utc(flat), "tzone"), "UTC")
})

test_that("pandas2df rejects a non-DataFrame", {
  expect_error(pandas2df(data.frame(a = 1)), "pandas DataFrame")
})

test_that("pandas2df recovers 64-bit ids and object columns", {
  skip_if_no_module("pandas")
  ids <- c("720575940621039145", "720575940626877799")
  # Build the frame entirely in Python (convert = FALSE, integer literals) so
  # the test does not depend on numpy string casting, R double precision, or
  # reticulate marshalling of large ids.
  df <- reticulate::py_eval(
    paste0("__import__('pandas').DataFrame({",
           "'id': __import__('pandas').array([",
           paste(ids, collapse = ", "), "], dtype='int64'), ",
           "'label': ['a', 'b']})"),
    convert = FALSE)
  expect_true(inherits(df, "pandas.core.frame.DataFrame"))
  out <- pandas2df(df)
  expect_s3_class(out, "data.frame")
  expect_s3_class(out$id, "integer64")
  expect_identical(as.character(out$id), ids)
  expect_identical(out$label, c("a", "b"))
})
