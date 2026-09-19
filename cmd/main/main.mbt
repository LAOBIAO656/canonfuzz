///|
/// canonfuzz's driver: for each fixture (currently only `wit/scalars.wit`),
/// generate real MoonBit guest bindings with `wit-bindgen`, build them with
/// `moon`, turn the result into a component with `wasm-tools`, then invoke
/// every case in the fixture's regression corpus through `wasmtime run
/// --invoke` and compare what comes back to what was sent in.
///
/// This package requires `wit-bindgen`, `wasm-tools` and `wasmtime` on
/// `PATH`, and only builds on the `native` target. `moonbitlang/async`'s
/// process support is exercised in CI on Linux and macOS; it has not been
/// run on Windows as part of this project, so Windows is not currently a
/// supported environment for this package - see README.md.
///
/// This first capability covers the scalar fixture only. It does not yet
/// generate values on its own: the corpus in `cases.mbt` is a fixed,
/// version-controlled list, so a run is reproducible byte-for-byte and a
/// failure is already a minimal, named reproduction rather than something
/// that still needs shrinking.
const WORK_DIR = ".canonfuzz-work/scalars"

///|
enum Outcome {
  Pass
  Trapped(String)
  Mismatch(actual~ : String, expected~ : String)
}

///|
async fn main {
  @fs.mkdir(WORK_DIR, recursive=true)
  println("canonfuzz: generating guest bindings for wit/scalars.wit")
  match run_wit_bindgen() {
    Some(reason) => {
      report_early_failure("codegen", reason)
      @abort.abort("canonfuzz: codegen failed, no cases were run")
    }
    None => ()
  }
  write_echo_impl()
  println("canonfuzz: building the guest component with moon")
  match build_guest() {
    Some(reason) => {
      report_early_failure("build", reason)
      @abort.abort("canonfuzz: build failed, no cases were run")
    }
    None => ()
  }
  println("canonfuzz: turning the core module into a component with wasm-tools")
  match componentize() {
    Some(reason) => {
      report_early_failure("componentize", reason)
      @abort.abort("canonfuzz: componentize failed, no cases were run")
    }
    None => ()
  }
  println("canonfuzz: running the regression suite against the component\n")
  let cases = @canonfuzz.scalar_regression_suite()
  let mut passed = 0
  let mut failed = 0
  for case in cases {
    let outcome = run_case(case)
    match outcome {
      Pass => {
        passed = passed + 1
        println("  pass  " + case.name)
      }
      _ => {
        failed = failed + 1
        println("  FAIL  " + case.name + "  (" + case.note + ")")
        println("        " + describe(outcome))
      }
    }
  }
  println(
    "\n" +
    passed.to_string() +
    " passed, " +
    failed.to_string() +
    " failed, " +
    cases.length().to_string() +
    " total",
  )
  if failed > 0 {
    @abort.abort("canonfuzz: " + failed.to_string() + " case(s) failed")
  }
}

///|
/// Run `wit-bindgen` to (re)generate the guest bindings into `WORK_DIR`.
/// Returns `None` on success, or `Some(output)` with the tool's combined
/// stdout/stderr on failure.
async fn run_wit_bindgen() -> String? {
  let (code, out) = @process.collect_output_merged("wit-bindgen", [
    "moonbit",
    "wit/scalars.wit",
    "--out-dir",
    WORK_DIR,
  ])
  if code == 0 {
    None
  } else {
    Some(out.text())
  }
}

