import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:john_estacio_website/features/about/domain/models/photo_item.dart';

class StorageBackedImage extends StatelessWidget {
  final BioPhotoItem item;
  final BoxFit fit;
  final Alignment alignment;

  const StorageBackedImage({super.key, required this.item, this.fit = BoxFit.cover, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl.isNotEmpty) {
      return Image.network(item.imageUrl, fit: fit, alignment: alignment);
    }
    if (item.storagePath.isEmpty) {
      return const Center(child: Icon(Icons.broken_image));
    }
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(item.storagePath).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          return const Center(child: Icon(Icons.broken_image));
        }
        return Image.network(snapshot.data!, fit: fit, alignment: alignment);
      },
    );
  }
}
