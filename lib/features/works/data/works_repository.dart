import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';

class WorksRepository {
  final CollectionReference<Map<String, dynamic>> _worksCollection;

  WorksRepository({FirebaseFirestore? firestore})
      : _worksCollection = (firestore ?? FirebaseFirestore.instance).collection('works');

  /// Fetches a real-time stream of works.
  ///
  /// By default returns only public-facing works (published + visible) ordered by 'order'.
  /// Admin pages can pass publishedOnly: false to stream all docs regardless of status/visibility.
  Stream<List<Work>> getWorksStream({bool publishedOnly = true}) {
    final key = publishedOnly ? 'works_public' : 'works_all';
    Query<Map<String, dynamic>> q = _worksCollection;
    if (publishedOnly) {
      q = q
          .where('currentStatus', isEqualTo: 'published')
          .where('isVisible', isEqualTo: true);
    }
    q = q.orderBy('order', descending: false);

    final source = q.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Work.fromFirestore(doc)).toList());
    return AppCache.instance.cacheFirstStream<List<Work>>(key, source);
  }

  /// Fetches the raw Firestore doc snapshot for a work.
  Future<DocumentSnapshot<Map<String, dynamic>>> getWorkDoc(String id) {
    return _worksCollection.doc(id).get();
  }

  /// Fetches a single work by its document ID (published view fields).
  Future<Work> getWorkById(String id) async {
    final key = 'work_by_id_$id';
    return AppCache.instance.getOrFetch<Work>(key, () async {
      final docSnapshot = await _worksCollection.doc(id).get();
      return Work.fromFirestore(docSnapshot);
    });
  }

  /// Fetches a single work by its title. Returns null if not found.
  Future<Work?> getWorkByTitle(String title) async {
    // Public lookup is used by WorkCardDialog; restrict to published + visible.
    final key = 'work_by_title_public_$title';
    return AppCache.instance.getOrFetch<Work?>(key, () async {
      final query = await _worksCollection
          .where('title', isEqualTo: title)
          .where('currentStatus', isEqualTo: 'published')
          .where('isVisible', isEqualTo: true)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return Work.fromFirestore(query.docs.first);
    });
  }

  /// Updates an existing work document (overwrites live/published fields)
  Future<void> updateWork(String id, Work work) async {
    await _worksCollection.doc(id).update(work.toJson());
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_id_$id');
    AppCache.instance.invalidate('work_by_title_${work.title}');
  }

  /// Adds a new work document with current fields (treated as published)
  Future<DocumentReference<Map<String, dynamic>>> addWork(Work work) async {
    final ref = await _worksCollection.add(work.toJson());
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_title_${work.title}');
    return ref;
  }

  /// Deletes a work document.
  Future<void> deleteWork(String id) async {
    await _worksCollection.doc(id).delete();
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_id_$id');
  }

  /// Updates the 'order' field for a list of works in a batch.
  Future<void> updateWorkOrder(List<Work> works) async {
    final batch = _worksCollection.firestore.batch();
    for (int i = 0; i < works.length; i++) {
      final work = works[i];
      batch.update(_worksCollection.doc(work.id), {'order': i});
    }
    await batch.commit();
    AppCache.instance.invalidate('works_all');
  }

  /// Set currentStatus only (without changing content)
  Future<void> setStatus(String id, WorkStatus status) async {
    await _worksCollection.doc(id).update({'currentStatus': status.name});
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_id_$id');
  }

  /// Sets the public visibility of a work. When false, the work is hidden
  /// from the public Works page and any public lookups by title.
  Future<void> setVisibility(String id, {
    required bool isVisible,
    String? titleForCache,
  }) async {
    await _worksCollection.doc(id).update({'isVisible': isVisible});
    // Invalidate caches so both admin and public lists refresh
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('works_public');
    AppCache.instance.invalidate('work_by_id_$id');
    if (titleForCache != null && titleForCache.isNotEmpty) {
      // Public title lookup cache key
      AppCache.instance.invalidate('work_by_title_public_$titleForCache');
    }
  }

  /// Create a new doc as draft: stores the draft map and marks status=draft.
  Future<DocumentReference<Map<String, dynamic>>> createDraft(Work draft, {int? explicitOrder}) async {
    final data = {
      'order': explicitOrder ?? draft.order,
      'currentStatus': WorkStatus.draft.name,
      'draft': draft.toJson(),
    };
    final ref = await _worksCollection.add(data);
    AppCache.instance.invalidate('works_all');
    return ref;
  }

  /// Save/overwrite the draft map for an existing work and mark status=draft.
  Future<void> saveDraft(String id, Work draft) async {
    await _worksCollection.doc(id).set({
      'draft': draft.toJson(),
      'currentStatus': WorkStatus.draft.name,
    }, SetOptions(merge: true));
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_id_$id');
  }

  /// Publish a draft: copy draft fields to live (top-level), remove draft, set status=published.
  Future<void> publishDraft(String id) async {
    final docRef = _worksCollection.doc(id);
    await _worksCollection.firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final data = snap.data() ?? {};
      final Map<String, dynamic>? draft = data['draft'] as Map<String, dynamic>?;
      if (draft == null) {
        // No draft; just mark published
        txn.update(docRef, {'currentStatus': WorkStatus.published.name});
        return;
      }
      final liveUpdate = Map<String, dynamic>.from(draft)..remove('currentStatus');
      txn.update(docRef, {
        ...liveUpdate,
        'currentStatus': WorkStatus.published.name,
        'draft': FieldValue.delete(),
      });
    });
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_id_$id');
  }

  /// Discard draft: remove the draft map and mark status=published.
  Future<void> resetDraft(String id) async {
    await _worksCollection.doc(id).update({
      'draft': FieldValue.delete(),
      'currentStatus': WorkStatus.published.name,
    });
    AppCache.instance.invalidate('works_all');
    AppCache.instance.invalidate('work_by_id_$id');
  }

  /// Runs a schema migration to normalize enums, add visibility/status defaults,
  /// ensure ordering, and compute icon-friendly flags at top level.
  /// Returns a summary map with counts.
  /// If dryRun is true, no writes are performed; only counts are computed.
  Future<Map<String, int>> migrateSchemaForIcons({bool dryRun = false}) async {
    final snapshot = await _worksCollection.get();

    int processed = 0;
    int updated = 0; // In dryRun this means "would update"
    int skipped = 0;
    int errors = 0;

    WriteBatch batch = _worksCollection.firestore.batch();
    int batchOps = 0;

    // Helper to commit the batch periodically
    Future<void> commitIfNeeded({bool force = false}) async {
      if (dryRun) return; // never commit in dry run
      if (force || batchOps >= 400) {
        await batch.commit();
        batch = _worksCollection.firestore.batch();
        batchOps = 0;
      }
    }

    for (int i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      processed++;
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final update = <String, dynamic>{};
        bool changed = false;

        // Ensure currentStatus and isVisible defaults
        final rawStatus = data['currentStatus'];
        if (rawStatus == null || (rawStatus is! String)) {
          update['currentStatus'] = WorkStatus.published.name;
          changed = true;
        }
        if (!data.containsKey('isVisible')) {
          update['isVisible'] = true;
          changed = true;
        }

        // Ensure order exists and is an int
        if (data['order'] == null || (data['order'] is! int)) {
          update['order'] = i; // fallback stable order by snapshot order
          changed = true;
        }

        // Normalize categories to List<String>
        if (data.containsKey('categories')) {
          final cat = data['categories'];
          if (cat is List) {
            final newCats = cat.map((e) => e.toString()).toList();
            if (newCats.toString() != (cat as List).map((e) => e.toString()).toList().toString()) {
              update['categories'] = newCats;
              changed = true;
            }
          } else {
            update['categories'] = [];
            changed = true;
          }
        }

        // Normalize details list and compute flags
        bool hasPdf = false;
        bool hasAudio = false;
        bool hasEmbed = false;
        bool hasLink = false;
        bool hasImage = false;
        bool hasRequest = false;

        if (data['details'] is List) {
          final details = List<Map<String, dynamic>>.from(
            (data['details'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)),
          );

          bool detailsChanged = false;
          for (int di = 0; di < details.length; di++) {
            final d = details[di];
            final normalized = _normalizeDetailMap(d, index: di);
            details[di] = normalized.map;
            detailsChanged = detailsChanged || normalized.changed;

            // Compute flags
            switch (normalized.typeName) {
              case 'DetailType.pdf':
                hasPdf = true;
                break;
              case 'DetailType.audio':
                hasAudio = true;
                break;
              case 'DetailType.embed':
                hasEmbed = true;
                break;
              case 'DetailType.link':
                hasLink = true;
                break;
              case 'DetailType.image':
                hasImage = true;
                break;
              case 'DetailType.request':
                hasRequest = true;
                break;
              default:
                break;
            }
          }

          if (detailsChanged) {
            update['details'] = details;
            changed = true;
          }
        }

        // Write icon-friendly flags if absent or different
        Map<String, dynamic> desiredFlags = {
          'hasPdf': hasPdf,
          'hasAudio': hasAudio,
          'hasEmbed': hasEmbed,
          'hasLink': hasLink,
          'hasImage': hasImage,
          'hasRequest': hasRequest,
        };
        bool flagsChanged = false;
        desiredFlags.forEach((k, v) {
          if (data[k] != v) flagsChanged = true;
        });
        if (flagsChanged) {
          update.addAll(desiredFlags);
          changed = true;
        }

        if (changed) {
          if (!dryRun) {
            batch.update(doc.reference, update);
            batchOps++;
            await commitIfNeeded();
          }
          updated++;
        } else {
          skipped++;
        }
      } catch (e) {
        errors++;
        // Avoid aborting the loop; continue with next doc.
      }
    }

    await commitIfNeeded(force: true);

    // Invalidate caches only when we actually wrote changes
    if (!dryRun) {
      AppCache.instance.invalidate('works_all');
    }

    return {
      'processed': processed,
      'updated': updated,
      'skipped': skipped,
      'errors': errors,
    };
  }

  /// Creates a full backup of the `works` collection into `worksBackup`.
  /// This clears the existing backup collection first, then copies all docs
  /// (preserving document IDs).
  /// Returns a summary with counts.
  Future<Map<String, int>> backupWorksCollection({String backupCollection = 'worksBackup'}) async {
    final firestore = _worksCollection.firestore;
    final backup = firestore.collection(backupCollection);

    final sourceSnap = await _worksCollection.get();
    final backupSnap = await backup.get();

    int deletedOldBackup = 0;
    int copied = 0;

    WriteBatch batch = firestore.batch();
    int ops = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (force || ops >= 400) {
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    // 1) Clear existing backup docs
    for (final doc in backupSnap.docs) {
      batch.delete(doc.reference);
      ops++;
      deletedOldBackup++;
      await commitIfNeeded();
    }

    // 2) Copy source docs to backup
    for (final doc in sourceSnap.docs) {
      batch.set(backup.doc(doc.id), doc.data());
      ops++;
      copied++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);

    return {
      'sourceCount': sourceSnap.docs.length,
      'deletedOldBackup': deletedOldBackup,
      'copiedToBackup': copied,
    };
  }

  /// Restores the `works` collection from `worksBackup`.
  /// This deletes all docs in `works`, then copies all docs from backup into it.
  /// Returns a summary with counts.
  Future<Map<String, int>> restoreWorksFromBackup({String backupCollection = 'worksBackup'}) async {
    final firestore = _worksCollection.firestore;
    final backup = firestore.collection(backupCollection);

    final backupSnap = await backup.get();
    final worksSnap = await _worksCollection.get();

    int deletedWorks = 0;
    int restored = 0;

    WriteBatch batch = firestore.batch();
    int ops = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (force || ops >= 400) {
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    // 1) Delete all existing docs in works
    for (final doc in worksSnap.docs) {
      batch.delete(doc.reference);
      ops++;
      deletedWorks++;
      await commitIfNeeded();
    }

    // 2) Copy backup docs into works
    for (final doc in backupSnap.docs) {
      batch.set(_worksCollection.doc(doc.id), doc.data());
      ops++;
      restored++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);

    // Invalidate caches so UI refetches the list
    AppCache.instance.invalidate('works_all');

    return {
      'deletedExisting': deletedWorks,
      'restoredFromBackup': restored,
      'backupCount': backupSnap.docs.length,
    };
  }
}


class _NormalizedDetailResult {
  final Map<String, dynamic> map;
  final bool changed;
  final String typeName;
  _NormalizedDetailResult({required this.map, required this.changed, required this.typeName});
}

_NormalizedDetailResult _normalizeDetailMap(Map<String, dynamic> d, {required int index}) {
  bool changed = false;
  final out = Map<String, dynamic>.from(d);

  // id
  if (out['id'] == null || (out['id'] as String).isEmpty) {
    out['id'] = FirebaseFirestore.instance.collection('tmp').doc().id;
    changed = true;
  }

  // order
  if (out['order'] == null || out['order'] is! int) {
    out['order'] = index;
    changed = true;
  }

  String prefixEnum(String prefix, dynamic value, List<String> allowed) {
    final raw = value?.toString() ?? '';
    if (raw.startsWith('$prefix.')) return raw;
    if (allowed.contains(raw)) return '$prefix.$raw';
    return raw.isEmpty ? '' : raw; // unknown; leave as-is to avoid destructive change
  }

  // displayType
  final displayRaw = out['displayType'];
  final displayNorm = prefixEnum('DisplayType', displayRaw, const ['button', 'inline']);
  if (displayNorm.isNotEmpty && displayNorm != displayRaw) {
    out['displayType'] = displayNorm;
    changed = true;
  }

  // buttonStyle
  final buttonRaw = out['buttonStyle'];
  final buttonNorm = prefixEnum('ButtonStyle', buttonRaw, const ['primary', 'secondary']);
  if (buttonNorm.isNotEmpty && buttonNorm != buttonRaw) {
    out['buttonStyle'] = buttonNorm;
    changed = true;
  }

  // detailType
  final detailRaw = out['detailType'];
  final detailNorm = prefixEnum('DetailType', detailRaw, const ['pdf', 'audio', 'link', 'embed', 'richText', 'request', 'image']);
  if (detailNorm.isNotEmpty && detailNorm != detailRaw) {
    out['detailType'] = detailNorm;
    changed = true;
  }

  // buttonText fallbacks to avoid corrupted flags in reader
  final disp = out['displayType']?.toString() ?? '';
  String btnText = (out['buttonText'] ?? '').toString();
  if (disp == 'DisplayType.button' && btnText.isEmpty) {
    out['buttonText'] = '[Button Text Missing]';
    changed = true;
  } else if (disp == 'DisplayType.inline' && btnText.isEmpty) {
    out['buttonText'] = '[Title Missing]';
    changed = true;
  }

  // Normalize width/height numeric to double or null
  if (out['width'] != null && out['width'] is! num) {
    out.remove('width');
    changed = true;
  }
  if (out['height'] != null && out['height'] is! num) {
    out.remove('height');
    changed = true;
  }

  final typeName = (out['detailType'] ?? '').toString();
  return _NormalizedDetailResult(map: out, changed: changed, typeName: typeName);
}

