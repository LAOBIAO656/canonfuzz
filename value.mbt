///|
/// A single WIT value that `canonfuzz` knows how to carry across a
/// component boundary. The v1 vocabulary is deliberately limited to the
/// primitive numeric types, `bool` and `char` - the type-formers that the
/// scalar regression suite in `cases.mbt` exercises. Compound shapes
/// (records, lists, options, results, variants, flags, resources) are
/// planned; see the roadmap in README.md.
pub enum Value {
  VBool(Bool)
  VS8(Int)
  VS16(Int)
  VS32(Int)
  VS64(Int64)
  VU8(Byte)
  VU16(UInt)
  VU32(UInt)
  VU64(UInt64)
  VF32(Float)
  VF64(Double)
  VChar(Char)
} derive(Debug)

///|
/// Structural equality for [Value], with IEEE-754 NaN treated as equal to
/// itself. Regular `==` cannot be used for the round-trip check because a
/// correct implementation that returns `nan` for a `nan` input must still be
/// reported as a pass, and `nan == nan` is `false` under normal float
/// comparison.
pub fn same(a : Value, b : Value) -> Bool {
  match (a, b) {
    (VBool(x), VBool(y)) => x == y
    (VS8(x), VS8(y)) => x == y
    (VS16(x), VS16(y)) => x == y
    (VS32(x), VS32(y)) => x == y
    (VS64(x), VS64(y)) => x == y
    (VU8(x), VU8(y)) => x == y
    (VU16(x), VU16(y)) => x == y
    (VU32(x), VU32(y)) => x == y
    (VU64(x), VU64(y)) => x == y
    (VF32(x), VF32(y)) => x == y || (x.is_nan() && y.is_nan())
    (VF64(x), VF64(y)) => x == y || (x.is_nan() && y.is_nan())
    (VChar(x), VChar(y)) => x == y
    (_, _) => false
  }
}
