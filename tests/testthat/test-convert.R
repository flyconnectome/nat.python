test_that("null2na replaces NULLs", {
  expect_identical(null2na(list(1, NULL, 3)), c(1, NA, 3))
  expect_identical(null2na(list("a", NULL)), c("a", NA))
})

test_that("classify_object_values picks the natural R type", {
  # small integers -> integer (base R type, mirroring py_to_r on python ints)
  expect_identical(classify_object_values(c("1", "2", "3")), c(1L, 2L, 3L))
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
  # int64-overflowing values -> character (faithful), with a warning
  expect_warning(
    ov <- classify_object_values(c("18446744073709551615", "1")),
    "beyond the signed 64-bit range")
  expect_identical(ov, c("18446744073709551615", "1"))
})

test_that("classify_integer_strings tiers by magnitude (bigint = auto)", {
  # small (fits 32-bit) -> integer
  expect_identical(classify_integer_strings(c("1", "2", "-3")), c(1L, 2L, -3L))
  # mid (> 2^31, < 2^53) -> double, exact
  mid <- c("3000000000", "5000000000")
  out <- classify_integer_strings(mid)
  expect_type(out, "double")
  expect_identical(out, c(3e9, 5e9))
  # large (>= 2^53) -> integer64
  large <- c("9007199254740993", "720575940621039145")
  out <- classify_integer_strings(large)
  expect_s3_class(out, "integer64")
  expect_identical(as.character(out), large)
  # a single mid value in the column promotes the whole column past integer
  expect_type(classify_integer_strings(c("1", "3000000000")), "double")
  # NA and non-integer input
  expect_identical(classify_integer_strings(c("1", NA)), c(1L, NA))
  expect_null(classify_integer_strings(c("1", "x")))
  expect_null(classify_integer_strings(c(NA_character_)))
  expect_null(classify_integer_strings(NULL))
})

test_that("classify_integer_strings honours bigint = integer64", {
  # every integer column -> integer64 regardless of magnitude
  out <- classify_integer_strings(c("1", "2"), bigint = "integer64")
  expect_s3_class(out, "integer64")
  expect_identical(as.character(out), c("1", "2"))
})

test_that("classify_integer_strings honours bigint = character", {
  # small still integer, large -> character (fread style)
  expect_identical(classify_integer_strings(c("1", "2"), bigint = "character"),
                   c(1L, 2L))
  large <- c("9007199254740993", "720575940621039145")
  expect_identical(classify_integer_strings(large, bigint = "character"), large)
  # uint64 overflow -> character, and no warning in this mode
  ov <- c("18446744073709551615", "1")
  expect_silent(out <- classify_integer_strings(ov, bigint = "character"))
  expect_identical(out, ov)
})

test_that("classify_integer_strings warns and returns character on uint64 overflow", {
  ov <- c("18446744073709551615", "1")
  expect_warning(out <- classify_integer_strings(ov, col = "seg_id"),
                 "seg_id")
  expect_identical(out, ov)
  # integer64 mode cannot hold it either -> still character + warning
  expect_warning(out2 <- classify_integer_strings(ov, bigint = "integer64"),
                 "beyond the signed 64-bit range")
  expect_identical(out2, ov)
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
  expect_true(is_pandas_dataframe(df))
  out <- pandas2df(df)
  expect_s3_class(out, "data.frame")
  expect_s3_class(out$id, "integer64")
  expect_identical(as.character(out$id), ids)
  expect_identical(out$label, c("a", "b"))
})

test_that("pandas2df flattens object columns and normalises datetimes", {
  skip_if_no_module("pandas")
  # An object column of python ints (flattened to an atomic vector), a genuine
  # list-valued object column (a multi-select, left as a list), an all-None
  # object column (-> NA), and a datetime column (-> UTC POSIXct).
  df <- reticulate::py_eval(
    paste0("__import__('pandas').DataFrame({",
           "'n': __import__('pandas').Series([1, 2, 3], dtype=object), ",
           "'tags': __import__('pandas').Series([['AB'], ['CD'], []], dtype=object), ",
           "'blank': __import__('pandas').Series([None, None, None], dtype=object), ",
           "'when': __import__('pandas').to_datetime(",
           "['2020-01-01', '2020-01-02', '2020-01-03'])})"),
    convert = FALSE)
  out <- pandas2df(df)
  # object ints flattened to a plain atomic vector, not a list of length-1s
  expect_false(is.list(out$n))
  expect_identical(out$n, c(1L, 2L, 3L))
  # a genuine list-valued (multi-select) column is left intact as a list
  expect_true(is.list(out$tags))
  expect_identical(out$tags[[1]], "AB")
  expect_length(out$tags[[3]], 0L)
  # an all-None object column collapses to NA
  expect_true(all(is.na(out$blank)))
  # datetimes come back as UTC POSIXct
  expect_s3_class(out$when, "POSIXct")
  expect_identical(attr(out$when, "tzone"), "UTC")
  expect_identical(as.character(as.Date(out$when)),
                   c("2020-01-01", "2020-01-02", "2020-01-03"))
})

