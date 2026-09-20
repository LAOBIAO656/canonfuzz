///|
/// One entry in the regression corpus: an exported WIT function together
/// with a value it should return unchanged.
///
/// `expect` is stored separately from `input` (even though every case here
/// is an identity check) so the corpus format already matches functions
/// that transform their input, which later capabilities will need.
///
/// `shape` is authored alongside `input`/`expect` rather than derived from
/// `expect`, because a single example `Value` cannot always describe its
/// own type: `expect: VOption(None)` does not say what the payload type
/// would be if a buggy component returned `some(...)` instead, and
/// `expect: VResult(Ok(x))` says nothing about the `err` arm's type. See
/// the doc comment on `Shape` in value.mbt.
pub struct Case {
  name : String
  function : String
  input : Value
  expect : Value
  shape : Shape
  note : String
} derive(Debug)

///|
/// The `wit/scalars.wit` regression corpus: boundary and representative
/// values for every primitive scalar type in `world canon-scalars`.
///
/// Several entries exist because of a specific, previously reported defect
/// in `wit-bindgen`'s MoonBit backend rather than generic boundary
/// coverage; those are called out in `note`. Running this suite against a
/// given `wit-bindgen` release does not prove the defect is fixed upstream
/// in general, only that this component, built with that release, returned
/// the correct value for that input.
pub fn scalar_regression_suite() -> Array[Case] {
  [
    {
      name: "bool-true",
      function: "echo-bool",
      input: VBool(true),
      expect: VBool(true),
      shape: ShBool,
      note: "sanity check",
    },
    {
      name: "bool-false",
      function: "echo-bool",
      input: VBool(false),
      expect: VBool(false),
      shape: ShBool,
      note: "sanity check",
    },
    {
      name: "s8-min",
      function: "echo-s8",
      input: VS8(-128),
      expect: VS8(-128),
      shape: ShS8,
      note: "lower bound of s8; wit-bindgen/wit-bindgen#1518 reported this width corrupting values",
    },
    {
      name: "s8-max",
      function: "echo-s8",
      input: VS8(127),
      expect: VS8(127),
      shape: ShS8,
      note: "upper bound of s8; see wit-bindgen/wit-bindgen#1518",
    },
    {
      name: "s8-zero",
      function: "echo-s8",
      input: VS8(0),
      expect: VS8(0),
      shape: ShS8,
      note: "zero crossing",
    },
    {
      name: "s8-neg-one",
      function: "echo-s8",
      input: VS8(-1),
      expect: VS8(-1),
      shape: ShS8,
      note: "all-ones bit pattern under two's complement",
    },
    {
      name: "s16-min",
      function: "echo-s16",
      input: VS16(-32768),
      expect: VS16(-32768),
      shape: ShS16,
      note: "lower bound of s16; see wit-bindgen/wit-bindgen#1518",
    },
    {
      name: "s16-max",
      function: "echo-s16",
      input: VS16(32767),
      expect: VS16(32767),
      shape: ShS16,
      note: "upper bound of s16; see wit-bindgen/wit-bindgen#1518",
    },
    {
      name: "s32-min",
      function: "echo-s32",
      input: VS32(-2147483648),
      expect: VS32(-2147483648),
      shape: ShS32,
      note: "lower bound of s32",
    },
    {
      name: "s32-max",
      function: "echo-s32",
      input: VS32(2147483647),
      expect: VS32(2147483647),
      shape: ShS32,
      note: "upper bound of s32",
    },
    {
      name: "s64-min",
      function: "echo-s64",
      input: VS64(-9223372036854775808L),
      expect: VS64(-9223372036854775808L),
      shape: ShS64,
      note: "lower bound of s64",
    },
    {
      name: "s64-max",
      function: "echo-s64",
      input: VS64(9223372036854775807L),
      expect: VS64(9223372036854775807L),
      shape: ShS64,
      note: "upper bound of s64",
    },
    {
      name: "u8-max",
      function: "echo-u8",
      input: VU8(255),
      expect: VU8(255),
      shape: ShU8,
      note: "upper bound of u8",
    },
    {
      name: "u8-zero",
      function: "echo-u8",
      input: VU8(0),
      expect: VU8(0),
      shape: ShU8,
      note: "lower bound of u8",
    },
    {
      name: "u16-max",
      function: "echo-u16",
      input: VU16(65535),
      expect: VU16(65535),
      shape: ShU16,
      note: "upper bound of u16",
    },
    {
      name: "u32-max",
      function: "echo-u32",
      input: VU32(4294967295),
      expect: VU32(4294967295),
      shape: ShU32,
      note: "upper bound of u32",
    },
    {
      name: "u64-max",
      function: "echo-u64",
      input: VU64(18446744073709551615UL),
      expect: VU64(18446744073709551615UL),
      shape: ShU64,
      note: "upper bound of u64",
    },
    {
      name: "f32-zero",
      function: "echo-f32",
      input: VF32(0.0),
      expect: VF32(0.0),
      shape: ShF32,
      note: "sanity check",
    },
    {
      name: "f32-fraction",
      function: "echo-f32",
      input: VF32(3.5),
      expect: VF32(3.5),
      shape: ShF32,
      note: "a value exactly representable in f32, to sidestep single-precision rounding when comparing rendered text",
    },
    {
      name: "f64-nan",
      function: "echo-f64",
      input: VF64(@double.not_a_number),
      expect: VF64(@double.not_a_number),
      shape: ShF64,
      note: "NaN must round-trip as NaN; see same() in value.mbt for why this needs special comparison",
    },
    {
      name: "f64-inf",
      function: "echo-f64",
      input: VF64(@double.infinity),
      expect: VF64(@double.infinity),
      shape: ShF64,
      note: "positive infinity",
    },
    {
      name: "f64-neg-inf",
      function: "echo-f64",
      input: VF64(@double.neg_infinity),
      expect: VF64(@double.neg_infinity),
      shape: ShF64,
      note: "negative infinity",
    },
    {
      name: "char-ascii",
      function: "echo-char",
      input: VChar('a'),
      expect: VChar('a'),
      shape: ShChar,
      note: "sanity check",
    },
    {
      name: "char-quote",
      function: "echo-char",
      input: VChar('\''),
      expect: VChar('\''),
      shape: ShChar,
      note: "the WAVE grammar requires escaping this char",
    },
    {
      name: "char-newline",
      function: "echo-char",
      input: VChar('\n'),
      expect: VChar('\n'),
      shape: ShChar,
      note: "the WAVE grammar requires escaping this char",
    },
    {
      name: "char-snowman",
      function: "echo-char",
      input: VChar('\u{2603}'),
      expect: VChar('\u{2603}'),
      shape: ShChar,
      note: "a codepoint outside ASCII, to exercise non-escaped multi-byte rendering",
    },
  ]
}

