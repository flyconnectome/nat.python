# Large-integer / id bridging between R (bit64), numpy and raw bytes.
#
# Generic uint64/int64 handling only -- no neuroglancer / segment-id parsing,
# which stays in fafbseg (see nat.python-plan.md §3d, §5.2). Ported from
# fafbseg's pyids2bit64 / rids2pyint / rids2raw / int64_overflows.

#' Detect character input that would overflow signed 64-bit integers
#'
#' @description Returns `TRUE` for any element of `x` that does not fit in a
#'   signed 64-bit integer, papering over a behaviour change across `bit64`
#'   versions.
#'
#' @details `bit64` < 4.8.0 silently clamped overflowing character input to the
#'   maximum int64; >= 4.8.0 returns `NA` with a warning. This helper detects
#'   both signatures so callers get a consistent logical vector regardless of the
#'   installed `bit64`.
#'
#' @param x A character vector of integer-shaped strings.
#'
#' @return A logical vector the same length as `x`.
#' @export
#' @examples
#' int64_overflows(c("123", "9223372036854775807", "9223372036854775808"))
int64_overflows <- function(x) {
  maxint64 <- "9223372036854775807"
  i64x <- suppressWarnings(bit64::as.integer64(x))
  # NA + non-NA input == new-bit64 overflow signature;
  # i64 == maxint64 but x != maxint64 == old-bit64 clamp signature.
  (!is.na(x) & is.na(i64x)) |
    (!is.na(i64x) & i64x == bit64::as.integer64(maxint64) & x != maxint64)
}

#' Convert a numpy 64-bit integer array to R
#'
#' @description Parses a numpy array (or Python list/int) of 64-bit integer ids
#'   into a `bit64::integer64` vector or character, round-tripping through raw
#'   bytes so no precision is lost.
#'
#' @details Only `int64` and `uint64` numpy dtypes are accepted; a `uint64` array
#'   is checked for values that would overflow signed int64 and errors if any is
#'   found. The bytes are written to a temporary file and read back as doubles
#'   whose class is then set to `integer64`, which is exact for all 64-bit ids.
#'
#' @param x A numpy array, Python list or Python int of 64-bit integers.
#' @param as_character If `TRUE` (the default) return a character vector;
#'   otherwise a `bit64::integer64` vector.
#'
#' @return A character or `bit64::integer64` vector.
#' @seealso [rids2pyint()] for the reverse direction.
#' @export
#' @examples
#' \dontrun{
#' np <- reticulate::import("numpy", convert = FALSE)
#' pyids2bit64(np$array(c("123", "456"), dtype = "uint64"))
#' }
pyids2bit64 <- function(x, as_character = TRUE) {
  np <- py_np()
  if (inherits(x, "python.builtin.list") || inherits(x, "python.builtin.int"))
    x <- np$asarray(x, dtype = "i8")

  if (isTRUE(x$size == 0L))
    return(if (as_character) character() else bit64::integer64())

  if (isFALSE(as.character(x$dtype) == "int64")) {
    if (isFALSE(as.character(x$dtype) == "uint64"))
      stop("I only accept dtype=int64 or uint64 numpy arrays!")
    # uint64 input: check that its maximum can be represented as int64.
    strmax <- reticulate::py_str(np$amax(x))
    if (int64_overflows(strmax))
      stop("int64 overflow! uint64 id cannot be represented as int64")
  }

  tf <- tempfile()
  on.exit(unlink(tf))
  x$tofile(tf)
  fi <- file.info(tf)
  if (fi$size %% 8L != 0)
    stop("Trouble parsing python int64. Binary data not a multiple of 8 bytes")

  # read in as double but then set class manually
  ids <- readBin(tf, what = "double", n = fi$size / 8, size = 8)
  class(ids) <- "integer64"
  if (as_character) ids <- as.character(ids)
  ids
}

#' Convert R ids to Python 64-bit integers
#'
#' @description Converts R ids (character, `bit64::integer64`, integer or
#'   numeric) into a Python list of ints or a numpy `int64` array, via a
#'   64-bit-exact path.
#'
#' @param x R ids in any form coercible to `bit64::integer64`, or a numpy array
#'   (passed through).
#' @param numpyarray If `TRUE`, return a numpy array; otherwise (the default) a
#'   Python list of ints.
#' @param usefile Whether to marshal via a temporary binary file (robust for
#'   large vectors) or an in-memory string. `NA` (the default) chooses
#'   automatically based on length.
#'
#' @return A Python list of ints, or a numpy `int64` array when
#'   `numpyarray = TRUE`.
#' @seealso [pyids2bit64()] for the reverse direction.
#' @export
#' @examples
#' \dontrun{
#' rids2pyint(c("720575940621039145", "720575940626877799"))
#' }
rids2pyint <- function(x, numpyarray = FALSE, usefile = NA) {
  if (!requireNamespace("reticulate", quietly = TRUE))
    stop("Please install the 'reticulate' package.", call. = FALSE)
  np <- py_np(convert = FALSE)
  npa <- if (inherits(x, "np.ndarray")) x
  else if (!isTRUE(usefile) && (length(x) < 1e4 || isFALSE(usefile))) {
    ids <- as.character(x)
    str <- if (length(ids) == 1) ids else paste0(ids, collapse = ",")
    np$fromstring(str, dtype = "i8", sep = ",")
  } else {
    x <- bit64::as.integer64(x)
    tf <- tempfile(fileext = ".bin")
    on.exit(unlink(tf))
    writeBin(unclass(x), tf, size = 8L)
    np$fromfile(tf, dtype = "i8")
  }
  if (isTRUE(numpyarray)) npa else reticulate::py_call(npa$tolist)
}

#' Convert 64-bit integer ids to raw bytes
#'
#' @description Serialises 64-bit integer ids to a raw byte vector, little-endian
#'   by default (as flywire servers expect).
#'
#' @param ids R ids in any form coercible to `bit64::integer64`.
#' @param endian Byte order, `"little"` (the default), `"big"`, or `NULL` to use
#'   the current platform's.
#' @param ... Additional arguments passed to [writeBin()].
#'
#' @return A raw vector of `8 * length(ids)` bytes.
#' @export
#' @examples
#' rids2raw(c("123", "456"))
rids2raw <- function(ids, endian = "little", ...) {
  if (is.null(endian)) endian <- .Platform$endian
  ids <- bit64::as.integer64(ids)
  rc <- rawConnection(raw(0), "wb")
  on.exit(close(rc))
  writeBin(unclass(ids), rc, size = 8L, endian = endian, ...)
  rawConnectionValue(rc)
}
