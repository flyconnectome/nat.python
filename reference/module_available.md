# Check whether a Python module is available

Tests whether a Python module can be imported, optionally warning or
erroring with an install hint when it cannot. Generalises the
per-package `*_available()` checks (e.g. fafbseg's
`dracopy_available()`), which become thin wrappers that supply their own
`install_hint`.

## Usage

``` r
module_available(
  module,
  action = c("none", "warning", "stop"),
  install_hint = NULL
)
```

## Arguments

- module:

  A single Python module (import) name.

- action:

  What to do when the module is missing: `"none"` (the default, just
  return `FALSE`), `"warning"`, or `"stop"`.

- install_hint:

  Optional character vector of extra lines appended to the warning/error
  message, e.g. how to install the module.

## Value

`TRUE` or `FALSE`, invisibly when `action != "none"`.

## Examples

``` r
if (FALSE) { # \dontrun{
module_available("numpy")
module_available("DracoPy", action = "stop",
  install_hint = "Install with fafbseg::simple_python('basic').")
} # }
```