///|
/// The flag labels declared by `wit/wide-flags.wit`, in declaration
/// order. Kept as one array so every case below and the fixture in
/// `cmd/main` agree on what bit index a given label is - a mismatch here
/// would make a case's `note` describe a different bit than the one it
/// actually sets.
pub fn wide_flags_labels() -> Array[String] {
  [
    "bit-00", "bit-01", "bit-02", "bit-03", "bit-04", "bit-05", "bit-06", "bit-07",
    "bit-08", "bit-09", "bit-10", "bit-11", "bit-12", "bit-13", "bit-14", "bit-15",
    "bit-16", "bit-17", "bit-18", "bit-19", "bit-20", "bit-21", "bit-22", "bit-23",
    "bit-24", "bit-25", "bit-26", "bit-27", "bit-28", "bit-29", "bit-30", "bit-31",
    "bit-32", "bit-33", "bit-34", "bit-35",
  ]
}

///|
fn flags(bits : UInt64) -> Value {
  VFlags(labels=wide_flags_labels(), bits~)
}

///|
fn wide_flags_shape() -> Shape {
  ShFlags(wide_flags_labels())
}

///|
/// The `wit/wide-flags.wit` regression corpus. As of this writing every
/// one of these cases fails before it can even run, because the fixture
/// does not build - see the "known finding" in README.md. The corpus
/// exists anyway so that the moment the underlying `wit-bindgen` defect is
/// fixed, `cmd/main` has real coverage ready rather than needing new cases
/// written under time pressure.
///
/// Each case's bit position matters: `bit-31` is the top bit of the low
/// 32-bit word, `bit-32` is the bottom bit of the high word, and `bit-35`
/// is the highest declared bit. Getting the boundary and just past it both
/// covered directly targets the reported defect (an extra `)` in the
/// generated high-word accessor).
pub fn wide_flags_regression_suite() -> Array[Case] {
  [
    {
      name: "flags-none",
      function: "echo-wide-flags",
      input: flags(0UL),
      expect: flags(0UL),
      shape: wide_flags_shape(),
      note: "no flags set",
    },
    {
      name: "flags-all",
      function: "echo-wide-flags",
      input: flags(0xFFFFFFFFFUL),
      expect: flags(0xFFFFFFFFFUL),
      shape: wide_flags_shape(),
      note: "all 36 declared flags set",
    },
    {
      name: "flags-bit-00",
      function: "echo-wide-flags",
      input: flags(1UL),
      expect: flags(1UL),
      shape: wide_flags_shape(),
      note: "lowest bit only, entirely within the low word",
    },
    {
      name: "flags-bit-31",
      function: "echo-wide-flags",
      input: flags(1UL << 31),
      expect: flags(1UL << 31),
      shape: wide_flags_shape(),
      note: "top bit of the low 32-bit word",
    },
    {
      name: "flags-bit-32",
      function: "echo-wide-flags",
      input: flags(1UL << 32),
      expect: flags(1UL << 32),
      shape: wide_flags_shape(),
      note: "bottom bit of the high word; wit-bindgen/wit-bindgen#1517 reported flags past 32 members mis-generating, and this project independently reproduced a parse error in exactly this accessor - see README",
    },
    {
      name: "flags-bit-35",
      function: "echo-wide-flags",
      input: flags(1UL << 35),
      expect: flags(1UL << 35),
      shape: wide_flags_shape(),
      note: "highest declared bit",
    },
  ]
}

