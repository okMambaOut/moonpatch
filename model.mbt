///|
pub enum LineEnding {
  Lf
  CrLf
} derive(Eq, @debug.Debug)

///|
pub enum ChangeKind {
  Context
  Addition
  Deletion
} derive(Eq, @debug.Debug)

///|
pub struct ChangeLine {
  kind : ChangeKind
  text : String
  no_newline : Bool
} derive(Eq, @debug.Debug)

///|
pub fn ChangeLine::new(
  kind : ChangeKind,
  text : String,
  no_newline? : Bool = false,
) -> ChangeLine {
  { kind, text, no_newline }
}

///|
pub fn ChangeLine::kind(self : ChangeLine) -> ChangeKind {
  self.kind
}

///|
pub fn ChangeLine::text(self : ChangeLine) -> String {
  self.text
}

///|
pub fn ChangeLine::has_no_newline_marker(self : ChangeLine) -> Bool {
  self.no_newline
}

///|
pub struct Hunk {
  old_start : Int
  old_count : Int
  new_start : Int
  new_count : Int
  section : String
  lines : Array[ChangeLine]
} derive(Eq, @debug.Debug)

///|
pub fn Hunk::new(
  old_start : Int,
  old_count : Int,
  new_start : Int,
  new_count : Int,
  section : String,
  lines : Array[ChangeLine],
) -> Hunk {
  { old_start, old_count, new_start, new_count, section, lines }
}

///|
pub fn Hunk::old_start(self : Hunk) -> Int {
  self.old_start
}

///|
pub fn Hunk::old_count(self : Hunk) -> Int {
  self.old_count
}

///|
pub fn Hunk::new_start(self : Hunk) -> Int {
  self.new_start
}

///|
pub fn Hunk::new_count(self : Hunk) -> Int {
  self.new_count
}

///|
pub fn Hunk::section(self : Hunk) -> String {
  self.section
}

///|
pub fn Hunk::lines(self : Hunk) -> Array[ChangeLine] {
  self.lines.copy()
}

///|
pub struct FilePatch {
  old_path : String
  new_path : String
  old_label : String
  new_label : String
  hunks : Array[Hunk]
} derive(Eq, @debug.Debug)

///|
pub fn FilePatch::new(
  old_path : String,
  new_path : String,
  old_label : String,
  new_label : String,
  hunks : Array[Hunk],
) -> FilePatch {
  { old_path, new_path, old_label, new_label, hunks }
}

///|
pub fn FilePatch::old_path(self : FilePatch) -> String {
  self.old_path
}

///|
pub fn FilePatch::new_path(self : FilePatch) -> String {
  self.new_path
}

///|
pub fn FilePatch::old_label(self : FilePatch) -> String {
  self.old_label
}

///|
pub fn FilePatch::new_label(self : FilePatch) -> String {
  self.new_label
}

///|
pub fn FilePatch::hunks(self : FilePatch) -> Array[Hunk] {
  self.hunks.copy()
}

///|
pub fn FilePatch::is_creation(self : FilePatch) -> Bool {
  self.old_path == "/dev/null"
}

///|
pub fn FilePatch::is_deletion(self : FilePatch) -> Bool {
  self.new_path == "/dev/null"
}

///|
pub fn FilePatch::is_path_change(self : FilePatch) -> Bool {
  !self.is_creation() && !self.is_deletion() && self.old_path != self.new_path
}

///|
pub struct PatchSet {
  files : Array[FilePatch]
  line_ending : LineEnding
} derive(Eq, @debug.Debug)

///|
pub fn PatchSet::new(
  files : Array[FilePatch],
  line_ending? : LineEnding = Lf,
) -> PatchSet {
  { files, line_ending }
}

///|
pub fn PatchSet::files(self : PatchSet) -> Array[FilePatch] {
  self.files.copy()
}

///|
pub fn PatchSet::line_ending(self : PatchSet) -> LineEnding {
  self.line_ending
}
