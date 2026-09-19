# canonfuzz

An end-to-end ABI regression testing and minimal reproduction tool for
MoonBit WebAssembly components.

`wit-bindgen` already generates the Canonical ABI lifting/lowering code
that lets a MoonBit program compile into a real WASI Preview 2 component
(see MoonBit's own [component model writeup](https://www.moonbitlang.com/blog/component-model)).
That backend is actively maintained, but it is young: at the time this
project started, it carried several open, MoonBit-specific defects
(`wit-bindgen` issues [#1518](https://github.com/bytecodealliance/wit-bindgen/issues/1518),
[#1517](https://github.com/bytecodealliance/wit-bindgen/issues/1517) and
[#1587](https://github.com/bytecodealliance/wit-bindgen/issues/1587)), and
its own CI had the MoonBit backend removed from the test matrix ("moonbit
removed from language matrix for now - causing CI failures", still true in
[`.github/workflows/main.yml`](https://github.com/bytecodealliance/wit-bindgen/blob/main/.github/workflows/main.yml)
as of this writing).

canonfuzz does not generate bindings and is not an alternative to
`wit-bindgen`. It takes a WIT world, a trivial "return what you were given"
implementation of it in MoonBit, and a fixed, version-controlled list of
boundary values, and checks that each value survives the real round trip:
`wit-bindgen` → `moon build --target wasm` → `wasm-tools component` →
`wasmtime run --invoke`. A failure is already a minimal, named reproduction
- there is nothing to shrink, because the corpus is small and specific by
construction rather than found by random search.

## What's implemented

- A `Value` type covering the primitive WIT scalars (`bool`, `s8`..`s64`,
  `u8`..`u64`, `f32`, `f64`, `char`, `string`), `flags`, `option<T>`, and
  `result<T, E>` for any `T`/`E` it can already represent, plus a
  WAVE-text renderer for all of them (`value.mbt`, `wave.mbt`). WAVE is
  the text encoding `wasmtime run --invoke` reads and writes; the grammar
  this implements is the subset described in bytecodealliance/wasm-tools'
  [wasm-wave README](https://github.com/bytecodealliance/wasm-tools/blob/main/crates/wasm-wave/README.md)
  needed for these types. No code from that project is reproduced here -
  this is an independent implementation against its published grammar.
- A fixed regression corpus per fixture (`cases.mbt`), each a list of named
  boundary or representative values with a note on why the case exists:
  `wit/scalars.wit` (every primitive scalar type), `wit/wide-flags.wit` (a
  36-member `flags` type, with cases targeting the 32-bit word boundary
  directly), `wit/option-u32.wit` (`none` and `some` at both ends of
  `u32`'s range), and `wit/result-u32-string.wit` (both arms, including an
  empty and a quote-containing error string to exercise WAVE's mandatory
  string escaping across a real component boundary).
- `cmd/main`: a native CLI that runs the full pipeline above against every
  fixture and reports pass/fail per case, with the tool stage (codegen,
  build, componentize, or the invocation itself) called out separately
  when something fails before any case can even run.
- Expected-failure tracking for a fixture whose build is currently known
  to fail (`wide-flags`, see "A finding along the way"): that failure is
  reported but does not fail the run, and if the build ever unexpectedly
  *succeeds* - i.e. the underlying defect got fixed upstream - `cmd/main`
  notices and runs the fixture's real cases instead of continuing to treat
  it as a known failure. A regression in the other direction (a fixture
  that is supposed to pass failing, or a supposedly-fixed one failing its
  cases once it builds) still fails the run.

The core (`value.mbt`, `wave.mbt`, `cases.mbt`) has no external
dependency and builds on every MoonBit target. `cmd/main` requires
`wit-bindgen`, `wasm-tools`, `moon` and `wasmtime` on `PATH`, is native-only,
and depends on `moonbitlang/async`'s process support, which this project
has only run on Linux and macOS - see "Supported environments" below.

## What's not implemented yet

- Only scalars, one flags type, `option<u32>`, and `result<u32, string>`.
  Records, lists, variants, enums and nested/recursive shapes are not
  covered.
- Resource handles are not covered (targets `wit-bindgen`#1587).
- The corpus is hand-picked, not generated. Property-based or
  coverage-guided generation of new cases is future work, not this
  capability.
- No differential mode against a second `wit-bindgen` backend (e.g. Rust)
  yet, even though #1587 was itself found by exactly that comparison.
- `cmd/main`'s exit code and console report are the only output format;
  machine-readable (JSON) reporting is future work.

## Running it

```sh
moon test                                    # core package, no external tools needed
moon run cmd/main --target native            # full pipeline; needs wit-bindgen, wasm-tools, wasmtime on PATH
```

`moon run cmd/main` regenerates `.canonfuzz-work/<fixture>` from the
matching `wit/*.wit` file on every run - nothing under that path is
checked in.

Sample output against `wit-bindgen-cli` 0.62.0 and `wasmtime` 48.0.2 (the
scalar portion is also reproducible by hand, one case at a time, with
`wasmtime run --invoke "echo-s8(-128)" component.wasm` against the
component `cmd/main` builds):

```
== scalars ==
canonfuzz: generating guest bindings for wit/scalars.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  bool-true
  pass  bool-false
  pass  s8-min
  pass  s8-max
  ...
  pass  char-snowman

24 passed, 0 failed, 24 total

== wide-flags ==
canonfuzz: generating guest bindings for wit/wide-flags.wit
canonfuzz: building the guest component with moon
canonfuzz: wide-flags build failed as expected (tracked, not a new problem)
  tracked cause: wit-bindgen-cli generates an extra closing parenthesis in
  the high-word accessor for flags with more than 32 members
  (wit-bindgen/wit-bindgen#1517-class defect); see README.md

== option-u32 ==
canonfuzz: generating guest bindings for wit/option-u32.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  option-none
  pass  option-some-zero
  pass  option-some-max

3 passed, 0 failed, 3 total

== result-u32-string ==
canonfuzz: generating guest bindings for wit/result-u32-string.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  result-ok-zero
  pass  result-ok-max
  pass  result-err-empty
  pass  result-err-message
  pass  result-err-escaped

5 passed, 0 failed, 5 total
```

This run passes overall: the scalars, option-u32 and result-u32-string
fixtures build and every case round-trips correctly, and the flags fixture's
build failure is the one already tracked in "A finding along the way" rather
than a new problem, so it does not fail the run. This exact sequence has run
and passed in CI on both Linux and macOS - see the Actions tab for the run
history.

## A finding along the way

Building the `wide-flags` fixture (a WIT `flags` type with 36 members, past
the 32-bit boundary a single machine word covers) through the same pipeline
by hand turned up a live code-generation defect in `wit-bindgen-cli` 0.62.0:
the generated accessor for the high bits emits an extra closing
parenthesis -

```
mbt_ffi_store32((return_area) + 4, (flag >> 32).to_int()))
```

- which fails to parse, so `moon build` rejects the generated package
outright. This is a fresh, independently reproduced instance of the same
class of bug reported in #1517 ("flags over 32 bits mis-generate"), still
present in the current release. `cmd/main` drives this fixture the same
way as the scalar one, but treats its build failure as expected (see
"What's implemented") rather than letting it fail the run - the point of
tracking it here, rather than just skipping the fixture, is that the
tracking itself breaks loudly (as a genuine, non-ignorable failure) the
day `wit-bindgen` fixes this and `cmd/main` starts running the six
`flags-*` cases in `cases.mbt` for real.

Separately, the previously reported `s8`/`s16` corruption (#1518) did not
reproduce against `wit-bindgen-cli` 0.62.0 for any boundary value in
`cases.mbt` - worth recording as a negative result, since a regression
suite is exactly the place to track a fix staying fixed.

## Supported environments

| Target | Status |
|---|---|
| `wasm-gc` | core package builds and tests pass locally |
| `wasm` | core package builds and tests pass locally |
| `js` | core package expected to work; not run locally (no Node.js in the development environment); exercised in CI |
| `native`, core package | type-checks locally; build/test not run locally (no C toolchain in the development environment); passes in CI on Linux, macOS and Windows |
| `native`, `cmd/main` | type-checks locally; not executed locally, for the same reason, and additionally needs `moonbitlang/async`'s process support; passes in CI on Linux and macOS, running the exact sequence in "Running it" above |
| `native` on Windows | not currently claimed as supported; `moonbitlang/async`'s own documentation states it currently supports native/LLVM on Linux and macOS, and this project has not tested otherwise |

## Why this and not something else

This project exists after a comparison against the existing MoonBit
ecosystem, not as a first idea. `pei0331/moon-wit` is a from-scratch WIT
parser and binding generator whose own README says it does not yet
implement the Canonical ABI - a different goal (codegen) from this
project's (verification). `0717lee/moonhostabi` locks and diffs the raw
Wasm-GC module's direct JS/native embedding contract, not the WIT
Canonical ABI or anything componentized - a different boundary entirely,
confirmed by reading its own README. Neither tests `wit-bindgen`'s output
against a real host.

## License

Apache-2.0, see `LICENSE`. Every file under `wit/` is original to this
project. The WAVE encoding this project implements a renderer for is
specified by the `wasm-wave` crate (bytecodealliance/wasm-tools,
Apache-2.0), linked above; this project does not vendor or reproduce that
crate's code.