///|
/// Every case from every suite `cmd/main` can run, concatenated. Tests
/// that check a property of "every case" (names are unique, input equals
/// expect, parsing a case's own rendering recovers it) iterate this
/// instead of listing each suite by hand, so adding a new suite here
/// automatically brings it under those checks too.
pub fn all_regression_suites() -> Array[Case] {
  scalar_regression_suite() +
  wide_flags_regression_suite() +
  option_u32_regression_suite() +
  result_u32_string_regression_suite() +
  record_point_regression_suite() +
  list_u32_regression_suite() +
  variant_match_result_regression_suite() +
  list_point_regression_suite() +
  option_result_u32_string_regression_suite() +
  record_shape_info_regression_suite()
}

///|
/// The `wit/option-u32.wit` regression corpus: `none`, and `some` at both
/// ends of `u32`'s range. `some(0)` matters on its own, separately from
/// `none` - a buggy lowering that collapsed "some of the zero value" into
/// "no value" would still pass a suite that only ever tried `none` and one
/// arbitrary `some`.
pub fn option_u32_regression_suite() -> Array[Case] {
  let shape = ShOption(ShU32)
  [
    {
      name: "option-none",
      function: "echo-option-u32",
      input: VOption(None),
      expect: VOption(None),
      shape,
      note: "the absent case",
    },
    {
      name: "option-some-zero",
      function: "echo-option-u32",
      input: VOption(Some(VU32(0))),
      expect: VOption(Some(VU32(0))),
      shape,
      note: "present with the payload type's zero value, distinct from none",
    },
    {
      name: "option-some-max",
      function: "echo-option-u32",
      input: VOption(Some(VU32(4294967295))),
      expect: VOption(Some(VU32(4294967295))),
      shape,
      note: "present with the payload's upper bound",
    },
  ]
}

