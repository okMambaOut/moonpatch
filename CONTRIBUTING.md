# Contributing

Use a current MoonBit toolchain and keep changes focused on documented unified
text-patch behavior. Before opening a change, run:

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target wasm
moon test --target js
```

Add positive and negative tests for behavior changes. New syntax must define
canonical serialization, failure diagnostics, limits, and reverse behavior.
Do not add filesystem writes to the core package or weaken path/context checks.

