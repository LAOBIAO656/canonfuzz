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
  `u8`..`u64`, `f32`, `f64`, `char`, `string`), `flags`, `option<T>`,
  `result<T, E>`, `record`, `list<T>`, and `variant` (a plain `enum`
  needs no separate representation - it is just a `variant` where every
  case's payload is `None`), plus a WAVE-text renderer for all of them
  (`value.mbt`, `wave.mbt`). WAVE is the text encoding `wasmtime run
  --invoke` reads and writes; the grammar this implements is the subset
  described in bytecodealliance/wasm-tools'
  [wasm-wave README](https://github.com/bytecodealliance/wasm-tools/blob/main/crates/wasm-wave/README.md)
  needed for these types. No code from that project is reproduced here -
  this is an independent implementation against its published grammar.
- A `Shape` type describing a `Value`'s type-former independently of any
  particular instance (needed because, e.g., `expect: VOption(None)` alone
  doesn't say what the payload type would be if a buggy component
  returned `some(...)` instead), and `parse`, the inverse of `render`:
  WAVE text plus a `Shape` back to a `Value`, or `None` if the text
  doesn't match that shape at all (`wave_parse.mbt`). `run_case` in
  `cmd/main` uses this to compare a real component's output to what was
  expected structurally, via `same()`, instead of as raw text - see "The
  comparator now compares structurally" below.
- A fixed regression corpus per fixture (`cases.mbt`), each a list of named
  boundary or representative values with a note on why the case exists:
  `wit/scalars.wit` (every primitive scalar type), `wit/wide-flags.wit` (a
  36-member `flags` type, with cases targeting the 32-bit word boundary
  directly), `wit/option-u32.wit` (`none` and `some` at both ends of
  `u32`'s range), `wit/result-u32-string.wit` (both arms, including an
  empty and a quote-containing error string to exercise WAVE's mandatory
  string escaping across a real component boundary), and
  `wit/record-point.wit` (a `record` with two `s32` fields and an
  `option<string>` field, with cases covering fields given out of
  declaration order, an omitted `option` field, and a string field
  containing a comma and a colon), `wit/list-u32.wit` (the empty list, a
  single element, and a case checking that element order - not just
  element membership - is preserved), `wit/variant-match-result.wit` (a
  three-case variant, one case with no payload, two with different
  payload types, where the no-payload case is deliberately named `none` -
  the same word as the `option` "empty" keyword - to exercise WAVE's
  mandatory `%` escaping for a colliding case name), and
  `wit/list-point.wit` (a `list<record>`), `wit/option-result-u32-string.wit`
  (`option<result<u32, string>>`, two paren-using wrappers nested inside
  each other), `wit/record-shape-info.wit` (a `record` field whose
  value is itself a `variant`, with a with-payload and a no-payload case),
  and `wit/variant-in-variant.wit` (a `variant` *case* whose own payload
  is itself a `variant`) - see "Nesting" below for why none of the four
  needed any code changes.
- `cmd/main`: a native CLI that runs the full pipeline above against every
  fixture and reports pass/fail per case, with the tool stage (codegen,
  build, componentize, or the invocation itself) called out separately
  when something fails before any case can even run.
- Fingerprinted expected-failure tracking for a fixture whose build is
  currently known to fail (`wide-flags`, see "A finding along the way").
  A build failure is only treated as *that* tracked issue - reported, but
  not failing the run (XFAIL) - if the build's own output actually
  contains the markers recorded for it; a build failure for any other
  reason (a `moon`/`wit-bindgen` version bump, a missing tool, a genuinely
  new bug) still fails the run (FAIL) instead of being silently absorbed.
  If the build ever unexpectedly *succeeds* (XPASS) - i.e. the underlying
  defect got fixed upstream - `cmd/main` says so explicitly and runs the
  fixture's real cases instead of continuing to treat it as known-failing;
  a real case failure at that point still fails the run.
- Each fixture's working directory is removed before it is regenerated,
  not just created if missing, so a `.mbt` file left over from a previous
  `wit-bindgen` version or a since-edited `.wit` file can never linger
  alongside freshly generated ones and change what actually gets built.
- `moon run cmd/main -- --json` prints a machine-readable report instead
  of the running commentary - see "Machine-readable output" below.

The core (`value.mbt`, `wave.mbt`, `cases.mbt`) has no external
dependency and builds on every MoonBit target. `cmd/main` requires
`wit-bindgen`, `wasm-tools`, `moon` and `wasmtime` on `PATH`, is native-only,
and depends on `moonbitlang/async`'s process support, which this project
has only run on Linux and macOS - see "Supported environments" below.

## What's not implemented yet

- Every WIT type-former has at least one fixture, including four nested
  ones (`list<record>`, `option<result<u32, string>>`, a `record` field
  whose value is a `variant`, and a `variant` *case* whose own value is
  a `variant` - see "Nesting" below; none of the four needed any code
  changes). Not yet exercised by a fixture: three or more levels of
  nesting in one shape. `parse`/`render` dispatch generically on
  `Shape`/`Value` with no type-specific special-casing beyond what's
  already confirmed, so this is expected to work unchanged too, but
  "expected to" is exactly the kind of claim this project exists to
  check rather than trust.
- Resource handles are not covered (targets `wit-bindgen`#1587).
- The corpus is hand-picked, not generated. Property-based or
  coverage-guided generation of new cases is future work, not this
  capability.
- No differential mode against a second `wit-bindgen` backend (e.g. Rust)
  yet, even though #1587 was itself found by exactly that comparison.

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
canonfuzz: wide-flags build failed as expected (XFAIL, tracked, not a new problem)
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

== record-point ==
canonfuzz: generating guest bindings for wit/record-point.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  record-label-none
  pass  record-label-some
  pass  record-fields-any-order
  pass  record-label-with-punctuation

4 passed, 0 failed, 4 total

== list-u32 ==
canonfuzz: generating guest bindings for wit/list-u32.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  list-empty
  pass  list-single
  pass  list-several

3 passed, 0 failed, 3 total

== variant-match-result ==
canonfuzz: generating guest bindings for wit/variant-match-result.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  match-none
  pass  match-exact
  pass  match-partial

3 passed, 0 failed, 3 total

== list-point ==
canonfuzz: generating guest bindings for wit/list-point.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  list-point-empty
  pass  list-point-several

2 passed, 0 failed, 2 total

== option-result-u32-string ==
canonfuzz: generating guest bindings for wit/option-result-u32-string.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  option-result-none
  pass  option-result-some-ok-zero
  pass  option-result-some-ok-max
  pass  option-result-some-err

4 passed, 0 failed, 4 total

== record-shape-info ==
canonfuzz: generating guest bindings for wit/record-shape-info.wit
canonfuzz: building the guest component with moon
canonfuzz: turning the core module into a component with wasm-tools
canonfuzz: running the regression suite against the component

  pass  shape-info-circle
  pass  shape-info-unknown

2 passed, 0 failed, 2 total
```

This run passes overall: every fixture except `wide-flags` builds and every
case round-trips correctly, and the flags fixture's build failure is the one
already tracked in "A finding along the way" rather than a new problem, so
it does not fail the run. This exact sequence has run and passed in CI on
both Linux and macOS - see the Actions tab for the run history.

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
way as the scalar one, but treats *this specific* build failure as
expected (see "What's implemented") rather than letting it fail the run.
The check is fingerprinted, not "did the build fail at all": the tracked
`KnownFailure` records that both `ffi.mbt` and `` unexpected token `)` ``
must appear in the build's own output, so a `moon` version bump, a
missing tool, or an unrelated new bug in the same fixture would show up as
a real failure (FAIL) rather than being absorbed as this one. The point of
tracking the issue at all, rather than just skipping the fixture, is that
tracking makes the day `wit-bindgen` fixes this loud rather than silent:
the build unexpectedly succeeding (XPASS) makes `cmd/main` run the six
`flags-*` cases in `cases.mbt` for real instead of continuing to report
"known failure."

Separately, the previously reported `s8`/`s16` corruption (#1518) did not
reproduce against `wit-bindgen-cli` 0.62.0 for any boundary value in
`cases.mbt` - worth recording as a negative result, since a regression
suite is exactly the place to track a fix staying fixed.

## The comparator now compares structurally

`run_case` used to compare `wasmtime`'s raw output text against
`render(case.expect)` byte-for-byte. That was exact for every shape
implemented at the time only because none of them had more than one way
to render correctly - a record's fields have no canonical order, and nothing
in WAVE's grammar pins down a single textual form once nesting is
involved, so text comparison would eventually reject a correct-but-
differently-ordered or differently-formatted result as a false
"mismatch." `run_case` now parses `wasmtime`'s output with `parse` and the
case's own `Shape`, then compares the result to `expect` with `same()` -
structurally, not as text.

This is more than a hedge against a hypothetical: `wave_parse.mbt` and
its parser are new, correctness-critical code, so they get the same kind
of coverage the rest of the project does rather than being trusted on
sight. `canonfuzz_wbtest.mbt` checks `parse` directly - recovering every
supported shape, rejecting an out-of-range narrow integer, rejecting
malformed escapes, rejecting an unknown flag label, rejecting text
matching neither arm of a result - and `canonfuzz_test.mbt` checks the
actual property `run_case` depends on: for every case in
`all_regression_suites()`, `parse(case.shape, render(case.expect))`
recovers a value `same()` to `case.expect`. If that property ever broke
for a case, every real component run against that case would misreport a
correct answer as a mismatch regardless of what `wasmtime` actually
returned - which is exactly why it's a test on its own, not just implied
by the fixtures passing in CI.

A component whose output isn't even a valid rendering of the expected
shape (garbage, or a shape violation) is now its own outcome -
"unparseable" - distinct from "parsed fine but the value was wrong," so a
`cmd/main` report can say which one happened instead of only ever
comparing two opaque strings.

`parse` is deliberately not a general WAVE parser: it only accepts the
forms `render` itself produces. Records get a proper depth- and
quote-aware splitter (`split_top_level` in `wave_parse.mbt`) precisely
because a record field's value can itself contain a comma or a colon -
see "Nesting" below for what nesting `option`/`result`/`variant` inside
each other or inside a record/list actually needs, which turned out to
be nothing.

## Nesting

`list<record>` (`wit/list-point.wit`) needed no changes to `parse` or
`render` at all - it already worked the moment `list<T>` and `record`
each existed on their own. That's not an accident: a record uses `{}`
and a list uses `[]`, and `split_top_level` already tracks bracket depth
generically across all three bracket kinds, so a list of records was
never actually blocked by anything.

The seemingly harder case - `option<result<u32, string>>`
(`wit/option-result-u32-string.wit`), two `()`-using wrappers nested
inside each other - turned out to need nothing either, which is not what
an earlier version of this document claimed. The reasoning behind that
claim was wrong: it assumed `strip` would need to find a *matching*
closing paren to handle nesting, the same way `split_top_level` finds
matching brackets for records and lists. But `strip` was never written
that way - it trims a fixed-length prefix and a one-character suffix,
and hands whatever text is left in the middle to the inner `parse`
completely unexamined. That middle text can contain any number of its
own parens, at any depth, without `strip` ever looking at them, so
nesting was free the whole time. `canonfuzz_wbtest.mbt` checks this
directly, and `wit/option-result-u32-string.wit` confirms it against a
real component the same way `list-point` confirmed `list<record>`.

A `record` field whose value is itself a `variant`
(`wit/record-shape-info.wit`) needed nothing either, for the same reason
`list<record>` didn't: `parse_wave_record` already calls `parse`
generically on each field's own `Shape`, with no awareness of what kind
of shape that is, so a field being a `variant` specifically was never
special. This one is worth calling out anyway, rather than treating it
as obvious from the `list<record>` result, because it covers a case
`list<record>` didn't: a *no-payload* variant case as a field's value
renders as a bare word with no parens at all, sitting directly between
the field's `:` and the record's `,` or `}` - a different shape of text
than anything nested-in-a-list ever produces, and `split_top_level`
needed to get that right too.

A `variant` *case* whose own payload is itself a `variant`
(`wit/variant-in-variant.wit`: `maybe-shape` has a `present(shape-kind)`
case, where `shape-kind` is itself a two-case `variant`) needed nothing
either, and for a reason distinct from the record-field case above: a
case's payload goes through `parse_wave_variant`'s own `strip(text,
label + "(", ")")`, not `parse_wave_record`'s per-field loop, so this
was genuinely a different code path, not just the same fact restated.
`strip` still doesn't care what's inside the parens it trims - the same
property that made `option<result<...>>` free - so `present(circle(2.5))`
recovers correctly with `shape-kind`'s own parens passed through
untouched.

What's left is not a known architectural gap so much as an absence of
evidence: three or more levels of nesting in one shape is not exercised
by any fixture yet. Nothing in `parse`/`render` special-cases depth, so
the same reasoning says this should also already work - but that is
exactly the kind of claim this project exists to check by building the
fixture, not to assert from how the code reads.

## Machine-readable output

`moon run cmd/main --target native -- --json` (the first `--` is
`moon`'s own separator between its flags and the program's) prints one
JSON object instead of the running commentary:

```json
{
  "ok": true,
  "fixtures": [
    {
      "name": "scalars",
      "status": "pass",
      "passed": 24,
      "failed": 0,
      "cases": [
        { "name": "bool-true", "outcome": "pass" },
        ...
      ]
    },
    {
      "name": "wide-flags",
      "status": "xfail",
      "reason": "wit-bindgen-cli generates an extra closing parenthesis ..."
    }
  ]
}
```

`status` is one of `pass`, `xfail`, `xpass`, `codegen-failed`,
`build-failed`, or `componentize-failed`; a case's `outcome` is one of
`pass`, `trapped`, `unparseable`, or `mismatch` (the latter two also
carrying `detail`, or `expected`/`actual` rendered as WAVE text, the
same as the console report shows). The top-level `ok` and the process
exit code are computed from the same `fixture_ok` check applied to the
same data, so a consumer parsing this JSON never needs to separately
trust the exit code to know what happened - they agree by construction,
not by convention.

`--json` only silences the per-fixture progress lines; it doesn't change
what's decided, which is why fixing a real bug during this change - a
`wasm-tools componentize` failure was, before this fix, being reported
as an empty case run (0 passed, 0 failed), which `fixture_ok` read as a
pass - was correctness-critical rather than incidental to adding a new
output format. It's now its own outcome (`componentize-failed`) in both
the JSON and the exit code.

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
project. The WAVE encoding this project implements a renderer and parser
for is specified by the `wasm-wave` crate (bytecodealliance/wasm-tools,
Apache-2.0), linked above; this project does not vendor or reproduce that
crate's code.