///|
/// The `wit/result-u32-string.wit` regression corpus. `result-err-empty`
/// and `result-err-escaped` both matter on their own: an empty string is
/// the string type's own "zero value" (the same reasoning as
/// `option-some-zero`), and a message containing a quote exercises the
/// same mandatory-escape path `canonfuzz_wbtest.mbt` already checks for
/// strings in isolation, but here across a real component boundary rather
/// than just in `render`.
pub fn result_u32_string_regression_suite() -> Array[Case] {
  let shape = ShResult(ok=ShU32, err=ShString)
  [
    {
      name: "result-ok-zero",
      function: "echo-result",
      input: VResult(Ok(VU32(0))),
      expect: VResult(Ok(VU32(0))),
      shape,
      note: "the ok arm's payload zero value",
    },
    {
      name: "result-ok-max",
      function: "echo-result",
      input: VResult(Ok(VU32(4294967295))),
      expect: VResult(Ok(VU32(4294967295))),
      shape,
      note: "the ok arm's payload upper bound",
    },
    {
      name: "result-err-empty",
      function: "echo-result",
      input: VResult(Err(VString(""))),
      expect: VResult(Err(VString(""))),
      shape,
      note: "an empty error string, distinct from no error at all",
    },
    {
      name: "result-err-message",
      function: "echo-result",
      input: VResult(Err(VString("not found"))),
      expect: VResult(Err(VString("not found"))),
      shape,
      note: "a representative error message",
    },
    {
      name: "result-err-escaped",
      function: "echo-result",
      input: VResult(Err(VString("say \"hi\""))),
      expect: VResult(Err(VString("say \"hi\""))),
      shape,
      note: "an error string containing a quote, which WAVE must escape to stay a single string literal",
    },
  ]
}

///|
fn record_point_shape() -> Shape {
  ShRecord([("x", ShS32), ("y", ShS32), ("label", ShOption(ShString))])
}

///|
fn point(x : Int, y : Int, label : Value) -> Value {
  VRecord([("x", VS32(x)), ("y", VS32(y)), ("label", label)])
}

///|
/// The `wit/record-point.wit` regression corpus: this is the fixture the
/// structural comparator (`Shape`/`parse`, see README, "The comparator
/// now compares structurally") was specifically motivated by, so two
/// cases here exist to exercise exactly that: `record-fields-any-order`
/// invokes with fields in a different order than declared (WAVE allows
/// this on input; the comparator must not care, though `render` itself
/// always emits declaration order), and `record-label-with-punctuation`
/// puts a comma and a colon inside the nested string field, which a
/// naive `split(", ")`-style parser would misread as extra fields.
pub fn record_point_regression_suite() -> Array[Case] {
  let shape = record_point_shape()
  [
    {
      name: "record-label-none",
      function: "echo-point",
      input: point(-5, 10, VOption(None)),
      expect: point(-5, 10, VOption(None)),
      shape,
      note: "wasmtime omits an option field entirely when it's none, rather than printing it; the comparator must still recover none, not reject the record as incomplete",
    },
    {
      name: "record-label-some",
      function: "echo-point",
      input: point(1, 2, VOption(Some(VString("origin")))),
      expect: point(1, 2, VOption(Some(VString("origin")))),
      shape,
      note: "sanity check with every field present",
    },
    {
      name: "record-fields-any-order",
      function: "echo-point",
      input: VRecord([
        ("label", VOption(Some(VString("reordered")))),
        ("y", VS32(2)),
        ("x", VS32(1)),
      ]),
      expect: point(1, 2, VOption(Some(VString("reordered")))),
      shape,
      note: "WAVE allows record fields in any order on input; render() always emits declaration order regardless of how input was built, and the comparator must not depend on wasmtime's output order matching it",
    },
    {
      name: "record-label-with-punctuation",
      function: "echo-point",
      input: point(0, 0, VOption(Some(VString("a, b: c \"q\"")))),
      expect: point(0, 0, VOption(Some(VString("a, b: c \"q\"")))),
      shape,
      note: "a comma and a colon inside the nested string field - exactly what split_top_level in wave_parse.mbt exists to not misread as extra fields",
    },
  ]
}

