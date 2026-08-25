# pandas / numpy -> R conversion.
#
# The "decent chunk of code" the nat.python plan is really about (§3c): turn a
# pandas DataFrame into an idiomatic R data frame, patching the columns that
# reticulate cannot faithfully represent -- 64-bit integer ids, object columns
# and datetimes. Ported verbatim from fafbseg's utils.R, with checkmate and
# dplyr/tibble dependencies removed in favour of base R and gated optional deps.

#' Convert a pandas DataFrame to an R data frame
#'
#' @description Converts a pandas `DataFrame` into an R `data.frame` (or a
#'   tibble), preserving the column types reticulate's default conversion gets
#'   wrong: 64-bit integer ids, object-dtype columns, and datetimes.
#'
#' @details The default in-memory path converts with reticulate and then patches
#'   individual columns:
#'   * Integer columns (`int64`, `uint64`, and `object` columns whose cells are
#'     all Python ints) are classified by magnitude so each maps to the
#'     narrowest faithful R type. This mirrors reticulate's own `py_to_r()`
#'     where reticulate is faithful, and reserves `bit64::integer64` for values
#'     base R cannot hold exactly -- see `bigint`.
#'   * `object` columns whose cells are all scalar (or `NA`) are flattened from a
#'     list of length-1 vectors to an atomic vector, with integer-valued cells
#'     read as strings so arbitrary-precision Python ints round-trip. Genuine
#'     list-valued columns (e.g. multi-select values) are left intact.
#'   * datetime columns are normalised to `POSIXct` in UTC.
#'   * pandas extension-array columns that reticulate leaves unconverted -- most
#'     importantly pandas 3.0's default Arrow-backed string dtype -- are
#'     recovered: string columns become character vectors, other Arrow columns
#'     are classified like object columns (so Arrow-backed ids map like native
#'     ones).
#'
#'   The optional `use_arrow` path round-trips through a Feather file and needs
#'   the Suggested `arrow` package; `bigint` does not apply to it.
#'
#' @param x A pandas `DataFrame` (a reticulate `pandas.core.frame.DataFrame`).
#' @param use_arrow If `TRUE`, convert via a temporary Feather file using the
#'   `arrow` package rather than in memory. Implies a tibble result.
#' @param keep_index Whether to keep the pandas index as a column.
#' @param tibble Whether to return a tibble rather than a base data frame.
#'   Defaults to `use_arrow`.
#' @param bigint How to represent integer columns. `"auto"` (the default) maps
#'   each column to the narrowest faithful base R type: values fitting a 32-bit
#'   R `integer` become `integer`, larger values below 2^53 become `double`
#'   (exact), and values from 2^53 up to the signed 64-bit maximum become
#'   `bit64::integer64` -- reserving `integer64` for what base R cannot hold
#'   exactly. `"integer64"` returns every integer column as `bit64::integer64`
#'   for a stable schema regardless of magnitude. `"character"` behaves like
#'   `"auto"` but returns the large (>= 2^53) tier as character, as
#'   `data.table::fread()` offers. `uint64` values beyond the signed 64-bit
#'   range cannot be held by `integer64`; they are always returned as character,
#'   with a warning unless `bigint = "character"`.
#'
#' @return An R `data.frame`, or a tibble when `tibble = TRUE`.
#' @export
#' @examples
#' \dontrun{
#' pd <- reticulate::import("pandas")
#' df <- pd$DataFrame(list(id = c("720575940621039145", "720575940626877799")))
#' pandas2df(df)
#' }
pandas2df <- function(x, use_arrow = FALSE, keep_index = FALSE,
                      tibble = use_arrow,
                      bigint = c("auto", "integer64", "character")) {
  bigint <- match.arg(bigint)
  use_arrow <- isTRUE(use_arrow)
  keep_index <- isTRUE(keep_index)
  tibble <- isTRUE(tibble)
  if (!is_pandas_dataframe(x))
    stop("`x` must be a pandas DataFrame (a ",
         "'pandas.core.frame.DataFrame').", call. = FALSE)
  if (keep_index || use_arrow || tibble)
    x$reset_index(drop = !keep_index, inplace = TRUE)
  nr <- nrow(x)
  if (!use_arrow)
    return(pandas2df_inmem(x, tibble = tibble, bigint = bigint))
  check_suggested("arrow", "for the use_arrow = TRUE conversion path")
  if (nr == 0L) {
    check_suggested("tibble", "for the use_arrow = TRUE conversion path")
    return(tibble::as_tibble(reticulate::py_to_r(x)))
  }

  tf <- tempfile(fileext = ".feather")
  on.exit(unlink(tf))
  if (isTRUE(module_version("pyarrow") >= "0.17.0") &&
      isTRUE(module_version("pandas") >= "1.1.0")) {
    comp <- ifelse(arrow::codec_is_available("lz4"), "lz4", "uncompressed")
    x$to_feather(tf, compression = comp)
  } else x$to_feather(tf)
  arrow::read_feather(tf)
}

