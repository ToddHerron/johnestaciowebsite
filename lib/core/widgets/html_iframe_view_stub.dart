import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Non-web stubs
String createObjectUrlFromBytes(Uint8List bytes, {String mimeType = 'application/pdf'}) => 'about:blank';
void revokeObjectUrl(String url) {}
void downloadBytesAsFile(Uint8List bytes, String filename, {String mimeType = 'application/pdf'}) {}
class HtmlIframeView extends StatelessWidget {
  final String src;
  final double? width;
  final double? height;
  final String? title;

  const HtmlIframeView({super.key, required this.src, this.width, this.height, this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: Text('Embedded content is available on the web.'),
      ),
    );
  }
}
