import 'dart:html' as html;

/// Web implementation to save a string as a downloadable file via a temporary
/// anchor element and Blob URL. Returns true if the download was triggered.
bool downloadStringAsFile(String content, String filename, {String mimeType = 'text/plain'}) {
  try {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}