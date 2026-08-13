///|
fn parse_decimal(value : String, location : String) -> Result[Int, Diagnostic] {
  if value.is_empty() {
    return Err(
      Diagnostic::new(
        "patch.range.integer", location, "range integer is empty", "decimal integer",
        value,
      ),
    )
  }
  let mut result = 0
  for char in value {
    if char < '0' || char > '9' {
      return Err(
        Diagnostic::new(
          "patch.range.integer", location, "range contains a non-decimal character",
          "decimal integer", value,
        ),
      )
    }
    result = result * 10 + char.to_int() - '0'.to_int()
    if result > 100000000 {
      return Err(
        Diagnostic::new(
          "patch.range.limit", location, "range exceeds the safety limit", "at most 100000000",
          value,
        ),
      )
    }
  }
  Ok(result)
}

///|
fn parse_range(
  value : String,
  sign : String,
  location : String,
) -> Result[(Int, Int), Diagnostic] {
  if !value.has_prefix(sign) {
    return Err(
      Diagnostic::new(
        "patch.range.sign", location, "range has the wrong sign", sign, value,
      ),
    )
  }
  let body = value[1:].to_owned()
  let pieces = body.split(",").map(fn(item) { item.to_owned() }).collect()
  if pieces.length() > 2 {
    return Err(
      Diagnostic::new(
        "patch.range.syntax",
        location,
        "range has too many fields",
        sign + "start[,count]",
        value,
      ),
    )
  }
  let start = match parse_decimal(pieces[0], location + ".start") {
    Ok(number) => number
    Err(error) => return Err(error)
  }
  let count = if pieces.length() == 2 {
    match parse_decimal(pieces[1], location + ".count") {
      Ok(number) => number
      Err(error) => return Err(error)
    }
  } else {
    1
  }
  if (count == 0 && start < 0) || (count > 0 && start < 1) {
    return Err(
      Diagnostic::new(
        "patch.range.start", location, "range starts outside the valid line domain",
        "positive start or zero-count insertion", value,
      ),
    )
  }
  Ok((start, count))
}

///|
fn parse_hunk_header(
  line : String,
  location : String,
) -> Result[(Int, Int, Int, Int, String), Diagnostic] {
  if !line.has_prefix("@@ ") {
    return Err(
      Diagnostic::new(
        "patch.hunk.header", location, "hunk header is missing its opening marker",
        "@@ -old +new @@", line,
      ),
    )
  }
  let rest = line[3:].to_owned()
  let close = match rest[:].find(" @@") {
    Some(index) => index
    None =>
      return Err(
        Diagnostic::new(
          "patch.hunk.header", location, "hunk header is missing its closing marker",
          "@@ -old +new @@", line,
        ),
      )
  }
  let ranges = rest[:close]
    .to_owned()
    .split(" ")
    .map(fn(item) { item.to_owned() })
    .collect()
  if ranges.length() != 2 {
    return Err(
      Diagnostic::new(
        "patch.hunk.header",
        location,
        "hunk header must contain two ranges",
        "-old +new",
        rest[:close].to_owned(),
      ),
    )
  }
  let (old_start, old_count) = match
    parse_range(ranges[0], "-", location + ".old") {
    Ok(range) => range
    Err(error) => return Err(error)
  }
  let (new_start, new_count) = match
    parse_range(ranges[1], "+", location + ".new") {
    Ok(range) => range
    Err(error) => return Err(error)
  }
  let suffix = rest[close + 3:].to_owned()
  let section = if suffix.has_prefix(" ") {
    suffix[1:].to_owned()
  } else {
    suffix
  }
  Ok((old_start, old_count, new_start, new_count, section))
}

///|
fn validate_hunk_counts(
  hunk : Hunk,
  location : String,
) -> Result[Unit, Diagnostic] {
  let mut old_actual = 0
  let mut new_actual = 0
  for line in hunk.lines {
    match line.kind {
      Context => {
        old_actual = old_actual + 1
        new_actual = new_actual + 1
      }
      Addition => new_actual = new_actual + 1
      Deletion => old_actual = old_actual + 1
    }
  }
  if old_actual != hunk.old_count {
    return Err(
      Diagnostic::new(
        "patch.hunk.old_count",
        location,
        "old range count does not match hunk lines",
        hunk.old_count.to_string(),
        old_actual.to_string(),
      ),
    )
  }
  if new_actual != hunk.new_count {
    return Err(
      Diagnostic::new(
        "patch.hunk.new_count",
        location,
        "new range count does not match hunk lines",
        hunk.new_count.to_string(),
        new_actual.to_string(),
      ),
    )
  }
  Ok(())
}

