///|
fn trim_trailing_cr(value : String) -> String {
  if value.has_suffix("\r") {
    value[:value.length() - 1].to_owned()
  } else {
    value
  }
}

///|
fn split_patch_lines(source : String) -> Array[String] {
  source
  .split("\n")
  .map(fn(line) { trim_trailing_cr(line.to_owned()) })
  .collect()
}

///|
fn detect_line_ending(source : String) -> LineEnding {
  if source.contains("\r\n") {
    CrLf
  } else {
    Lf
  }
}

///|
fn line_ending_text(ending : LineEnding) -> String {
  match ending {
    Lf => "\n"
    CrLf => "\r\n"
  }
}

///|
fn strip_path_prefix(path : String) -> String {
  if path.has_prefix("a/") || path.has_prefix("b/") {
    path[2:].to_owned()
  } else {
    path
  }
}

///|
fn parse_header_path(value : String) -> String {
  let raw = match value[:].find("\t") {
    Some(index) => value[:index].to_owned()
    None => value
  }
  strip_path_prefix(raw)
}

///|
fn is_safe_path(path : String) -> Bool {
  if path == "/dev/null" {
    return true
  }
  if path.is_empty() || path.has_prefix("/") || path.contains("\\") {
    return false
  }
  let parts = path.split("/")
  for part in parts {
    if part.is_empty() || part == "." || part == ".." {
      return false
    }
  }
  true
}
