///|
test "generate deterministic modification and replay it" {
  let old = TextFile::new("notes.txt", "alpha\nbeta\ngamma\n")
  let new = TextFile::new("notes.txt", "alpha\nBETA\ngamma\ndelta\n")
  let patch = diff_file(old, new).unwrap()
  let expected = "--- a/notes.txt\n+++ b/notes.txt\n@@ -1,3 +1,4 @@\n alpha\n-beta\n+BETA\n gamma\n+delta\n"
  assert_eq(patch.to_unified_diff(), expected)
  assert_eq(
    patch.apply(inventory([old])).unwrap().inventory().get("notes.txt").unwrap(),
    new,
  )
  let stats = patch.stats()
  assert_eq(stats.files(), 1)
  assert_eq(stats.hunks(), 1)
  assert_eq(stats.context_lines(), 2)
  assert_eq(stats.additions(), 2)
  assert_eq(stats.deletions(), 1)
  assert_eq(stats.changed_lines(), 3)
}

///|
test "generate and replay create delete and path-only changes" {
  let created = create_file("new.txt", "first\nlast").unwrap()
  assert_eq(created.stats().creations(), 1)
  assert_eq(
    created
    .apply(inventory([]))
    .unwrap()
    .inventory()
    .get("new.txt")
    .unwrap()
    .content(),
    "first\nlast",
  )
  let deleted = delete_file("old.txt", "gone\n").unwrap()
  assert_eq(deleted.stats().removals(), 1)
  assert_true(
    deleted
    .apply(inventory([TextFile::new("old.txt", "gone\n")]))
    .unwrap()
    .inventory()
    .get("old.txt")
    is None,
  )
  let moved = diff_file(
    TextFile::new("before.txt", "same\n"),
    TextFile::new("after.txt", "same\n"),
  ).unwrap()
  assert_eq(moved.stats().path_changes(), 1)
  assert_eq(
    moved
    .apply(inventory([TextFile::new("before.txt", "same\n")]))
    .unwrap()
    .inventory()
    .get("after.txt")
    .unwrap()
    .content(),
    "same\n",
  )
}

///|
test "newline-only change is represented and reversible" {
  let old = TextFile::new("note", "value")
  let new = TextFile::new("note", "value\n")
  let patch = diff_file(old, new).unwrap()
  assert_true(
    patch
    .to_unified_diff()
    .contains("-value\n\\ No newline at end of file\n+value\n"),
  )
  let after = patch.apply(inventory([old])).unwrap().inventory()
  assert_eq(after.get("note").unwrap(), new)
  assert_eq(
    patch.reverse().apply(after).unwrap().inventory().get("note").unwrap(),
    old,
  )
}

///|
test "diff limits unchanged inputs and unsafe paths are diagnosed" {
  assert_eq(
    diff_text("x", "same", "x", "same").unwrap_err().code(),
    "diff.unchanged",
  )
  assert_eq(
    diff_text("../x", "a", "x", "b").unwrap_err().code(),
    "diff.path.unsafe",
  )
  let options = DiffOptions::new(max_cells=4).unwrap()
  assert_eq(
    diff_text("x", "a\nb\n", "x", "a\nc\n", options~).unwrap_err().code(),
    "diff.cells.exceeded",
  )
  assert_eq(
    DiffOptions::new(max_cells=0).unwrap_err().code(),
    "diff.cells.limit",
  )
}

///|
test "validate detects duplicate outputs overlapping hunks and context-only changes" {
  let duplicate = parse(
    "--- /dev/null\n+++ b/x\n@@ -0,0 +1 @@\n+a\n--- /dev/null\n+++ b/x\n@@ -0,0 +1 @@\n+b\n",
  ).unwrap()
  assert_eq(
    duplicate.validate().unwrap_err().code(),
    "patch.path.duplicate_target",
  )
  let overlap = parse(
    "--- a/x\n+++ b/x\n@@ -2 +2 @@\n-b\n+B\n@@ -1 +1 @@\n-a\n+A\n",
  ).unwrap()
  assert_eq(overlap.validate().unwrap_err().code(), "patch.hunk.order")
  let context = parse("--- a/x\n+++ b/x\n@@ -1 +1 @@\n x\n").unwrap()
  assert_eq(context.validate().unwrap_err().code(), "patch.hunk.empty_change")
}
