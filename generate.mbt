///|
pub struct DiffOptions {
  max_cells : Int
  line_ending : LineEnding
} derive(Eq, @debug.Debug)

///|
pub fn DiffOptions::new(
  max_cells? : Int = 4000000,
  line_ending? : LineEnding = Lf,
) -> Result[DiffOptions, Diagnostic] {
  if max_cells < 1 || max_cells > 16000000 {
    Err(
      Diagnostic::new(
        "diff.cells.limit",
        "options.max_cells",
        "LCS cell limit is outside the safety range",
        "1 through 16000000",
        max_cells.to_string(),
      ),
    )
  } else {
    Ok({ max_cells, line_ending })
  }
}

///|
pub fn DiffOptions::max_cells(self : DiffOptions) -> Int {
  self.max_cells
}

///|
pub fn DiffOptions::line_ending(self : DiffOptions) -> LineEnding {
  self.line_ending
}

///|
fn lcs_index(row : Int, column : Int, width : Int) -> Int {
  row * width + column
}

///|
fn lines_match(
  old : TextDocument,
  new : TextDocument,
  old_index : Int,
  new_index : Int,
) -> Bool {
  if old.lines[old_index] != new.lines[new_index] {
    return false
  }
  let old_last = old_index == old.lines.length() - 1
  let new_last = new_index == new.lines.length() - 1
  if old_last && new_last && old.final_newline != new.final_newline {
    false
  } else {
    true
  }
}

///|
fn mark_no_newline(
  line : ChangeLine,
  old : TextDocument,
  new : TextDocument,
  old_index : Int,
  new_index : Int,
) -> ChangeLine {
  let no_newline = match line.kind {
    Context => old_index == old.lines.length() - 1 && !old.final_newline
    Deletion => old_index == old.lines.length() - 1 && !old.final_newline
    Addition => new_index == new.lines.length() - 1 && !new.final_newline
  }
  ChangeLine::new(line.kind, line.text, no_newline~)
}

///|
fn build_changes(
  old : TextDocument,
  new : TextDocument,
  max_cells : Int,
) -> Result[Array[ChangeLine], Diagnostic] {
  let height = old.lines.length() + 1
  let width = new.lines.length() + 1
  if height > max_cells / width {
    return Err(
      Diagnostic::new(
        "diff.cells.exceeded",
        "texts",
        "input pair exceeds the configured LCS work limit",
        "at most " + max_cells.to_string() + " cells",
        (height * width).to_string() + " cells",
      ),
    )
  }
  let table = Array::make(height * width, 0)
  for old_index = old.lines.length() - 1
      old_index >= 0
      old_index = old_index - 1 {
    for new_index = new.lines.length() - 1
        new_index >= 0
        new_index = new_index - 1 {
      let index = lcs_index(old_index, new_index, width)
      if lines_match(old, new, old_index, new_index) {
        table[index] = table[lcs_index(old_index + 1, new_index + 1, width)] + 1
      } else {
        let skip_old = table[lcs_index(old_index + 1, new_index, width)]
        let skip_new = table[lcs_index(old_index, new_index + 1, width)]
        table[index] = if skip_old >= skip_new { skip_old } else { skip_new }
      }
    }
  }
  let result = []
  let mut old_index = 0
  let mut new_index = 0
  while old_index < old.lines.length() || new_index < new.lines.length() {
    if old_index < old.lines.length() &&
      new_index < new.lines.length() &&
      lines_match(old, new, old_index, new_index) {
      result.push(
        mark_no_newline(
          ChangeLine::new(Context, old.lines[old_index]),
          old,
          new,
          old_index,
          new_index,
        ),
      )
      old_index = old_index + 1
      new_index = new_index + 1
    } else if old_index < old.lines.length() &&
      (
        new_index == new.lines.length() ||
        table[lcs_index(old_index + 1, new_index, width)] >=
        table[lcs_index(old_index, new_index + 1, width)]
      ) {
      result.push(
        mark_no_newline(
          ChangeLine::new(Deletion, old.lines[old_index]),
          old,
          new,
          old_index,
          new_index,
        ),
      )
      old_index = old_index + 1
    } else {
      result.push(
        mark_no_newline(
          ChangeLine::new(Addition, new.lines[new_index]),
          old,
          new,
          old_index,
          new_index,
        ),
      )
      new_index = new_index + 1
    }
  }
  Ok(result)
}

///|
pub fn diff_text(
  old_path : String,
  old_content : String,
  new_path : String,
  new_content : String,
  options? : DiffOptions = { max_cells: 4000000, line_ending: Lf },
) -> Result[PatchSet, Diagnostic] {
  if !is_safe_path(old_path) || !is_safe_path(new_path) {
    return Err(
      Diagnostic::new(
        "diff.path.unsafe",
        "paths",
        "diff path is not safe",
        "relative normalized path",
        old_path + " -> " + new_path,
      ),
    )
  }
  if old_content == new_content && old_path == new_path {
    return Err(
      Diagnostic::new(
        "diff.unchanged", "texts", "old and new inputs are identical", "a content or path change",
        "no change",
      ),
    )
  }
  let old_document = parse_document(old_content)
  let new_document = parse_document(new_content)
  let changes = match
    build_changes(old_document, new_document, options.max_cells) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let old_start = if old_document.lines.is_empty() { 0 } else { 1 }
  let new_start = if new_document.lines.is_empty() { 0 } else { 1 }
  let hunk = Hunk::new(
    old_start,
    old_document.lines.length(),
    new_start,
    new_document.lines.length(),
    "",
    changes,
  )
  let old_label = if old_path == "/dev/null" {
    old_path
  } else {
    "a/" + old_path
  }
  let new_label = if new_path == "/dev/null" {
    new_path
  } else {
    "b/" + new_path
  }
  let patch = PatchSet::new(
    [FilePatch::new(old_path, new_path, old_label, new_label, [hunk])],
    line_ending=options.line_ending,
  )
  match patch.validate() {
    Ok(_) => Ok(patch)
    Err(error) => Err(error)
  }
}

///|
pub fn diff_file(
  old : TextFile,
  new : TextFile,
  options? : DiffOptions = { max_cells: 4000000, line_ending: Lf },
) -> Result[PatchSet, Diagnostic] {
  diff_text(old.path, old.content, new.path, new.content, options~)
}

///|
pub fn create_file(
  path : String,
  content : String,
  options? : DiffOptions = { max_cells: 4000000, line_ending: Lf },
) -> Result[PatchSet, Diagnostic] {
  diff_text("/dev/null", "", path, content, options~)
}

///|
pub fn delete_file(
  path : String,
  content : String,
  options? : DiffOptions = { max_cells: 4000000, line_ending: Lf },
) -> Result[PatchSet, Diagnostic] {
  diff_text(path, content, "/dev/null", "", options~)
}
