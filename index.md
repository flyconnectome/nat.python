# nat.python

> **⚠️ Design-phase package.** nat.python is being extracted from
> [fafbseg](https://github.com/natverse/fafbseg) and is **not yet ready
> for general use**. The API is unstable and may change without notice.
> See
> [`nat.python-plan.md`](https://flyconnectome.github.io/nat.python/nat.python-plan.md)
> for the full design, scope and migration plan.

nat.python is a small shared layer of **library-agnostic** Python
interoperability helpers built on
[reticulate](https://rstudio.github.io/reticulate/). It holds only the
code that does not care *which* Python library you are talking to:

- **introspection** — which modules are installed and at what version
  ([`py_module_info()`](https://flyconnectome.github.io/nat.python/reference/py_module_info.md),
  `py_module_info2()`,
  [`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md),
  [`module_available()`](https://flyconnectome.github.io/nat.python/reference/module_available.md));
- **conversion** — turn generic Python return values into idiomatic R:
  [`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md)
  (pandas `DataFrame` → R data frame, preserving 64-bit ids, object
  columns and datetimes),
  [`ts2pydatetime()`](https://flyconnectome.github.io/nat.python/reference/ts2pydatetime.md),
  [`null2na()`](https://flyconnectome.github.io/nat.python/reference/null2na.md);
- **id bridging** — 64-bit integer ids between R (`bit64`), numpy and
  raw bytes
  ([`pyids2bit64()`](https://flyconnectome.github.io/nat.python/reference/pyids2bit64.md),
  [`rids2pyint()`](https://flyconnectome.github.io/nat.python/reference/rids2pyint.md),
  [`rids2raw()`](https://flyconnectome.github.io/nat.python/reference/rids2raw.md),
  [`int64_overflows()`](https://flyconnectome.github.io/nat.python/reference/int64_overflows.md)).

It contains **no knowledge of any specific Python package**
(`cloudvolume`, `caveclient`, `seatable_api`, `navis`, …) or scientific
domain. Packages such as [fafbseg](https://github.com/natverse/fafbseg),
[bancr](https://github.com/flyconnectome/bancr) and
[seatabler](https://github.com/flyconnectome/seatabler) depend on
nat.python and supply that specificity themselves.

The name follows the `nat*` family (`nat`, `nat.utils`, `nat.nblast`) —
read it as “nat + Python interop”. It is unrelated to the PyPI package
`natpy`.

## Status

This repository currently implements **Phase 1** of the plan: the module
introspection, pandas/numpy → R conversion, and large-integer bridging
code, lifted out of fafbseg. The Python *environment engine* (the
mechanics under `simple_python`) and the diagnostic `py_report()` are
**Phase 2** and not yet here. See
[`nat.python-plan.md`](https://flyconnectome.github.io/nat.python/nat.python-plan.md).

## Installation

``` r

# install.packages("remotes")
remotes::install_github("flyconnectome/nat.python")
```

nat.python does not manage Python environments itself (yet — see the
plan). It uses whatever interpreter reticulate resolves. The conversion
functions need `numpy` and `pandas` in that environment; the
`use_arrow = TRUE` path additionally needs the R `arrow` package.

## Usage

``` r

library(nat.python)

# What is installed?
module_version("pandas")
py_module_info(c("numpy", "pandas"))

# Convert a pandas DataFrame, keeping 64-bit ids exact
pd <- reticulate::import("pandas")
df <- pd$DataFrame(list(id = c("720575940621039145", "720575940626877799")))
pandas2df(df)
```

## License

GPL-3
