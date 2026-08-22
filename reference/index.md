# Package index

## Package

- [`nat.python`](https://flyconnectome.github.io/nat.python/reference/nat.python-package.md)
  [`nat.python-package`](https://flyconnectome.github.io/nat.python/reference/nat.python-package.md)
  : nat.python: library-agnostic Python interoperability for R

## Python environment provisioning

Set up and check a managed Python for use from R via reticulate.

- [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  : Install a managed Python environment for R
- [`check_reticulate()`](https://flyconnectome.github.io/nat.python/reference/check_reticulate.md)
  : Check that a working Python is available via reticulate

## Module management

Check, load and introspect Python modules, installing on demand.

- [`check_module()`](https://flyconnectome.github.io/nat.python/reference/check_module.md)
  : Ensure a Python module is installed and importable
- [`module_available()`](https://flyconnectome.github.io/nat.python/reference/module_available.md)
  : Check whether a Python module is available
- [`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md)
  [`forget_module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md)
  : The installed version of a Python module
- [`py_module_info()`](https://flyconnectome.github.io/nat.python/reference/py_module_info.md)
  : Report on installed Python modules

## pandas and data conversion

Convert pandas DataFrames to R, recovering 64-bit ids and datetimes.

- [`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md)
  : Convert a pandas DataFrame to an R data frame
- [`null2na()`](https://flyconnectome.github.io/nat.python/reference/null2na.md)
  : Replace NULL elements of a list with NA

## 64-bit id marshalling

Round-trip large integer ids between R (bit64) and Python without loss.

- [`pyids2bit64()`](https://flyconnectome.github.io/nat.python/reference/pyids2bit64.md)
  : Convert a numpy 64-bit integer array to R
- [`rids2pyint()`](https://flyconnectome.github.io/nat.python/reference/rids2pyint.md)
  : Convert R ids to Python 64-bit integers
- [`rids2raw()`](https://flyconnectome.github.io/nat.python/reference/rids2raw.md)
  : Convert 64-bit integer ids to raw bytes
- [`int64_overflows()`](https://flyconnectome.github.io/nat.python/reference/int64_overflows.md)
  : Detect character input that would overflow signed 64-bit integers

## Datetime

- [`ts2pydatetime()`](https://flyconnectome.github.io/nat.python/reference/ts2pydatetime.md)
  : Convert an R time to a Python datetime
