import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/discography/domain/models/discography_model.dart';

class DiscographyRepository {
  final CollectionReference _discographyCollection;

  DiscographyRepository({FirebaseFirestore? firestore})
      : _discographyCollection = (firestore ?? FirebaseFirestore.instance).collection('discographyItems');

  Stream<List<DiscographyItem>> getDiscographyItemsStream() {
    final key = 'discography_all';
    final source = _discographyCollection
        .orderBy('order', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DiscographyItem.fromFirestore(doc)).toList();
    });
    return AppCache.instance.cacheFirstStream<List<DiscographyItem>>(key, source);
  }

  Future<void> addDiscographyItem(DiscographyItem item) async {
    await _discographyCollection.add(item.toJson());
    AppCache.instance.invalidate('discography_all');
  }

  Future<void> updateDiscographyItem(DiscographyItem item) async {
    await _discographyCollection.doc(item.id).update(item.toJson());
    AppCache.instance.invalidate('discography_all');
  }

  Future<void> deleteDiscographyItem(String id) async {
    await _discographyCollection.doc(id).delete();
    AppCache.instance.invalidate('discography_all');
  }

  /// Updates the 'order' field for a list of items in a batch.
  Future<void> updateDiscographyOrder(List<DiscographyItem> items) async {
    final batch = _discographyCollection.firestore.batch();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      batch.update(_discographyCollection.doc(item.id), {'order': i});
    }
    await batch.commit();
    AppCache.instance.invalidate('discography_all');
  }
}