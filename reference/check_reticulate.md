# Check that a working Python is available via reticulate

reticulate is a hard dependency of nat.python, so this really just
checks that a usable Python is set up, guiding the user to
[`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
when it is not. The name is kept for continuity with the ecosystem's
`check_reticulate()` entry point.

## Usage

``` r
check_reticulate(check_python = TRUE)
```

## Arguments

- check_python:

  Whether to check that a working Python is available. When `FALSE` the
  function is a no-op returning `TRUE`.

## Value

Invisibly `TRUE` when the check passes, `FALSE` otherwise.
