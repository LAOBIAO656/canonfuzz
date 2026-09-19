///|
/// The inverse of `render`: parse WAVE text into a [Value] of the shape
/// `shape` describes, or `None` if `text` does not match that shape at
/// all. This lets `cmd/main` compare a real component's output to what
/// was expected structurally (via `same`) instead of as raw text, so a
/// difference that WAVE's grammar does not actually distinguish - such as
/// whitespace between flags labels - can never register as a false
/// mismatch, and so that once records or lists are added, a difference in
/// field order is not mistaken for one either.
///
/// `parse` is deliberately not a general WAVE parser: it only handles the
/// forms `render` itself produces (always the explicit
/// `some(...)`/`none` and `ok(...)`/`err(...)` forms, never WAVE's "flat"
/// alternatives - see the note on `render` in wave.mbt), and it expects
/// exactly one `some(...)`/`ok(...)`/`err(...)` wrapper with no nested
/// parentheses inside it, which holds for every shape in `cases.mbt`
/// today but would need generalizing before an option or result could
/// wrap something bigger, like a record.
pub fn parse(shape : Shape, text : String) -> Value? {
  match shape {
    ShBool =>
      if text == "true" {
        Some(VBool(true))
      } else if text == "false" {
        Some(VBool(false))
      } else {
        None
      }
    ShS8 => parse_signed(text).bind(fn(n) { Some(VS8(n)) })
    ShS16 => parse_signed(text).bind(fn(n) { Some(VS16(n)) })
    ShS32 => parse_signed(text).bind(fn(n) { Some(VS32(n)) })
    ShS64 => parse_signed64(text).bind(fn(n) { Some(VS64(n)) })
    ShU8 =>
      parse_unsigned(text).bind(fn(n) {
        if n <= 255 {
          Some(VU8(n.to_byte()))
        } else {
          None
        }
      })
    ShU16 =>
      parse_unsigned(text).bind(fn(n) {
        if n <= 65535 {
          Some(VU16(n))
        } else {
          None
        }
      })
    ShU32 => parse_unsigned(text).bind(fn(n) { Some(VU32(n)) })
    ShU64 => parse_unsigned64(text).bind(fn(n) { Some(VU64(n)) })
    ShF32 =>
      parse_wave_float(text).bind(fn(f) { Some(VF32(Float::from_double(f))) })
    ShF64 => parse_wave_float(text).bind(fn(f) { Some(VF64(f)) })
    ShChar => parse_wave_char(text)
    ShString => parse_wave_string(text)
    ShFlags(labels) => parse_wave_flags(text, labels)
    ShOption(inner) => parse_wave_option(text, inner)
    ShResult(ok~, err~) => parse_wave_result(text, ok~, err~)
    ShRecord(field_shapes) => parse_wave_record(text, field_shapes)
  }
}

///|
fn parse_signed(text : String) -> Int? {
  Some(@string.parse_int(text)) catch {
    _ => None
  }
}

///|
fn parse_signed64(text : String) -> Int64? {
  Some(@string.parse_int64(text)) catch {
    _ => None
  }
}

///|
fn parse_unsigned(text : String) -> UInt? {
  Some(@string.parse_uint(text)) catch {
    _ => None
  }
}

///|
fn parse_unsigned64(text : String) -> UInt64? {
  Some(@string.parse_uint64(text)) catch {
    _ => None
  }
}

///|
/// WAVE's three float keywords first, since none of them are valid input
/// to a decimal parser; anything else falls through to `parse_double`.
fn parse_wave_float(text : String) -> Double? {
  if text == "nan" {
    Some(@double.not_a_number)
  } else if text == "inf" {
    Some(@double.infinity)
  } else if text == "-inf" {
    Some(@double.neg_infinity)
  } else {
    Some(@string.parse_double(text)) catch {
      _ => None
    }
  }
}

///|
/// A char literal must be exactly `'`, an unescaped body, `'` - `strip`
/// (see below) already rejects anything shorter than two quote chars, and
/// a body that unescapes to more or less than one char is not a valid
/// char literal even if the quotes are right.
fn parse_wave_char(text : String) -> Value? {
  strip(text, "'", "'").bind(fn(body) {
    unescape(body).bind(fn(chars) {
      if chars.length() == 1 {
        Some(VChar(chars[0]))
      } else {
        None
      }
    })
  })
}

