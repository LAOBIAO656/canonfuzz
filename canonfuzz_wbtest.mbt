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