test_that("pandas2df use_arrow path round-trips via a feather file", {
  skip_if_no_module("pandas")
  skip_if_no_module("pyarrow")          # pandas.to_feather needs pyarrow
  skip_if_not_installed("arrow")        # R arrow::read_feather
  df <- reticulate::py_eval(
    "__import__('pandas').DataFrame({'label': ['a', 'b', 'c'], 'n': [1, 2, 3]})",
    convert = FALSE)
  out <- pandas2df(df, use_arrow = TRUE)
  # the arrow path always returns a tibble
  expect_s3_class(out, "tbl_df")
  expect_identical(out$label, c("a", "b", "c"))
  expect_equal(as.integer(out$n), 1:3)
})

test_that("pandas2df use_arrow handles an empty frame", {
  skip_if_no_module("pandas")
  skip_if_not_installed("arrow")
  skip_if_not_installed("tibble")
  # the empty-frame branch returns via py_to_r + tibble, without touching arrow
  df <- reticulate::py_eval(
    "__import__('pandas').DataFrame({'label': [], 'n': []})", convert = FALSE)
  out <- pandas2df(df, use_arrow = TRUE)
  expect_s3_class(out, "tbl_df")
  expect_identical(nrow(out), 0L)
  expect_identical(names(out), c("label", "n"))
})

test_that("pandas2df fast-path preserves column order and nullable ids", {
  skip_if_no_module("pandas")
  ids <- c("720575940621039145", "720575940626877799")
  # A nullable Int64 id column sandwiched between object columns, with a NA in
  # the id column: exercises the fast path (which pulls id out of the py_to_r
  # pass) and its splice back into the original position.
  df <- reticulate::py_eval(
    paste0("__import__('pandas').DataFrame({",
           "'label': ['a', 'b', 'c'], ",
           "'id': __import__('pandas').array([",
           paste(ids, collapse = ", "), ", None], dtype='Int64'), ",
           "'n': __import__('pandas').array([1, 2, 3], dtype='Int64')})"),
    convert = FALSE)
  out <- pandas2df(df)
  # id stays the 2nd column (fast path spliced back in place)
  expect_identical(names(out), c("label", "id", "n"))
  expect_s3_class(out$id, "integer64")
  expect_identical(as.character(out$id), c(ids, NA))
  # a small-valued Int64 column comes back as a plain integer, NA preserved
  expect_identical(out$n, c(1L, 2L, 3L))
  expect_identical(out$label, c("a", "b", "c"))
})

test_that("is_string_dtype recognises the string dtype family", {
  expect_true(is_string_dtype("str"))                 # pandas 3.0 default
  expect_true(is_string_dtype("string"))
  expect_true(is_string_dtype("string[python]"))
  expect_true(is_string_dtype("string[pyarrow]"))
  expect_true(is_string_dtype("large_string[pyarrow]"))
  expect_false(is_string_dtype("object"))
  expect_false(is_string_dtype("int64[pyarrow]"))
  expect_false(is_string_dtype("struct"))             # not a string dtype
})

test_that("pandas2df converts Arrow-backed string columns to character", {
  skip_if_no_module("pandas")
  skip_if_no_module("pyarrow")
  # An explicit Arrow-backed string column reproduces pandas 3.0's default
  # dtype (an ArrowStringArray) even under pandas 2: reticulate leaves it as a
  # raw python object, and pandas2df must recover an R character vector (with a
  # missing cell -> NA), while a neighbouring numeric column is unaffected.
  df <- reticulate::py_eval(
    paste0("__import__('pandas').DataFrame({",
           "'label': __import__('pandas').array(",
           "['a', 'b', None], dtype='string[pyarrow]'), ",
           "'n': [1, 2, 3]})"),
    convert = FALSE)
  out <- pandas2df(df)
  expect_type(out$label, "character")
  expect_identical(out$label, c("a", "b", NA))
  expect_identical(out$n, c(1L, 2L, 3L))
})

test_that("pandas2df converts Arrow-backed integer id columns", {
  skip_if_no_module("pandas")
  skip_if_no_module("pyarrow")
  # A general (non-string) Arrow extension column: 64-bit ids in an
  # int64[pyarrow] column must map to the same integer64 the native int64 path
  # produces, not survive as a raw python object.
  ids <- c("720575940621039145", "720575940626877799")
  df <- reticulate::py_eval(
    paste0("__import__('pandas').DataFrame({",
           "'id': __import__('pandas').array([",
           paste(ids, collapse = ", "), "], dtype='int64[pyarrow]')})"),
    convert = FALSE)
  out <- pandas2df(df)
  expect_s3_class(out$id, "integer64")
  expect_identical(as.character(out$id), ids)
})
