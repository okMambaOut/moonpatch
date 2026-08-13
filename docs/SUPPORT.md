# Support Matrix

| Behavior | Status | Notes |
| --- | --- | --- |
| Standard `---` / `+++` file headers | Supported | Optional tab suffix retained as label text and excluded from normalized path |
| `@@ -a,b +c,d @@` hunks | Supported | Omitted count means one; zero-count insertion/deletion supported |
| Context, addition, deletion lines | Supported | Counts are verified exactly |
| No-final-newline marker | Supported | Duplicate/orphan markers rejected |
| LF and CRLF patches | Supported | Source file line-ending style is preserved on apply |
| File creation/deletion | Supported | Uses `/dev/null` on one header side |
| Different old/new paths | Supported | Content and path change are applied together |
| Multi-file transactions | Supported | Pure in-memory inventory, all-or-error result |
| Bounded hunk relocation | Supported | Unique match required within configured offset |
| Reverse application | Supported | Swaps paths, ranges, and add/delete operations |
| Diff generation | Supported | Deterministic full-file single hunk, bounded LCS |
| Git extended headers | Partial | Ignored preambles are not accepted; feed the unified section only |
| Timestamps after a tab | Partial | Retained in labels, not interpreted |
| Quoted or backslash paths | Unsupported | Paths must be safe relative forward-slash paths |
| Fuzzy whitespace matching | Unsupported | Text lines match exactly |
| Binary patches | Unsupported | Text only |
| Mode, owner, symlink changes | Unsupported | No filesystem metadata model |
| Direct filesystem mutation | Unsupported | Integrators perform I/O around `FileInventory` |

## Safety Limits

- Parsed patch input: 16 MiB.
- Parsed range values: at most 100,000,000.
- Apply offset: 0 through 10,000 lines.
- Generated diff table: 4,000,000 cells by default, configurable up to 16,000,000.

Diagnostics are stable dot-separated codes. Message prose may become clearer in
minor releases; integrations should branch on `Diagnostic::code`.

