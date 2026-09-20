///|
/// A single WIT value that `canonfuzz` knows how to carry across a
/// component boundary: the primitive numeric types, `bool`, `char` and
/// `string` (the scalar regression suite in `cases.mbt`), `flags` (the
/// `wide-flags` suite), `option<T>` (the `option-u32` suite),
/// `result<T, E>` (the `result-u32-string` suite), `record` (the
/// `record-point` suite), `list<T>` (the `list-u32` suite), and
/// `variant` (the `variant-match-result` suite; a plain `enum` is just a
/// `variant` where every case's payload is `None`, so it needs no
/// separate representation). Nested compound shapes and resources are
/// planned; see the roadmap in README.md.
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
///
/// `VRecord` keeps its fields as an `(name, value)` array in declaration
/// order for `render` to walk, but - per the WAVE grammar, and confirmed
/// by hand against `wasmtime` 48.0.2 - field order is not part of a
/// record's identity: `same` below compares by name, and `wasmtime`
/// itself both accepts input fields in any order and omits an
/// `option`-typed field from its output entirely when that field is
/// `none`, rather than printing `none` explicitly.
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
  VRecord(Array[(String, Value)])
  VList(Array[Value])
  VVariant(case_name~ : String, payload~ : Value?)
} derive(Debug)

///|
/// WAVE keywords that a variant or enum case name must be prefixed with
/// `%` to use, since the bare word would otherwise parse as the keyword
/// itself (`none`, most notably, since it is also a perfectly ordinary
/// case name to want - see `wit/variant-match-result.wit`).
let wave_keywords : Array[String] = [
  "true", "false", "inf", "nan", "some", "none", "ok", "err",
]

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
    (VRecord(fx), VRecord(fy)) => same_fields(fx, fy)
    (VList(xs), VList(ys)) => same_elements(xs, ys)
    (VVariant(case_name=cx, payload=px), VVariant(case_name=cy, payload=py)) =>
      cx == cy && same_option(px, py)
    (_, _) => false
  }
}

///|
/// Unlike a record's fields, a list's elements are ordered - WAVE gives
/// no basis for treating `[1, 2]` and `[2, 1]` as the same value - so
/// this compares position by position instead of by lookup.
fn same_elements(a : Array[Value], b : Array[Value]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !same(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
/// Two records are equal if they have the same set of field names, each
/// naming a `same()`-equal value - independent of the order either side
/// happens to store its fields in, since WAVE does not consider record
/// field order part of a value's identity (see the doc comment on
/// `VRecord`).
fn same_fields(a : Array[(String, Value)], b : Array[(String, Value)]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for entry in a {
    let (name, value) = entry
    match find_field(b, name) {
      Some(other) => if !same(value, other) { return false }
      None => return false
    }
  }
  true
}

///|
fn find_field(fields : Array[(String, Value)], name : String) -> Value? {
  for entry in fields {
    let (field_name, value) = entry
    if field_name == name {
      return Some(value)
    }
  }
  None
}

///|
/// `same` lifted to `Value?`, for comparing a parse result against an
/// expected value without going through derived `==` (which would be
/// wrong for the same reason `same` exists: `Some(nan) == Some(nan)` must
/// be `true` here, and plain `==` on a `Double` says otherwise).
pub fn same_option(a : Value?, b : Value?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => same(x, y)
    (_, _) => false
  }
}

///|
/// The type-former shape of a [Value], carrying enough information to
/// parse WAVE text back into one - which a `Value` itself cannot always
/// do. A `Value` instance only ever populates one arm of an `option` or
/// `result`; parsing needs to know what the *other* arm would look like
/// too; so it can tell a genuinely malformed result from a component that
/// (correctly or not) returned the arm nobody expected, and describe
/// either case structurally instead of falling back to raw text. Each
/// regression suite in `cases.mbt` authors one `Shape` per case
/// alongside its `Value`s, rather than `parse` trying to infer a shape
/// from a single example value.
pub enum Shape {
  ShBool
  ShS8
  ShS16
  ShS32
  ShS64
  ShU8
  ShU16
  ShU32
  ShU64
  ShF32
  ShF64
  ShChar
  ShString
  ShFlags(Array[String])
  ShOption(Shape)
  ShResult(ok~ : Shape, err~ : Shape)
  ShRecord(Array[(String, Shape)])
  ShList(Shape)
  /// Each case's optional payload shape; `None` for a case with no
  /// payload. A plain `enum` is represented as a `ShVariant` where every
  /// entry's payload shape is `None`.
  ShVariant(Array[(String, Shape?)])
} derive(Debug)