# Robust test that `x` is a pandas DataFrame. reticulate normally exposes the
# full Python class path (pandas.core.frame.DataFrame), but that internal path
# is not guaranteed stable across pandas versions or reticulate/Python combos,
# so fall back to the Python type name.
is_pandas_dataframe <- function(x) {
  if (inherits(x, "pandas.core.frame.DataFrame")) return(TRUE)
  if (!inherits(x, "python.builtin.object")) return(FALSE)
  nm <- tryCatch(
    reticulate::py_to_r(reticulate::py_get_attr(
      reticulate::py_get_attr(x, "__class__"), "__name__")),
    error = function(e) NA_character_)
  identical(nm, "DataFrame")
}

pandas2df_inmem <- function(df, tibble = FALSE, bigint = "auto") {
  if (!is_pandas_dataframe(df))
    stop("`df` must be a pandas DataFrame.", call. = FALSE)
  dtypes <- pandas_dataframe_dtypes(df)
  # Row count from the *original* frame: once the fast path filters columns out
  # of df_slow, an all-fast frame yields a 0-column res whose nrow() would read
  # as 0 even with rows present, so the empty check cannot rely on nrow(res).
  nr <- nrow(df)

  # Fast-path 64-bit integer id columns: convert them ourselves and keep them
  # out of the reticulate py_to_r pass below. reticulate converts pandas
  # *nullable* integer extension columns (dtype "Int64"/"UInt64") cell by cell,
  # which is pathologically slow on the large id columns that dominate synapse /
  # partner queries (~20x the whole conversion). classify_integer_strings() is
  # the same conversion the int64 rescue used to redo *after* the slow pass, so
  # we run it first and filter those columns out of the frame handed to py_to_r.
  # Columns the fast path declines (returns NULL -- an all-NA column) stay in
  # the py_to_r pass and keep their native R type.
  int_cols <- names(dtypes)[tolower(dtypes) %in% c("int64", "uint64")]
  fast_int <- list()
  for (col in int_cols) {
    conv <- classify_integer_strings(
      pandas_series_character_values(reticulate::py_get_item(df, col)),
      bigint = bigint, col = col)
    if (!is.null(conv))
      fast_int[[col]] <- conv
  }

  df_slow <- if (length(fast_int))
    reticulate::py_call(
      df$filter,
      items = as.list(setdiff(names(dtypes), names(fast_int))))
  else df
  res <- pandas_py_to_r_frame(df_slow)
  if (tibble) {
    check_suggested("tibble", "for tibble = TRUE")
    res <- tibble::as_tibble(res)
  }

  # pandas extension arrays reticulate cannot convert come back as raw python
  # objects. The one that now arrives by default is pandas 3.0's Arrow-backed
  # string dtype (PDEP-14), but any explicit ArrowDtype column lands here too.
  # Convert each from its string values: a declared string dtype becomes an R
  # character vector; any other extension column is classified like an object
  # column, so Arrow-backed ids and numbers map to the same R types as their
  # native-dtype equivalents.
  ext_cols <- names(res)[vapply(res, function(v)
    inherits(v, "python.builtin.object"), logical(1))]
  for (col in ext_cols) {
    vals <- pandas_series_character_values(reticulate::py_get_item(df, col))
    if (is.null(vals)) next
    res[[col]] <- if (col %in% names(dtypes) && is_string_dtype(dtypes[[col]]))
      vals
    else
      classify_object_values(vals, bigint = bigint, col = col)
  }

  # splice the fast-converted int columns back into their original positions
  splice_fast_int <- function(res) {
    for (col in names(fast_int)) res[[col]] <- fast_int[[col]]
    if (length(fast_int)) res <- res[names(dtypes)]
    res
  }

  if (nr == 0L) {
    res <- splice_fast_int(res)
    attr(res, "pandas.index") <- NULL
    return(res)
  }

  # Object dtype: each cell can be an arbitrary Python object. reticulate's
  # default conversion returns a list of length-1 R vectors even when every
  # cell is the same scalar type (e.g. a Python `int` per row -- the shape
  # caveclient's get_l2data_table uses for declared-scalar columns when
  # mixed with array-valued ones). Detect that case and flatten to an atomic
  # vector. For integer-valued cells we read via series.map(str).tolist() so
  # arbitrary-precision Python ints round-trip without int32 truncation.
  object_cols <- names(dtypes)[tolower(dtypes) == "object"]
  for (col in intersect(object_cols, names(res))) {
    x <- res[[col]]
    if (!is.list(x)) next
    lens <- lengths(x)
    if (!all(lens <= 1L)) next                       # heterogeneous, leave alone
    if (all(lens == 0L)) {                           # all NA
      res[[col]] <- rep(NA, length(x))
      next
    }
    series <- reticulate::py_get_item(df, col)
    # a column whose cells are themselves python lists/tuples (e.g. a
    # seatable multi-select value like ['AB']) looks identical, at the R
    # level, to a column of length-1-wrapped scalars once every row happens
    # to hold 0 or 1 elements -- most commonly a single-row query result.
    # py_to_r() has already converted such a column correctly (a list of
    # character vectors); re-deriving values via series.map(str) below
    # would instead capture Python's list repr (e.g. "['AB']") as a literal
    # string, so leave genuine list-valued columns alone.
    if (pandas_series_has_list_cells(series)) next
    flat <- pandas_object_series_to_vector(series, bigint = bigint, col = col)
    if (!is.null(flat))
      res[[col]] <- flat
  }

  datetime_cols <- names(dtypes)[grepl("^datetime", dtypes)]
  posix_list_cols <- names(res)[vapply(res, is_posixct_list, logical(1))]
  for (col in intersect(unique(c(datetime_cols, posix_list_cols)), names(res))) {
    res[[col]] <- normalise_posixct_utc(flatten_posixct_list(res[[col]]))
  }

  res <- splice_fast_int(res)
  attr(res, "pandas.index") <- NULL
  res
}

