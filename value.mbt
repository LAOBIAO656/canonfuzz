///|
/// A single WIT value that `canonfuzz` knows how to carry across a
/// component boundary: the primitive numeric types, `bool`, `char` and
/// `string` (the scalar regression suite in `cases.mbt`), `flags` (the
/// `wide-flags` suite), `option<T>` (the `option-u32` suite), and
/// `result<T, E>` for any `T`/`E` this type can already represent (the
/// `result-u32-string` suite). Records, lists, variants, enums and
/// resources are planned; see the roadmap in README.md.
///
/// `VFlags` carries its own label list rather than referring to some
/// external schema, because WAVE renders a flags value as the set of its
/// member *names* (`{read, write}`), not as a bitmask - a `Value` has to
/// be self-contained to render itself. `bits` sets bit `i` for
/// `labels[i]`; `labels.length()` must be at most 64.
///
/// `VResult` reuses MoonBit's built-in `Result` rather than inventing a
/// two-armed variant of its own, since `wit-bindgen` already lowers WIT
/// `result<T, E>` to exactly `Result[T, E]`.
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
  VString(String)
  VFlags(labels~ : Array[String], bits~ : UInt64)
  VOption(Value?)
  VResult(Result[Value, Value])
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
    (VString(x), VString(y)) => x == y
    (VFlags(labels=lx, bits=bx), VFlags(labels=ly, bits=by)) =>
      lx == ly && bx == by
    (VOption(None), VOption(None)) => true
    (VOption(Some(x)), VOption(Some(y))) => same(x, y)
    (VResult(Ok(x)), VResult(Ok(y))) => same(x, y)
    (VResult(Err(x)), VResult(Err(y))) => same(x, y)
    (_, _) => false
  }
}
