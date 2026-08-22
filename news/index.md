# Changelog

## nat.python 0.2.0

First tagged release. A small shared layer of Python interoperability
and environment management for the natverse, built on reticulate.
fafbseg, bancr and seatabler depend on it for both concerns.

### Python environment management

- [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  provisions and manages a shared miniconda environment, with curated
  bundles for the FlyWire/connectomics ecosystem: `"basic"`
  (cloud-volume + seatable_api + CAVEclient), `"full"` (+ navis +
  fafbseg), `"extra"` (+ skeletonisation tooling), `"minimal"` (just
  pandas, nat.python’s own baseline; numpy rides in with it), and
  `"none"` for an env with no bundle.
- [`check_reticulate()`](https://flyconnectome.github.io/nat.python/reference/check_reticulate.md)
  checks a usable Python is available, guiding users to
  [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  when not.

### Module management

- [`check_module()`](https://flyconnectome.github.io/nat.python/reference/check_module.md)
  — install/load gate that checks whether a module is present (from
  distribution metadata, without importing), imports it, and on absence
  offers to install it or errors with guidance.
- [`module_available()`](https://flyconnectome.github.io/nat.python/reference/module_available.md),
  [`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md)
  /
  [`forget_module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md),
  [`py_module_info()`](https://flyconnectome.github.io/nat.python/reference/py_module_info.md)
  for introspecting the environment.

### Data conversion

- [`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md)
  converts pandas `DataFrame`s to R, recovering 64-bit id columns as
  `bit64`, flattening object/numpy columns and coercing datetimes.
  - Fast-path for pandas nullable `Int64`/`UInt64` extension columns,
    which reticulate otherwise converts cell-by-cell (~24x faster on
    large id-heavy frames; output byte-for-byte identical).
  - A `bigint` argument and unified integer-column classification.
- [`null2na()`](https://flyconnectome.github.io/nat.python/reference/null2na.md)
  helper for `None` → `NA`.

### 64-bit id marshalling

- [`pyids2bit64()`](https://flyconnectome.github.io/nat.python/reference/pyids2bit64.md),
  [`rids2pyint()`](https://flyconnectome.github.io/nat.python/reference/rids2pyint.md),
  [`rids2raw()`](https://flyconnectome.github.io/nat.python/reference/rids2raw.md)
  round-trip large integer identifiers between R (`bit64`), numpy and
  raw bytes without precision loss;
  [`int64_overflows()`](https://flyconnectome.github.io/nat.python/reference/int64_overflows.md)
  flags values that would overflow.

### Datetime

- [`ts2pydatetime()`](https://flyconnectome.github.io/nat.python/reference/ts2pydatetime.md)
  converts R timestamps to Python datetimes.
