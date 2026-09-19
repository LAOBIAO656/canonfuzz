///|
/// Every rendered case's input and expected value must actually be equal
/// under `same()` - otherwise the corpus itself would report a pass/fail
/// pair that can never agree, which would make the whole suite useless
/// regardless of what a component returns.
test "regression suite entries are internally consistent" {
  for case in all_regression_suites() {
    assert_true(same(case.input, case.expect))
  }
}

///|
/// Case names must be unique across every suite `cmd/main` can run:
/// `cmd/main` uses the name to report failures, and a duplicate would make
/// a failure report ambiguous about which case actually failed, whether
/// the clash is within one suite or between two of them.
test "regression suite case names are unique" {
  let seen : Map[String, Bool] = Map([])
  for case in all_regression_suites() {
    assert_false(seen.contains(case.name))
    seen[case.name] = true
  }
}

///|
/// The flags suite's cases must all name the same 36 labels declared by
/// `wit/wide-flags.wit` - a case built against a different label list
/// would render bit positions that don't match the fixture it is meant to
/// test.
test "wide flags cases all use the declared label list" {
  let labels = wide_flags_labels()
  assert_eq(labels.length(), 36)
  for case in wide_flags_regression_suite() {
    match case.input {
      VFlags(labels=case_labels, ..) => assert_eq(case_labels, labels)
      _ => fail("case " + case.name + " is not a VFlags value")
    }
  }
}

///|
/// The round-trip property `cmd/main` actually depends on: rendering a
/// case's expected value and parsing that text back with the case's own
/// `shape` must recover an equal value. This is the property that lets
/// `run_case` compare structurally instead of as raw text (see README,
/// "the comparator's ordering limit") - if it failed for any case here,
/// that case's `shape` would already disagree with its own `expect`, and
/// every real component run would misreport a correct answer as a
/// mismatch regardless of what `wasmtime` actually returned.
test "parsing a case's own rendering recovers the expected value" {
  for case in all_regression_suites() {
    let text = render(case.expect)
    match parse(case.shape, text) {
      Some(recovered) =>
        if !same(recovered, case.expect) {
          fail(
            "case " +
            case.name +
            ": parse(shape, \"" +
            text +
            "\") recovered a different value than expect",
          )
        }
      None =>
        fail(
          "case " +
          case.name +
          ": parse(shape, ...) rejected \"" +
          text +
          "\", its own expect rendered",
        )
    }
  }
}