///|
/// The `wit/list-u32.wit` regression corpus: the empty list matters on
/// its own (distinct from, say, a list containing one zero element), and
/// `list-single`/`list-several` check that element order is preserved,
/// not just that the right elements are present - `same` for lists
/// compares position by position for exactly this reason.
pub fn list_u32_regression_suite() -> Array[Case] {
  let shape = ShList(ShU32)
  [
    {
      name: "list-empty",
      function: "echo-list-u32",
      input: VList([]),
      expect: VList([]),
      shape,
      note: "the empty list",
    },
    {
      name: "list-single",
      function: "echo-list-u32",
      input: VList([VU32(4294967295)]),
      expect: VList([VU32(4294967295)]),
      shape,
      note: "one element, at the payload type's upper bound",
    },
    {
      name: "list-several",
      function: "echo-list-u32",
      input: VList([VU32(0), VU32(1), VU32(2)]),
      expect: VList([VU32(0), VU32(1), VU32(2)]),
      shape,
      note: "element order must be preserved, not just element membership",
    },
  ]
}

///|
fn match_result_shape() -> Shape {
  ShVariant([
    ("none", None),
    ("exact", Some(ShString)),
    ("partial", Some(ShU32)),
  ])
}

///|
/// The `wit/variant-match-result.wit` regression corpus. `match-none`
/// matters specifically because the case is *named* `none` - the same
/// word as the `option` "empty" keyword - so it directly exercises the
/// `%`-escaping WAVE requires for a variant case name that collides with
/// a keyword (confirmed by hand that `wasmtime` requires `%none` on
/// input and produces it on output, not the bare word).
pub fn variant_match_result_regression_suite() -> Array[Case] {
  let shape = match_result_shape()
  [
    {
      name: "match-none",
      function: "echo-match-result",
      input: VVariant(case_name="none", payload=None),
      expect: VVariant(case_name="none", payload=None),
      shape,
      note: "a case named the same as the option \"empty\" keyword - must round-trip as %none, not none",
    },
    {
      name: "match-exact",
      function: "echo-match-result",
      input: VVariant(case_name="exact", payload=Some(VString("needle"))),
      expect: VVariant(case_name="exact", payload=Some(VString("needle"))),
      shape,
      note: "a case with a string payload",
    },
    {
      name: "match-partial",
      function: "echo-match-result",
      input: VVariant(case_name="partial", payload=Some(VU32(5))),
      expect: VVariant(case_name="partial", payload=Some(VU32(5))),
      shape,
      note: "a case with a numeric payload, to check that different cases' payload shapes are each used correctly, not just the first case declared",
    },
  ]
}

///|
/// A smaller `point` than `record_point_shape`'s - just the two required
/// fields, no `option` field - since what this suite is checking is
/// nesting a record inside a list, not re-checking the record work
/// itself.
fn nested_point_shape() -> Shape {
  ShRecord([("x", ShS32), ("y", ShS32)])
}

///|
fn nested_point(x : Int, y : Int) -> Value {
  VRecord([("x", VS32(x)), ("y", VS32(y))])
}

///|
/// The `wit/list-point.wit` regression corpus: a list of records. Neither
/// `option`/`result`'s parsing (which still assumes no nested parens
/// inside its own wrapper, see the doc comment on `parse` in
/// `wave_parse.mbt`) nor anything else needed to change for this to
/// work - a record uses `{}`, not `()`, so `split_top_level` already
/// keeps a record's internal comma separate from the list's. This suite
/// exists to confirm that's actually true against a real component, not
/// just architecturally plausible.
pub fn list_point_regression_suite() -> Array[Case] {
  let shape = ShList(nested_point_shape())
  [
    {
      name: "list-point-empty",
      function: "echo-list-point",
      input: VList([]),
      expect: VList([]),
      shape,
      note: "the empty list, same as list-u32's, now with a record element type",
    },
    {
      name: "list-point-several",
      function: "echo-list-point",
      input: VList([nested_point(1, 2), nested_point(-3, 4)]),
      expect: VList([nested_point(1, 2), nested_point(-3, 4)]),
      shape,
      note: "two records in one list - each record's own comma and the list's separating comma must both be recognized correctly",
    },
  ]
}