///|
fn parse_hunk(
  lines : Array[String],
  start : Int,
  file_index : Int,
  hunk_index : Int,
) -> Result[(Hunk, Int), Diagnostic] {
  let location = "files[" +
    file_index.to_string() +
    "].hunks[" +
    hunk_index.to_string() +
    "]"
  let (old_start, old_count, new_start, new_count, section) = match
    parse_hunk_header(lines[start], location + ".header") {
    Ok(header) => header
    Err(error) => return Err(error)
  }
  let changes : Array[ChangeLine] = []
  let mut index = start + 1
  while index < lines.length() {
    let line = lines[index]
    if line.has_prefix("@@ ") || line.has_prefix("--- ") {
      break
    }
    if line == "" && index == lines.length() - 1 {
      break
    }
    if line == "\\ No newline at end of file" {
      if changes.is_empty() {
        return Err(
          Diagnostic::new(
            "patch.newline.orphan", location, "newline marker has no preceding change line",
            "change line", line,
          ),
        )
      }
      let previous = changes[changes.length() - 1]
      if previous.no_newline {
        return Err(
          Diagnostic::new(
            "patch.newline.duplicate", location, "change line has more than one no-newline marker",
            "at most one marker", "duplicate marker",
          ),
        )
      }
      changes[changes.length() - 1] = ChangeLine::new(
        previous.kind,
        previous.text,
        no_newline=true,
      )
      index = index + 1
      continue
    }
    if line.is_empty() {
      return Err(
        Diagnostic::new(
          "patch.hunk.line",
          location + ".lines[" + changes.length().to_string() + "]",
          "hunk line is missing an operation prefix",
          "space, +, or -",
          "empty line",
        ),
      )
    }
    let kind = match line[0] {
      ' ' => Context
      '+' => Addition
      '-' => Deletion
      other =>
        return Err(
          Diagnostic::new(
            "patch.hunk.line",
            location + ".lines[" + changes.length().to_string() + "]",
            "unknown hunk operation",
            "space, +, or -",
            other.to_string(),
          ),
        )
    }
    changes.push(ChangeLine::new(kind, line[1:].to_owned()))
    index = index + 1
  }
  let hunk = Hunk::new(
    old_start, old_count, new_start, new_count, section, changes,
  )
  match validate_hunk_counts(hunk, location) {
    Ok(_) => Ok((hunk, index))
    Err(error) => Err(error)
  }
}

///|
pub fn parse(source : String) -> Result[PatchSet, Diagnostic] {
  if source.is_empty() {
    return Err(
      Diagnostic::new(
        "patch.empty", "patch", "patch source is empty", "at least one file patch",
        "empty input",
      ),
    )
  }
  if source.length() > 16777216 {
    return Err(
      Diagnostic::new(
        "patch.limit",
        "patch",
        "patch exceeds the input safety limit",
        "at most 16777216 bytes",
        source.length().to_string(),
      ),
    )
  }
  let ending = detect_line_ending(source)
  let lines = split_patch_lines(source)
  let files = []
  let mut index = 0
  while index < lines.length() {
    if lines[index] == "" && index == lines.length() - 1 {
      break
    }
    if !lines[index].has_prefix("--- ") {
      return Err(
        Diagnostic::new(
          "patch.file.old_header",
          "lines[" + index.to_string() + "]",
          "expected an old-file header",
          "--- path",
          lines[index],
        ),
      )
    }
    let old_label = lines[index][4:].to_owned()
    let old_path = parse_header_path(old_label)
    index = index + 1
    if index >= lines.length() || !lines[index].has_prefix("+++ ") {
      let actual = if index < lines.length() {
        lines[index]
      } else {
        "end of input"
      }
      return Err(
        Diagnostic::new(
          "patch.file.new_header",
          "files[" + files.length().to_string() + "]",
          "expected a new-file header",
          "+++ path",
          actual,
        ),
      )
    }
    let new_label = lines[index][4:].to_owned()
    let new_path = parse_header_path(new_label)
    if !is_safe_path(old_path) ||
      !is_safe_path(new_path) ||
      (old_path == "/dev/null" && new_path == "/dev/null") {
      return Err(
        Diagnostic::new(
          "patch.path.unsafe",
          "files[" + files.length().to_string() + "]",
          "file header contains an unsafe or unusable path",
          "relative normalized path or one /dev/null side",
          old_path + " -> " + new_path,
        ),
      )
    }
    index = index + 1
    let hunks = []
    while index < lines.length() && lines[index].has_prefix("@@ ") {
      match parse_hunk(lines, index, files.length(), hunks.length()) {
        Ok((hunk, next)) => {
          hunks.push(hunk)
          index = next
        }
        Err(error) => return Err(error)
      }
    }
    if hunks.is_empty() {
      return Err(
        Diagnostic::new(
          "patch.file.hunks",
          "files[" + files.length().to_string() + "]",
          "file patch contains no hunks",
          "at least one @@ hunk",
          "none",
        ),
      )
    }
    files.push(FilePatch::new(old_path, new_path, old_label, new_label, hunks))
  }
  if files.is_empty() {
    Err(
      Diagnostic::new(
        "patch.empty", "patch", "patch source contains no file patches", "at least one file patch",
        "none",
      ),
    )
  } else {
    Ok(PatchSet::new(files, line_ending=ending))
  }
}

///|
fn range_text(start : Int, count : Int, sign : String) -> String {
  if count == 1 {
    sign + start.to_string()
  } else {
    sign + start.to_string() + "," + count.to_string()
  }
}

///|
pub fn PatchSet::to_unified_diff(self : PatchSet) -> String {
  let ending = line_ending_text(self.line_ending)
  let output = StringBuilder::new()
  for file in self.files {
    output.write_string("--- " + file.old_label + ending)
    output.write_string("+++ " + file.new_label + ending)
    for hunk in file.hunks {
      let section = if hunk.section.is_empty() {
        ""
      } else {
        " " + hunk.section
      }
      output.write_string(
        "@@ " +
        range_text(hunk.old_start, hunk.old_count, "-") +
        " " +
        range_text(hunk.new_start, hunk.new_count, "+") +
        " @@" +
        section +
        ending,
      )
      for line in hunk.lines {
        let prefix = match line.kind {
          Context => " "
          Addition => "+"
          Deletion => "-"
        }
        output.write_string(prefix + line.text + ending)
        if line.no_newline {
          output.write_string("\\ No newline at end of file" + ending)
        }
      }
    }
  }
  output.to_string()
}
