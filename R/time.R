# Generic R <-> Python time conversion.
#
# ts2pydatetime lived in fafbseg's cave.R but is not CAVE-specific (see
# nat.python-plan.md §3e); it converts a plain R time to a Python datetime.

#' Convert an R time to a Python datetime
#'
#' @description Converts an R `POSIXct`/`POSIXt` (or anything
#'   [as.POSIXlt()] accepts) into a timezone-explicit Python `datetime` in UTC.
#'   A value that is already a Python `datetime` is returned unchanged.
#'
#' @details The timezone is made explicit (UTC) on the Python side so that
#'   downstream code does not silently reinterpret a naive datetime in the local
#'   zone.
#'
#' @param x An R time, or an existing Python `datetime.datetime`.
#'
#' @return A Python `datetime.datetime` with `tzinfo` set to UTC.
#' @export
#' @examples
#' \dontrun{
#' ts2pydatetime(Sys.time())
#' }
ts2pydatetime <- function(x) {
  if (inherits(x, "datetime.datetime"))
    return(x)
  dt <- reticulate::import("datetime")
  x2 <- as.numeric(as.POSIXlt(x, origin = "1970-01-01", "UTC"))
  utc <- dt$timezone$utc
  # make timezone explicit so there are no conversion issues later
  reticulate::py_call(dt$datetime$fromtimestamp, x2, utc)
}
