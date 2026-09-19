///|
/// Rendering of [Value] into WAVE (WebAssembly Value Encoding) text.
///
/// WAVE is the text format `wasmtime run --invoke` uses for both arguments
/// and results; encoding our test inputs this way lets `cmd/main` drive a
/// real component through the command line with no custom host binary.
///
/// This module implements only the subset of the WAVE grammar needed for
/// the value vocabulary in `value.mbt` (booleans, integers, floats and
/// chars). The full grammar, including records, lists and variants, is
/// specified by the `wasm-wave` crate that ships with `wasm-tools`:
/// https://github.com/bytecodealliance/wasm-tools/blob/main/crates/wasm-wave/README.md
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
  }
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
