///|
pub struct PatchStats {
  files : Int
  hunks : Int
  context_lines : Int
  additions : Int
  deletions : Int
  creations : Int
  removals : Int
  path_changes : Int
} derive(Eq, @debug.Debug)

///|
pub fn PatchStats::files(self : PatchStats) -> Int {
  self.files
}

///|
pub fn PatchStats::hunks(self : PatchStats) -> Int {
  self.hunks
}

///|
pub fn PatchStats::context_lines(self : PatchStats) -> Int {
  self.context_lines
}

///|
pub fn PatchStats::additions(self : PatchStats) -> Int {
  self.additions
}

///|
pub fn PatchStats::deletions(self : PatchStats) -> Int {
  self.deletions
}

///|
pub fn PatchStats::creations(self : PatchStats) -> Int {
  self.creations
}

///|
pub fn PatchStats::removals(self : PatchStats) -> Int {
  self.removals
}

///|
pub fn PatchStats::path_changes(self : PatchStats) -> Int {
  self.path_changes
}

///|
pub fn PatchStats::changed_lines(self : PatchStats) -> Int {
  self.additions + self.deletions
}

///|
pub fn PatchSet::stats(self : PatchSet) -> PatchStats {
  let mut hunks = 0
  let mut context_lines = 0
  let mut additions = 0
  let mut deletions = 0
  let mut creations = 0
  let mut removals = 0
  let mut path_changes = 0
  for file in self.files {
    if file.is_creation() {
      creations = creations + 1
    }
    if file.is_deletion() {
      removals = removals + 1
    }
    if file.is_path_change() {
      path_changes = path_changes + 1
    }
    hunks = hunks + file.hunks.length()
    for hunk in file.hunks {
      for line in hunk.lines {
        match line.kind {
          Context => context_lines = context_lines + 1
          Addition => additions = additions + 1
          Deletion => deletions = deletions + 1
        }
      }
    }
  }
  {
    files: self.files.length(),
    hunks,
    context_lines,
    additions,
    deletions,
    creations,
    removals,
    path_changes,
  }
}

///|
pub fn PatchSet::validate(self : PatchSet) -> Result[Unit, Diagnostic] {
  let source_keys : Array[String] = []
  let target_keys : Array[String] = []
  for file_index, file in self.files {
    let location = "files[" + file_index.to_string() + "]"
    if !file.is_creation() {
      for key in source_keys {
        if key == file.old_path {
          return Err(
            Diagnostic::new(
              "patch.path.duplicate_source",
              location + ".old_path",
              "multiple file patches consume the same source",
              "unique source path",
              file.old_path,
            ),
          )
        }
      }
      source_keys.push(file.old_path)
    }
    if !file.is_deletion() {
      for key in target_keys {
        if key == file.new_path {
          return Err(
            Diagnostic::new(
              "patch.path.duplicate_target",
              location + ".new_path",
              "multiple file patches produce the same target",
              "unique target path",
              file.new_path,
            ),
          )
        }
      }
      target_keys.push(file.new_path)
    }
    let mut old_end = 0
    let mut new_end = 0
    for hunk_index, hunk in file.hunks {
      let hunk_location = location + ".hunks[" + hunk_index.to_string() + "]"
      let old_position = if hunk.old_count == 0 {
        hunk.old_start
      } else {
        hunk.old_start - 1
      }
      let new_position = if hunk.new_count == 0 {
        hunk.new_start
      } else {
        hunk.new_start - 1
      }
      if hunk_index > 0 && (old_position < old_end || new_position < new_end) {
        return Err(
          Diagnostic::new(
            "patch.hunk.order",
            hunk_location,
            "hunks overlap or are out of source order",
            "monotonic non-overlapping ranges",
            hunk.old_start.to_string() + " -> " + hunk.new_start.to_string(),
          ),
        )
      }
      let mut changed = false
      for line in hunk.lines {
        if line.kind != Context {
          changed = true
        }
      }
      if !changed && !file.is_path_change() {
        return Err(
          Diagnostic::new(
            "patch.hunk.empty_change", hunk_location, "hunk contains context but no change",
            "at least one addition or deletion", "context only",
          ),
        )
      }
      old_end = old_position + hunk.old_count
      new_end = new_position + hunk.new_count
    }
  }
  Ok(())
}
