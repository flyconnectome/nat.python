# nat.python — plan

Extract the **library-agnostic Python/reticulate machinery** currently
living in `fafbseg` (and duplicated in `bancr`, and about to be
re-needed by `seatabler`) into a small shared package, `nat.python`.

This document is self-contained: it captures the motivation, the
dividing principle, a function-level inventory of what moves vs stays,
the boundary judgement calls, and a phased migration, so work can resume
without prior context.

Companion to `~/dev/R/seatabler/seatabler-plan.md`, which arrived at the
same package from the SeaTable side (its `pandas2df` `TODO(port)`
markers resolve *here*).

------------------------------------------------------------------------

## 1. Motivation

Three consumers now need the same generic Python glue:

- **fafbseg** — CAVE (`caveclient`), cloudvolume, meshparty, navis, and
  FlyTable all go through reticulate and return pandas frames / numpy
  int64 ids.
- **bancr** — independently reimplements a chunk of the same (its own
  seatable + conversion code).
- **seatabler** — needs `pandas2df` for SeaTable SQL results, and would
  otherwise either duplicate it or acquire a backwards dependency on
  fafbseg.

The unifying concern is **not** SeaTable or flywire: it is *get a
working Python env, check what’s in it, call into it, and turn generic
Python return values (pandas DataFrames, numpy int64/uint64, datetimes,
`None`) into idiomatic R.* That is a real horizontal layer, currently
smeared across fafbseg. Naming it as `nat.python` lets every consumer
converge on one implementation and removes two present awkwardnesses
(see §6).

------------------------------------------------------------------------

## 2. The dividing principle (the one rule)

> **nat.python** holds code that is agnostic to *which* Python library
> you are talking to. **fafbseg** keeps everything that knows the API of
> a specific Python package (`cloudvolume`, `caveclient`, `meshparty`,
> `navis`, `dracopy`) or encodes flywire / neuroglancer / segmentation
> domain semantics. The library-specific code becomes a **consumer** of
> nat.python.

Litmus test: *if the function would make sense to someone using Python
for something completely unrelated to connectomics, it is nat.python.*
`pandas2df` passes; `flywire_cave_query` does not.

Explicit constraint (per design discussion): **CAVE-specific,
cloudvolume- specific, meshparty-specific and navis-specific code does
NOT belong in nat.python**, even the parts that feel like “just
interop”. They stay in fafbseg and call nat.python.

------------------------------------------------------------------------

## 3. What moves to nat.python

All paths are `fafbseg/R/`. All of these are **internal** (not exported)
unless marked, so they move with no user-visible break.

### 3a. Environment engine (`R/env.R`)

The mechanics under `simple_python`, not its opinionated package
bundles.

- `simple_python_base(what, miniconda)` — `utils.R:639`
- `checkownpython`, `ownpythonrequested` — `utils.R:712,717`
- `current_python`, `default_pyenv` — `utils.R:721,730`
- `update_miniconda_base` — `utils.R:738`
- `ourpip()` (pip helper used by the above)
- `check_python(initialize=)` — `utils.R:172`
- `check_reticulate(check_python=)` — `utils.R:162`

