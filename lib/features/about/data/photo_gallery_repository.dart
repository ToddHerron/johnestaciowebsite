import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as fstorage;
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/about/domain/models/photo_item.dart';

class PullProgress {
  final String currentPath;
  final int scanned;
  final int created;
  const PullProgress({required this.currentPath, required this.scanned, required this.created});
}

class PhotoGalleryRepository {
  final FirebaseFirestore _firestore;
  final String collectionPath;

  PhotoGalleryRepository({FirebaseFirestore? firestore, this.collectionPath = 'bio_gallery'})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(collectionPath);

  Future<List<BioPhotoItem>> getAll() async {
    final snapshot = await _collection.orderBy('order').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((d) => BioPhotoItem.fromFirestore(d)).toList();
  }

  // Index-safe stream with fallback: tries ordered query first, falls back to unordered + client-side sort if index is missing.
  Stream<List<BioPhotoItem>> streamAll() {
    final primary = _collection.orderBy('order').orderBy('createdAt', descending: true);
    final source = _indexSafeStream(primaryQuery: primary, publicOnly: false);
    return AppCache.instance.cacheFirstStream<List<BioPhotoItem>>('gallery_all_$collectionPath', source);
  }

  // Public-visible stream: index-safe with fallback. Shows only visible items.
  Stream<List<BioPhotoItem>> streamPublic() {
    final primary = _collection
        .where('visible', isEqualTo: true)
        .orderBy('order')
        .orderBy('createdAt', descending: true);
    final source = _indexSafeStream(primaryQuery: primary, publicOnly: true);
    return AppCache.instance.cacheFirstStream<List<BioPhotoItem>>('gallery_public_$collectionPath', source);
  }

  Stream<List<BioPhotoItem>> _indexSafeStream({
    required Query<Map<String, dynamic>> primaryQuery,
    required bool publicOnly,
  }) {
    // Live-switching stream: start with the ordered query; if Firestore throws a
    // failed-precondition (missing composite index), seamlessly switch to an
    // unordered fallback and sort client-side.
    return Stream<List<BioPhotoItem>>.multi((controller) {
      StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
      
      void listenTo(Query<Map<String, dynamic>> q, {required bool isFallback}) {
        sub = q.snapshots().listen(
          (s) {
            var items = s.docs.map((d) => BioPhotoItem.fromFirestore(d)).toList();
            if (isFallback) {
              items.sort((a, b) {
                final byOrder = a.order.compareTo(b.order);
                if (byOrder != 0) return byOrder;
                return b.createdAt.compareTo(a.createdAt);
              });
            }
            controller.add(items);
          },
          onError: (err, stack) {
            if (err is FirebaseException && err.code == 'failed-precondition') {
              // Switch to fallback (unordered + client sort)
              sub?.cancel();
              Query<Map<String, dynamic>> fallback = _collection;
              if (publicOnly) {
                fallback = fallback.where('visible', isEqualTo: true);
              }
              listenTo(fallback, isFallback: true);
            } else {
              controller.addError(err, stack);
            }
          },
          onDone: controller.close,
          cancelOnError: false,
        );
      }
      
      listenTo(primaryQuery, isFallback: false);
      controller.onCancel = () => sub?.cancel();
    });
  }

  Future<String> create({
    required String imageUrl,
    String storagePath = '',
    required String title,
    required String description,
    bool visible = true,
    int order = 0,
  }) async {
    final now = DateTime.now();
    final doc = _collection.doc();
    await doc.set({
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'title': title,
      'description': description,
      'visible': visible,
      'order': order,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    AppCache.instance.invalidate('gallery_all_$collectionPath');
    AppCache.instance.invalidate('gallery_public_$collectionPath');
    return doc.id;
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _collection.doc(id).update(updates);
    AppCache.instance.invalidate('gallery_all_$collectionPath');
    AppCache.instance.invalidate('gallery_public_$collectionPath');
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
    AppCache.instance.invalidate('gallery_all_$collectionPath');
    AppCache.instance.invalidate('gallery_public_$collectionPath');
  }

  // Pulls image files from a Firebase Storage folder and creates gallery docs for any missing ones.
  // Titles and descriptions are left blank. New items are added as not visible by default.
  // Returns the number of documents created.
  Future<int> pullFromStorageFolder(
    String folderPath, {
    void Function(PullProgress progress)? onProgress,
  }) async {
    final storage = fstorage.FirebaseStorage.instance;
    final rootRef = storage.ref(folderPath);

    // Determine starting order by finding current max order.
    final existingSnap = await _collection.get();
    int maxOrder = 0;
    for (final d in existingSnap.docs) {
      final o = d.data()['order'];
      if (o is int && o > maxOrder) maxOrder = o;
      if (o is num && o.toInt() > maxOrder) maxOrder = o.toInt();
    }

    int created = 0;
    int scanned = 0;

    Future<void> scanFolder(fstorage.Reference ref) async {
      onProgress?.call(PullProgress(currentPath: ref.fullPath, scanned: scanned, created: created));
      // Use paged listing to be safe on large folders.
      fstorage.ListResult result = await ref.list(const fstorage.ListOptions(maxResults: 1000));
      while (true) {
        // Files inside this folder
        for (final item in result.items) {
          final fullPath = item.fullPath; // e.g., users/uid/uploads/file.jpg
          // Skip non-image extensions quickly
          final lower = fullPath.toLowerCase();
          final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp') || lower.endsWith('.gif');
          if (!isImage) continue;

          scanned += 1;
          onProgress?.call(PullProgress(currentPath: fullPath, scanned: scanned, created: created));

          // Check if a doc already exists for this storagePath
          final existing = await _collection.where('storagePath', isEqualTo: fullPath).limit(1).get();
          if (existing.docs.isEmpty) {
            maxOrder += 1;
            await create(
              imageUrl: '',
              storagePath: fullPath,
              title: '',
              description: '',
              visible: false, // do not publish automatically
              order: maxOrder,
            );
            created += 1;
            onProgress?.call(PullProgress(currentPath: fullPath, scanned: scanned, created: created));
          }
        }
        // Recurse into subfolders
        for (final prefix in result.prefixes) {
          await scanFolder(prefix);
        }
        // Pagination
        final token = result.nextPageToken;
        if (token == null) break;
        result = await ref.list(fstorage.ListOptions(maxResults: 1000, pageToken: token));
      }
    }

    await scanFolder(rootRef);

    return created;
  }
}
