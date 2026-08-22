# Replace NULL elements of a list with NA

A small helper that turns the `NULL`s in a list (e.g. missing fields in
a parsed JSON/Python response) into `NA`, returning a simplified vector.

## Usage

``` r
null2na(x)
```

## Arguments

- x:

  A list, possibly containing `NULL` elements.

## Value

A vector with each `NULL` replaced by `NA`, simplified by
[`sapply()`](https://rdrr.io/r/base/lapply.html).

## Examples

``` r
null2na(list(1, NULL, 3))
#> [1]  1 NA  3
```