pandas_py_to_r_frame <- function(df) {
  withCallingHandlers(
    reticulate::py_to_r(df),
    warning = function(w) {
      if (grepl("NAs introduced by coercion to integer range",
                conditionMessage(w), fixed = TRUE))
        invokeRestart("muffleWarning")
    }
  )
}

# Does a pandas dtype string denote a string dtype? Covers the StringDtype
# family ("string", "string[python]", "string[pyarrow]"), Arrow large strings,
# and pandas 3.0's new default string dtype, which reports simply as "str".
is_string_dtype <- function(dt) {
  grepl("^(str|string|large_string)(\\[.*\\])?$", tolower(dt))
}

pandas_dataframe_dtypes <- function(df) {
  dtype_series <- reticulate::py_get_attr(df, "dtypes")
  dtype_strings <- reticulate::py_call(
    reticulate::py_get_attr(dtype_series, "astype"), "str")
  dtype_dict <- reticulate::py_call(
    reticulate::py_get_attr(dtype_strings, "to_dict"))
  dtypes <- reticulate::py_to_r(dtype_dict)
  unlist(dtypes, use.names = TRUE)
}

# Classify a vector of exact integer strings (NA for missing) into the natural
# R representation, honouring `bigint`. This is the single decision point shared
# by the typed int64/uint64 path and the object-column path, so both dtypes and
# both code paths behave identically.
#
#   "auto"       small -> integer, mid (< 2^53) -> double, large -> integer64
#   "integer64"  every column -> integer64 (stable schema)
#   "character"  as "auto" but the large (>= 2^53) tier -> character
#
# The tiering mirrors reticulate's py_to_r() where it is faithful (small ->
# integer, mid -> double) and only reaches for bit64::integer64 once a value
# exceeds 2^53, the largest integer a double represents exactly.
#
# uint64 values beyond the signed 64-bit maximum cannot be held by integer64
# (which is signed); they are returned as character -- the only faithful option
# -- and, outside "character" mode, warned about.
#
# Returns NULL when the caller should leave the column untouched: input is NULL,
# all cells are missing, or the cells are not all integer-shaped.
classify_integer_strings <- function(vals,
                                     bigint = c("auto", "integer64",
                                                "character"),
                                     col = NULL) {
  bigint <- match.arg(bigint)
  if (is.null(vals))
    return(NULL)
  present <- !is.na(vals)
  if (!any(present))
    return(NULL)
  if (!all(grepl("^-?[0-9]+$", vals[present])))
    return(NULL)

  if (any(int64_overflows(vals), na.rm = TRUE)) {
    if (!identical(bigint, "character"))
      warning(sprintf(
        paste0("%s holds integers beyond the signed 64-bit range; ",
               "returning character. Pass bigint = \"character\" to silence."),
        if (is.null(col)) "A column" else sprintf("Column '%s'", col)),
        call. = FALSE)
    return(vals)
  }

  i64 <- bit64::as.integer64(vals)
  if (identical(bigint, "integer64"))
    return(i64)

  amax <- max(abs(i64), na.rm = TRUE)
  if (amax >= bit64::as.integer64("9007199254740992"))   # 2^53
    return(if (identical(bigint, "character")) vals else i64)
  if (amax > .Machine$integer.max)                        # mid -> double
    return(as.double(i64))
  as.integer(i64)                                         # small -> integer
}

