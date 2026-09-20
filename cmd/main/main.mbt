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
      known_build_failure: Some({
        reason: "wit-bindgen-cli generates an extra closing parenthesis in the high-word accessor for flags with more than 32 members (wit-bindgen/wit-bindgen#1517-class defect); see README.md",
        // Both markers must show up in the build's own output for a
        // failure to count as *this* tracked issue - see the doc comment
        // on `fingerprint_matches`. Without this check, any unrelated
        // build failure (a moon version bump, a missing tool, a real new
        // bug) would be silently swallowed as "known, not fatal".
        fingerprint: ["ffi.mbt", "unexpected token `)`"],
      }),
    },
    {
      name: "option-u32",
      wit_file: "wit/option-u32.wit",
      world: "canon-option-u32",
      echo_pkg_dir: "gen/world/canon-option-u32",
      echo_impl: OPTION_U32_ECHO_IMPL,
      work_dir: ".canonfuzz-work/option-u32",
      cases: @canonfuzz.option_u32_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "result-u32-string",
      wit_file: "wit/result-u32-string.wit",
      world: "canon-result-u32-string",
      echo_pkg_dir: "gen/world/canon-result-u32-string",
      echo_impl: RESULT_U32_STRING_ECHO_IMPL,
      work_dir: ".canonfuzz-work/result-u32-string",
      cases: @canonfuzz.result_u32_string_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "record-point",
      wit_file: "wit/record-point.wit",
      world: "canon-record-point",
      echo_pkg_dir: "gen/world/canon-record-point",
      echo_impl: RECORD_POINT_ECHO_IMPL,
      work_dir: ".canonfuzz-work/record-point",
      cases: @canonfuzz.record_point_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "list-u32",
      wit_file: "wit/list-u32.wit",
      world: "canon-list-u32",
      echo_pkg_dir: "gen/world/canon-list-u32",
      echo_impl: LIST_U32_ECHO_IMPL,
      work_dir: ".canonfuzz-work/list-u32",
      cases: @canonfuzz.list_u32_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "variant-match-result",
      wit_file: "wit/variant-match-result.wit",
      world: "canon-variant-match-result",
      echo_pkg_dir: "gen/world/canon-variant-match-result",
      echo_impl: VARIANT_MATCH_RESULT_ECHO_IMPL,
      work_dir: ".canonfuzz-work/variant-match-result",
      cases: @canonfuzz.variant_match_result_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "list-point",
      wit_file: "wit/list-point.wit",
      world: "canon-list-point",
      echo_pkg_dir: "gen/world/canon-list-point",
      echo_impl: LIST_POINT_ECHO_IMPL,
      work_dir: ".canonfuzz-work/list-point",
      cases: @canonfuzz.list_point_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "option-result-u32-string",
      wit_file: "wit/option-result-u32-string.wit",
      world: "canon-option-result-u32-string",
      echo_pkg_dir: "gen/world/canon-option-result-u32-string",
      echo_impl: OPTION_RESULT_U32_STRING_ECHO_IMPL,
      work_dir: ".canonfuzz-work/option-result-u32-string",
      cases: @canonfuzz.option_result_u32_string_regression_suite(),
      known_build_failure: None,
    },
    {
      name: "record-shape-info",
      wit_file: "wit/record-shape-info.wit",
      world: "canon-record-shape-info",
      echo_pkg_dir: "gen/world/canon-record-shape-info",
      echo_impl: RECORD_SHAPE_INFO_ECHO_IMPL,
      work_dir: ".canonfuzz-work/record-shape-info",
      cases: @canonfuzz.record_shape_info_regression_suite(),
      known_build_failure: None,
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
  /// `Some(known)` if it is currently expected to fail to build, so that
  /// *that specific* failure does not fail the overall run - see
  /// `run_fixture` and `fingerprint_matches`.
  known_build_failure : KnownFailure?
}

///|
struct KnownFailure {
  reason : String
  /// Substrings that must *all* appear in the build's actual output for a
  /// failure to count as this tracked issue rather than something new.
  fingerprint : Array[String]
}

///|
/// Whether `output` looks like the specific failure `known` describes,
/// rather than some other failure that happens to occur while building
/// the same fixture. Requiring every fingerprint substring to appear
/// (rather than, say, just checking that the build failed at all) is what
/// stops an unrelated problem - a `moon` version bump, a missing tool, a
/// real new bug in the same fixture - from being silently swallowed as
/// "known, not fatal".
fn fingerprint_matches(output : String, known : KnownFailure) -> Bool {
  for marker in known.fingerprint {
    if !output.contains(marker) {
      return false
    }
  }
  true
}

