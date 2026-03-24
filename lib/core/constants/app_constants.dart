// lib/core/constants/app_constants.dart

class AppConstants {
  // Cloud Function URLs
  static const String imageProxyUrl = 'https://us-central1-moonlitely-entertainmen-xt654z.cloudfunctions.net/imageProxy';
  static const String linkProxyUrl = 'https://us-central1-moonlitely-entertainmen-xt654z.cloudfunctions.net/linkProxy';

  // File proxy configuration
  // If you have Firebase Hosting set up with a rewrite for "/fileProxy",
  // set this to your hosting origin (e.g., https://your-site.web.app or https://www.yourdomain.com).
  // When empty, the app will fall back to the Cloud Function URL.
  static const String fileProxyHostingOrigin = 'https://moonlitely-entertainmen-xt654z.web.app';

  // Cloud Functions fallback and Hosting path
  static const String fileProxyFunctionUrl = 'https://us-central1-moonlitely-entertainmen-xt654z.cloudfunctions.net/fileProxy';
  static const String fileProxyPath = '/fileProxy';

  // Google Apps Script Web App for sending emails (Score Requests)
  // Deployed with secret passed as query parameter. Rotate if compromised.
  static const String googleAppsScriptEmailUrl =
      'https://script.google.com/macros/s/AKfycbyJ6jZTzkPysn-29Tjvqx2tMFlNmEoaDwMrI_1aMeZ13X8_XOvAwt5LFwNd86dMtdREsQ/exec?secret=dreamflow-secure-0066bondjohnbond';

  // Private constructor to prevent instantiation
  AppConstants._();
}