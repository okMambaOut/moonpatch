///|
fn roundtrip_case(
  name : String,
  old_content : String,
  new_content : String,
) -> Unit raise {
  let old = TextFile::new(name, old_content)
  let new = TextFile::new(name, new_content)
  let patch = diff_file(old, new).unwrap()
  let before = inventory([old])
  let after = patch.apply(before).unwrap().inventory()
  assert_eq(after.get(name).unwrap(), new)
  let restored = patch.reverse().apply(after).unwrap().inventory()
  assert_eq(restored.get(name).unwrap(), old)
  assert_eq(parse(patch.to_unified_diff()).unwrap(), patch)
}

///|
test "generated patches replay and reverse across a text matrix" {
  roundtrip_case("case-01", "a\n", "b\n")
  roundtrip_case("case-02", "a", "b")
  roundtrip_case("case-03", "a\n", "a")
  roundtrip_case("case-04", "a", "a\n")
  roundtrip_case("case-05", "", "created\n")
  roundtrip_case("case-06", "removed\n", "")
  roundtrip_case("case-07", "a\nb\nc\n", "a\nc\n")
  roundtrip_case("case-08", "a\nc\n", "a\nb\nc\n")
  roundtrip_case("case-09", "same\nleft\n", "same\nright\n")
  roundtrip_case("case-10", "repeat\nrepeat\n", "repeat\nchanged\n")
  roundtrip_case("case-11", "你好\nMoonBit\n", "你好\n月兔\n")
  roundtrip_case("case-12", "emoji 😀\n", "emoji 🌙\n")
  roundtrip_case("case-13", "tabs\there\n", "tabs\tthere\n")
  roundtrip_case("case-14", "space \n", "space\n")
  roundtrip_case("case-15", "one\ntwo\nthree", "zero\none\nthree\nfour")
  roundtrip_case("case-16", "\n", "x\n")
  roundtrip_case("case-17", "x\n", "\n")
  roundtrip_case("case-18", "a\rb\n", "a\rb\nc\n")
  roundtrip_case("case-19", "alpha\nbeta\n", "beta\nalpha\n")
  roundtrip_case("case-20", "first\nmiddle\nlast\n", "FIRST\nmiddle\nLAST\n")
}

///|
test "multiple hunks account for accumulated line displacement" {
  let source = "--- a/list\n+++ b/list\n@@ -1,2 +1,3 @@\n one\n+one-half\n two\n@@ -4,2 +5 @@\n four\n-five\n"
  let before = inventory([
    TextFile::new("list", "one\ntwo\nthree\nfour\nfive\n"),
  ])
  let patch = parse(source).unwrap()
  let report = patch.apply(before).unwrap()
  assert_eq(
    report.inventory().get("list").unwrap().content(),
    "one\none-half\ntwo\nthree\nfour\n",
  )
  assert_eq(report.hunks().length(), 2)
  assert_eq(report.hunks()[0].offset(), 0)
  assert_eq(report.hunks()[1].offset(), 0)
  assert_eq(
    patch
    .reverse()
    .apply(report.inventory())
    .unwrap()
    .inventory()
    .get("list")
    .unwrap()
    .content(),
    "one\ntwo\nthree\nfour\nfive\n",
  )
}

///|
test "CRLF source content keeps its native line ending after application" {
  let source = "--- a/win.txt\r\n+++ b/win.txt\r\n@@ -1,2 +1,2 @@\r\n first\r\n-old\r\n+new\r\n"
  let before = inventory([TextFile::new("win.txt", "first\r\nold\r\n")])
  let patch = parse(source).unwrap()
  assert_true(patch.line_ending() is CrLf)
  let report = patch.apply(before).unwrap()
  assert_eq(
    report.inventory().get("win.txt").unwrap().content(),
    "first\r\nnew\r\n",
  )
}

///|
test "bounded relocation stays ambiguous when two candidate windows match" {
  let source = "--- a/x\n+++ b/x\n@@ -3 +3 @@\n-same\n+changed\n"
  let before = inventory([TextFile::new("x", "same\nother\nsame\n")])
  let options = ApplyOptions::new(max_offset=2).unwrap()
  assert_eq(
    parse(source).unwrap().apply(before, options~).unwrap_err().code(),
    "apply.context.ambiguous",
  )
}

///|
test "parser rejects headers without hunks and invalid operation prefixes" {
  assert_eq(parse("--- a/x\n+++ b/x\n").unwrap_err().code(), "patch.file.hunks")
  assert_eq(
    parse("--- a/x\n+++ b/x\n@@ -1 +1 @@\n?x\n").unwrap_err().code(),
    "patch.hunk.line",
  )
  assert_eq(
    parse(
      "--- a/x\n+++ b/x\n@@ -1 +1 @@\n-x\n+y\n\\ No newline at end of file\n\\ No newline at end of file\n",
    )
    .unwrap_err()
    .code(),
    "patch.newline.duplicate",
  )
}
