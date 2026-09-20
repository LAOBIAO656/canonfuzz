///|
/// Exact WAVE text for representative values, cross-checked by hand against
/// the grammar in bytecodealliance/wasm-tools' wasm-wave README. These are
/// examples rather than a property test because WAVE's rendering rules
/// (e.g. which floats get the flat vs. keyword form) are a fixed lookup,
/// not a computed relationship.
test "render produces the expected WAVE text for representative values" {
  assert_eq(render(VBool(true)), "true")
  assert_eq(render(VBool(false)), "false")
  assert_eq(render(VS8(-128)), "-128")
  assert_eq(render(VS8(127)), "127")
  assert_eq(render(VU8(255)), "255")
  assert_eq(render(VU64(18446744073709551615UL)), "18446744073709551615")
  assert_eq(render(VF64(@double.not_a_number)), "nan")
  assert_eq(render(VF64(@double.infinity)), "inf")
  assert_eq(render(VF64(@double.neg_infinity)), "-inf")
  assert_eq(render(VChar('a')), "'a'")
}

///|
/// The WAVE grammar makes escaping backslash, single quote, and the C0
/// controls `\n`/`\r`/`\t` mandatory inside a char literal - an
/// unescaped one of these would either fail to parse or change meaning.
test "render escapes chars the WAVE grammar requires escaping" {
  assert_eq(render(VChar('\\')), "'\\\\'")
  assert_eq(render(VChar('\'')), "'\\''")
  assert_eq(render(VChar('\n')), "'\\n'")
  assert_eq(render(VChar('\r')), "'\\r'")
  assert_eq(render(VChar('\t')), "'\\t'")
}

///|
/// A control character with no dedicated escape still needs one, spelled
/// as `\u{...}`, otherwise the literal WAVE text would contain a raw
/// control byte.
test "render escapes other control chars as \\u{...}" {
  assert_eq(render(VChar('\u{0}')), "'\\u{0}'")
}

///|
/// A codepoint outside ASCII that is not one of the mandatory escapes is
/// written out directly - WAVE text is Unicode, not ASCII-only.
test "render leaves non-ASCII non-control chars unescaped" {
  assert_eq(render(VChar('\u{2603}')), "'\u{2603}'")
}

///|
/// `same()` must treat NaN as equal to itself. This is the one case where
/// plain `==` on the underlying float would give the wrong answer, and it
/// is exactly the case the regression suite's `f64-nan` entry relies on.
test "same treats NaN as equal to itself" {
  assert_true(same(VF64(@double.not_a_number), VF64(@double.not_a_number)))
  assert_true(same(VF32(@float.not_a_number), VF32(@float.not_a_number)))
}

///|
/// `same()` must still distinguish ordinary unequal values - it is only
/// NaN that gets special treatment.
test "same rejects unequal values of the same shape" {
  assert_false(same(VS8(1), VS8(2)))
  assert_false(same(VF64(0.0), VF64(1.0)))
}

///|
/// `same()` must reject values of different shapes rather than raising, so
/// a `cmd/main` mismatch between e.g. a s8 case and a corrupted result that
/// happens to decode as a different type is still reported as a plain
/// mismatch instead of crashing the report.
test "same rejects mismatched shapes" {
  assert_false(same(VS8(1), VS16(1)))
}

///|
/// WAVE renders a flags value as the set of labels whose bit is set. An
/// empty set is `{}`, not empty text - dropping the braces would parse as
/// nothing at all rather than as a valid flags literal.
test "render renders flags as the set of labels whose bit is set" {
  let labels = ["a", "b", "c"]
  assert_eq(render(VFlags(labels~, bits=0UL)), "{}")
  assert_eq(render(VFlags(labels~, bits=1UL)), "{a}")
  assert_eq(render(VFlags(labels~, bits=0b101UL)), "{a, c}")
  assert_eq(render(VFlags(labels~, bits=0b111UL)), "{a, b, c}")
}

///|
/// The defect this suite exists to catch concerns exactly the boundary
/// between the low and high 32-bit words of a flags value backed by more
/// than 32 members; rendering must not special-case that boundary itself,
/// so a bit past it renders the same way a bit before it would.
test "render handles flag bits past the 32-bit boundary" {
  let labels = wide_flags_labels()
  assert_eq(render(VFlags(labels~, bits=1UL << 32)), "{bit-32}")
  assert_eq(render(VFlags(labels~, bits=1UL << 35)), "{bit-35}")
}

///|
/// `same()` for flags compares both the label list and the bits - two
/// values with the same bits set but different label lists describe
/// different flags types and must not compare equal.
test "same distinguishes flags by labels as well as bits" {
  assert_true(
    same(VFlags(labels=["a"], bits=1UL), VFlags(labels=["a"], bits=1UL)),
  )
  assert_false(
    same(VFlags(labels=["a"], bits=1UL), VFlags(labels=["b"], bits=1UL)),
  )
  assert_false(
    same(VFlags(labels=["a"], bits=1UL), VFlags(labels=["a"], bits=0UL)),
  )
}

