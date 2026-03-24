import 'package:firebase_storage/firebase_storage.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/domain/stored_file_model.dart';

class StoredFilesRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Simple in-memory cache to avoid repeated listAll() calls
  static List<StoredFile>? _cache;
  static DateTime? _lastFetch;

  Future<List<StoredFile>> listFiles({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final isFresh = _lastFetch != null && now.difference(_lastFetch!) < const Duration(minutes: 5);

    if (!forceRefresh && isFresh && _cache != null) {
      return _cache!;
    }

    try {
      final path = 'users/vzAXwY46qHNpWZt0H203RZxq0mv1/uploads';
      final listResult = await _storage.ref(path).listAll();
      
      final filesWithMetadata = await Future.wait(
        listResult.items.map((ref) async {
          final metadata = await ref.getMetadata();
          return StoredFile(ref: ref, metadata: metadata);
        }).toList(),
      );
      
      // Sort by custom title if present, else by filename
      filesWithMetadata.sort((a, b) {
        final at = (a.title.isNotEmpty ? a.title : a.ref.name).toLowerCase();
        final bt = (b.title.isNotEmpty ? b.title : b.ref.name).toLowerCase();
        return at.compareTo(bt);
      });

      _cache = filesWithMetadata;
      _lastFetch = now;
      return filesWithMetadata;
    } catch (e) {
      print('Error listing files: $e');
      rethrow;
    }
  }

  Future<void> updateFileTitle(Reference ref, String title) async {
    try {
      await ref.updateMetadata(SettableMetadata(
        customMetadata: {'title': title},
      ));
      // Invalidate cache so next fetch reflects the change
      _cache = null;
      _lastFetch = null;
    } catch (e) {
      print('Error updating file title: $e');
      rethrow;
    }
  }

  /// Deletes a file from Firebase Cloud Storage.
  Future<void> deleteFile(Reference ref) async {
    try {
      await ref.delete();
      // Evict deleted item from cache if present
      _cache?.removeWhere((f) => f.ref.fullPath == ref.fullPath);
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }
}
