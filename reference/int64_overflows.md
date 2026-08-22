# Detect character input that would overflow signed 64-bit integers

Returns `TRUE` for any element of `x` that does not fit in a signed
64-bit integer, papering over a behaviour change across `bit64`
versions.

## Usage

``` r
int64_overflows(x)
```

## Arguments

- x:

  A character vector of integer-shaped strings.

## Value

A logical vector the same length as `x`.

## Details

`bit64` \< 4.8.0 silently clamped overflowing character input to the
maximum int64; \>= 4.8.0 returns `NA` with a warning. This helper
detects both signatures so callers get a consistent logical vector
regardless of the installed `bit64`.

## Examples

``` r
int64_overflows(c("123", "9223372036854775807", "9223372036854775808"))
#> [1] FALSE FALSE  TRUE
```