///|
enum Outcome {
  Pass
  Trapped(String)
  /// `wasmtime`'s output was not even a valid rendering of the case's
  /// `shape` - not "a different value", but not a value this shape can
  /// represent at all.
  Unparseable(String)
  Mismatch(actual~ : @canonfuzz.Value, expected~ : @canonfuzz.Value)
}

///|
/// What happened to one fixture, structured rather than just printed -
/// this is what `--json` serializes, and what decides the process exit
/// status, so both read the same facts instead of the exit code and the
/// JSON report ever being able to silently disagree.
struct FixtureReport {
  name : String
  outcome : FixtureOutcome
}

///|
struct CaseRun {
  cases : Array[(String, Outcome)]
  passed : Int
  failed : Int
}

///|
enum FixtureOutcome {
  CodegenFailed(String)
  BuildFailed(String)
  ComponentizeFailed(String)
  /// A known build failure reproduced as tracked - not a problem.
  Xfail(String)
  /// A known build failure did *not* reproduce - the build succeeded, so
  /// its cases were run for real; see `run_fixture`.
  Xpass(CaseRun)
  Ran(CaseRun)
}

///|
/// Whether a fixture's outcome is one `cmd/main` should exit non-zero
/// for. `Xfail` alone is not a failure - that is the entire point of
/// tracking it - but an `Xpass` still needs every case to have actually
/// passed.
fn fixture_ok(outcome : FixtureOutcome) -> Bool {
  match outcome {
    CodegenFailed(_) => false
    BuildFailed(_) => false
    ComponentizeFailed(_) => false
    Xfail(_) => true
    Xpass(run) => run.failed == 0
    Ran(run) => run.failed == 0
  }
}

///|
async fn main {
  // `moon run cmd/main -- --json` (the `--` is moon's own separator);
  // JSON mode suppresses the running commentary so stdout is nothing but
  // the final report, and machine-readable exit status is the same
  // fixture_ok() check either way - the report and the exit code can
  // never disagree about what happened.
  let quiet = @env.args().contains("--json")
  let reports = []
  for fixture in fixtures() {
    reports.push(run_fixture(fixture, quiet~))
  }
  if quiet {
    println(report_to_json(reports).stringify(indent=2))
  }
  if reports.iter().any(fn(r) { !fixture_ok(r.outcome) }) {
    @abort.abort("canonfuzz: at least one fixture had an unexpected failure")
  }
}

///|
/// Run one fixture end to end and return what happened. `quiet` silences
/// the running commentary this always printed before `--json` existed
/// (see `main`); it never changes what is decided, only whether it is
/// also narrated as it happens.
async fn run_fixture(f : Fixture, quiet~ : Bool) -> FixtureReport {
  fn say(s : String) -> Unit {
    if !quiet {
      println(s)
    }
  }

  say("\n== " + f.name + " ==")
  if @fs.exists(f.work_dir) {
    // Remove any output left by a previous run (a different wit-bindgen
    // version, an edited fixture, ...) before regenerating, so stale
    // .mbt files from a since-changed layout can never get built
    // alongside fresh ones and contaminate the result.
    @fs.rmdir(f.work_dir, recursive=true)
  }
  @fs.mkdir(f.work_dir, recursive=true)
  say("canonfuzz: generating guest bindings for " + f.wit_file)
  let outcome = match run_wit_bindgen(f) {
    Some(reason) => {
      report_early_failure("codegen", reason, quiet~)
      CodegenFailed(reason)
    }
    None => {
      write_echo_impl(f)
      say("canonfuzz: building the guest component with moon")
      match (build_guest(f), f.known_build_failure) {
        (Some(actual), Some(known)) =>
          if fingerprint_matches(actual, known) {
            say(
              "canonfuzz: " +
              f.name +
              " build failed as expected (XFAIL, tracked, not a new problem)",
            )
            say("  tracked cause: " + known.reason)
            Xfail(known.reason)
          } else {
            say(
              "canonfuzz: " +
              f.name +
              " build failed, but NOT for the tracked reason (FAIL)",
            )
            say("  tracked cause was: " + known.reason)
            report_early_failure("build", actual, quiet~)
            BuildFailed(actual)
          }
        (Some(reason), None) => {
          report_early_failure("build", reason, quiet~)
          BuildFailed(reason)
        }
        (None, Some(known)) => {
          say("canonfuzz: " + f.name + " build UNEXPECTEDLY SUCCEEDED (XPASS)")
          say("  previously tracked as a known failure: " + known.reason)
          say(
            "  ALERT: update this fixture's known_build_failure in fixtures() - running its cases for real now",
          )
          match run_componentize_and_cases(f, quiet~) {
            ComponentizeFailed(reason) => ComponentizeFailed(reason)
            CasesRan(run) => Xpass(run)
          }
        }
        (None, None) =>
          match run_componentize_and_cases(f, quiet~) {
            ComponentizeFailed(reason) => ComponentizeFailed(reason)
            CasesRan(run) => Ran(run)
          }
      }
    }
  }
  { name: f.name, outcome, }
}

