import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/discography/presentation/widgets/iframe_view.dart';

class EmbedViewerDialog extends StatelessWidget {
  final String embedCode;
  final String? title;

  const EmbedViewerDialog({
    super.key,
    required this.embedCode,
    this.title,
  });

  double _extractWidth(String html) {
    final regex = RegExp(r'width="([^"]+)"', caseSensitive: false);
    final match = regex.firstMatch(html);
    return double.tryParse(match?.group(1) ?? '800') ?? 800;
  }

  double _extractHeight(String html) {
    final regex = RegExp(r'height="([^"]+)"', caseSensitive: false);
    final match = regex.firstMatch(html);
    return double.tryParse(match?.group(1) ?? '600') ?? 600;
  }

  @override
  Widget build(BuildContext context) {
    final width = _extractWidth(embedCode);
    final height = _extractHeight(embedCode);

    return AlertDialog(
      title: title != null && title!.isNotEmpty ? Text(title!) : null,
      contentPadding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
      content: IframeView(
        htmlContent: embedCode,
        width: width,
        height: height,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}