[`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
itself (the **exported** front-end, `utils.R:588`) **stays in fafbseg**
— see §4.

### 3b. Module introspection (`R/modules.R`)

- `py_module_info`, `py_module_info2` — `utils.R:345,287`
- `module_version` — (used by the `*_version` wrappers)
- `python_module_path` — `utils.R:374`
- `py_report` — `utils.R:216`
- a generic
  [`module_available()`](https://flyconnectome.github.io/nat.python/reference/module_available.md)
  (generalise `dracopy_available`’s mechanism)

### 3c. pandas / numpy → R conversion (`R/convert.R`)

The “decent chunk of code” — the whole cluster:

- `pandas2df`, `pandas2df_inmem` — `utils.R:760,788`
- `pandas_py_to_r_frame` — `utils.R:846`
- `pandas_dataframe_dtypes` — `utils.R:857`
- `pandas_series_integer64` — `utils.R:868`
- `pandas_object_series_to_vector` — `utils.R:895`
- `classify_object_values` — `utils.R:918`
- `py_to_r_if_needed` — `utils.R:948`
- `pandas_series_character_values` — `utils.R:952`
- `is_posixct_list`, `flatten_posixct_list`, `normalise_posixct_utc` —
  `utils.R:974,982,991`
- `null2na` — `ids.R:398`

### 3d. Large-integer / id bridging (`R/int64.R`)

Generic uint64/int64 ↔︎ R (`bit64`) ↔︎ numpy ↔︎ raw. **Not** neuroglancer
id parsing (that stays — see §4).

- `pyids2bit64` — `utils.R:402`
- `rids2pyint` — `utils.R:442`
- `rids2raw` — `utils.R:463`
- `int64_overflows` — `utils.R:392`

### 3e. Generic time conversion

- `ts2pydatetime` (R POSIXct → Python datetime) — `cave.R:559`. Lives in
  `cave.R` today but is not CAVE-specific; move with the convert
  cluster.

------------------------------------------------------------------------

## 4. What stays in fafbseg (consumers of nat.python)

Everything that names a specific Python library or a domain concept.

- **[`simple_python()`](https://flyconnectome.github.io/nat.python/reference/simple_python.md)
  (exported, `utils.R:588`)** — the front-end and its
  `pyinstall = c("basic","full","extra","cleanenv","blast")` bundles
  stay: they hardcode `cloudvolume`, `seatable_api!=2.6.3`,
  `caveclient`, `navis+fafbseg`, `fastremap`, `ncollpyde` — fafbseg
  curation. It delegates env/pip mechanics to nat.python. **The public
  symbol does not move**, so no back-compat wrapper is needed and its
  many callers (crantr, aedes, coconatfly, …) are untouched.
- **`dr_fafbseg()` (exported, `utils.R:17`)**, `google_report`,
  `flywire_report` — branded diagnostics; keep, but call nat.python’s
  `py_report` / `py_module_info`.
- **cloudvolume** — `save_cloudvolume_meshes`,
  `read_cloudvolume_meshes`, `dracopy_available`, `boundingbox.*`,
  `cloudvolume_secret_path`, `cloudvolume_version`
  (`cloudvolume-reticulate.R`, `utils.R`).
- **caveclient / CAVE** — `flywire_cave_query`, `cavedict_rtopy`,
  `flywire_partners_cave`, `update_rootids`, `cave_latestid`,
  `cave_get_delta_roots`, `flywire_timestamp`, `flywire_version`,
  `drop_if_row_limited` (`cave.R`). These become the archetypal
  nat.python consumer: call caveclient, hand the pandas result to
  [`nat.python::pandas2df`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md).
- **meshparty** — `meshparty_skeletonize` (`meshparty-reticulate.R`).
- **navis** — `navis2nat_neuron`, `navis2nat_neuronlist`,
  `as.neuron.navis.*`, `as.neuronlist.navis.*`, `read_l2skel`,
  `read_l2dp` (`fafbseg-py.R`).
- **neuroglancer / segment-id domain** — `ngl_segments`,
  `swc2segmentid`, `segmentid2zip`, `zip2segmentstem`, `valid_id`,
  `id2char`, `ngl_layers` (`ids.R`). These touch ids but encode
  neuroglancer/segmentation semantics, not generic int64 handling.
- **not Python at all** — `fafbseg_userdir`, `tabify_coords`,
  `add_field_seq`, `internet_ok`, `nullToZero`: leave in fafbseg (or
  promote to `nat`/`nat.utils` separately; out of scope here).

------------------------------------------------------------------------

## 5. Boundary judgement calls (where the line is subtle)

1.  **`simple_python` split — the crux.** Engine → nat.python, bundles →
    fafbseg. nat.python must have *no* hardcoded knowledge of
    cloudvolume/caveclient/navis; it installs whatever package spec it
    is handed. fafbseg’s `simple_python` owns the “basic/full/extra”
    curation and passes it down. This split is what makes the migration
    low-risk.
2.  **ids: generic vs neuroglancer.** `pyids2bit64` / `rids2pyint` /
    `int64_overflows` / `rids2raw` are generic big-integer bridging →
    nat.python. `ngl_segments` / `swc2segmentid` parse
    neuroglancer/segment strings → stay. `id2char` is borderline; keep
    with the ngl code unless a second consumer needs it.
3.  **`*_version` / `*_available` wrappers.** The mechanism
    (`module_version`, `module_available`) → nat.python; the per-package
    named conveniences (`cloudvolume_version`, `pandas_version`,
    `pyarrow_version`, `dracopy_available`) stay as thin wrappers in
    fafbseg, or are dropped.
4.  **`ts2pydatetime` / posixct helpers** → nat.python (generic Python
    time), even though only CAVE uses them today.
5.  **`check_package_available`** (`utils.R:472`) checks an *R* package,
    not Python — it is a plain util, arguably not nat.python’s remit.
    Leave in fafbseg utils unless it earns a home elsewhere.

------------------------------------------------------------------------

## 6. Dependency graph and the two awkwardnesses it removes

                     nat.python
            (env · modules · convert · int64 · time)
            ↑        ↑          ↑          ↑
       seatabler  fafbseg     bancr    aedes / crantr

No cycles. Two current hacks disappear:

- **seatabler’s provisioner hook.** Today seatabler declares a
  `seatabler.python_provisioner` option that fafbseg registers
  `simple_python` into, purely to avoid a fafbseg dependency. With
  nat.python, seatabler depends on nat.python and calls the env engine
  directly — the inversion-of-control dance goes away.
- **No backwards fafbseg → seatabler dependency** for `pandas2df`, and
  no duplicate converter in seatabler.

------------------------------------------------------------------------

## 7. Phased migration

Each step is independently shippable; do not attempt all at once.

- **Phase 0 — skeleton.** Create `nat.python` (deps: `reticulate`,
  `bit64`; `arrow` Suggests for the arrow path in `pandas2df`). Decide
  hosting (§8).
- **Phase 1 — move the internals.** Lift §3b/§3c/§3d/§3e into
  nat.python. In fafbseg, replace the definitions with
  `@importFrom nat.python …` / `nat.python::`. All internal, so **no
  user-visible change**; fafbseg’s tests are the acceptance gate.
- **Phase 2 — env engine.** Extract §3a into nat.python.
  `fafbseg::simple_python` stays exported, keeps its bundles, delegates
  mechanics to nat.python. Public signature unchanged; `dr_fafbseg`
  delegates its generic parts.
- **Phase 3 — seatabler adopts.** seatabler depends on nat.python,
  deletes its minimal `pandas2df` and the `python_provisioner` hook, and
  calls
  [`nat.python::pandas2df`](https://flyconnectome.github.io/nat.python/reference/pandas2df.md) +
  the env engine directly. (Coordinates with seatabler-plan Phase 1:
  write seatabler’s converter as an isolated, seatable-free file so this
  is a *move*, not a rewrite.)
- **Phase 4 — bancr / aedes / crantr (owners’ schedule).** Optional;
  they can drop their duplicated conversion in favour of nat.python when
  convenient. Nothing above depends on them.

Back-compat summary: only `simple_python` and `dr_fafbseg` are exported,
and **both stay in fafbseg**, so no deprecation shims are required for
the move.

------------------------------------------------------------------------

## 8. Open questions / decisions

### 8.1 Hosting / org

`natverse/nat.python` vs `flyconnectome/nat.python`. Lean **natverse** —
bancr/aedes/crant span more than one lab, and the `nat*` family is the
natural home. A decision, not a blocker.

### 8.2 Name — decided: `nat.python`

Chosen over the earlier `natpy` for two reasons: - **Avoids a PyPI
clash.** There is a `natpy` on PyPI — an unrelated particle-physics
unit-conversion library. Since this package *wraps* Python, `natpy` (R)
vs `import natpy` (Python) would have been a real confusability trap;
`nat.python` has no such collision. - **Fits the family.** It reads
naturally alongside `nat`, `nat.utils`, `nat.nblast`,
`nat.templatebrains` — “nat + Python interop” — where `natpy` did not.
(`.` is legal in R package names.)

Confirmed free on CRAN (`package=nat.python` → 404), so 8.6 stays open.

### 8.3 arrow dependency

**Suggests, with a runtime check — settled.** The
`pandas2df(use_arrow=TRUE)` path is the only consumer; keeping `arrow`
in Suggests matches current fafbseg behaviour and keeps the base install
light. `reticulate` and `bit64` are the only hard Imports.

### 8.4 Interpreter sharing — the real design question

reticulate binds **exactly one** Python interpreter per R session: once
any package triggers initialisation, the interpreter and its environment
are fixed until R restarts. With several consumers (fafbseg, seatabler,
bancr) live in one session they cannot each choose their own Python, so
*someone* must own a single, deterministic resolution. **Decision:
(C).** Alternatives, with (C) adopted:

- **(A) Leave env management in each consumer.** Rejected. fafbseg and
  seatabler would race to initialise Python and could disagree on the
  env; whoever imports first silently wins. This is the status quo’s
  latent bug, worsened by more consumers.
- **(B) nat.python owns one managed env, eagerly.** A single
  `simple_python`-style env holds everything (cloudvolume + caveclient +
  seatable_api + …). Simple and close to today, but monolithic: every
  package must co-resolve in one env (the existing `seatable_api!=2.6.3`
  pin is exactly such a conflict), and it spins up Python even in
  sessions that never need it.
- **(C) nat.python owns resolution but is *deferential* — the
  decision.** nat.python is the single resolver, but:
  1.  **respects a user-configured Python first** — `RETICULATE_PYTHON`,
      an active venv/conda, or an explicit `reticulate::use_*` — and
      only falls back to the managed miniconda env (generalising
      fafbseg’s existing `ownpythonrequested` / `checkownpython`);
  2.  **reuses the existing env name/path** (`default_pyenv`) so current
      fafbseg users are not saddled with a second multi-GB environment;
  3.  **initialises lazily** (`delay_load`) so merely loading a consumer
      package does not start Python;
  4.  **diagnoses rather than enforces** — the interpreter cannot be
      swapped mid-session, so a missing module yields a clear *“active
      Python is X; module Y absent; run `simple_python(...)`”* (via
      `py_report`), not a silent re-initialisation attempt.

  The written contract then reads: *nat.python resolves the interpreter
  once, deterministically, honouring user configuration; all consumers
  share it; provisioning is idempotent and additive.* Consumers never
  call `use_python` themselves.

### 8.5 navis conversion

Unchanged from §5: `navis2nat_*` is navis-specific and stays in fafbseg;
a hypothetical `natnavis` is out of scope, noted so it is not folded
into nat.python by reflex.

### 8.6 CRAN

**Probably not now — keep the door open.** nat.python is infrastructure
for a GitHub-installed package family, so GitHub distribution is fine
near-term. Because the name is CRAN-free (8.2) and the dependency
surface is deliberately tiny (`reticulate` + `bit64`, `arrow`
Suggested), a later submission stays low-friction — so avoid
dependencies or design choices that would foreclose it.
