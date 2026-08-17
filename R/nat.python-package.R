#' nat.python: library-agnostic Python interoperability for R
#'
#' @description nat.python is a small shared layer of Python interoperability
#'   helpers built on \pkg{reticulate}. It holds only code that is agnostic to
#'   *which* Python library you are talking to: introspecting an environment,
#'   converting generic Python return values to idiomatic R, and bridging large
#'   integer identifiers.
#'
#'   It deliberately contains no knowledge of any specific Python package
#'   (\code{cloudvolume}, \code{caveclient}, \code{seatable_api}, ...) or
#'   scientific domain. Packages such as fafbseg, bancr and seatabler depend on
#'   nat.python and supply that specificity themselves.
#'
#' @section Main tools:
#'   * [pandas2df()] — convert a pandas `DataFrame` to an R data frame,
#'     preserving 64-bit integer, object and datetime columns.
#'   * [py_module_info()], [module_version()], [module_available()] — introspect
#'     the active Python environment.
#'   * [pyids2bit64()], [rids2pyint()], [rids2raw()] — bridge 64-bit integer ids
#'     between R (`bit64`), numpy and raw bytes.
#'   * [ts2pydatetime()] — convert an R time to a timezone-explicit Python
#'     `datetime`.
#'
#' @keywords internal
"_PACKAGE"