///|
fn parse_wave_string(text : String) -> Value? {
  strip(text, "\"", "\"").bind(fn(body) {
    unescape(body).bind(fn(chars) {
      let buf = StringBuilder()
      for c in chars {
        buf.write_char(c)
      }
      Some(VString(buf.to_string()))
    })
  })
}

///|
/// The labels between the braces, comma-and-space separated per
/// `render_flags`. An empty set is `{}` with nothing between the braces,
/// not a single empty label. Any label not in `labels` - a typo, or a
/// member `wit-bindgen` added that this suite does not know about yet -
/// is treated as malformed input rather than silently ignored, since
/// dropping it would make a real corruption bug look like a pass.
fn parse_wave_flags(text : String, labels : Array[String]) -> Value? {
  strip(text, "{", "}").bind(fn(body) {
    let mut bits = 0UL
    if body != "" {
      for token in body.split(", ") {
        let token = token.to_owned()
        match labels.search(token) {
          Some(index) => bits = bits | (1UL << index)
          None => return None
        }
      }
    }
    Some(VFlags(labels~, bits~))
  })
}

///|
fn parse_wave_option(text : String, inner : Shape) -> Value? {
  if text == "none" {
    Some(VOption(None))
  } else {
    strip(text, "some(", ")").bind(fn(body) {
      parse(inner, body).bind(fn(v) { Some(VOption(Some(v))) })
    })
  }
}

///|
fn parse_wave_result(text : String, ok~ : Shape, err~ : Shape) -> Value? {
  match strip(text, "ok(", ")") {
    Some(body) => parse(ok, body).bind(fn(v) { Some(VResult(Ok(v))) })
    None =>
      strip(text, "err(", ")").bind(fn(body) {
        parse(err, body).bind(fn(v) { Some(VResult(Err(v))) })
      })
  }
}

///|
/// A record's fields may appear in any order and, per the WAVE grammar,
/// an `option`-typed field whose value is `none` may be omitted entirely
/// - which is in fact what `wasmtime` itself does on output (confirmed by
/// hand against `wasmtime` 48.0.2), so an omitted field is filled in as
/// `none` rather than treated as malformed. A field this shape doesn't
/// declare is rejected as unknown, and a non-optional field that's
/// missing is rejected as incomplete, rather than either being silently
/// accepted.
///
/// The special-cased `":"` body is WAVE's own disambiguation for the
/// all-fields-omitted case (`{:}`, distinct from `{}`, which means an
/// empty *flags* set) - not exercised by any fixture in `cases.mbt` today
/// (every record shape here has at least one non-optional field), but
/// handled so a record that could hit it later doesn't need this
/// function revisited.
fn parse_wave_record(
  text : String,
  field_shapes : Array[(String, Shape)],
) -> Value? {
  strip(text, "{", "}").bind(fn(body) {
    let present : Array[(String, Value)] = []
    let normalized = if body == ":" { "" } else { body }
    if normalized != "" {
      for entry_text in split_top_level(normalized, ',') {
        let entry_text = entry_text.trim(chars=" ").to_owned()
        match split_field_entry(entry_text) {
          None => return None
          Some((name, value_text)) =>
            match find_shape(field_shapes, name) {
              None => return None
              Some(field_shape) =>
                match parse(field_shape, value_text) {
                  None => return None
                  Some(value) => present.push((name, value))
                }
            }
        }
      }
    }
    let ordered : Array[(String, Value)] = []
    for entry in field_shapes {
      let (name, shape) = entry
      match find_field(present, name) {
        Some(value) => ordered.push((name, value))
        None =>
          match shape {
            ShOption(_) => ordered.push((name, VOption(None)))
            _ => return None
          }
      }
    }
    Some(VRecord(ordered))
  })
}

///|
fn find_shape(field_shapes : Array[(String, Shape)], name : String) -> Shape? {
  for entry in field_shapes {
    let (field_name, shape) = entry
    if field_name == name {
      return Some(shape)
    }
  }
  None
}

