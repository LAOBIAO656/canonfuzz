///|
/// `fingerprint_matches` is the whole reason a known-failure fixture
/// doesn't just silently accept any build failure - so it gets its own
/// test rather than only being exercised end to end through a real
/// `wit-bindgen` run. All three cases here are the ones `run_fixture`
/// actually branches on.
test "fingerprint_matches requires every marker present" {
  let known = KnownFailure::{
    reason: "extra paren in the flags high-word accessor",
    fingerprint: ["ffi.mbt", "unexpected token `)`"],
  }

  // The real error text captured from wit-bindgen-cli 0.62.0 building
  // wit/wide-flags.wit - this must match, or the tracked issue would
  // never register as XFAIL at all.
  let real_error =
    #|Error: [3002]
    #|    |-[ ...\gen\world\canon-wide-flags\ffi.mbt:11:64 ]
    #|    |
    #| 11 |       mbt_ffi_store32((return_area) + 4, (flag >> 32).to_int()))
    #|    |
    #|    `-- Parse error, unexpected token `)`, you may expect a statement or expression on a new line, or `}` to close the block.
    #|Failed with 0 warnings, 1 errors.
  assert_true(fingerprint_matches(real_error, known))

  // A failure that touches the same file but for an unrelated reason
  // (missing a comma, say) must NOT match - only one of the two markers
  // is present, and a partial match is exactly what would let an
  // unrelated regression hide behind this fixture's tracked one.
  let different_error_same_file =
    #|Error: [3002]
    #|    |-[ ...\gen\world\canon-wide-flags\ffi.mbt:40:1 ]
    #|    `-- Parse error, expected a comma
  assert_false(fingerprint_matches(different_error_same_file, known))

  // A failure with nothing in common at all (e.g. the toolchain itself
  // missing) must also not match.
  let unrelated_error = "moon: command not found"
  assert_false(fingerprint_matches(unrelated_error, known))
}

///|
/// `fixture_ok` must treat every non-`Xfail` failure outcome as a
/// failure, including `ComponentizeFailed` - which, before this test and
/// the fix alongside it, was never actually produced: a `wasm-tools`
/// failure was folded into an empty `CaseRun` (0 passed, 0 failed), and
/// `fixture_ok` read that as a pass. This test exists specifically so
/// that regression can't come back silently.
test "fixture_ok treats every failure outcome as a failure" {
  assert_false(fixture_ok(CodegenFailed("boom")))
  assert_false(fixture_ok(BuildFailed("boom")))
  assert_false(fixture_ok(ComponentizeFailed("boom")))
  assert_true(fixture_ok(Xfail("tracked")))
}

///|
/// An `Xpass`/`Ran` outcome is only "ok" if every case in it actually
/// passed - a nonempty `CaseRun` with `failed > 0` must not be read as
/// success just because the fixture's build succeeded.
test "fixture_ok checks the case run's failed count, not just its shape" {
  assert_true(fixture_ok(Ran({ cases: [], passed: 3, failed: 0, })))
  assert_false(fixture_ok(Ran({ cases: [], passed: 2, failed: 1, })))
  assert_true(fixture_ok(Xpass({ cases: [], passed: 3, failed: 0, })))
  assert_false(fixture_ok(Xpass({ cases: [], passed: 2, failed: 1, })))
}

///|
/// The JSON report's top-level `ok` must agree with what `fixture_ok`
/// would say about each fixture - the whole point of computing both from
/// the same `FixtureOutcome` (see the doc comment on `report_to_json`)
/// is that a consumer never needs to cross-check the exit code against
/// the JSON to know what happened.
test "report_to_json's ok field agrees with fixture_ok" {
  let all_pass = [
    { name: "a", outcome: Ran({ cases: [], passed: 1, failed: 0, }), },
    { name: "b", outcome: Xfail("tracked"), },
  ]
  assert_true(
    match report_to_json(all_pass) {
      Object(fields) => fields.get("ok") is Some(True)
      _ => false
    },
  )
  let one_fails = [
    { name: "a", outcome: Ran({ cases: [], passed: 1, failed: 0, }), },
    { name: "b", outcome: ComponentizeFailed("boom"), },
  ]
  assert_true(
    match report_to_json(one_fails) {
      Object(fields) => fields.get("ok") is Some(False)
      _ => false
    },
  )
}

///|
/// `case_to_json` must actually include the diagnostic detail for a
/// non-pass outcome, not just the outcome's name - the whole reason
/// `--json` exists is so a consumer can act on *why* a case failed
/// without re-parsing console text.
test "case_to_json includes diagnostic detail for non-pass outcomes" {
  assert_true(
    match case_to_json("c", Trapped("oops")) {
      Object(fields) =>
        fields.get("outcome") is Some(String("trapped")) &&
        fields.get("detail") is Some(String("oops"))
      _ => false
    },
  )
  // Value isn't constructible from outside LAOBIAO656/canonfuzz (only
  // pattern-matchable), so this borrows two real, distinct values from
  // the scalar suite by name rather than constructing its own or
  // depending on the suite's array order.
  fn expect_of(name : String) -> @canonfuzz.Value {
    let suite = @canonfuzz.scalar_regression_suite()
    let index = suite.search_by(fn(case) { case.name == name }).unwrap()
    suite[index].expect
  }

  let u8_max = expect_of("u8-max")
  let u16_max = expect_of("u16-max")
  assert_true(
    match case_to_json("c", Mismatch(actual=u8_max, expected=u16_max)) {
      Object(fields) =>
        fields.get("expected") is Some(String(text)) &&
        text == @canonfuzz.render(u16_max) &&
        fields.get("actual") is Some(String(text2)) &&
        text2 == @canonfuzz.render(u8_max)
      _ => false
    },
  )
}
