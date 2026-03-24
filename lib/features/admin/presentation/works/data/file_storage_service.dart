import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FileStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Method now returns the UploadTask directly
  UploadTask uploadFile(Uint8List fileBytes, String fileName) {
    final userUid = 'vzAXwY46qHNpWZt0H203RZxq0mv1';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueFileName = '$timestamp-$fileName';
    final path = 'users/$userUid/uploads/$uniqueFileName';

    final ref = _storage.ref(path);
    final uploadTask = ref.putData(
      fileBytes,
      SettableMetadata(contentType: _getMimeType(fileName)),
    );

    return uploadTask;
  }

  String? _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';

    // images
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    if (lower.endsWith('.svg')) return 'image/svg+xml';

    return null;
  }

  Future<String> getDownloadUrl(TaskSnapshot snapshot) {
    return snapshot.ref.getDownloadURL();
  }
}