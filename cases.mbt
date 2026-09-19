///|
/// One entry in the regression corpus: an exported WIT function together
/// with a value it should return unchanged.
///
/// `expect` is stored separately from `input` (even though every case here
/// is an identity check) so the corpus format already matches functions
/// that transform their input, which later capabilities will need.
pub struct Case {
  name : String
  function : String
  input : Value
  expect : Value
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
      note: "sanity check",
    },
    {
      name: "bool-false",
      function: "echo-bool",
      input: VBool(false),
      expect: VBool(false),
      note: "sanity check",
    },
    {
      name: "s8-min",
      function: "echo-s8",
      input: VS8(-128),
      expect: VS8(-128),
      note: "lower bound of s8; wit-bindgen/wit-bindgen#1518 reported this width corrupting values",
    },
    {
      name: "s8-max",
      function: "echo-s8",
      input: VS8(127),
      expect: VS8(127),
      note: "upper bound of s8; see wit-bindgen/wit-bindgen#1518",
    },
    {
      name: "s8-zero",
      function: "echo-s8",
      input: VS8(0),
      expect: VS8(0),
      note: "zero crossing",
    },
    {
      name: "s8-neg-one",
      function: "echo-s8",
      input: VS8(-1),
      expect: VS8(-1),
      note: "all-ones bit pattern under two's complement",
    },
    {
      name: "s16-min",
      function: "echo-s16",
      input: VS16(-32768),
      expect: VS16(-32768),
      note: "lower bound of s16; see wit-bindgen/wit-bindgen#1518",
    },
    {
      name: "s16-max",
      function: "echo-s16",
      input: VS16(32767),
      expect: VS16(32767),
      note: "upper bound of s16; see wit-bindgen/wit-bindgen#1518",
    },
    {
      name: "s32-min",
      function: "echo-s32",
      input: VS32(-2147483648),
      expect: VS32(-2147483648),
      note: "lower bound of s32",
    },
    {
      name: "s32-max",
      function: "echo-s32",
      input: VS32(2147483647),
      expect: VS32(2147483647),
      note: "upper bound of s32",
    },
    {
      name: "s64-min",
      function: "echo-s64",
      input: VS64(-9223372036854775808L),
      expect: VS64(-9223372036854775808L),
      note: "lower bound of s64",
    },
    {
      name: "s64-max",
      function: "echo-s64",
      input: VS64(9223372036854775807L),
      expect: VS64(9223372036854775807L),
      note: "upper bound of s64",
    },
    {
      name: "u8-max",
      function: "echo-u8",
      input: VU8(255),
      expect: VU8(255),
      note: "upper bound of u8",
    },
    {
      name: "u8-zero",
      function: "echo-u8",
      input: VU8(0),
      expect: VU8(0),
      note: "lower bound of u8",
    },
    {
      name: "u16-max",
      function: "echo-u16",
      input: VU16(65535),
      expect: VU16(65535),
      note: "upper bound of u16",
    },
    {
      name: "u32-max",
      function: "echo-u32",
      input: VU32(4294967295),
      expect: VU32(4294967295),
      note: "upper bound of u32",
    },
    {
      name: "u64-max",
      function: "echo-u64",
      input: VU64(18446744073709551615UL),
      expect: VU64(18446744073709551615UL),
      note: "upper bound of u64",
    },
    {
      name: "f32-zero",
      function: "echo-f32",
      input: VF32(0.0),
      expect: VF32(0.0),
      note: "sanity check",
    },
    {
      name: "f32-fraction",
      function: "echo-f32",
      input: VF32(3.5),
      expect: VF32(3.5),
      note: "a value exactly representable in f32, to sidestep single-precision rounding when comparing rendered text",
    },
    {
      name: "f64-nan",
      function: "echo-f64",
      input: VF64(@double.not_a_number),
      expect: VF64(@double.not_a_number),
      note: "NaN must round-trip as NaN; see same() in value.mbt for why this needs special comparison",
    },
    {
      name: "f64-inf",
      function: "echo-f64",
      input: VF64(@double.infinity),
      expect: VF64(@double.infinity),
      note: "positive infinity",
    },
    {
      name: "f64-neg-inf",
      function: "echo-f64",
      input: VF64(@double.neg_infinity),
      expect: VF64(@double.neg_infinity),
      note: "negative infinity",
    },
    {
      name: "char-ascii",
      function: "echo-char",
      input: VChar('a'),
      expect: VChar('a'),
      note: "sanity check",
    },
    {
      name: "char-quote",
      function: "echo-char",
      input: VChar('\''),
      expect: VChar('\''),
      note: "the WAVE grammar requires escaping this char",
    },
    {
      name: "char-newline",
      function: "echo-char",
      input: VChar('\n'),
      expect: VChar('\n'),
      note: "the WAVE grammar requires escaping this char",
    },
    {
      name: "char-snowman",
      function: "echo-char",
      input: VChar('\u{2603}'),
      expect: VChar('\u{2603}'),
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
      note: "no flags set",
    },
    {
      name: "flags-all",
      function: "echo-wide-flags",
      input: flags(0xFFFFFFFFFUL),
      expect: flags(0xFFFFFFFFFUL),
      note: "all 36 declared flags set",
    },
    {
      name: "flags-bit-00",
      function: "echo-wide-flags",
      input: flags(1UL),
      expect: flags(1UL),
      note: "lowest bit only, entirely within the low word",
    },
    {
      name: "flags-bit-31",
      function: "echo-wide-flags",
      input: flags(1UL << 31),
      expect: flags(1UL << 31),
      note: "top bit of the low 32-bit word",
    },
    {
      name: "flags-bit-32",
      function: "echo-wide-flags",
      input: flags(1UL << 32),
      expect: flags(1UL << 32),
      note: "bottom bit of the high word; wit-bindgen/wit-bindgen#1517 reported flags past 32 members mis-generating, and this project independently reproduced a parse error in exactly this accessor - see README",
    },
    {
      name: "flags-bit-35",
      function: "echo-wide-flags",
      input: flags(1UL << 35),
      expect: flags(1UL << 35),
      note: "highest declared bit",
    },
  ]
}

