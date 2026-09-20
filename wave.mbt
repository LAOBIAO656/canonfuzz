///|
/// Rendering of [Value] into WAVE (WebAssembly Value Encoding) text.
///
/// WAVE is the text format `wasmtime run --invoke` uses for both arguments
/// and results; encoding our test inputs this way lets `cmd/main` drive a
/// real component through the command line with no custom host binary.
///
/// This module implements only the subset of the WAVE grammar needed for
/// the value vocabulary in `value.mbt` (booleans, integers, floats, chars,
/// flags and options). The full grammar, including records, lists and
/// variants, is specified by the `wasm-wave` crate that ships with
/// `wasm-tools`:
/// https://github.com/bytecodealliance/wasm-tools/blob/main/crates/wasm-wave/README.md
///
/// `option` and `result` always render in their explicit
/// `some(...)`/`none` and `ok(...)`/`err(...)` forms rather than the
/// grammar's "flat" alternatives (a bare payload standing for `some` or
/// `ok`), because that is what `wasmtime run --invoke` itself prints for
/// both - confirmed by hand against `wasmtime` 48.0.2, since the grammar
/// documents the flat forms as legal input but does not commit any
/// implementation to using them for output.
pub fn render(v : Value) -> String {
  match v {
    VBool(b) => if b { "true" } else { "false" }
    VS8(n) => n.to_string()
    VS16(n) => n.to_string()
    VS32(n) => n.to_string()
    VS64(n) => n.to_string()
    VU8(n) => n.to_uint().to_string()
    VU16(n) => n.to_string()
    VU32(n) => n.to_string()
    VU64(n) => n.to_string()
    VF32(f) => render_float(f.to_double())
    VF64(f) => render_float(f)
    VChar(c) => "'" + escape(c, quote='\'') + "'"
    VString(s) => render_string(s)
    VFlags(labels~, bits~) => render_flags(labels, bits)
    VOption(None) => "none"
    VOption(Some(inner)) => "some(" + render(inner) + ")"
    VResult(Ok(inner)) => "ok(" + render(inner) + ")"
    VResult(Err(inner)) => "err(" + render(inner) + ")"
    VRecord(fields) => render_record(fields)
    VList(elements) => render_list(elements)
    VVariant(case_name~, payload~) => render_variant(case_name, payload)
  }
}

///|
/// A case name that collides with a WAVE keyword (most notably `none`,
/// which is both a perfectly ordinary case name and the `option` "empty"
/// keyword) must be prefixed with `%` - confirmed by hand that `wasmtime`
/// both requires this on input and produces it on output.
fn render_variant(case_name : String, payload : Value?) -> String {
  let label = if wave_keywords.contains(case_name) {
    "%" + case_name
  } else {
    case_name
  }
  match payload {
    None => label
    Some(inner) => label + "(" + render(inner) + ")"
  }
}

///|
fn render_list(elements : Array[Value]) -> String {
  let mut out = "["
  let mut first = true
  for element in elements {
    if !first {
      out = out + ", "
    }
    out = out + render(element)
    first = false
  }
  out + "]"
}

///|
/// Render every field explicitly, `{field-a: 1, field-b: "two"}`, in
/// declaration order. WAVE also allows omitting a `none`-valued `option`
/// field entirely - which is in fact what `wasmtime` itself does on
/// output, confirmed by hand against `wasmtime` 48.0.2 - but rendering
/// every field explicitly here keeps `render` a total function of a
/// `Value` alone, with no need to know which fields are optional; `parse`
/// is the side that has to accept the omitted form, since that is what it
/// actually receives from a real component.
fn render_record(fields : Array[(String, Value)]) -> String {
  let mut out = "{"
  let mut first = true
  for entry in fields {
    let (name, value) = entry
    if !first {
      out = out + ", "
    }
    out = out + name + ": " + render(value)
    first = false
  }
  out + "}"
}

///|
/// Render a flags value as the WAVE set-of-labels form: the labels whose
/// bit is set, comma-separated inside braces, in declaration order (WAVE
/// allows any order; declaration order keeps output deterministic so two
/// renderings of an equal value are always byte-identical). An empty set
/// is `{}`.
fn render_flags(labels : Array[String], bits : UInt64) -> String {
  let mut out = "{"
  let mut first = true
  for i = 0; i < labels.length(); i = i + 1 {
    if ((bits >> i) & 1UL) == 1UL {
      if !first {
        out = out + ", "
      }
      out = out + labels[i]
      first = false
    }
  }
  out + "}"
}

///|
/// Shared float rendering for both `f32` and `f64` payloads. WAVE spells
/// the three non-finite values as bare keywords rather than the usual
/// decimal syntax.
fn render_float(f : Double) -> String {
  if f.is_nan() {
    "nan"
  } else if f == @double.infinity {
    "inf"
  } else if f == @double.neg_infinity {
    "-inf"
  } else {
    f.to_string()
  }
}

///|
/// Render a WAVE string literal: double-quote-delimited, with every char
/// escaped the same way `escape` would escape it inside a char literal,
/// except that `"` rather than `'` is the delimiter that must be escaped -
/// a bare `'` needs no escape inside a string, and a bare `"` would end
/// the literal early.
fn render_string(s : String) -> String {
  let mut out = "\""
  for c in s {
    out = out + escape(c, quote='"')
  }
  out + "\""
}

///|
/// The escape WAVE requires for one char, inside either a char or a string
/// literal: backslash, the active delimiter (`'` for a char, `"` for a
/// string), and the three C0 controls with their own escape. Every other
/// control character uses the `\u{...}` form; everything else is written
/// out as-is.
fn escape(c : Char, quote~ : Char) -> String {
  if c == '\\' {
    "\\\\"
  } else if c == quote {
    "\\" + quote.to_string()
  } else {
    match c {
      '\n' => "\\n"
      '\r' => "\\r"
      '\t' => "\\t"
      _ =>
        if c.to_int() < 0x20 {
          "\\u{" + c.to_int().to_string() + "}"
        } else {
          c.to_string()
        }
    }
  }
}
