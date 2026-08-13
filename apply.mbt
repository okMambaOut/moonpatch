///|
pub struct ApplyOptions {
  max_offset : Int
} derive(Eq, @debug.Debug)

///|
pub fn ApplyOptions::new(
  max_offset? : Int = 0,
) -> Result[ApplyOptions, Diagnostic] {
  if max_offset < 0 || max_offset > 10000 {
    Err(
      Diagnostic::new(
        "apply.offset.limit",
        "options.max_offset",
        "maximum offset is outside the safety range",
        "0 through 10000",
        max_offset.to_string(),
      ),
    )
  } else {
    Ok({ max_offset, })
  }
}

///|
pub fn ApplyOptions::max_offset(self : ApplyOptions) -> Int {
  self.max_offset
}

///|
pub struct AppliedHunk {
  file_index : Int
  hunk_index : Int
  declared_line : Int
  applied_line : Int
  offset : Int
} derive(Eq, @debug.Debug)

///|
pub fn AppliedHunk::file_index(self : AppliedHunk) -> Int {
  self.file_index
}

///|
pub fn AppliedHunk::hunk_index(self : AppliedHunk) -> Int {
  self.hunk_index
}

///|
pub fn AppliedHunk::declared_line(self : AppliedHunk) -> Int {
  self.declared_line
}

///|
pub fn AppliedHunk::applied_line(self : AppliedHunk) -> Int {
  self.applied_line
}

///|
pub fn AppliedHunk::offset(self : AppliedHunk) -> Int {
  self.offset
}

///|
pub struct ApplyReport {
  inventory : FileInventory
  hunks : Array[AppliedHunk]
  files_created : Int
  files_modified : Int
  files_deleted : Int
  paths_changed : Int
  additions : Int
  deletions : Int
} derive(Eq, @debug.Debug)

///|
pub fn ApplyReport::inventory(self : ApplyReport) -> FileInventory {
  self.inventory
}

///|
pub fn ApplyReport::hunks(self : ApplyReport) -> Array[AppliedHunk] {
  self.hunks.copy()
}

///|
pub fn ApplyReport::files_created(self : ApplyReport) -> Int {
  self.files_created
}

///|
pub fn ApplyReport::files_modified(self : ApplyReport) -> Int {
  self.files_modified
}

///|
pub fn ApplyReport::files_deleted(self : ApplyReport) -> Int {
  self.files_deleted
}

///|
pub fn ApplyReport::paths_changed(self : ApplyReport) -> Int {
  self.paths_changed
}

///|
pub fn ApplyReport::additions(self : ApplyReport) -> Int {
  self.additions
}

///|
pub fn ApplyReport::deletions(self : ApplyReport) -> Int {
  self.deletions
}

///|
priv struct TextDocument {
  lines : Array[String]
  final_newline : Bool
  ending : LineEnding
}

///|
fn parse_document(content : String) -> TextDocument {
  let ending = detect_line_ending(content)
  let final_newline = content.has_suffix("\n")
  let lines = split_patch_lines(content)
  if final_newline && !lines.is_empty() {
    lines.remove(lines.length() - 1) |> ignore
  }
  { lines, final_newline, ending }
}

///|
fn document_text(document : TextDocument) -> String {
  let separator = line_ending_text(document.ending)
  let output = StringBuilder::new()
  for index, line in document.lines {
    if index > 0 {
      output.write_string(separator)
    }
    output.write_string(line)
  }
  if document.final_newline {
    output.write_string(separator)
  }
  output.to_string()
}

///|
fn source_lines(hunk : Hunk) -> Array[String] {
  let result = []
  for line in hunk.lines {
    if line.kind != Addition {
      result.push(line.text)
    }
  }
  result
}

///|
fn target_lines(hunk : Hunk) -> Array[String] {
  let result = []
  for line in hunk.lines {
    if line.kind != Deletion {
      result.push(line.text)
    }
  }
  result
}

///|
fn source_has_final_newline(hunk : Hunk, fallback : Bool) -> Bool {
  for index = hunk.lines.length() - 1; index >= 0; index = index - 1 {
    let line = hunk.lines[index]
    if line.kind != Addition {
      return !line.no_newline
    }
  }
  fallback
}

///|
fn target_has_final_newline(hunk : Hunk, fallback : Bool) -> Bool {
  for index = hunk.lines.length() - 1; index >= 0; index = index - 1 {
    let line = hunk.lines[index]
    if line.kind != Deletion {
      return !line.no_newline
    }
  }
  fallback
}

///|
fn matches_at(
  lines : Array[String],
  pattern : Array[String],
  position : Int,
) -> Bool {
  if position < 0 || position + pattern.length() > lines.length() {
    return false
  }
  for index, expected in pattern {
    if lines[position + index] != expected {
      return false
    }
  }
  true
}

///|
fn find_hunk_position(
  lines : Array[String],
  pattern : Array[String],
  expected : Int,
  max_offset : Int,
  location : String,
) -> Result[Int, Diagnostic] {
  if pattern.is_empty() {
    if expected >= 0 && expected <= lines.length() {
      return Ok(expected)
    }
    return Err(
      Diagnostic::new(
        "apply.position.range",
        location,
        "insertion position is outside the file",
        "0 through " + lines.length().to_string(),
        expected.to_string(),
      ),
    )
  }
  let matches = []
  let first = if expected - max_offset < 0 { 0 } else { expected - max_offset }
  let last_candidate = lines.length() - pattern.length()
  let last = if expected + max_offset < last_candidate {
    expected + max_offset
  } else {
    last_candidate
  }
  if first <= last {
    for position = first; position <= last; position = position + 1 {
      if matches_at(lines, pattern, position) {
        matches.push(position)
      }
    }
  }
  if matches.is_empty() {
    Err(
      Diagnostic::new(
        "apply.context.mismatch",
        location,
        "hunk source lines do not match within the allowed offset",
        "unique match near line " + (expected + 1).to_string(),
        "no match",
      ),
    )
  } else if matches.length() > 1 {
    Err(
      Diagnostic::new(
        "apply.context.ambiguous",
        location,
        "hunk source lines match at multiple positions",
        "one match",
        matches.length().to_string() + " matches",
      ),
    )
  } else {
    Ok(matches[0])
  }
}