///|
/// The scalar fixture's implementation of every exported `echo-*` function
/// is the identity function - the guest logic is deliberately trivial so
/// that a wrong result can only come from `wit-bindgen`'s generated
/// lifting/lowering code, not from anything canonfuzz itself computes.
const ECHO_IMPL =
  #|///|
  #|pub fn echo_bool(v : Bool) -> Bool { v }
  #|
  #|///|
  #|pub fn echo_s8(v : Int) -> Int { v }
  #|
  #|///|
  #|pub fn echo_s16(v : Int) -> Int { v }
  #|
  #|///|
  #|pub fn echo_s32(v : Int) -> Int { v }
  #|
  #|///|
  #|pub fn echo_s64(v : Int64) -> Int64 { v }
  #|
  #|///|
  #|pub fn echo_u8(v : Byte) -> Byte { v }
  #|
  #|///|
  #|pub fn echo_u16(v : UInt) -> UInt { v }
  #|
  #|///|
  #|pub fn echo_u32(v : UInt) -> UInt { v }
  #|
  #|///|
  #|pub fn echo_u64(v : UInt64) -> UInt64 { v }
  #|
  #|///|
  #|pub fn echo_f32(v : Float) -> Float { v }
  #|
  #|///|
  #|pub fn echo_f64(v : Double) -> Double { v }
  #|
  #|///|
  #|pub fn echo_char(v : Char) -> Char { v }
  #|

///|
async fn write_echo_impl() -> Unit {
  @fs.write_file(WORK_DIR + "/gen/world/canon-scalars/echo_impl.mbt", ECHO_IMPL)
}

///|
/// Build the guest module for the `wasm` target in release mode (matching
/// the profile `wit-bindgen`'s own MoonBit test harness builds with) and
/// leave debug info in place, since a build failure's value is in what it
/// says, not in binary size.
async fn build_guest() -> String? {
  let (code, out) = @process.collect_output_merged(
    "moon",
    ["build", "--target", "wasm", "--release", "--no-strip"],
    cwd=WORK_DIR,
  )
  if code == 0 {
    None
  } else {
    Some(out.text())
  }
}

///|
fn artifact_path() -> String {
  WORK_DIR + "/_build/wasm/release/build/gen/gen.wasm"
}

///|
fn component_path() -> String {
  WORK_DIR + "/component.wasm"
}

///|
/// Embed the WIT world into the core module and turn it into a component.
/// Both steps use `wasm-tools`, matching the workflow MoonBit's own
/// component-model documentation describes:
/// https://www.moonbitlang.com/blog/component-model
async fn componentize() -> String? {
  let artifact = artifact_path()
  let (embed_code, embed_out) = @process.collect_output_merged("wasm-tools", [
    "component", "embed", "wit/scalars.wit", "--world", "canon-scalars", "-o", artifact,
    artifact, "--encoding", "utf16",
  ])
  if embed_code != 0 {
    return Some(embed_out.text())
  }
  let (new_code, new_out) = @process.collect_output_merged("wasm-tools", [
    "component",
    "new",
    artifact,
    "-o",
    component_path(),
  ])
  if new_code != 0 {
    Some(new_out.text())
  } else {
    None
  }
}

///|
/// Run one case through `wasmtime run --invoke` and classify the result.
/// The input is rendered to WAVE text with the same `render()` the core
/// package is tested against, and the expected output is rendered the same
/// way, so the comparison never depends on `wasmtime`'s own formatting
/// matching canonfuzz's byte-for-byte - only on the two renderings of
/// equal `Value`s agreeing, which `canonfuzz_wbtest.mbt` already checks
/// independently of any component.
async fn run_case(case : @canonfuzz.Case) -> Outcome {
  let invoke = case.function + "(" + @canonfuzz.render(case.input) + ")"
  let (code, out) = @process.collect_output_merged("wasmtime", [
    "run",
    "--invoke",
    invoke,
    component_path(),
  ])
  if code != 0 {
    return Trapped(out.text().trim().to_owned())
  }
  let actual = out.text().trim().to_owned()
  let expected = @canonfuzz.render(case.expect)
  if actual == expected {
    Pass
  } else {
    Mismatch(actual~, expected~)
  }
}

///|
fn describe(outcome : Outcome) -> String {
  match outcome {
    Pass => "pass"
    Trapped(reason) => "trapped: " + reason
    Mismatch(actual~, expected~) => "expected " + expected + ", got " + actual
  }
}

///|
fn report_early_failure(stage : String, reason : String) -> Unit {
  println("canonfuzz: " + stage + " failed, no cases were run\n")
  println(reason)
}
