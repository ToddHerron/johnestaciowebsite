// lib/core/utils/file_proxy.dart

import 'package:john_estacio_website/core/constants/app_constants.dart';

class FileProxy {
  FileProxy._();

  /// Builds a URL for the file proxy that works across environments:
  /// - If running on your Firebase Hosting origin, returns a same-origin path
  ///   like "/fileProxy?url=...&filename=..." so Safari Private Relay treats it
  ///   as first‑party.
  /// - If running on a different origin (e.g., Dreamflow Preview/Share), falls back
  ///   to the absolute Cloud Function URL to avoid SPA routing catching the path.
  /// - If no Hosting origin is configured, also use the Cloud Function URL.
  static Uri build(String targetUrl, {String? filename}) {
    final query = <String, String>{'url': targetUrl};

    // Be defensive: filename might come from dynamic sources; coerce to String safely
    final safeFilename = (filename ?? '').toString().trim();
    if (safeFilename.isNotEmpty) {
      query['filename'] = safeFilename;
    }

    final currentOrigin = _originOf(Uri.base);
    final hostingOrigin = AppConstants.fileProxyHostingOrigin.trim();

    if (hostingOrigin.isNotEmpty) {
      if (currentOrigin == hostingOrigin) {
        // Same-origin path; Hosting rewrite serves the proxy.
        return Uri(path: AppConstants.fileProxyPath, queryParameters: query);
      }
      // When not on Hosting, prefer calling the Cloud Function directly to avoid
      // SPA routers on the Hosting site intercepting and returning index.html.
      return Uri.parse(AppConstants.fileProxyFunctionUrl)
          .replace(queryParameters: query);
    }

    // Fallback to the Cloud Function URL if no hosting origin is provided.
    return Uri.parse(AppConstants.fileProxyFunctionUrl).replace(queryParameters: query);
  }

  static String _originOf(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static String _joinPaths(String a, String b) {
    final left = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
    final right = b.startsWith('/') ? b.substring(1) : b;
    return '$left/$right';
  }
}
