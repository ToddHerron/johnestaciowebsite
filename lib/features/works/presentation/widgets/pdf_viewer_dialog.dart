// pdf_viewer_dialog.dart
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:http/http.dart' as http;
import 'package:john_estacio_website/core/widgets/html_iframe_view.dart';

class PdfViewerDialog extends StatelessWidget {
  final String pdfUrl; // Can be https:// or gs:// Firebase Storage URL
  final String? storagePath; // Optional explicit storage path like "stored_files/foo.pdf"
  final String title;

  const PdfViewerDialog({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.storagePath,
  });

  Future<String> _resolvePdfHttpsUrl() async {
    final storage = FirebaseStorage.instance;
    if ((storagePath != null && storagePath!.trim().isNotEmpty) || pdfUrl.startsWith('gs://')) {
      final Reference ref = storagePath != null && storagePath!.trim().isNotEmpty
          ? storage.ref(storagePath)
          : storage.refFromURL(pdfUrl);
      final url = await ref.getDownloadURL();
      return url;
    }
    // Already an https URL
    return pdfUrl;
  }

  Future<Uint8List> _loadPdfBytes() async {
    final url = await _resolvePdfHttpsUrl();
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      return resp.bodyBytes;
    }
    throw Exception('Failed to load PDF: HTTP ${resp.statusCode}');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = (size.width * 0.9).clamp(360.0, 1400.0);
    final height = (size.height * 0.9).clamp(360.0, 1400.0);

    return Dialog(
      backgroundColor: AppTheme.darkGray,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width, height: height),
        child: Column(
          children: [
            _DialogTitleBar(title: title),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _loadPdfBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryOrange),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load PDF.',
                              textAlign: TextAlign.center,
                              style: AppTheme.theme.textTheme.bodyLarge?.copyWith(color: AppTheme.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final bytes = snapshot.data!;

                  if (kIsWeb) {
                    // On web, avoid pdfrx's PDFium WASM requirement by embedding directly via iframe
                    final dataUrl = createObjectUrlFromBytes(bytes, mimeType: 'application/pdf');
                    return HtmlIframeView(
                      src: dataUrl,
                      title: title.isNotEmpty ? title : 'PDF document',
                    );
                  }

                  // Native platforms: use pdfrx viewer
                  return PdfViewer.data(
                    bytes,
                    sourceName: title.isNotEmpty ? title : 'PDF document',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogTitleBar extends StatelessWidget {
  final String title;
  const _DialogTitleBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkGray,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: AppTheme.white)),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppTheme.primaryOrange),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
