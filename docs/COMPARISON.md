# Originality and Candidate Comparison

The selected identity was compared with every project in the hackathon registry
before implementation.

| Candidate | Domain and main loop | Registry overlap | Decision |
| --- | --- | --- | --- |
| MoonPatch | Text changes: parse/generate diff, locate hunks, apply/reverse | No shared core data, algorithm, output, or acceptance loop | Selected: reusable, portable developer-tool core |
| MoonFlow | Workflow graphs: load DAG, validate dependencies, schedule, analyze critical path | Distinct, but broader execution semantics weakened the first release | Not selected |
| MoonCSV | Tabular quality: infer columns, stream rows, validate constraints, emit profiles | Distinct, but CSV profiling is less MoonBit-specific and ecosystem-focused | Not selected |

MoonPatch differs from MoonBench (timing samples and performance baselines),
MoonContract (OpenAPI/HTTP contracts and mocks), MoonRecur (civil-calendar
recurrence expansion), and MoonShard (content-defined chunks and incremental
reconstruction). Its core data is text lines and unified-diff hunks; its
acceptance loop is reversible patch application.

