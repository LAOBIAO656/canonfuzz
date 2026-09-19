///|
/// canonfuzz is an end-to-end ABI regression testing and minimal
/// reproduction tool for MoonBit WebAssembly components.
///
/// This package holds the toolchain-independent core: the [Value]
/// vocabulary, its WAVE text rendering, and the fixed regression corpus in
/// `cases.mbt`. It has no dependency on any external tool and builds on
/// every MoonBit target. The part of the project that actually drives
/// `wit-bindgen`, `moon`, `wasm-tools` and `wasmtime` to run these cases
/// against a real component lives in `cmd/main`, which is native-only.
