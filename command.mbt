///|
pub struct CommandResult {
  exit_code : Int
  output : String
} derive(Eq, @debug.Debug)

///|
pub fn CommandResult::exit_code(self : CommandResult) -> Int {
  self.exit_code
}

///|
pub fn CommandResult::output(self : CommandResult) -> String {
  self.output
}

///|
fn command_ok(output : String) -> CommandResult {
  { exit_code: 0, output }
}

///|
fn command_error(output : String) -> CommandResult {
  { exit_code: 2, output }
}

///|
fn usage() -> String {
  "MoonPatch - deterministic unified-diff tools\n\n" +
  "USAGE:\n" +
  "  moonpatch inspect --patch TEXT\n" +
  "  moonpatch apply --path PATH --text TEXT --patch TEXT [--max-offset N]\n" +
  "  moonpatch reverse --patch TEXT\n" +
  "  moonpatch diff --path PATH --old TEXT --new TEXT\n" +
  "  moonpatch demo\n\n" +
  "TEXT values decode \\n, \\r, \\t, and \\\\. Commands operate on one in-memory file;\n" +
  "the library API supports transactional multi-file inventories."
}

///|
fn decode_text(value : String, field : String) -> Result[String, Diagnostic] {
  let output = StringBuilder::new()
  let mut escaping = false
  for char in value {
    if escaping {
      match char {
        'n' => output.write_char('\n')
        'r' => output.write_char('\r')
        't' => output.write_char('\t')
        '\\' => output.write_char('\\')
        other =>
          return Err(
            Diagnostic::new(
              "cli.escape.invalid",
              field,
              "text contains an unsupported escape",
              "n, r, t, or backslash after an escape",
              "escape followed by " + other.to_string(),
            ),
          )
      }
      escaping = false
    } else if char == '\\' {
      escaping = true
    } else {
      output.write_char(char)
    }
  }
  if escaping {
    Err(
      Diagnostic::new(
        "cli.escape.trailing", field, "text ends with an incomplete escape", "character after the escape",
        "end of input",
      ),
    )
  } else {
    Ok(output.to_string())
  }
}

///|
fn encode_text(value : String) -> String {
  let output = StringBuilder::new()
  for char in value {
    match char {
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      '\\' => output.write_string("\\\\")
      other => output.write_char(other)
    }
  }
  output.to_string()
}

///|
fn option(args : Array[String], name : String) -> Result[String, Diagnostic] {
  let mut found : String? = None
  let mut index = 1
  while index < args.length() {
    if args[index] == name {
      if found is Some(_) {
        return Err(
          Diagnostic::new(
            "cli.option.duplicate", name, "option appears more than once", "one value",
            "duplicate",
          ),
        )
      }
      if index + 1 >= args.length() {
        return Err(
          Diagnostic::new(
            "cli.option.value", name, "option is missing its value", "value after option",
            "missing",
          ),
        )
      }
      found = Some(args[index + 1])
      index = index + 2
    } else {
      index = index + 1
    }
  }
  match found {
    Some(value) => Ok(value)
    None =>
      Err(
        Diagnostic::new(
          "cli.option.required",
          name,
          "required option is missing",
          name + " VALUE",
          "missing",
        ),
      )
  }
}

///|
fn optional_option(
  args : Array[String],
  name : String,
) -> Result[String?, Diagnostic] {
  match option(args, name) {
    Ok(value) => Ok(Some(value))
    Err(error) if error.code == "cli.option.required" => Ok(None)
    Err(error) => Err(error)
  }
}

///|
fn check_options(
  args : Array[String],
  allowed : Array[String],
) -> Result[Unit, Diagnostic] {
  let mut index = 1
  while index < args.length() {
    let name = args[index]
    if !name.has_prefix("--") {
      return Err(
        Diagnostic::new(
          "cli.argument.unexpected",
          "args[" + index.to_string() + "]",
          "unexpected positional argument",
          "named option",
          name,
        ),
      )
    }
    let mut accepted = false
    for candidate in allowed {
      if name == candidate {
        accepted = true
      }
    }
    if !accepted {
      return Err(
        Diagnostic::new(
          "cli.option.unknown",
          "args[" + index.to_string() + "]",
          "unknown option",
          "supported option",
          name,
        ),
      )
    }
    index = index + 2
  }
  Ok(())
}

///|
fn decimal_option(value : String, name : String) -> Result[Int, Diagnostic] {
  match parse_decimal(value, name) {
    Ok(number) => Ok(number)
    Err(_) =>
      Err(
        Diagnostic::new(
          "cli.option.integer", name, "option must be a decimal integer", "decimal integer",
          value,
        ),
      )
  }
}

