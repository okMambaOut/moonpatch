///|
fn inventory(entries : Array[TextFile]) -> FileInventory {
  FileInventory::new(entries).unwrap()
}

///|
test "apply modification and report exact hunk position" {
  let patch = parse(sample_patch).unwrap()
  let before = inventory([
    TextFile::new("src/hello.txt", "hello\nold world\ndone\n"),
  ])
  let report = patch.apply(before).unwrap()
  assert_eq(
    report.inventory().get("src/hello.txt").unwrap().content(),
    "hello\nnew world\nagain\ndone\n",
  )
  assert_eq(report.files_modified(), 1)
  assert_eq(report.additions(), 2)
  assert_eq(report.deletions(), 1)
  assert_eq(report.hunks()[0].offset(), 0)
}

///|
test "apply creation deletion and path change transaction" {
  let source = "--- /dev/null\n+++ b/new.txt\n@@ -0,0 +1 @@\n+created\n--- a/old.txt\n+++ /dev/null\n@@ -1 +0,0 @@\n-remove\n--- a/move.txt\n+++ b/moved.txt\n@@ -1 +1 @@\n-before\n+after\n"
  let before = inventory([
    TextFile::new("old.txt", "remove\n"),
    TextFile::new("move.txt", "before\n"),
  ])
  let applied = parse(source).unwrap().apply(before)
  let report = applied.unwrap()
  assert_eq(report.files_created(), 1)
  assert_eq(report.files_deleted(), 1)
  assert_eq(report.paths_changed(), 1)
  assert_true(report.inventory().get("old.txt") is None)
  assert_true(report.inventory().get("move.txt") is None)
  assert_eq(report.inventory().get("moved.txt").unwrap().content(), "after\n")
  assert_eq(report.inventory().get("new.txt").unwrap().content(), "created\n")
}

///|
test "bounded offset applies a uniquely relocated hunk" {
  let before = inventory([
    TextFile::new("src/hello.txt", "prefix\nhello\nold world\ndone\n"),
  ])
  let options = ApplyOptions::new(max_offset=2).unwrap()
  let report = parse(sample_patch).unwrap().apply(before, options~).unwrap()
  assert_eq(report.hunks()[0].offset(), 1)
  assert_eq(report.hunks()[0].applied_line(), 2)
}

///|
test "context mismatch ambiguity and path conflicts are stable errors" {
  let patch = parse(sample_patch).unwrap()
  let mismatch = inventory([TextFile::new("src/hello.txt", "different\n")])
  assert_eq(patch.apply(mismatch).unwrap_err().code(), "apply.context.mismatch")
  let duplicated = inventory([
    TextFile::new(
      "src/hello.txt", "hello\nold world\ndone\nhello\nold world\ndone\n",
    ),
  ])
  let options = ApplyOptions::new(max_offset=10).unwrap()
  assert_eq(
    patch.apply(duplicated, options~).unwrap_err().code(),
    "apply.context.ambiguous",
  )
  let create = parse("--- /dev/null\n+++ b/existing\n@@ -0,0 +1 @@\n+x\n").unwrap()
  assert_eq(
    create
    .apply(inventory([TextFile::new("existing", "x\n")]))
    .unwrap_err()
    .code(),
    "apply.path.exists",
  )
}

///|
test "failed later file does not mutate the caller inventory" {
  let source = "--- a/one\n+++ b/one\n@@ -1 +1 @@\n-old\n+new\n--- a/two\n+++ b/two\n@@ -1 +1 @@\n-wrong\n+changed\n"
  let before = inventory([
    TextFile::new("one", "old\n"),
    TextFile::new("two", "actual\n"),
  ])
  assert_eq(
    parse(source).unwrap().apply(before).unwrap_err().code(),
    "apply.context.mismatch",
  )
  assert_eq(before.get("one").unwrap().content(), "old\n")
}

///|
test "reverse recovers original inventory including no-final-newline" {
  let source = "--- a/note\n+++ b/note\n@@ -1,2 +1,2 @@\n first\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n"
  let before = inventory([TextFile::new("note", "first\nold")])
  let patch = parse(source).unwrap()
  let after = patch.apply(before).unwrap().inventory()
  assert_eq(after.get("note").unwrap().content(), "first\nnew")
  let restored = patch.reverse().apply(after).unwrap().inventory()
  assert_eq(restored, before)
}

///|
test "inventory and option validation reject unsafe state" {
  assert_eq(
    FileInventory::new([TextFile::new("../bad", "")]).unwrap_err().code(),
    "inventory.path.unsafe",
  )
  assert_eq(
    FileInventory::new([TextFile::new("same", "a"), TextFile::new("same", "b")])
    .unwrap_err()
    .code(),
    "inventory.path.duplicate",
  )
  assert_eq(
    ApplyOptions::new(max_offset=-1).unwrap_err().code(),
    "apply.offset.limit",
  )
}
