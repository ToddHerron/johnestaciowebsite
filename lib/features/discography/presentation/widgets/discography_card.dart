import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:john_estacio_website/features/discography/domain/models/discography_model.dart';
import 'package:john_estacio_website/features/discography/presentation/widgets/iframe_view.dart';
import 'package:john_estacio_website/theme.dart';

class DiscographyCard extends StatelessWidget {
  final DiscographyItem item;

  const DiscographyCard({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final hasIframe = item.embedHtml.toLowerCase().contains('<iframe');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryOrange,
                  ),
            ),
            const SizedBox(height: 16),
            if (hasIframe)
              _EmbedWebContent(html: item.embedHtml)
            else
              Html(
                data: item.embedHtml,
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmbedWebContent extends StatelessWidget {
  final String html;
  const _EmbedWebContent({required this.html});

  double _extractHeight(String html) {
    final heightAttr = RegExp(r'height\s*=\s*"(\d+)"', caseSensitive: false).firstMatch(html);
    if (heightAttr != null) {
      return double.tryParse(heightAttr.group(1) ?? '') ?? 360;
    }
    final styleHeight = RegExp(r'height\s*:\s*(\d+)px', caseSensitive: false).firstMatch(html);
    if (styleHeight != null) {
      return double.tryParse(styleHeight.group(1) ?? '') ?? 360;
    }
    return 360;
  }

  double? _extractWidth(String html) {
    final widthAttr = RegExp(r'width\s*=\s*"(\d+)"', caseSensitive: false).firstMatch(html);
    if (widthAttr != null) {
      return double.tryParse(widthAttr.group(1) ?? '');
    }
    final styleWidth = RegExp(r'width\s*:\s*(\d+)px', caseSensitive: false).firstMatch(html);
    if (styleWidth != null) {
      return double.tryParse(styleWidth.group(1) ?? '');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final targetHeight = _extractHeight(html);
    final targetWidth = _extractWidth(html);

    // For web, use the unified IframeView which handles HtmlElementView.
    if (kIsWeb) {
      return Align(
        alignment: Alignment.centerLeft,
        child: IframeView(
          htmlContent: html,
          height: targetHeight,
          width: targetWidth,
        ),
      );
    }

    // For mobile, use the WebView implementation.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadHtmlString(
          '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body { margin: 0; padding: 0; background: transparent; }
      .container { display: flex; justify-content: center; }
    </style>
  </head>
  <body>
    <div class="container">$html</div>
  </body>
</html>
''',
        );

      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: targetHeight,
          width: targetWidth ?? double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: WebViewWidget(controller: controller),
          ),
        ),
      );
    }

    // Fallback for other platforms.
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: targetHeight,
        width: targetWidth ?? double.infinity,
        child: const Center(
          child: Text('Preview not supported on this platform.'),
        ),
      ),
    );
  }
}