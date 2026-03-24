import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/about/data/photo_gallery_repository.dart';
import 'package:john_estacio_website/features/about/domain/models/photo_item.dart';
import 'package:john_estacio_website/features/about/presentation/widgets/bio_photo_viewer_dialog.dart';
import 'package:john_estacio_website/features/about/presentation/widgets/storage_backed_image.dart';
import 'package:john_estacio_website/theme.dart';

class BioPhotoGallery extends StatelessWidget {
  final PhotoGalleryRepository repository;
  const BioPhotoGallery({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BioPhotoItem>>(
      stream: repository.streamPublic(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText('Error loading photos: ${snapshot.error}'),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Text('No photos yet. Check back soon.', style: TextStyle(color: AppTheme.lightGray)),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int columns = 1;
            if (width >= 1200) {
              columns = 4;
            } else if (width >= 900) {
              columns = 3;
            } else if (width >= 600) {
              columns = 2;
            }

            // Distribute items into columns (round-robin) to create a masonry-like vertical column layout.
            final List<List<BioPhotoItem>> columnItems = List.generate(columns, (_) => []);
            for (int i = 0; i < items.length; i++) {
              columnItems[i % columns].add(items[i]);
            }

            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(columns * 2 - 1, (i) {
                  if (i.isOdd) {
                    // Gap between columns
                    return const SizedBox(width: 16);
                  }
                  final colIndex = i ~/ 2;
                  return Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in columnItems[colIndex]) ...[
                          _GalleryCard(item: item),
                          const SizedBox(height: 16),
                        ]
                      ],
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final BioPhotoItem item;
  const _GalleryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => BioPhotoViewerDialog(item: item),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkGray,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: StorageBackedImage(
                item: item,
                // Ensure the image occupies full card width and keeps its
                // intrinsic aspect ratio so nothing is cropped.
                fit: BoxFit.fitWidth,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.title.isNotEmpty) ...[
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (item.description.isNotEmpty)
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: AppTheme.lightGray,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
