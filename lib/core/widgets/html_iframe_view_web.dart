import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui; // platformViewRegistry
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Creates a data: URL from raw bytes with a given MIME type.
/// Works well for iframe embedding inside the app.
String createObjectUrlFromBytes(Uint8List bytes, {String mimeType = 'application/pdf'}) {
  final b64 = base64Encode(bytes);
  return 'data:$mimeType;base64,$b64';
}

/// No-op for data URLs
void revokeObjectUrl(String url) {}

/// Triggers a browser download for the provided bytes (web only).
void downloadBytesAsFile(Uint8List bytes, String filename, {String mimeType = 'application/pdf'}) {
  final href = createObjectUrlFromBytes(bytes, mimeType: mimeType);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = href;
  anchor.download = filename;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
class HtmlIframeView extends StatefulWidget {
  final String src;
  final double? width;
  final double? height;
  final String? title;

  const HtmlIframeView({super.key, required this.src, this.width, this.height, this.title});

  @override
  State<HtmlIframeView> createState() => _HtmlIframeViewState();
}

class _HtmlIframeViewState extends State<HtmlIframeView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'core-html-iframe-${UniqueKey()}';

    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper = web.document.createElement('div') as web.HTMLDivElement;
      wrapper.style.width = '100%';
      wrapper.style.height = '100%';
      wrapper.style.backgroundColor = 'transparent';

      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = widget.src;
      iframe.title = widget.title ?? 'embedded content';
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'fullscreen';

      wrapper.appendChild(iframe);
      return wrapper;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
