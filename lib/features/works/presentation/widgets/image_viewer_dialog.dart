import 'package:flutter/material.dart';

class ImageViewerDialog extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  const ImageViewerDialog({super.key, required this.imageUrl, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final content = InteractiveViewer(
      child: Image.network(
        imageUrl,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Text('Could not load image.'));
        },
      ),
    );

    return Dialog(
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          if (width != null || height != null)
            SizedBox(width: width, height: height, child: content)
          else
            content,
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}