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
