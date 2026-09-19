///|
/// Every rendered case's input and expected value must actually be equal
/// under `same()` - otherwise the corpus itself would report a pass/fail
/// pair that can never agree, which would make the whole suite useless
/// regardless of what a component returns.
test "regression suite entries are internally consistent" {
  for case in scalar_regression_suite() {
    assert_true(same(case.input, case.expect))
  }
}

///|
/// Case names must be unique: `cmd/main` uses the name to report failures,
/// and a duplicate would make a failure report ambiguous about which case
/// actually failed.
test "regression suite case names are unique" {
  let seen : Map[String, Bool] = Map([])
  for case in scalar_regression_suite() {
    assert_false(seen.contains(case.name))
    seen[case.name] = true
  }
}
