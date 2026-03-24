import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/about/domain/models/photo_item.dart';
import 'package:john_estacio_website/features/about/presentation/widgets/storage_backed_image.dart';
import 'package:john_estacio_website/theme.dart';

class BioPhotoViewerDialog extends StatelessWidget {
  final BioPhotoItem item;
  const BioPhotoViewerDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.black,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 720;
                return isWide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: StorageBackedImage(item: item, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.title.isNotEmpty)
                                    Text(item.title, style: Theme.of(context).textTheme.headlineLarge),
                                  if (item.title.isNotEmpty) const SizedBox(height: 8),
                                  if (item.description.isNotEmpty)
                                    Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: StorageBackedImage(item: item, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (item.title.isNotEmpty)
                              Text(item.title, style: Theme.of(context).textTheme.headlineLarge),
                            if (item.title.isNotEmpty) const SizedBox(height: 8),
                            if (item.description.isNotEmpty)
                              Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      );
              },
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppTheme.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          )
        ],
      ),
    );
  }
}
