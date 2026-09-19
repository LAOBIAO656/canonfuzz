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
/// `option` always renders in its explicit `some(...)`/`none` form rather
/// than the grammar's "flat" alternative (a bare payload standing for
/// `some`), because that is what `wasmtime run --invoke` itself prints for
/// an option result - confirmed by hand against `wasmtime` 48.0.2, since
/// the grammar documents the flat form as legal input but does not commit
/// any implementation to using it for output.
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
    VChar(c) => render_char(c)
    VFlags(labels~, bits~) => render_flags(labels, bits)
    VOption(None) => "none"
    VOption(Some(inner)) => "some(" + render(inner) + ")"
  }
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
/// Render a single WAVE char literal, applying the escapes the grammar
/// makes mandatory (backslash, quote, and the three C0 controls with their
/// own escape). Every other control character uses the `\u{...}` form;
/// everything else is written out as-is.
fn render_char(c : Char) -> String {
  let body = match c {
    '\\' => "\\\\"
    '\'' => "\\'"
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
  "'" + body + "'"
}
