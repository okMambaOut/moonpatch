# Architecture

MoonPatch is a pure text transformation engine. The CLI is a thin adapter over
the same public library exercised by tests.

```text
unified diff -> parser -> PatchSet -> structural validation
                                  -> stats / canonical serialization / reverse
old text + new text -> bounded LCS generator -----------^

PatchSet + FileInventory -> path preflight -> per-hunk unique context match
                         -> staged replacements -> sorted ApplyReport
```

## Model

`PatchSet` contains ordered `FilePatch` values; each file contains ordered
`Hunk` values and typed context/addition/deletion lines. File paths are relative,
forward-slash paths or `/dev/null` on exactly one side. `FileInventory` is an
immutable caller-facing value backed by copied arrays.

## Parsing and Validation

The parser normalizes LF/CRLF only while interpreting syntax and retains the
patch's original line-ending style for serialization. It checks header shape,
decimal ranges, hunk operation prefixes, count agreement, and newline markers.
`PatchSet::validate` adds cross-hunk and cross-file invariants such as ordered
ranges and unique real source/target paths.

## Generation

`diff_text` builds a suffix LCS table and deterministically prefers deletion on
ties. Final-newline differences participate in line equality. The cell limit is
checked before allocation. Generation currently emits one complete hunk, which
is easy to audit and replay but can be larger than a conventional context-pruned
diff.

## Transactional Application

Application copies the inventory, preflights paths, and applies hunks only to
the copy. Each hunk extracts its old-side sequence and searches the declared
position plus or minus `max_offset`. Zero matches produce
`apply.context.mismatch`; multiple matches produce `apply.context.ambiguous`.
The result is returned only after every file succeeds, so an error cannot expose
partial state.

## Complexity

- Parsing and serialization: linear in patch size.
- Exact-position application: linear in changed file size across replacements.
- Offset search: proportional to window width times hunk source length.
- Generation: `O(old_lines * new_lines)` time and memory, bounded by `max_cells`.

