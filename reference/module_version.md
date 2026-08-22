# The installed version of a Python module

Returns the version string of an installed Python module, or `NA` if it
is not available. The result is cached for the session; call
`forget_module_version()` after installing or upgrading modules to clear
it.

`forget_module_version()` clears the `module_version()` cache.

## Usage

``` r
module_version(module)

forget_module_version()
```

## Arguments

- module:

  A single Python module (import) name.

## Value

A version string, or `NA_character_` if the module is not installed.

`forget_module_version()` returns `NULL` invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
module_version("numpy")
if (!is.na(module_version("pandas"))) message("pandas is available")
} # }
```