///|
/// The `wit/option-result-u32-string.wit` regression corpus:
/// `option<result<u32, string>>`, two paren-using wrappers nested inside
/// each other. `parse`'s `option`/`result` handling was believed to need
/// generalizing before this would work (see "Nesting" in README.md) -
/// it didn't: `strip` trims a fixed-length prefix/suffix rather than
/// matching brackets, so the text between is handed to the inner `parse`
/// unchanged no matter what parens it contains. This suite exists to
/// confirm that against a real component, the same way `list-point`
/// confirmed `list<record>` needed nothing either.
pub fn option_result_u32_string_regression_suite() -> Array[Case] {
  let shape = ShOption(ShResult(ok=ShU32, err=ShString))
  [
    {
      name: "option-result-none",
      function: "echo-option-result",
      input: VOption(None),
      expect: VOption(None),
      shape,
      note: "the absent case, same as option-u32's",
    },
    {
      name: "option-result-some-ok-zero",
      function: "echo-option-result",
      input: VOption(Some(VResult(Ok(VU32(0))))),
      expect: VOption(Some(VResult(Ok(VU32(0))))),
      shape,
      note: "present, ok arm, payload zero value",
    },
    {
      name: "option-result-some-ok-max",
      function: "echo-option-result",
      input: VOption(Some(VResult(Ok(VU32(4294967295))))),
      expect: VOption(Some(VResult(Ok(VU32(4294967295))))),
      shape,
      note: "present, ok arm, payload upper bound",
    },
    {
      name: "option-result-some-err",
      function: "echo-option-result",
      input: VOption(Some(VResult(Err(VString("not found"))))),
      expect: VOption(Some(VResult(Err(VString("not found"))))),
      shape,
      note: "present, err arm - three levels of wrapper (option, result, string) all at once",
    },
  ]
}

///|
fn shape_kind_shape() -> Shape {
  ShVariant([
    ("circle", Some(ShF64)),
    ("square", Some(ShF64)),
    ("unknown", None),
  ])
}

///|
fn shape_info(id : UInt, kind : Value) -> Value {
  VRecord([("id", VU32(id)), ("kind", kind)])
}

///|
/// The `wit/record-shape-info.wit` regression corpus: a `record` field
/// whose value is itself a `variant` - the other documented gap in
/// "what's not implemented" alongside deeper nesting. `parse_wave_record`
/// already calls `parse` generically on each field's own shape, so this
/// was expected to work unchanged; this suite confirms it does against a
/// real component, covering both a with-payload case and the no-payload
/// case (whose field value is a bare word, immediately followed by the
/// closing `}` with no parens at all).
pub fn record_shape_info_regression_suite() -> Array[Case] {
  let shape = ShRecord([("id", ShU32), ("kind", shape_kind_shape())])
  [
    {
      name: "shape-info-circle",
      function: "echo-shape-info",
      input: shape_info(
        1,
        VVariant(case_name="circle", payload=Some(VF64(3.5))),
      ),
      expect: shape_info(
        1,
        VVariant(case_name="circle", payload=Some(VF64(3.5))),
      ),
      shape,
      note: "a with-payload variant case as a record field's value",
    },
    {
      name: "shape-info-unknown",
      function: "echo-shape-info",
      input: shape_info(2, VVariant(case_name="unknown", payload=None)),
      expect: shape_info(2, VVariant(case_name="unknown", payload=None)),
      shape,
      note: "a no-payload variant case as a record field's value - the field's text is a bare word right next to the record's own : and }",
    },
  ]
}