///|
/// Every case from every suite `cmd/main` can run, concatenated. Tests
/// that check a property of "every case" (names are unique, input equals
/// expect) iterate this instead of listing each suite by hand, so adding a
/// new suite here automatically brings it under those checks too.
pub fn all_regression_suites() -> Array[Case] {
  scalar_regression_suite() +
  wide_flags_regression_suite() +
  option_u32_regression_suite() +
  result_u32_string_regression_suite()
}

///|
/// The `wit/option-u32.wit` regression corpus: `none`, and `some` at both
/// ends of `u32`'s range. `some(0)` matters on its own, separately from
/// `none` - a buggy lowering that collapsed "some of the zero value" into
/// "no value" would still pass a suite that only ever tried `none` and one
/// arbitrary `some`.
pub fn option_u32_regression_suite() -> Array[Case] {
  [
    {
      name: "option-none",
      function: "echo-option-u32",
      input: VOption(None),
      expect: VOption(None),
      note: "the absent case",
    },
    {
      name: "option-some-zero",
      function: "echo-option-u32",
      input: VOption(Some(VU32(0))),
      expect: VOption(Some(VU32(0))),
      note: "present with the payload type's zero value, distinct from none",
    },
    {
      name: "option-some-max",
      function: "echo-option-u32",
      input: VOption(Some(VU32(4294967295))),
      expect: VOption(Some(VU32(4294967295))),
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
  [
    {
      name: "result-ok-zero",
      function: "echo-result",
      input: VResult(Ok(VU32(0))),
      expect: VResult(Ok(VU32(0))),
      note: "the ok arm's payload zero value",
    },
    {
      name: "result-ok-max",
      function: "echo-result",
      input: VResult(Ok(VU32(4294967295))),
      expect: VResult(Ok(VU32(4294967295))),
      note: "the ok arm's payload upper bound",
    },
    {
      name: "result-err-empty",
      function: "echo-result",
      input: VResult(Err(VString(""))),
      expect: VResult(Err(VString(""))),
      note: "an empty error string, distinct from no error at all",
    },
    {
      name: "result-err-message",
      function: "echo-result",
      input: VResult(Err(VString("not found"))),
      expect: VResult(Err(VString("not found"))),
      note: "a representative error message",
    },
    {
      name: "result-err-escaped",
      function: "echo-result",
      input: VResult(Err(VString("say \"hi\""))),
      expect: VResult(Err(VString("say \"hi\""))),
      note: "an error string containing a quote, which WAVE must escape to stay a single string literal",
    },
  ]
}
