/// Platform-agnostic facade for downloading content as a file.
/// Returns false when not supported on this platform.
bool downloadStringAsFile(String content, String filename, {String mimeType = 'text/plain'}) {
  return false;
}