///|
/// The two things that can come out of turning a built core module into
/// a running, tested component: either `wasm-tools` itself failed (a
/// distinct outcome, not zero cases run and zero cases failed - the
/// difference between "nothing to report" and "something is wrong" would
/// otherwise be lost, and `fixture_ok` would wrongly treat an empty
/// `CaseRun` as a pass), or it succeeded and every case actually ran.
enum ComponentizeResult {
  ComponentizeFailed(String)
  CasesRan(CaseRun)
}

///|
async fn run_componentize_and_cases(
  f : Fixture,
  quiet~ : Bool,
) -> ComponentizeResult {
  fn say(s : String) -> Unit {
    if !quiet {
      println(s)
    }
  }

  say("canonfuzz: turning the core module into a component with wasm-tools")
  match componentize(f) {
    Some(reason) => {
      report_early_failure("componentize", reason, quiet~)
      ComponentizeFailed(reason)
    }
    None => {
      say("canonfuzz: running the regression suite against the component\n")
      let mut passed = 0
      let mut failed = 0
      let cases = []
      for case in f.cases {
        let outcome = run_case(f, case)
        cases.push((case.name, outcome))
        match outcome {
          Pass => {
            passed = passed + 1
            say("  pass  " + case.name)
          }
          _ => {
            failed = failed + 1
            say("  FAIL  " + case.name + "  (" + case.note + ")")
            say("        " + describe(outcome))
          }
        }
      }
      say(
        "\n" +
        passed.to_string() +
        " passed, " +
        failed.to_string() +
        " failed, " +
        f.cases.length().to_string() +
        " total",
      )
      CasesRan({ cases, passed, failed, })
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
const OPTION_U32_ECHO_IMPL =
  #|///|
  #|pub fn echo_option_u32(v : UInt?) -> UInt? { v }
  #|

///|
const RESULT_U32_STRING_ECHO_IMPL =
  #|///|
  #|pub fn echo_result(v : Result[UInt, String]) -> Result[UInt, String] { v }
  #|

///|
const RECORD_POINT_ECHO_IMPL =
  #|///|
  #|pub fn echo_point(
  #|  v : @canon-record-point.Point,
  #|) -> @canon-record-point.Point {
  #|  v
  #|}
  #|

///|
const LIST_U32_ECHO_IMPL =
  #|///|
  #|pub fn echo_list_u32(v : FixedArray[UInt]) -> FixedArray[UInt] { v }
  #|

///|
const VARIANT_MATCH_RESULT_ECHO_IMPL =
  #|///|
  #|pub fn echo_match_result(
  #|  v : @canon-variant-match-result.MatchResult,
  #|) -> @canon-variant-match-result.MatchResult {
  #|  v
  #|}
  #|

///|
const LIST_POINT_ECHO_IMPL =
  #|///|
  #|pub fn echo_list_point(
  #|  v : Array[@canon-list-point.Point],
  #|) -> Array[@canon-list-point.Point] {
  #|  v
  #|}
  #|

///|
const OPTION_RESULT_U32_STRING_ECHO_IMPL =
  #|///|
  #|pub fn echo_option_result(
  #|  v : Result[UInt, String]?,
  #|) -> Result[UInt, String]? {
  #|  v
  #|}
  #|

///|
const RECORD_SHAPE_INFO_ECHO_IMPL =
  #|///|
  #|pub fn echo_shape_info(
  #|  v : @canon-record-shape-info.ShapeInfo,
  #|) -> @canon-record-shape-info.ShapeInfo {
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
/// package is tested against, and the raw text `wasmtime` prints back is
/// parsed with `case.shape` and compared to `case.expect` via `same()` -
/// structurally, not as text - so a difference WAVE's grammar does not
/// actually distinguish (whitespace, an equally-valid float spelling, and
/// once records exist, field order) can never register as a false
/// mismatch. `canonfuzz_test.mbt` checks the round trip this depends on
/// (`parse(shape, render(expect))` recovers `expect`) independently of
/// any component.
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
  let actual_text = out.text().trim().to_owned()
  match @canonfuzz.parse(case.shape, actual_text) {
    None => Unparseable(actual_text)
    Some(actual) =>
      if @canonfuzz.same(actual, case.expect) {
        Pass
      } else {
        Mismatch(actual~, expected=case.expect)
      }
  }
}

///|
fn describe(outcome : Outcome) -> String {
  match outcome {
    Pass => "pass"
    Trapped(reason) => "trapped: " + reason
    Unparseable(text) =>
      "wasmtime printed something that isn't a valid value of the expected shape: " +
      text
    Mismatch(actual~, expected~) =>
      "expected " +
      @canonfuzz.render(expected) +
      ", got " +
      @canonfuzz.render(actual)
  }
}

///|
fn report_early_failure(stage : String, reason : String, quiet~ : Bool) -> Unit {
  if !quiet {
    println("canonfuzz: " + stage + " failed, no cases were run\n")
    println(reason)
  }
}

///|
/// The `--json` report: one object per fixture, each carrying enough to
/// reconstruct exactly what the human-readable commentary would have
/// said, plus the same `ok` a caller would get from the process exit
/// code - both computed from the same `FixtureOutcome`, so a consumer
/// parsing this never needs to also inspect the exit code to know what
/// happened.
fn report_to_json(reports : Array[FixtureReport]) -> Json {
  let ok = reports.iter().all(fn(r) { fixture_ok(r.outcome) })
  Json::object(
    Map::from_array([
      ("ok", Json::boolean(ok)),
      ("fixtures", Json::array(reports.map(fn(r) { fixture_to_json(r) }))),
    ]),
  )
}

///|
fn fixture_to_json(r : FixtureReport) -> Json {
  let fields : Array[(String, Json)] = [("name", Json::string(r.name))]
  let fields = match r.outcome {
    CodegenFailed(reason) =>
      fields +
      [
        ("status", Json::string("codegen-failed")),
        ("reason", Json::string(reason)),
      ]
    BuildFailed(reason) =>
      fields +
      [
        ("status", Json::string("build-failed")),
        ("reason", Json::string(reason)),
      ]
    ComponentizeFailed(reason) =>
      fields +
      [
        ("status", Json::string("componentize-failed")),
        ("reason", Json::string(reason)),
      ]
    Xfail(reason) =>
      fields +
      [("status", Json::string("xfail")), ("reason", Json::string(reason))]
    Xpass(run) =>
      fields + [("status", Json::string("xpass"))] + case_run_to_json(run)
    Ran(run) =>
      fields + [("status", Json::string("pass"))] + case_run_to_json(run)
  }
  Json::object(Map::from_array(fields))
}

///|
fn case_run_to_json(run : CaseRun) -> Array[(String, Json)] {
  [
    ("passed", Json::number(run.passed.to_double())),
    ("failed", Json::number(run.failed.to_double())),
    (
      "cases",
      Json::array(run.cases.map(fn(entry) { case_to_json(entry.0, entry.1) })),
    ),
  ]
}

///|
fn case_to_json(name : String, outcome : Outcome) -> Json {
  let base : Array[(String, Json)] = [("name", Json::string(name))]
  let fields = match outcome {
    Pass => base + [("outcome", Json::string("pass"))]
    Trapped(detail) =>
      base +
      [("outcome", Json::string("trapped")), ("detail", Json::string(detail))]
    Unparseable(detail) =>
      base +
      [
        ("outcome", Json::string("unparseable")),
        ("detail", Json::string(detail)),
      ]
    Mismatch(actual~, expected~) =>
      base +
      [
        ("outcome", Json::string("mismatch")),
        ("expected", Json::string(@canonfuzz.render(expected))),
        ("actual", Json::string(@canonfuzz.render(actual))),
      ]
  }
  Json::object(Map::from_array(fields))
}
