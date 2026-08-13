///|
pub struct TextFile {
  path : String
  content : String
} derive(Eq, @debug.Debug)

///|
pub fn TextFile::new(path : String, content : String) -> TextFile {
  { path, content }
}

///|
pub fn TextFile::path(self : TextFile) -> String {
  self.path
}

///|
pub fn TextFile::content(self : TextFile) -> String {
  self.content
}

///|
pub struct FileInventory {
  files : Array[TextFile]
} derive(Eq, @debug.Debug)

///|
pub fn FileInventory::new(
  files : Array[TextFile],
) -> Result[FileInventory, Diagnostic] {
  let checked : Array[TextFile] = []
  for index, file in files {
    if !is_safe_path(file.path) || file.path == "/dev/null" {
      return Err(
        Diagnostic::new(
          "inventory.path.unsafe",
          "files[" + index.to_string() + "].path",
          "inventory path is not safe",
          "relative normalized path",
          file.path,
        ),
      )
    }
    for previous in checked {
      if previous.path == file.path {
        return Err(
          Diagnostic::new(
            "inventory.path.duplicate",
            "files[" + index.to_string() + "].path",
            "inventory contains the same path twice",
            "unique path",
            file.path,
          ),
        )
      }
    }
    checked.push(file)
  }
  Ok({ files: checked })
}

///|
pub fn FileInventory::files(self : FileInventory) -> Array[TextFile] {
  self.files.copy()
}

///|
pub fn FileInventory::get(self : FileInventory, path : String) -> TextFile? {
  for file in self.files {
    if file.path == path {
      return Some(file)
    }
  }
  None
}

///|
fn inventory_index(files : Array[TextFile], path : String) -> Int? {
  for index, file in files {
    if file.path == path {
      return Some(index)
    }
  }
  None
}

///|
fn sort_inventory(files : Array[TextFile]) -> Array[TextFile] {
  let result = files.copy()
  let mut index = 1
  while index < result.length() {
    let current = result[index]
    let mut position = index
    while position > 0 && result[position - 1].path > current.path {
      result[position] = result[position - 1]
      position = position - 1
    }
    result[position] = current
    index = index + 1
  }
  result
}
