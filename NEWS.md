# nat.python 0.2.0.9000 (development version)

* `pandas2df()` now converts pandas extension-array columns that reticulate
  leaves unconverted, in particular pandas 3.0's default Arrow-backed string
  dtype (PDEP-14): string columns become R character vectors and other Arrow
  columns (e.g. `int64[pyarrow]` ids) map to the same R types as their
  native-dtype equivalents (#6).
* `simple_python()` pins the baseline install to `pandas < 3` for now. Although
  `pandas2df()` handles pandas 3.0, the pin is retained as a caution while the
  wider ecosystem settles on pandas 3; lift it (back to `pandas`) once ready.
* CI now provisions Python through `simple_python()` itself (the end-user path),
  rather than a bespoke `reticulate::py_install()` call.

# nat.python 0.2.0

First tagged release. A small shared layer of Python interoperability and
environment management for the natverse, built on reticulate. fafbseg, bancr and
seatabler depend on it for both concerns.

## Python environment management
* `simple_python()` provisions and manages a shared miniconda environment, with
  curated bundles for the FlyWire/connectomics ecosystem: `"basic"`
  (cloud-volume + seatable_api + CAVEclient), `"full"` (+ navis + fafbseg),
  `"extra"` (+ skeletonisation tooling), `"minimal"` (just pandas, nat.python's
  own baseline; numpy rides in with it), and `"none"` for an env with no bundle.
* `check_reticulate()` checks a usable Python is available, guiding users to
  `simple_python()` when not.

## Module management
* `check_module()` — install/load gate that checks whether a module is present
  (from distribution metadata, without importing), imports it, and on absence
  offers to install it or errors with guidance.
* `module_available()`, `module_version()` / `forget_module_version()`,
  `py_module_info()` for introspecting the environment.

## Data conversion
* `pandas2df()` converts pandas `DataFrame`s to R, recovering 64-bit id columns
  as `bit64`, flattening object/numpy columns and coercing datetimes.
  * Fast-path for pandas nullable `Int64`/`UInt64` extension columns, which
    reticulate otherwise converts cell-by-cell (~24x faster on large id-heavy
    frames; output byte-for-byte identical).
  * A `bigint` argument and unified integer-column classification.
* `null2na()` helper for `None` → `NA`.

## 64-bit id marshalling
* `pyids2bit64()`, `rids2pyint()`, `rids2raw()` round-trip large integer
  identifiers between R (`bit64`), numpy and raw bytes without precision loss;
  `int64_overflows()` flags values that would overflow.

## Datetime
* `ts2pydatetime()` converts R timestamps to Python datetimes.
