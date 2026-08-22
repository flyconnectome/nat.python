# Convert a pandas DataFrame to an R data frame

Converts a pandas `DataFrame` into an R `data.frame` (or a tibble),
preserving the column types reticulate's default conversion gets wrong:
64-bit integer ids, object-dtype columns, and datetimes.

## Usage

``` r
pandas2df(
  x,
  use_arrow = FALSE,
  keep_index = FALSE,
  tibble = use_arrow,
  bigint = c("auto", "integer64", "character")
)
```

## Arguments

- x:

  A pandas `DataFrame` (a reticulate `pandas.core.frame.DataFrame`).

- use_arrow:

  If `TRUE`, convert via a temporary Feather file using the `arrow`
  package rather than in memory. Implies a tibble result.

- keep_index:

  Whether to keep the pandas index as a column.

- tibble:

  Whether to return a tibble rather than a base data frame. Defaults to
  `use_arrow`.

- bigint:

  How to represent integer columns. `"auto"` (the default) maps each
  column to the narrowest faithful base R type: values fitting a 32-bit
  R `integer` become `integer`, larger values below 2^53 become `double`
  (exact), and values from 2^53 up to the signed 64-bit maximum become
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
  – reserving `integer64` for what base R cannot hold exactly.
  `"integer64"` returns every integer column as
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
  for a stable schema regardless of magnitude. `"character"` behaves
  like `"auto"` but returns the large (\>= 2^53) tier as character, as
  `data.table::fread()` offers. `uint64` values beyond the signed 64-bit
  range cannot be held by `integer64`; they are always returned as
  character, with a warning unless `bigint = "character"`.

## Value

An R `data.frame`, or a tibble when `tibble = TRUE`.

## Details

The default in-memory path converts with reticulate and then patches
individual columns:

- Integer columns (`int64`, `uint64`, and `object` columns whose cells
  are all Python ints) are classified by magnitude so each maps to the
  narrowest faithful R type. This mirrors reticulate's own `py_to_r()`
  where reticulate is faithful, and reserves
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
  for values base R cannot hold exactly – see `bigint`.

- `object` columns whose cells are all scalar (or `NA`) are flattened
  from a list of length-1 vectors to an atomic vector, with
  integer-valued cells read as strings so arbitrary-precision Python
  ints round-trip. Genuine list-valued columns (e.g. multi-select
  values) are left intact.

- datetime columns are normalised to `POSIXct` in UTC.

The optional `use_arrow` path round-trips through a Feather file and
needs the Suggested `arrow` package; `bigint` does not apply to it.

## Examples

``` r
if (FALSE) { # \dontrun{
pd <- reticulate::import("pandas")
df <- pd$DataFrame(list(id = c("720575940621039145", "720575940626877799")))
pandas2df(df)
} # }
```
