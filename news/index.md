# Changelog

## nat.python 0.2.0.9000 (development version)

- [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  now pins the managed environment’s Python interpreter to a known-good
  version (new `python_version` argument, default `"3.12"`, overridable
  via `options(nat.python.python_version=)`) instead of letting
  reticulate pick, which on a fresh install can be a bleeding-edge
  Python that key packages do not yet support. An existing environment
  at a different version is kept, with a warning pointing at
  `simple_python("cleanenv")`.
- [`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md)
  now converts pandas extension-array columns that reticulate leaves
  unconverted, in particular pandas 3.0’s default Arrow-backed string
  dtype (PDEP-14): string columns become R character vectors and other
  Arrow columns (e.g. `int64[pyarrow]` ids) map to the same R types as
  their native-dtype equivalents
  ([\#6](https://github.com/flyconnectome/nat.python/issues/6)).
- [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  pins the baseline install to `pandas < 3` for now. Although
  [`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md)
  handles pandas 3.0, the pin is retained as a caution while the wider
  ecosystem settles on pandas 3; lift it (back to `pandas`) once ready.
- CI now provisions Python through
  [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  itself (the end-user path), rather than a bespoke
  [`reticulate::py_install()`](https://rstudio.github.io/reticulate/reference/py_install.html)
  call.

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
