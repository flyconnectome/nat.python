# Convert R ids to Python 64-bit integers

Converts R ids (character,
[`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html),
integer or numeric) into a Python list of ints or a numpy `int64` array,
via a 64-bit-exact path.

## Usage

``` r
rids2pyint(x, numpyarray = FALSE, usefile = NA)
```

## Arguments

- x:

  R ids in any form coercible to
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html),
  or a numpy array (passed through).

- numpyarray:

  If `TRUE`, return a numpy array; otherwise (the default) a Python list
  of ints.

- usefile:

  Whether to marshal via a temporary binary file (robust for large
  vectors) or an in-memory string. `NA` (the default) chooses
  automatically based on length.

## Value

A Python list of ints, or a numpy `int64` array when
`numpyarray = TRUE`.

## See also

[`pyids2bit64()`](https://flyconnectome.github.io/nat.python/reference/pyids2bit64.md)
for the reverse direction.

## Examples

``` r
if (FALSE) { # \dontrun{
rids2pyint(c("720575940621039145", "720575940626877799"))
} # }
```