///|
fn parse_patch_option(args : Array[String]) -> Result[PatchSet, Diagnostic] {
  let encoded = match option(args, "--patch") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let source = match decode_text(encoded, "--patch") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match parse(source) {
    Ok(patch) =>
      match patch.validate() {
        Ok(_) => Ok(patch)
        Err(error) => Err(error)
      }
    Err(error) => Err(error)
  }
}

///|
fn stats_text(patch : PatchSet) -> String {
  let stats = patch.stats()
  "files=" +
  stats.files().to_string() +
  " hunks=" +
  stats.hunks().to_string() +
  " additions=" +
  stats.additions().to_string() +
  " deletions=" +
  stats.deletions().to_string() +
  " creations=" +
  stats.creations().to_string() +
  " removals=" +
  stats.removals().to_string() +
  " path_changes=" +
  stats.path_changes().to_string()
}

///|
fn inspect_command(args : Array[String]) -> Result[String, Diagnostic] {
  match check_options(args, ["--patch"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match parse_patch_option(args) {
    Ok(patch) => Ok(stats_text(patch))
    Err(error) => Err(error)
  }
}

///|
fn reverse_command(args : Array[String]) -> Result[String, Diagnostic] {
  match check_options(args, ["--patch"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match parse_patch_option(args) {
    Ok(patch) => Ok(encode_text(patch.reverse().to_unified_diff()))
    Err(error) => Err(error)
  }
}

///|
fn apply_command(args : Array[String]) -> Result[String, Diagnostic] {
  match check_options(args, ["--path", "--text", "--patch", "--max-offset"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let path = match option(args, "--path") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let encoded = match option(args, "--text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let content = match decode_text(encoded, "--text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let offset = match optional_option(args, "--max-offset") {
    Ok(Some(value)) =>
      match decimal_option(value, "--max-offset") {
        Ok(number) => number
        Err(error) => return Err(error)
      }
    Ok(None) => 0
    Err(error) => return Err(error)
  }
  let options = match ApplyOptions::new(max_offset=offset) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let patch = match parse_patch_option(args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let inventory = match FileInventory::new([TextFile::new(path, content)]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = match patch.apply(inventory, options~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let files = report.inventory().files()
  let output = StringBuilder::new()
  output.write_string(
    "applied hunks=" +
    report.hunks().length().to_string() +
    " additions=" +
    report.additions().to_string() +
    " deletions=" +
    report.deletions().to_string(),
  )
  for file in files {
    output.write_string("\n" + file.path() + "=" + encode_text(file.content()))
  }
  Ok(output.to_string())
}

///|
fn diff_command(args : Array[String]) -> Result[String, Diagnostic] {
  match check_options(args, ["--path", "--old", "--new"]) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let path = match option(args, "--path") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let old = match option(args, "--old") {
    Ok(value) =>
      match decode_text(value, "--old") {
        Ok(text) => text
        Err(error) => return Err(error)
      }
    Err(error) => return Err(error)
  }
  let new = match option(args, "--new") {
    Ok(value) =>
      match decode_text(value, "--new") {
        Ok(text) => text
        Err(error) => return Err(error)
      }
    Err(error) => return Err(error)
  }
  match diff_text(path, old, path, new) {
    Ok(patch) => Ok(encode_text(patch.to_unified_diff()))
    Err(error) => Err(error)
  }
}

///|
fn demo_command() -> Result[String, Diagnostic] {
  let before = TextFile::new("story.txt", "title\nold ending\n")
  let after = TextFile::new("story.txt", "title\nnew ending\nepilogue\n")
  let patch = match diff_file(before, after) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let inventory = FileInventory::new([before]).unwrap()
  let report = match patch.apply(inventory) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let restored = match patch.reverse().apply(report.inventory()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if restored.inventory().get("story.txt").unwrap() != before {
    return Err(
      Diagnostic::new(
        "demo.reverse.failed", "demo", "reverse application did not recover the original",
        "original file", "different file",
      ),
    )
  }
  Ok(
    "demo files=1 hunks=1 additions=2 deletions=1\nupdated story.txt=title\\nnew ending\\nepilogue\\n\nreverse=verified",
  )
}

///|
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    return command_ok(usage())
  }
  let result = match args[0] {
    "inspect" => inspect_command(args)
    "apply" => apply_command(args)
    "reverse" => reverse_command(args)
    "diff" => diff_command(args)
    "demo" =>
      if args.length() == 1 {
        demo_command()
      } else {
        Err(
          Diagnostic::new(
            "cli.argument.unexpected",
            "args[1]",
            "demo accepts no arguments",
            "no arguments",
            args[1],
          ),
        )
      }
    command =>
      Err(
        Diagnostic::new(
          "cli.command.unknown", "args[0]", "unknown command", "inspect, apply, reverse, diff, demo, or help",
          command,
        ),
      )
  }
  match result {
    Ok(output) => command_ok(output)
    Err(error) => command_error(error.to_text())
  }
}
