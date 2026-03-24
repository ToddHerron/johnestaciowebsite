import 'package:firebase_storage/firebase_storage.dart';

class StoredFile {
  final Reference ref;
  final FullMetadata metadata;

  StoredFile({required this.ref, required this.metadata});

  // Helper getter to safely access the title from the custom metadata map
  String get title => metadata.customMetadata?['title'] ?? '';
}