# Flatten a pandas Series of object dtype whose cells are all the same scalar
# Python type (or NA) into an atomic R vector. Reads cells as strings via
# series.map(str).tolist() so arbitrary-precision Python ints round-trip
# without int32 truncation (the bug that corrupts uint32 columns >= 2^31
# returned by the L2 cache).
pandas_object_series_to_vector <- function(series, bigint = "auto",
                                           col = NULL) {
  classify_object_values(pandas_series_character_values(series),
                         bigint = bigint, col = col)
}

# TRUE if any non-missing cell of this pandas object Series is itself a
# python list or tuple, e.g. a seatable multi-select value such as
# ['AB', 'CD']. Runs entirely on the python side (no R callback per cell)
# for speed; the lambda is built lazily and cached across calls.
pandas_series_has_list_cells <- local({
  checker <- NULL
  function(series) {
    if (is.null(checker))
      checker <<- reticulate::py_eval(
        "lambda s: bool(any(isinstance(v, (list, tuple)) for v in s.dropna()))",
        convert = FALSE)
    isTRUE(reticulate::py_to_r(reticulate::py_call(checker, series)))
  }
})

# Pure-R companion: given a character vector of pandas object cells (each
# already mapped via str()), classify and convert to the natural atomic R
# type. Returns NULL when the column can't be classified (mixed types) and
# the caller should leave the list-column intact.
classify_object_values <- function(vals, bigint = c("auto", "integer64",
                                                    "character"),
                                    col = NULL) {
  bigint <- match.arg(bigint)
  if (is.null(vals)) return(NULL)
  present <- !is.na(vals)
  if (!any(present)) return(rep(NA, length(vals)))   # all-NA: caller's choice

  # Integer-shaped strings share the magnitude-based classifier used by the
  # typed int64/uint64 path, so an id column comes back the same type whether
  # pandas declared it int64 or handed it to us as an object of Python ints.
  if (all(grepl("^-?[0-9]+$", vals[present])))
    return(classify_integer_strings(vals, bigint = bigint, col = col))

  # Float-shaped strings (incl. "nan", "inf", "-inf", scientific notation).
  # as.numeric returns NA for unparseable strings; require the parse to
  # introduce no *new* NAs before accepting numeric classification.
  nums <- suppressWarnings(as.numeric(vals))
  if (identical(is.na(nums), is.na(vals))) return(nums)

  # Otherwise treat as character vector.
  vals
}