///|
/// `render` always uses the explicit `some(...)`/`none` form, matching
/// what `wasmtime run --invoke` itself prints (confirmed by hand against
/// `wasmtime` 48.0.2 - see the note on `render` in wave.mbt) rather than
/// the grammar's alternate flat form for `some`.
test "render renders options in explicit some/none form" {
  assert_eq(render(VOption(None)), "none")
  assert_eq(render(VOption(Some(VU32(0)))), "some(0)")
  assert_eq(render(VOption(Some(VU32(4294967295)))), "some(4294967295)")
}

///|
/// An option's payload can itself be any `Value` this module knows how to
/// render - `render` for `VOption` must not special-case what it wraps.
test "render renders an option around a non-trivial payload" {
  assert_eq(render(VOption(Some(VChar('\'')))), "some('\\'')")
}

///|
/// `same()` for options must compare `None` to `None`, compare payloads
/// recursively when both are `Some`, and reject a `None`/`Some` mismatch -
/// exactly the three cases `option_u32_regression_suite` exercises against
/// a real component.
test "same compares options structurally" {
  assert_true(same(VOption(None), VOption(None)))
  assert_true(same(VOption(Some(VU32(1))), VOption(Some(VU32(1)))))
  assert_false(same(VOption(Some(VU32(1))), VOption(Some(VU32(2)))))
  assert_false(same(VOption(None), VOption(Some(VU32(0)))))
}

///|
/// A string with nothing to escape renders as a plain double-quoted
/// literal; the empty string still needs its quotes, since dropping them
/// would render as no text at all rather than as a valid string literal.
test "render renders plain strings" {
  assert_eq(render(VString("")), "\"\"")
  assert_eq(render(VString("hello")), "\"hello\"")
}

///|
/// Strings share `escape`'s mandatory-escape set with chars, but `"` (not
/// `'`) is the delimiter that must be escaped, and `'` needs no escape
/// inside a string - the two literal forms must not cross-apply each
/// other's escape rules.
test "render escapes what a string literal requires" {
  assert_eq(render(VString("say \"hi\"")), "\"say \\\"hi\\\"\"")
  assert_eq(render(VString("back\\slash")), "\"back\\\\slash\"")
  assert_eq(render(VString("line\nbreak")), "\"line\\nbreak\"")
  assert_eq(render(VString("it's fine")), "\"it's fine\"")
}

///|
/// `result` renders in explicit `ok(...)`/`err(...)` form, matching what
/// `wasmtime run --invoke` itself prints (confirmed by hand against
/// `wasmtime` 48.0.2, the same way as for `option` - see the note on
/// `render` in wave.mbt).
test "render renders results in explicit ok/err form" {
  assert_eq(render(VResult(Ok(VU32(0)))), "ok(0)")
  assert_eq(render(VResult(Err(VString("oops")))), "err(\"oops\")")
}

///|
/// `same()` for results must compare payloads recursively within a
/// matching arm and reject an `Ok`/`Err` mismatch even when the payloads
/// would otherwise look alike.
test "same compares results structurally" {
  assert_true(same(VResult(Ok(VU32(1))), VResult(Ok(VU32(1)))))
  assert_true(same(VResult(Err(VString("x"))), VResult(Err(VString("x")))))
  assert_false(same(VResult(Ok(VU32(1))), VResult(Ok(VU32(2)))))
  assert_false(same(VResult(Ok(VU32(0))), VResult(Err(VString("0")))))
}

// -- parse -------------------------------------------------------------
//
// `render` is checked above against hand-picked expected text. These
// tests check `parse`, the direction `cmd/main` actually depends on: can
// it recover a `Value` from text, including text this project did not
// itself produce (an out-of-range number, a bad escape, an unknown flag
// label) without raising or returning something wrong. The round-trip
// property (`parse(shape, render(v))` recovers `v` for every case in
// every suite) is checked separately in canonfuzz_test.mbt, where it can
// use the public `all_regression_suites()`.

///|
test "parse recovers scalars from their own rendering" {
  assert_true(same_option(parse(ShBool, "true"), Some(VBool(true))))
  assert_true(same_option(parse(ShS8, "-128"), Some(VS8(-128))))
  assert_true(
    same_option(
      parse(ShU64, "18446744073709551615"),
      Some(VU64(18446744073709551615UL)),
    ),
  )
  // Uses same_option (NaN-aware), not plain equality: nan == nan is
  // false, but a parsed "nan" recovering VF64(NaN) is exactly correct.
  assert_true(
    same_option(parse(ShF64, "nan"), Some(VF64(@double.not_a_number))),
  )
  assert_true(same_option(parse(ShChar, "'a'"), Some(VChar('a'))))
}

