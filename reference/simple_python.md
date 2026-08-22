# Install a managed Python environment for R

Sets up (and optionally populates) a dedicated miniconda Python
environment for use from R via reticulate. This is the ecosystem's
shared provisioning entry point: packages such as fafbseg, bancr and
seatabler all route their Python installation through it, so users have
one command to run and one environment to manage.

## Usage

``` r
simple_python(
  pyinstall = c("basic", "full", "extra", "minimal", "cleanenv", "blast", "none"),
  pkgs = NULL,
  miniconda = TRUE
)
```

## Arguments

- pyinstall:

  Which package bundle to install. One of `"basic"`, `"full"`,
  `"extra"`, `"minimal"`, `"cleanenv"`, `"blast"` or `"none"`.

- pkgs:

  Optional character vector of additional Python packages (pip
  specifications) to install into the environment.

- miniconda:

  Whether to use the managed miniconda environment (strongly
  recommended). When `FALSE` your current Python is used as-is.

## Value

Invisibly `NULL`. Called for its side effect of provisioning Python.

## Details

With `miniconda = TRUE` (the default and recommendation) a private
miniconda install and `r-reticulate` conda environment are
created/updated, independent of any system Python. The `pyinstall`
bundles install a curated set of packages used across the
FlyWire/connectomics ecosystem: `"minimal"` installs just pandas –
nat.python's own baseline, needed by
[`pandas2df()`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md),
with numpy coming in as its dependency; `"basic"` adds cloud-volume,
seatable_api and CAVEclient on top; `"full"` adds navis + fafbseg;
`"extra"` additionally installs skeletonisation tooling (skeletor,
meshparty and friends). `"none"` provisions the environment but installs
no bundle, which is what you want when passing your own `pkgs`.
`"cleanenv"` and `"blast"` only print the (destructive) commands needed
to remove an environment; they never delete anything themselves.

After any installation the cached module versions
([`forget_module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md))
and the
[`check_module()`](https://flyconnectome.github.io/nat.python/reference/check_module.md)
memoise cache are cleared so that subsequent checks reflect the new
environment.

## Examples

``` r
if (FALSE) { # \dontrun{
simple_python("basic")                          # the common case
simple_python("minimal")                        # just pandas (+ numpy)
simple_python("minimal", pkgs = "seatable_api") # pandas baseline + one pkg
simple_python("none", pkgs = "seatable_api")    # just one package
} # }
```
