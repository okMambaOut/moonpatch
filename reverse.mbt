///|
fn reverse_line(line : ChangeLine) -> ChangeLine {
  let kind = match line.kind {
    Context => Context
    Addition => Deletion
    Deletion => Addition
  }
  ChangeLine::new(kind, line.text, no_newline=line.no_newline)
}

///|
pub fn PatchSet::reverse(self : PatchSet) -> PatchSet {
  let files = []
  for file in self.files {
    let hunks = []
    for hunk in file.hunks {
      hunks.push(
        Hunk::new(
          hunk.new_start,
          hunk.new_count,
          hunk.old_start,
          hunk.old_count,
          hunk.section,
          hunk.lines.map(reverse_line),
        ),
      )
    }
    files.push(
      FilePatch::new(
        file.new_path,
        file.old_path,
        file.new_label,
        file.old_label,
        hunks,
      ),
    )
  }
  PatchSet::new(files, line_ending=self.line_ending)
}
