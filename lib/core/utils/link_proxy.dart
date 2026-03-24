// lib/core/utils/link_proxy.dart

import 'package:john_estacio_website/core/constants/app_constants.dart';

class LinkProxy {
  LinkProxy._();

  /// Builds the Cloud Function URL that will handle opening/redirecting to [targetUrl].
  /// Optionally include a [filename] hint for content-disposition where supported.
  ///
  /// We append `redirect=1` so that when this URL is opened in a new browser tab,
  /// the Cloud Function issues an HTTP redirect to the final resource instead of
  /// returning JSON.
  static Uri build(String targetUrl, {String? filename}) {
    final encodedUrl = Uri.encodeComponent(targetUrl);
    final safeFilename = (filename ?? '').toString().trim();
    final filenamePart = safeFilename.isNotEmpty
        ? '&filename=${Uri.encodeComponent(safeFilename)}'
        : '';
    final full = '${AppConstants.linkProxyUrl}?url=$encodedUrl$filenamePart&redirect=1';
    return Uri.parse(full);
  }
}
