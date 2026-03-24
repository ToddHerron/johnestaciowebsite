import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/domain/bug_report_model.dart';

class BugsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _collection => _firestore.collection('bugs');

  Stream<List<BugReportModel>> streamBugs() {
    final key = 'bugs_all';
    final source = _collection
        .orderBy('position')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => BugReportModel.fromFirestore(d)).toList());
    return AppCache.instance.cacheFirstStream<List<BugReportModel>>(key, source);
  }

  /// Streams the most recently updated bugs that are marked Closed.
  /// Ordered by updated_at descending, limited to [limit] (default 5).
  Stream<List<BugReportModel>> streamRecentClosedBugs({int limit = 5}) {
    // Fetch all bugs and compute client-side. This avoids dropping legacy
    // documents that might be missing updated_at.
    return _collection.snapshots().map((snapshot) {
      final models = snapshot.docs.map((d) => BugReportModel.fromFirestore(d)).toList();
      models.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      // Only include real bugs (exclude features) that are closed
      return models
          .where((m) => m.kind == BugKind.bug && m.status == BugStatus.closed)
          .take(limit)
          .toList();
    });
  }

  /// Streams the most recently added features (kind == Feature).
  /// Ordered by created_at descending, limited to [limit] (default 5).
  Stream<List<BugReportModel>> streamRecentFeatures({int limit = 5}) {
    // Fetch all bugs and compute client-side. This avoids dropping legacy
    // documents that might be missing created_at.
    return _collection.snapshots().map((snapshot) {
      final models = snapshot.docs.map((d) => BugReportModel.fromFirestore(d)).toList();
      final features = models.where((m) => m.kind == BugKind.feature).toList();
      features.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return features.take(limit).toList();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBugChat(String bugId) {
    // Chat is already live; no cache to avoid stale chats.
    return _collection
        .doc(bugId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .withConverter<Map<String, dynamic>>(fromFirestore: (d, _) => d.data() ?? {}, toFirestore: (data, _) => data)
        .snapshots();
  }

  /// Streams whether a bug has at least one chat message. Lightweight (limit 1).
  Stream<bool> streamHasChat(String bugId) {
    return _collection
        .doc(bugId)
        .collection('chat')
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> addBugChatMessage({
    required String bugId,
    required String senderUid,
    required String text,
  }) async {
    await _collection.doc(bugId).collection('chat').add({
      'senderUid': senderUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<int> _getNextPosition() async {
    final snapshot = await _collection.orderBy('position', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return 0;
    final top = snapshot.docs.first.data() as Map<String, dynamic>;
    return ((top['position'] ?? 0) as int) + 1;
  }

  Future<String> addBug({
    required String title,
    required String body,
    required bool urgent,
    required BugStatus status,
    BugKind kind = BugKind.bug,
  }) async {
    final docRef = _collection.doc();
    final now = Timestamp.now();
    final pos = await _getNextPosition();
    await docRef.set({
      'title': title,
      'body': body,
      'urgent': urgent,
      'status': status.toStorage(),
      'kind': kind.toStorage(),
      'position': pos,
      'created_at': now,
      'updated_at': now,
    });
    AppCache.instance.invalidate('bugs_all');
    return docRef.id;
  }

  Future<void> updateBug(String id, {
    String? title,
    String? body,
    bool? urgent,
    BugStatus? status,
    BugKind? kind,
    int? position,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': Timestamp.now(),
    };
    if (title != null) updates['title'] = title;
    if (body != null) updates['body'] = body;
    if (urgent != null) updates['urgent'] = urgent;
    if (status != null) updates['status'] = status.toStorage();
    if (kind != null) updates['kind'] = kind.toStorage();
    if (position != null) updates['position'] = position;

    await _collection.doc(id).update(updates);
    AppCache.instance.invalidate('bugs_all');
  }

  Future<void> deleteBug(String id) async {
    await _collection.doc(id).delete();
    AppCache.instance.invalidate('bugs_all');
  }

  Future<void> reorderBugs(List<BugReportModel> bugsInNewOrder) async {
    final batch = _firestore.batch();
    for (int i = 0; i < bugsInNewOrder.length; i++) {
      final b = bugsInNewOrder[i];
      final ref = _collection.doc(b.id);
      batch.update(ref, {'position': i, 'updated_at': Timestamp.now()});
    }
    await batch.commit();
    AppCache.instance.invalidate('bugs_all');
  }
}