///|
/// Split one already-top-level-comma-separated record entry into its
/// field name and value text, at the first top-level `:` - always the
/// field-separating one, since a field name precedes any nested structure
/// in the entry and WIT identifiers never contain `:`.
fn split_field_entry(entry : String) -> (String, String)? {
  let parts = split_top_level(entry, ':')
  if parts.length() < 2 {
    None
  } else {
    let name = parts[0].trim(chars=" ").to_owned()
    let rest = parts[1:].join(":")
    Some((name, rest.trim(chars=" ").to_owned()))
  }
}

///|
/// Split `text` on every top-level occurrence of `sep` - one not inside a
/// `'...'`/`"..."` literal and not nested inside `(...)`/`{...}`/`[...]` -
/// so a comma or colon inside a record field's string value never gets
/// mistaken for a field separator.
fn split_top_level(text : String, sep : Char) -> Array[String] {
  let chars = text.to_array()
  let parts = []
  let mut depth = 0
  let mut in_string = false
  let mut in_char = false
  let mut current = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if !in_string && !in_char && c == sep && depth == 0 {
      parts.push(current.to_string())
      current = StringBuilder()
    } else {
      current.write_char(c)
      if in_string {
        if c == '\\' && i + 1 < chars.length() {
          i = i + 1
          current.write_char(chars[i])
        } else if c == '"' {
          in_string = false
        }
      } else if in_char {
        if c == '\\' && i + 1 < chars.length() {
          i = i + 1
          current.write_char(chars[i])
        } else if c == '\'' {
          in_char = false
        }
      } else if c == '"' {
        in_string = true
      } else if c == '\'' {
        in_char = true
      } else if c == '(' || c == '{' || c == '[' {
        depth = depth + 1
      } else if c == ')' || c == '}' || c == ']' {
        depth = depth - 1
      }
    }
    i = i + 1
  }
  parts.push(current.to_string())
  parts
}

///|
/// `text` with `prefix` and `suffix` removed, or `None` if `text` does
/// not have both.
fn strip(text : String, prefix : String, suffix : String) -> String? {
  if text.length() >= prefix.length() + suffix.length() &&
    text.has_prefix(prefix) &&
    text.has_suffix(suffix) {
    Some(text[prefix.length():text.length() - suffix.length()].to_owned())
  } else {
    None
  }
}

///|
/// Decode a char/string literal's body (the text between its delimiting
/// quotes) into the sequence of chars it denotes, applying the WAVE
/// escapes `escape` in wave.mbt produces. Returns `None` on a malformed
/// escape (a trailing lone backslash, an unknown escape letter, or an
/// unterminated `\u{...}`) rather than passing corrupted text through.
fn unescape(body : String) -> Array[Char]? {
  let chars = body.to_array()
  let out = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' {
      if i + 1 >= chars.length() {
        return None
      }
      match chars[i + 1] {
        '\\' => {
          out.push('\\')
          i = i + 2
        }
        '\'' => {
          out.push('\'')
          i = i + 2
        }
        '"' => {
          out.push('"')
          i = i + 2
        }
        'n' => {
          out.push('\n')
          i = i + 2
        }
        'r' => {
          out.push('\r')
          i = i + 2
        }
        't' => {
          out.push('\t')
          i = i + 2
        }
        'u' =>
          if i + 2 < chars.length() && chars[i + 2] == '{' {
            let mut j = i + 3
            let hex = StringBuilder()
            while j < chars.length() && chars[j] != '}' {
              hex.write_char(chars[j])
              j = j + 1
            }
            if j >= chars.length() {
              return None
            }
            match parse_unsigned_hex(hex.to_string()) {
              Some(code) => {
                out.push(Int::unsafe_to_char(code.reinterpret_as_int()))
                i = j + 1
              }
              None => return None
            }
          } else {
            return None
          }
        _ => return None
      }
    } else {
      out.push(chars[i])
      i = i + 1
    }
  }
  Some(out)
}

///|
fn parse_unsigned_hex(text : String) -> UInt? {
  Some(@string.parse_uint(text, base=16)) catch {
    _ => None
  }
}