///|
fn replace_range(
  lines : Array[String],
  start : Int,
  count : Int,
  replacement : Array[String],
) -> Array[String] {
  let result = []
  for index = 0; index < start; index = index + 1 {
    result.push(lines[index])
  }
  for line in replacement {
    result.push(line)
  }
  for index = start + count; index < lines.length(); index = index + 1 {
    result.push(lines[index])
  }
  result
}

///|
fn apply_file_hunks(
  content : String,
  file : FilePatch,
  file_index : Int,
  options : ApplyOptions,
) -> Result[(String, Array[AppliedHunk]), Diagnostic] {
  let document = parse_document(content)
  let mut current_lines = document.lines
  let mut current_final_newline = document.final_newline
  let reports = []
  let mut displacement = 0
  for hunk_index, hunk in file.hunks {
    let location = "files[" +
      file_index.to_string() +
      "].hunks[" +
      hunk_index.to_string() +
      "]"
    let declared = if hunk.old_count == 0 {
      hunk.old_start
    } else {
      hunk.old_start - 1
    }
    let expected = declared + displacement
    let source = source_lines(hunk)
    let position = match
      find_hunk_position(
        current_lines,
        source,
        expected,
        options.max_offset,
        location,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let replacement = target_lines(hunk)
    let touches_end = position + source.length() == current_lines.length()
    let source_final = source_has_final_newline(hunk, current_final_newline)
    if touches_end && source_final != current_final_newline {
      return Err(
        Diagnostic::new(
          "apply.newline.mismatch",
          location,
          "source newline marker does not match the file",
          source_final.to_string(),
          current_final_newline.to_string(),
        ),
      )
    }
    current_lines = replace_range(
      current_lines,
      position,
      source.length(),
      replacement,
    )
    if current_lines.is_empty() {
      current_final_newline = false
    } else if touches_end {
      current_final_newline = target_has_final_newline(
        hunk, current_final_newline,
      )
    }
    reports.push({
      file_index,
      hunk_index,
      declared_line: hunk.old_start,
      applied_line: position + 1,
      offset: position - expected,
    })
    displacement = displacement +
      replacement.length() -
      source.length() +
      position -
      expected
  }
  Ok(
    (
      document_text({
        lines: current_lines,
        final_newline: current_final_newline,
        ending: document.ending,
      }),
      reports,
    ),
  )
}

///|
pub fn PatchSet::apply(
  self : PatchSet,
  inventory : FileInventory,
  options? : ApplyOptions = { max_offset: 0 },
) -> Result[ApplyReport, Diagnostic] {
  let working = inventory.files.copy()
  let all_hunks = []
  let mut created = 0
  let mut modified = 0
  let mut deleted = 0
  let mut moved = 0
  let mut additions = 0
  let mut deletions = 0
  for file_index, file in self.files {
    for hunk in file.hunks {
      for line in hunk.lines {
        match line.kind {
          Addition => additions = additions + 1
          Deletion => deletions = deletions + 1
          Context => ()
        }
      }
    }
    let old_index = if file.is_creation() {
      None
    } else {
      inventory_index(working, file.old_path)
    }
    let new_index = if file.is_deletion() {
      None
    } else {
      inventory_index(working, file.new_path)
    }
    if file.is_creation() && new_index is Some(_) {
      return Err(
        Diagnostic::new(
          "apply.path.exists",
          "files[" + file_index.to_string() + "].new_path",
          "creation target already exists",
          "missing path",
          file.new_path,
        ),
      )
    }
    if !file.is_creation() && old_index is None {
      return Err(
        Diagnostic::new(
          "apply.path.missing",
          "files[" + file_index.to_string() + "].old_path",
          "source path does not exist",
          "existing path",
          file.old_path,
        ),
      )
    }
    if file.is_path_change() && new_index is Some(_) {
      return Err(
        Diagnostic::new(
          "apply.path.exists",
          "files[" + file_index.to_string() + "].new_path",
          "path-change target already exists",
          "missing path",
          file.new_path,
        ),
      )
    }
    let source_content = match old_index {
      Some(index) => working[index].content
      None => ""
    }
    let (updated, reports) = match
      apply_file_hunks(source_content, file, file_index, options) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    for report in reports {
      all_hunks.push(report)
    }
    if file.is_deletion() {
      if !updated.is_empty() {
        return Err(
          Diagnostic::new(
            "apply.delete.nonempty",
            "files[" + file_index.to_string() + "]",
            "deletion patch leaves content behind",
            "empty result",
            updated.length().to_string() + " bytes",
          ),
        )
      }
      working.remove(old_index.unwrap()) |> ignore
      deleted = deleted + 1
    } else if file.is_creation() {
      working.push(TextFile::new(file.new_path, updated))
      created = created + 1
    } else {
      let index = old_index.unwrap()
      working[index] = TextFile::new(file.new_path, updated)
      modified = modified + 1
      if file.is_path_change() {
        moved = moved + 1
      }
    }
  }
  let final_inventory = FileInventory::new(sort_inventory(working)).unwrap()
  Ok({
    inventory: final_inventory,
    hunks: all_hunks,
    files_created: created,
    files_modified: modified,
    files_deleted: deleted,
    paths_changed: moved,
    additions,
    deletions,
  })
}
