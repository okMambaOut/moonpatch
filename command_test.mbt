///|
let encoded_sample = "--- a/src/hello.txt\\n+++ b/src/hello.txt\\n@@ -1,3 +1,4 @@ greeting\\n hello\\n-old world\\n+new world\\n+again\\n done\\n"

///|
test "CLI inspects and applies a patch" {
  let inspected = execute(["inspect", "--patch", encoded_sample])
  assert_eq(inspected.exit_code(), 0)
  assert_eq(
    inspected.output(),
    "files=1 hunks=1 additions=2 deletions=1 creations=0 removals=0 path_changes=0",
  )
  let applied = execute([
    "apply", "--path", "src/hello.txt", "--text", "prefix\\nhello\\nold world\\ndone\\n",
    "--patch", encoded_sample, "--max-offset", "2",
  ])
  assert_eq(applied.exit_code(), 0)
  assert_true(
    applied.output().contains("applied hunks=1 additions=2 deletions=1"),
  )
  assert_true(
    applied
    .output()
    .contains("src/hello.txt=prefix\\nhello\\nnew world\\nagain\\ndone\\n"),
  )
}

///|
test "CLI generates and reverses encoded diffs" {
  let generated = execute([
    "diff", "--path", "note", "--old", "old\\n", "--new", "new\\n",
  ])
  assert_eq(generated.exit_code(), 0)
  assert_eq(
    generated.output(),
    "--- a/note\\n+++ b/note\\n@@ -1 +1 @@\\n-old\\n+new\\n",
  )
  let reversed = execute(["reverse", "--patch", generated.output()])
  assert_eq(reversed.exit_code(), 0)
  assert_eq(
    reversed.output(),
    "--- b/note\\n+++ a/note\\n@@ -1 +1 @@\\n+old\\n-new\\n",
  )
}

///|
test "CLI demo proves generation application and reverse" {
  let demo = execute(["demo"])
  assert_eq(demo.exit_code(), 0)
  assert_true(
    demo.output().contains("demo files=1 hunks=1 additions=2 deletions=1"),
  )
  assert_true(demo.output().contains("reverse=verified"))
}

///|
test "CLI reports invalid escapes options integers and commands" {
  assert_eq(execute(["inspect", "--patch", "bad\\q"]).exit_code(), 2)
  assert_true(
    execute(["inspect", "--patch", "bad\\q"])
    .output()
    .contains("cli.escape.invalid"),
  )
  assert_true(execute(["inspect"]).output().contains("cli.option.required"))
  assert_true(
    execute(["inspect", "--patch", encoded_sample, "--other", "x"])
    .output()
    .contains("cli.option.unknown"),
  )
  assert_true(
    execute([
      "apply", "--path", "x", "--text", "x", "--patch", encoded_sample, "--max-offset",
      "many",
    ])
    .output()
    .contains("cli.option.integer"),
  )
  assert_true(execute(["launch"]).output().contains("cli.command.unknown"))
  assert_true(execute([]).output().contains("USAGE:"))
}
