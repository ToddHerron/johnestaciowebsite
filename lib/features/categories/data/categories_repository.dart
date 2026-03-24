import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/categories/domain/work_category.dart';

class CategoriesRepository {
  final CollectionReference<Map<String, dynamic>> _categoriesCol;

  CategoriesRepository({FirebaseFirestore? firestore})
      : _categoriesCol = (firestore ?? FirebaseFirestore.instance).collection('workCategories');

  /// Stream of categories ordered by 'order'. Uses cache-first emission.
  Stream<List<WorkCategory>> getCategoriesStream({bool includeInactive = true}) {
    final key = includeInactive ? 'work_categories_all' : 'work_categories_active';
    final src = _categoriesCol.orderBy('order').snapshots().map((snap) {
      final items = snap.docs.map((d) => WorkCategory.fromMap(d.id, d.data())).toList();
      return includeInactive ? items : items.where((c) => c.isActive).toList();
    });
    return AppCache.instance.cacheFirstStream<List<WorkCategory>>(key, src);
  }

  Future<List<WorkCategory>> getCategories({bool includeInactive = true}) async {
    final q = await _categoriesCol.orderBy('order').get();
    final items = q.docs.map((d) => WorkCategory.fromMap(d.id, d.data())).toList();
    return includeInactive ? items : items.where((c) => c.isActive).toList();
  }

  Future<DocumentReference<Map<String, dynamic>>> addCategory(String name, {int? order}) async {
    final items = await getCategories();
    final nextOrder = order ?? items.length;
    final ref = await _categoriesCol.add({
      'name': name.trim(),
      'order': nextOrder,
      'isActive': true,
    });
    AppCache.instance.invalidate('work_categories_all');
    AppCache.instance.invalidate('work_categories_active');
    return ref;
  }

  Future<void> renameCategory(String id, String newName) async {
    await _categoriesCol.doc(id).update({'name': newName.trim()});
    AppCache.instance.invalidate('work_categories_all');
    AppCache.instance.invalidate('work_categories_active');
  }

  Future<void> setActive(String id, bool isActive) async {
    await _categoriesCol.doc(id).update({'isActive': isActive});
    AppCache.instance.invalidate('work_categories_all');
    AppCache.instance.invalidate('work_categories_active');
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesCol.doc(id).delete();
    // Renormalize order to be dense [0..n-1]
    await renormalizeOrder();
  }

  Future<void> renormalizeOrder() async {
    final items = await getCategories();
    final batch = _categoriesCol.firestore.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(_categoriesCol.doc(items[i].id), {'order': i});
    }
    await batch.commit();
    AppCache.instance.invalidate('work_categories_all');
    AppCache.instance.invalidate('work_categories_active');
  }

  Future<void> updateOrder(List<WorkCategory> categoriesInNewOrder) async {
    final batch = _categoriesCol.firestore.batch();
    for (int i = 0; i < categoriesInNewOrder.length; i++) {
      final c = categoriesInNewOrder[i];
      batch.update(_categoriesCol.doc(c.id), {'order': i});
    }
    await batch.commit();
    AppCache.instance.invalidate('work_categories_all');
    AppCache.instance.invalidate('work_categories_active');
  }
}
