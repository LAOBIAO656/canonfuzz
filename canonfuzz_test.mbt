///|
/// Every rendered case's input and expected value must actually be equal
/// under `same()` - otherwise the corpus itself would report a pass/fail
/// pair that can never agree, which would make the whole suite useless
/// regardless of what a component returns.
test "regression suite entries are internally consistent" {
  for case in scalar_regression_suite() {
    assert_true(same(case.input, case.expect))
  }
  for case in wide_flags_regression_suite() {
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
  for case in scalar_regression_suite() {
    assert_false(seen.contains(case.name))
    seen[case.name] = true
  }
  for case in wide_flags_regression_suite() {
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
