///|
/// canonfuzz's driver: for each fixture below, generate real MoonBit guest
/// bindings with `wit-bindgen`, build them with `moon`, turn the result
/// into a component with `wasm-tools`, then invoke every case in the
/// fixture's regression corpus through `wasmtime run --invoke` and compare
/// what comes back to what was sent in.
///
/// This package requires `wit-bindgen`, `wasm-tools` and `wasmtime` on
/// `PATH`, and only builds on the `native` target. `moonbitlang/async`'s
/// process support is exercised in CI on Linux and macOS; it has not been
/// run on Windows as part of this project, so Windows is not currently a
/// supported environment for this package - see README.md.
///
/// Neither fixture generates values on its own: each corpus in `cases.mbt`
/// is a fixed, version-controlled list, so a run is reproducible
/// byte-for-byte and a failure is already a minimal, named reproduction
/// rather than something that still needs shrinking.
fn fixtures() -> Array[Fixture] {
  [
    {
      name: "scalars",
      wit_file: "wit/scalars.wit",
      world: "canon-scalars",
      echo_pkg_dir: "gen/world/canon-scalars",
      echo_impl: SCALARS_ECHO_IMPL,
      work_dir: ".canonfuzz-work/scalars",
      cases: @canonfuzz.scalar_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "wide-flags",
      wit_file: "wit/wide-flags.wit",
      world: "canon-wide-flags",
      echo_pkg_dir: "gen/world/canon-wide-flags",
      echo_impl: WIDE_FLAGS_ECHO_IMPL,
      work_dir: ".canonfuzz-work/wide-flags",
      cases: @canonfuzz.wide_flags_regression_suite(),
      known_build_failure: Some(
        "wit-bindgen-cli generates an extra closing parenthesis in the high-word accessor for flags with more than 32 members (wit-bindgen/wit-bindgen#1517-class defect); see README.md",
      ),
    },
  ]
}

///|
struct Fixture {
  name : String
  wit_file : String
  world : String
  echo_pkg_dir : String
  echo_impl : String
  work_dir : String
  cases : Array[@canonfuzz.Case]
  /// `None` if this fixture is expected to build and pass outright.
  /// `Some(reason)` if it is currently expected to fail to build, so that
  /// expected failure does not fail the overall run - see `run_fixture`.
  known_build_failure : String?
}

///|
enum Outcome {
  Pass
  Trapped(String)
  Mismatch(actual~ : String, expected~ : String)
}

///|
async fn main {
  let mut any_unexpected_failure = false
  for fixture in fixtures() {
    let ok = run_fixture(fixture)
    if !ok {
      any_unexpected_failure = true
    }
  }
  if any_unexpected_failure {
    @abort.abort("canonfuzz: at least one fixture had an unexpected failure")
  }
}

///|
/// Run one fixture end to end. Returns `true` if the fixture's outcome
/// matched what was expected of it (all cases passed, or a known build
/// failure reproduced as tracked), `false` if something needs attention.
///
/// A fixture whose build is expected to fail and does not fail is not
/// treated as an error: its cases are run for real instead, since the
/// underlying defect may have just been fixed upstream.
async fn run_fixture(f : Fixture) -> Bool {
  println("\n== " + f.name + " ==")
  @fs.mkdir(f.work_dir, recursive=true)
  println("canonfuzz: generating guest bindings for " + f.wit_file)
  match run_wit_bindgen(f) {
    Some(reason) => {
      report_early_failure("codegen", reason)
      false
    }
    None => {
      write_echo_impl(f)
      println("canonfuzz: building the guest component with moon")
      match (build_guest(f), f.known_build_failure) {
        (Some(_), Some(known_reason)) => {
          println(
            "canonfuzz: " +
            f.name +
            " build failed as expected (tracked, not a new problem)",
          )
          println("  tracked cause: " + known_reason)
          true
        }
        (Some(reason), None) => {
          report_early_failure("build", reason)
          false
        }
        (None, Some(known_reason)) => {
          println("canonfuzz: " + f.name + " build UNEXPECTEDLY SUCCEEDED")
          println("  previously tracked as a known failure: " + known_reason)
          println(
            "  running its cases for real - if they all pass, the tracked issue can likely be closed",
          )
          run_componentize_and_cases(f)
        }
        (None, None) => run_componentize_and_cases(f)
      }
    }
  }
}

