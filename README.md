# MoonPatch

MoonPatch is a portable MoonBit library and CLI for deterministic unified-diff
workflows. It parses and validates text patches, generates bounded LCS-based
patches, applies multi-file changes transactionally to an in-memory inventory,
and reverses patches without target-specific file APIs.

## Why

Code generators, offline updaters, review tools, and CI utilities often need to
exchange text changes without shelling out to `patch` or Git. MoonPatch gives
those tools a typed model, stable diagnostics, explicit resource limits, and the
same behavior on wasm-gc, wasm, JavaScript, and native MoonBit targets.

## Capabilities

- Parse and canonically serialize standard `---` / `+++` unified diffs.
- Validate hunk counts, ordering, paths, duplicate outputs, and newline markers.
- Generate deterministic single-hunk diffs with a configurable LCS cell limit.
- Apply modifications, creations, deletions, and path-changing text patches.
- Relocate hunks within an explicit offset window and reject ambiguous matches.
- Preserve LF/CRLF source style and final-newline state.
- Apply a patch set transactionally: failures never mutate the caller inventory.
- Reverse patches and report file, hunk, line, and operation statistics.

## Install and Build

Install the current [MoonBit toolchain](https://www.moonbitlang.com/download/),
then run:

```sh
moon update
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc
```

## CLI

CLI text arguments decode `\n`, `\r`, `\t`, and `\\`, which keeps examples
portable across shells. Run the complete generate/apply/reverse flow:

```sh
moon run cmd/moonpatch --target js -- demo
```

Inspect a patch:

```sh
moon run cmd/moonpatch --target js -- inspect --patch '--- a/note\n+++ b/note\n@@ -1 +1 @@\n-old\n+new\n'
```

Generate and apply a patch:

```sh
moon run cmd/moonpatch --target js -- diff --path note --old 'old\n' --new 'new\n'
moon run cmd/moonpatch --target js -- apply --path note --text 'old\n' --patch '--- a/note\n+++ b/note\n@@ -1 +1 @@\n-old\n+new\n'
```

Successful commands exit `0`; input, validation, and application failures exit
`2` with a stable diagnostic code.

## Library

```moonbit
let before = @moonpatch.TextFile::new("note.txt", "old\n")
let after = @moonpatch.TextFile::new("note.txt", "new\n")
let patch = @moonpatch.diff_file(before, after).unwrap()
let files = @moonpatch.FileInventory::new([before]).unwrap()
let applied = patch.apply(files).unwrap()
let restored = patch.reverse().apply(applied.inventory()).unwrap()
```

`pkg.generated.mbti` is the generated public interface. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the data flow and
[`docs/SUPPORT.md`](docs/SUPPORT.md) for exact format boundaries.

## Verification

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
```

The native commands require a C compiler. GitHub Actions runs every command and
checks the JavaScript and native CLI output against committed examples.

## Boundaries

MoonPatch intentionally does not write the filesystem, invoke Git, merge fuzzy
or ambiguous context, generate minimal multi-hunk diffs, or support binary
patches, mode changes, symbolic links, quoting, or Git extended headers. Inputs
are bounded to 16 MiB per parsed patch; diff generation defaults to 4,000,000
LCS cells. See the support document for all guarantees.

## License and Provenance

Licensed under MIT. Runtime code is original and uses MoonBit core plus
`moonbitlang/x` for the executable exit API. See `THIRD_PARTY.md` and
`AI_USAGE.md` for attribution and AI assistance disclosure.
