import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/public_page_scaffold.dart';
import 'package:john_estacio_website/features/about/data/photo_gallery_repository.dart';
import 'package:john_estacio_website/features/about/presentation/widgets/bio_photo_gallery.dart';
import 'package:john_estacio_website/theme.dart';

class PhotosPage extends StatelessWidget {
  const PhotosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photos',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.darkGray,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BioPhotoGallery(
                repository: PhotoGalleryRepository(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