///|
async fn run_componentize_and_cases(f : Fixture) -> Bool {
  println("canonfuzz: turning the core module into a component with wasm-tools")
  match componentize(f) {
    Some(reason) => {
      report_early_failure("componentize", reason)
      false
    }
    None => {
      println("canonfuzz: running the regression suite against the component\n")
      let mut passed = 0
      let mut failed = 0
      for case in f.cases {
        let outcome = run_case(f, case)
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
        f.cases.length().to_string() +
        " total",
      )
      failed == 0
    }
  }
}

///|
/// Run `wit-bindgen` to (re)generate a fixture's guest bindings. Returns
/// `None` on success, or `Some(output)` with the tool's combined
/// stdout/stderr on failure.
async fn run_wit_bindgen(f : Fixture) -> String? {
  let (code, out) = @process.collect_output_merged("wit-bindgen", [
    "moonbit",
    f.wit_file,
    "--out-dir",
    f.work_dir,
  ])
  if code == 0 {
    None
  } else {
    Some(out.text())
  }
}

///|
/// Every exported `echo-*` function in every fixture is implemented as the
/// identity function - the guest logic is deliberately trivial so that a
/// wrong result can only come from `wit-bindgen`'s generated
/// lifting/lowering code, not from anything canonfuzz itself computes.
const SCALARS_ECHO_IMPL =
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
const WIDE_FLAGS_ECHO_IMPL =
  #|///|
  #|pub fn echo_wide_flags(
  #|  v : @canon-wide-flags.WideFlags,
  #|) -> @canon-wide-flags.WideFlags {
  #|  v
  #|}
  #|

///|
async fn write_echo_impl(f : Fixture) -> Unit {
  @fs.write_file(
    f.work_dir + "/" + f.echo_pkg_dir + "/echo_impl.mbt",
    f.echo_impl,
  )
}

///|
/// Build the guest module for the `wasm` target in release mode (matching
/// the profile `wit-bindgen`'s own MoonBit test harness builds with) and
/// leave debug info in place, since a build failure's value is in what it
/// says, not in binary size.
async fn build_guest(f : Fixture) -> String? {
  let (code, out) = @process.collect_output_merged(
    "moon",
    ["build", "--target", "wasm", "--release", "--no-strip"],
    cwd=f.work_dir,
  )
  if code == 0 {
    None
  } else {
    Some(out.text())
  }
}

///|
fn artifact_path(f : Fixture) -> String {
  f.work_dir + "/_build/wasm/release/build/gen/gen.wasm"
}

///|
fn component_path(f : Fixture) -> String {
  f.work_dir + "/component.wasm"
}

///|
/// Embed the WIT world into the core module and turn it into a component.
/// Both steps use `wasm-tools`, matching the workflow MoonBit's own
/// component-model documentation describes:
/// https://www.moonbitlang.com/blog/component-model
async fn componentize(f : Fixture) -> String? {
  let artifact = artifact_path(f)
  let (embed_code, embed_out) = @process.collect_output_merged("wasm-tools", [
    "component",
    "embed",
    f.wit_file,
    "--world",
    f.world,
    "-o",
    artifact,
    artifact,
    "--encoding",
    "utf16",
  ])
  if embed_code != 0 {
    return Some(embed_out.text())
  }
  let (new_code, new_out) = @process.collect_output_merged("wasm-tools", [
    "component",
    "new",
    artifact,
    "-o",
    component_path(f),
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
async fn run_case(f : Fixture, case : @canonfuzz.Case) -> Outcome {
  let invoke = case.function + "(" + @canonfuzz.render(case.input) + ")"
  let (code, out) = @process.collect_output_merged("wasmtime", [
    "run",
    "--invoke",
    invoke,
    component_path(f),
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
