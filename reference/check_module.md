# Ensure a Python module is installed and importable

A generic gate for code that needs a particular Python module: it checks
the module is installed, imports it, optionally enforces a minimum
version, and — when it is missing — either installs it (interactively or
on request) or errors with actionable guidance. Package-specific checks
(such as fafbseg's `check_seatable()` /
`check_cloudvolume_reticulate()`) become thin wrappers over this.

## Usage

``` r
check_module(
  module,
  package = module,
  min_version = NULL,
  install = c("ask", "never", "always"),
  install_cmd = "none",
  docs_url = NULL,
  cache = TRUE
)
```

## Arguments

- module:

  A single Python module (import) name, e.g. `"seatable_api"`.

- package:

  The pip package (distribution) name to install if `module` is missing.
  Defaults to `module`; supply it when they differ (e.g. import `"cv2"`
  from package `"opencv-python"`).

- min_version:

  Optional minimum acceptable version (character or
  [numeric_version](https://rdrr.io/r/base/numeric_version.html)).
  Checked on every call via
  [`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md).

- install:

  How to handle a missing module: `"ask"` (the default) prompts in an
  interactive session and otherwise errors; `"never"` always errors with
  install instructions; `"always"` installs without prompting.

- install_cmd:

  The bundle argument passed to
  [`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  when installing (default `"none"`, i.e. install only `package`). Use
  e.g. `"basic"` to pull a whole ecosystem bundle instead.

- docs_url:

  Optional documentation URL added to the failure message.

- cache:

  Whether to use (and populate) the session cache of results (default
  `TRUE`). Pass `FALSE` to force a fresh check — e.g. after installing
  or upgrading the module out of band.

## Value

The imported module (a reticulate object), invisibly.

## Details

The check is deliberately ordered **installed-first, load-second**,
because the two failure modes need different advice. Installation is
detected from Python distribution metadata via
[`py_module_info()`](https://flyconnectome.github.io/nat.python/reference/py_module_info.md)
(which does not import the module), falling back to
[`reticulate::py_module_available()`](https://rstudio.github.io/reticulate/reference/py_module_available.html)
for namespace/local packages that lack metadata. Only once the module is
known to be installed is it actually imported, so an import that fails
then is reported as a *load* problem (a broken or mismatched
environment), distinct from the package simply being absent — with the
underlying Python error surfaced.

The result is memoised for the session, so repeated calls for the same
module are cheap and hand back the already-imported module object. Any
installation via
[`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
clears this cache (as well as the
[`module_version()`](https://flyconnectome.github.io/nat.python/reference/module_version.md)
cache), so the next call re-checks and picks up the newly installed
package. Because of this, package-specific wrappers need not memoise
themselves.

## Examples

``` r
if (FALSE) { # \dontrun{
seatable_api <- check_module("seatable_api")
cv <- check_module("cloudvolume", install_cmd = "basic", min_version = "5.0",
                   docs_url = "https://github.com/seung-lab/cloud-volume#setup")
} # }
```
