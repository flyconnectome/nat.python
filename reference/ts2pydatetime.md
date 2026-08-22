# Convert an R time to a Python datetime

Converts an R `POSIXct`/`POSIXt` (or anything
[`as.POSIXlt()`](https://rdrr.io/r/base/as.POSIXlt.html) accepts) into a
timezone-explicit Python `datetime` in UTC. A value that is already a
Python `datetime` is returned unchanged.

## Usage

``` r
ts2pydatetime(x)
```

## Arguments

- x:

  An R time, or an existing Python `datetime.datetime`.

## Value

A Python `datetime.datetime` with `tzinfo` set to UTC.

## Details

The timezone is made explicit (UTC) on the Python side so that
downstream code does not silently reinterpret a naive datetime in the
local zone.

## Examples

``` r
if (FALSE) { # \dontrun{
ts2pydatetime(Sys.time())
} # }
```
