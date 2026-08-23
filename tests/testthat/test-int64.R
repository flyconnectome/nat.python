test_that("int64_overflows flags only true overflows", {
  x <- c("0", "-1", "123",
         "9223372036854775807",     # max int64, fits
         "9223372036854775808",     # max int64 + 1, overflows
         "18446744073709551615",    # max uint64, overflows
         NA_character_)
  # NA input is not an overflow
  expect_identical(int64_overflows(x),
                   c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE))
})

test_that("rids2raw round-trips through readBin", {
  ids <- c("123", "456", "9223372036854775807")
  raw <- rids2raw(ids)
  expect_type(raw, "raw")
  expect_length(raw, 8L * length(ids))
  back <- readBin(raw, what = "double", n = length(ids), size = 8L,
                  endian = "little")
  class(back) <- "integer64"
  expect_identical(as.character(back), ids)
})

test_that("rids2raw honours endianness", {
  expect_false(identical(rids2raw(1:3, endian = "little"),
                         rids2raw(1:3, endian = "big")))
})

test_that("pyids2bit64 round-trips a numpy int64 array", {
  skip_if_no_module("numpy")
  np <- reticulate::import("numpy", convert = FALSE)
  ids <- c("123", "720575940621039145", "9223372036854775807")
  arr <- np$array(ids, dtype = "int64")
  # default: character out
  expect_identical(pyids2bit64(arr), ids)
  # as_character = FALSE: an exact integer64 vector
  i64 <- pyids2bit64(arr, as_character = FALSE)
  expect_s3_class(i64, "integer64")
  expect_identical(as.character(i64), ids)
})

test_that("pyids2bit64 accepts uint64 within signed range and rejects overflow", {
  skip_if_no_module("numpy")
  np <- reticulate::import("numpy", convert = FALSE)
  ok <- np$array(c("123", "9223372036854775807"), dtype = "uint64")
  expect_identical(pyids2bit64(ok), c("123", "9223372036854775807"))
  # a uint64 value beyond the signed range cannot be represented as int64
  ov <- np$array(c("18446744073709551615"), dtype = "uint64")
  expect_error(pyids2bit64(ov), "int64 overflow")
  # unsupported dtype is rejected
  f <- np$array(c("1.5"), dtype = "float64")
  expect_error(pyids2bit64(f), "dtype=int64 or uint64")
})

test_that("pyids2bit64 handles an empty array", {
  skip_if_no_module("numpy")
  np <- reticulate::import("numpy", convert = FALSE)
  empty <- np$array(list(), dtype = "int64")
  expect_identical(pyids2bit64(empty), character())
  expect_identical(pyids2bit64(empty, as_character = FALSE), bit64::integer64())
})

test_that("rids2pyint round-trips R ids back through pyids2bit64", {
  skip_if_no_module("numpy")
  ids <- c("123", "720575940621039145", "9223372036854775807")
  # in-memory string path (default for short vectors)
  arr <- rids2pyint(ids, numpyarray = TRUE)
  expect_identical(pyids2bit64(arr), ids)
  # a Python list of ints is the non-numpyarray default
  lst <- rids2pyint(ids)
  expect_s3_class(lst, "python.builtin.list")
  # the file-marshalling path (usefile = TRUE) yields the same ids
  arr2 <- rids2pyint(ids, numpyarray = TRUE, usefile = TRUE)
  expect_identical(pyids2bit64(arr2), ids)
  # a numpy array passed in is returned as-is
  expect_identical(pyids2bit64(rids2pyint(arr, numpyarray = TRUE)), ids)
})
