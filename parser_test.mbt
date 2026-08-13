///|
let sample_patch = "--- a/src/hello.txt\n+++ b/src/hello.txt\n@@ -1,3 +1,4 @@ greeting\n hello\n-old world\n+new world\n+again\n done\n"

///|
test "parse a complete file patch and preserve its structure" {
  let parsed = parse(sample_patch).unwrap()
  assert_eq(parsed.files().length(), 1)
  let file = parsed.files()[0]
  assert_eq(file.old_path(), "src/hello.txt")
  assert_eq(file.new_path(), "src/hello.txt")
  assert_false(file.is_creation())
  assert_false(file.is_deletion())
  assert_eq(file.hunks().length(), 1)
  let hunk = file.hunks()[0]
  assert_eq(hunk.old_start(), 1)
  assert_eq(hunk.old_count(), 3)
  assert_eq(hunk.new_count(), 4)
  assert_eq(hunk.section(), "greeting")
  assert_eq(hunk.lines().length(), 5)
}

///|
test "round trip canonical LF and CRLF patches" {
  assert_eq(parse(sample_patch).unwrap().to_unified_diff(), sample_patch)
  let crlf = sample_patch.replace_all(old="\n", new="\r\n")
  let parsed = parse(crlf).unwrap()
  assert_true(parsed.line_ending() is CrLf)
  assert_eq(parsed.to_unified_diff(), crlf)
}

///|
test "parse zero-count creation and no-newline markers" {
  let source = "--- /dev/null\n+++ b/new.txt\n@@ -0,0 +1,2 @@\n+first\n+last\n\\ No newline at end of file\n"
  let parsed = parse(source).unwrap()
  let file = parsed.files()[0]
  assert_true(file.is_creation())
  assert_eq(file.hunks()[0].lines()[1].has_no_newline_marker(), true)
  assert_eq(parsed.to_unified_diff(), source)
}

///|
test "reject unsafe paths malformed headers and mismatched counts" {
  let unsafe_patch = "--- a/../secret\n+++ b/secret\n@@ -1 +1 @@\n-x\n+y\n"
  assert_eq(parse(unsafe_patch).unwrap_err().code(), "patch.path.unsafe")
  let missing = "--- a/file\n@@ -1 +1 @@\n-x\n+y\n"
  assert_eq(parse(missing).unwrap_err().code(), "patch.file.new_header")
  let mismatch = "--- a/file\n+++ b/file\n@@ -1,2 +1 @@\n-x\n+y\n"
  assert_eq(parse(mismatch).unwrap_err().code(), "patch.hunk.old_count")
}

///|
test "reject orphan no-newline marker and non-decimal ranges" {
  let orphan = "--- a/file\n+++ b/file\n@@ -1 +1 @@\n\\ No newline at end of file\n-x\n+y\n"
  assert_eq(parse(orphan).unwrap_err().code(), "patch.newline.orphan")
  let invalid = "--- a/file\n+++ b/file\n@@ -x +1 @@\n-x\n+y\n"
  assert_eq(parse(invalid).unwrap_err().code(), "patch.range.integer")
}
