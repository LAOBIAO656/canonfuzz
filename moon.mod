// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "LAOBIAO656/canonfuzz"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/LAOBIAO656/canonfuzz"

license = "Apache-2.0"

keywords = [
  "webassembly",
  "wasm",
  "component-model",
  "wit-bindgen",
  "testing",
]

preferred_target = "wasm"

description = "ABI regression testing and minimal reproduction for MoonBit WebAssembly components"

import {
  "moonbitlang/async@0.22.1",
}