///|
/// A `u8` is a full `Shape` of its own, not just "any integer" - text
/// that parses fine as a number but falls outside the type's range must
/// still be rejected, or a real corruption bug that returns an
/// out-of-range value would parse "successfully" into some other value
/// instead of being caught.
test "parse rejects an out-of-range value for a narrower type" {
  assert_true(parse(ShU8, "256") is None)
  assert_true(parse(ShU16, "65536") is None)
}

///|
test "parse rejects text that is not a bool at all" {
  assert_true(parse(ShBool, "True") is None)
  assert_true(parse(ShBool, "") is None)
}

///|
/// `parse` must undo every escape `escape` (in wave.mbt) can produce,
/// including `\u{...}`, for a char or a string.
test "parse recovers escaped chars and strings" {
  assert_true(same_option(parse(ShChar, "'\\''"), Some(VChar('\''))))
  assert_true(same_option(parse(ShChar, "'\\n'"), Some(VChar('\n'))))
  assert_true(
    same_option(parse(ShChar, "'\\u{2603}'"), Some(VChar('\u{2603}'))),
  )
  assert_true(
    same_option(
      parse(ShString, "\"say \\\"hi\\\"\""),
      Some(VString("say \"hi\"")),
    ),
  )
  assert_true(same_option(parse(ShString, "\"\""), Some(VString(""))))
}

///|
/// A lone trailing backslash and an unterminated `\u{...}` are malformed
/// escapes, not text to pass through as-is - doing that would silently
/// turn a real corruption in the escaping logic into a "successful"
/// parse of the wrong string.
test "parse rejects malformed escapes" {
  assert_true(parse(ShString, "\"abc\\\"") is None)
  assert_true(parse(ShString, "\"\\u{41\"") is None)
  assert_true(parse(ShChar, "'ab'") is None)
}

///|
test "parse recovers flags, including the empty set" {
  let sh = ShFlags(["a", "b", "c"])
  assert_true(
    same_option(parse(sh, "{}"), Some(VFlags(labels=["a", "b", "c"], bits=0UL))),
  )
  assert_true(
    same_option(
      parse(sh, "{a, c}"),
      Some(VFlags(labels=["a", "b", "c"], bits=0b101UL)),
    ),
  )
}

///|
/// A label this suite does not declare - a typo, or a member added
/// upstream that the fixture hasn't been updated for - must be rejected
/// rather than silently dropped, which would let a real corruption look
/// like a clean, if incomplete, set.
test "parse rejects an unknown flag label" {
  assert_true(parse(ShFlags(["a", "b"]), "{a, z}") is None)
}

///|
test "parse recovers options in both arms" {
  let sh = ShOption(ShU32)
  assert_true(same_option(parse(sh, "none"), Some(VOption(None))))
  assert_true(same_option(parse(sh, "some(0)"), Some(VOption(Some(VU32(0))))))
}

///|
/// `wasmtime` never prints the "flat" form of `some` (see the note on
/// `render` in wave.mbt), so `parse` only needs to accept the explicit
/// form. A bare payload is correctly rejected as malformed input, not
/// silently accepted as an alternate spelling of `some`.
test "parse rejects the flat option form since wasmtime never emits it" {
  assert_true(parse(ShOption(ShU32), "0") is None)
}

///|
test "parse recovers both result arms using their own shapes" {
  let sh = ShResult(ok=ShU32, err=ShString)
  assert_true(same_option(parse(sh, "ok(0)"), Some(VResult(Ok(VU32(0))))))
  assert_true(
    same_option(parse(sh, "err(\"oops\")"), Some(VResult(Err(VString("oops"))))),
  )
}

///|
/// Text that is not a valid rendering of *either* arm - not just the one
/// a particular case happened to expect - is malformed input, not a
/// same()-false mismatch to report as if parsing had succeeded.
test "parse rejects text matching neither result arm" {
  assert_true(parse(ShResult(ok=ShU32, err=ShString), "maybe(0)") is None)
}

// -- records -------------------------------------------------------------

///|
fn point_shape() -> Shape {
  ShRecord([("x", ShS32), ("y", ShS32), ("label", ShOption(ShString))])
}

///|
test "render renders every record field explicitly, in declaration order" {
  let v = VRecord([
    ("x", VS32(1)),
    ("y", VS32(2)),
    ("label", VOption(Some(VString("hi")))),
  ])
  assert_eq(render(v), "{x: 1, y: 2, label: some(\"hi\")}")
}