# Whether a series carries reticulate's convert flag decides whether calls on it
# come back as python objects or as already-converted R vectors. Converting
# unconditionally errors on the latter with "Object to convert is not a Python
# object", which used to be swallowed by the try() below, silently disabling the
# int64 rescue in pandas2df_inmem() and leaving 64-bit ids overflowed to NA.
py_to_r_if_needed <- function(x) {
  if (inherits(x, "python.builtin.object")) reticulate::py_to_r(x) else x
}

pandas_series_character_values <- function(series) {
  # astype("str"), not map(str): mapping python str() over a nullable Int64 /
  # UInt64 Series that holds a missing value first upcasts it to float64, so
  # 64-bit ids come back in scientific notation and lose precision -- and the
  # int64 rescue in pandas2df_inmem() then collapses the whole column to NA.
  # astype("str") stringifies the integer cells exactly and renders missing
  # cells as "<NA>", which the isna() mask below turns into NA.
  vals <- try(py_to_r_if_needed(
    reticulate::py_call(series$astype, "str")$tolist()), silent = TRUE)
  if (inherits(vals, "try-error"))
    return(NULL)
  vals <- as.character(unlist(vals, use.names = FALSE))
  missing <- try(py_to_r_if_needed(reticulate::py_call(
    reticulate::py_call(series$isna)$to_numpy)), silent = TRUE)
  if (inherits(missing, "try-error"))
    return(NULL)
  missing <- as.logical(missing)
  if (length(missing) == length(vals))
    vals[missing] <- NA_character_
  vals
}

is_posixct_list <- function(x) {
  if (!is.list(x) || inherits(x, "data.frame") || inherits(x, "vctrs_vctr"))
    return(FALSE)
  all(vapply(x, function(el) {
    length(el) <= 1L && (length(el) == 0L || inherits(el, "POSIXt"))
  }, logical(1)))
}

flatten_posixct_list <- function(x) {
  if (!is_posixct_list(x))
    return(x)
  vals <- lapply(x, function(el) {
    if (length(el)) el else as.POSIXct(NA)
  })
  do.call(c, vals)
}

normalise_posixct_utc <- function(x) {
  tz <- attr(x, "tzone")
  if (inherits(x, "POSIXct") && (is.null(tz) || !nzchar(tz)))
    attr(x, "tzone") <- "UTC"
  x
}

#' Replace NULL elements of a list with NA
#'
#' @description A small helper that turns the `NULL`s in a list (e.g. missing
#'   fields in a parsed JSON/Python response) into `NA`, returning a simplified
#'   vector.
#'
#' @param x A list, possibly containing `NULL` elements.
#'
#' @return A vector with each `NULL` replaced by `NA`, simplified by [sapply()].
#' @export
#' @examples
#' null2na(list(1, NULL, 3))
null2na <- function(x)
  sapply(x, function(y) if (is.null(y)) NA else y, USE.NAMES = FALSE)
