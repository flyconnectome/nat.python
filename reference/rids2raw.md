# Convert 64-bit integer ids to raw bytes

Serialises 64-bit integer ids to a raw byte vector, little-endian by
default (as flywire servers expect).

## Usage

``` r
rids2raw(ids, endian = "little", ...)
```

## Arguments

- ids:

  R ids in any form coercible to
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html).

- endian:

  Byte order, `"little"` (the default), `"big"`, or `NULL` to use the
  current platform's.

- ...:

  Additional arguments passed to
  [`writeBin()`](https://rdrr.io/r/base/readBin.html).

## Value

A raw vector of `8 * length(ids)` bytes.

## Examples

``` r
rids2raw(c("123", "456"))
#>  [1] 7b 00 00 00 00 00 00 00 c8 01 00 00 00 00 00 00
```
