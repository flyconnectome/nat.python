# nat.python: library-agnostic Python interoperability for R

nat.python is a small shared layer of Python interoperability helpers
built on reticulate. It holds only code that is agnostic to *which*
Python library you are talking to: introspecting an environment,
converting generic Python return values to idiomatic R, and bridging
large integer identifiers.

It deliberately contains no knowledge of any specific Python package
(`cloudvolume`, `caveclient`, `seatable_api`, ...) or scientific domain.
Packages such as fafbseg, bancr and seatabler depend on nat.python and
supply that specificity themselves.

## Main tools

- [`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md)
  — convert a pandas `DataFrame` to an R data frame, preserving 64-bit
  integer, object and datetime columns.

- [`py_module_info()`](https://flyconnectome.github.io/nat.python/reference/py_module_info.md),
  [`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md),
  [`module_available()`](https://flyconnectome.github.io/nat.python/reference/module_available.md)
  — introspect the active Python environment.

- [`pyids2bit64()`](https://flyconnectome.github.io/nat.python/reference/pyids2bit64.md),
  [`rids2pyint()`](https://flyconnectome.github.io/nat.python/reference/rids2pyint.md),
  [`rids2raw()`](https://flyconnectome.github.io/nat.python/reference/rids2raw.md)
  — bridge 64-bit integer ids between R (`bit64`), numpy and raw bytes.

- [`ts2pydatetime()`](https://flyconnectome.github.io/nat.python/reference/ts2pydatetime.md)
  — convert an R time to a timezone-explicit Python `datetime`.

## See also

Useful links:

- <https://github.com/flyconnectome/nat.python>

- Report bugs at <https://github.com/flyconnectome/nat.python/issues>

## Author

**Maintainer**: Gregory Jefferis <jefferis@gmail.com>
([ORCID](https://orcid.org/0000-0002-0587-9355))

Authors:

- Gregory Jefferis <jefferis@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-0587-9355))
