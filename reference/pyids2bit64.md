# Convert a numpy 64-bit integer array to R

Parses a numpy array (or Python list/int) of 64-bit integer ids into a
[`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
vector or character, round-tripping through raw bytes so no precision is
lost.

## Usage

``` r
pyids2bit64(x, as_character = TRUE)
```

## Arguments

- x:

  A numpy array, Python list or Python int of 64-bit integers.

- as_character:

  If `TRUE` (the default) return a character vector; otherwise a
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
  vector.

## Value

A character or
[`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
vector.

## Details

Only `int64` and `uint64` numpy dtypes are accepted; a `uint64` array is
checked for values that would overflow signed int64 and errors if any is
found. The bytes are written to a temporary file and read back as
doubles whose class is then set to `integer64`, which is exact for all
64-bit ids.

## See also

[`rids2pyint()`](https://flyconnectome.github.io/nat.python/reference/rids2pyint.md)
for the reverse direction.

## Examples

``` r
if (FALSE) { # \dontrun{
np <- reticulate::import("numpy", convert = FALSE)
pyids2bit64(np$array(c("123", "456"), dtype = "uint64"))
} # }
```