///|
/// `same` compares records by field name, not by the order either side's
/// `Value` happens to store them in - `render` always emits declaration
/// order, but nothing should depend on that for correctness.
test "same compares records by field name, independent of storage order" {
  let a = VRecord([("x", VS32(1)), ("y", VS32(2))])
  let b = VRecord([("y", VS32(2)), ("x", VS32(1))])
  assert_true(same(a, b))
  let c = VRecord([("x", VS32(1)), ("y", VS32(3))])
  assert_false(same(a, c))
}

///|
/// `same` also rejects records with a different set of field names
/// entirely, rather than only comparing the fields both sides happen to
/// share.
test "same rejects records with different field sets" {
  let a = VRecord([("x", VS32(1)), ("y", VS32(2))])
  let b = VRecord([("x", VS32(1))])
  assert_false(same(a, b))
}

///|
/// `parse` must accept fields in any order - `wasmtime` output happens to
/// be declaration order (confirmed by hand), but the WAVE grammar does
/// not require it, and nothing here should depend on the specific
/// implementation's ordering choice.
test "parse recovers a record with fields in any order" {
  let expected = VRecord([
    ("x", VS32(1)),
    ("y", VS32(2)),
    ("label", VOption(Some(VString("hi")))),
  ])
  assert_true(
    same_option(
      parse(point_shape(), "{y: 2, label: some(\"hi\"), x: 1}"),
      Some(expected),
    ),
  )
}

///|
/// `wasmtime` omits an `option`-typed field entirely when it's `none`
/// (confirmed by hand against `wasmtime` 48.0.2) rather than printing
/// `label: none` - `parse` must fill the field in as `none`, not reject
/// the record as incomplete.
test "parse fills in an omitted option field as none" {
  let expected = VRecord([
    ("x", VS32(1)),
    ("y", VS32(2)),
    ("label", VOption(None)),
  ])
  assert_true(same_option(parse(point_shape(), "{x: 1, y: 2}"), Some(expected)))
}

///|
/// A record value can itself contain a comma or colon inside a nested
/// string - the exact scenario `split_top_level` exists for. Getting this
/// wrong would misread the string's contents as a second field.
test "parse handles a comma and colon inside a nested string field" {
  let expected = VRecord([
    ("x", VS32(1)),
    ("y", VS32(2)),
    ("label", VOption(Some(VString("a, b: c")))),
  ])
  assert_true(
    same_option(
      parse(point_shape(), "{x: 1, y: 2, label: some(\"a, b: c\")}"),
      Some(expected),
    ),
  )
}

///|
/// A field this shape does not declare - a typo, or a member added
/// upstream this suite hasn't been updated for - is malformed input, not
/// something to silently ignore.
test "parse rejects an unknown record field" {
  assert_true(parse(point_shape(), "{x: 1, y: 2, z: 3, label: none}") is None)
}

///|
/// A missing *non-optional* field is genuinely incomplete, unlike an
/// omitted `option` field - WAVE only allows omitting `option`-typed
/// fields whose value is `none`.
test "parse rejects a record missing a non-optional field" {
  assert_true(parse(point_shape(), "{x: 1}") is None)
}

// -- lists -----------------------------------------------------------

///|
test "render renders lists, including the empty list" {
  assert_eq(render(VList([])), "[]")
  assert_eq(render(VList([VU32(1), VU32(2), VU32(3)])), "[1, 2, 3]")
}

///|
/// `same` for lists compares position by position and cares about
/// length and order - unlike a record's fields, WAVE gives no basis for
/// treating two lists with the same elements in a different order as
/// equal.
test "same compares lists by position, not just by contents" {
  assert_true(same(VList([VU32(1), VU32(2)]), VList([VU32(1), VU32(2)])))
  assert_false(same(VList([VU32(1), VU32(2)]), VList([VU32(2), VU32(1)])))
  assert_false(same(VList([VU32(1)]), VList([VU32(1), VU32(1)])))
}

///|
test "parse recovers lists, including the empty list" {
  assert_true(same_option(parse(ShList(ShU32), "[]"), Some(VList([]))))
  assert_true(
    same_option(
      parse(ShList(ShU32), "[1, 2, 3]"),
      Some(VList([VU32(1), VU32(2), VU32(3)])),
    ),
  )
}

///|
/// Every element must parse against the list's element shape - a
/// component that (correctly or not) returned an out-of-range element is
/// malformed input, not a value to accept and then mismatch on
/// elsewhere.
test "parse rejects a list with an out-of-range element" {
  assert_true(parse(ShList(ShU8), "[1, 256]") is None)
}

///|
/// A list element can itself contain a comma inside a nested string -
/// the same `split_top_level` property already checked for records,
/// checked again here since lists use it independently.
test "parse handles a comma inside a nested string element" {
  assert_true(
    same_option(
      parse(ShList(ShString), "[\"a, b\", \"c\"]"),
      Some(VList([VString("a, b"), VString("c")])),
    ),
  )
}
