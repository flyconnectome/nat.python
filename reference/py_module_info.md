# Report on installed Python modules

Reports which of the named Python modules are installed and at what
version *without importing* them — cheap, and safe for modules with
heavy or side-effecting imports.

## Usage

``` r
py_module_info(modules)
```

## Arguments

- modules:

  Character vector of Python module (import) names.

## Value

A data frame with one row per unique module and columns `module`,
`available`, `version`.

## Details

Reads Python distribution metadata via `importlib.metadata` (or the
`importlib_metadata` backport) together with `packages_distributions()`
to map top-level import names onto installed distributions, so the
target modules are never imported. Modules installed without standard
distribution metadata (namespace packages, some editable installs) can
therefore report as unavailable here even when they are importable;
[`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md)
falls back to importing in that case.

## Examples

``` r
if (FALSE) { # \dontrun{
py_module_info(c("numpy", "pandas"))
} # }
```
