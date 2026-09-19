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
