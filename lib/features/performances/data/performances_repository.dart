import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/performances/domain/models/performance_models.dart';

class PerformancesRepository {
  final FirebaseFirestore _db;
  final CollectionReference _requests;

  PerformancesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _requests = (firestore ?? FirebaseFirestore.instance).collection('performance_requests');

  Stream<List<PerformanceRequest>> streamAll() {
    final key = 'perf_requests_all';
    final source = _requests.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map((d) => PerformanceRequest.fromFirestore(d)).toList(),
        );
    return AppCache.instance.cacheFirstStream<List<PerformanceRequest>>(key, source);
  }

  Stream<List<PerformanceRequest>> streamUpcomingComplete() {
    final key = 'perf_upcoming_complete';
    final now = Timestamp.now();
    final source = _requests
        .where('status', isEqualTo: RequestStatus.complete.name)
        .snapshots()
        .map((s) => s.docs.map((d) => PerformanceRequest.fromFirestore(d)).toList())
        .map((list) {
      // Only include if any performance date >= now
      return list
          .where((r) => r.performances.any((p) => p.dateTime.compareTo(now) >= 0))
          .toList()
        ..sort((a, b) {
          // sort by the next upcoming performance date
          Timestamp nextA = a.performances
              .map((p) => p.dateTime)
              .where((t) => t.compareTo(now) >= 0)
              .fold<Timestamp?>(null, (prev, t) => (prev == null || t.compareTo(prev) < 0) ? t : prev) ?? now;
          Timestamp nextB = b.performances
              .map((p) => p.dateTime)
              .where((t) => t.compareTo(now) >= 0)
              .fold<Timestamp?>(null, (prev, t) => (prev == null || t.compareTo(prev) < 0) ? t : prev) ?? now;
          return nextA.compareTo(nextB);
        });
    });
    return AppCache.instance.cacheFirstStream<List<PerformanceRequest>>(key, source);
  }

  // Stream upcoming, completed requests that include a specific work title
  Stream<List<PerformanceRequest>> streamUpcomingForWorkTitle(String workTitle) {
    final key = 'perf_upcoming_for_title_$workTitle';
    final now = Timestamp.now();
    final source = _requests
        .where('status', isEqualTo: RequestStatus.complete.name)
        .where('works', arrayContains: workTitle)
        .snapshots()
        .map((s) => s.docs.map((d) => PerformanceRequest.fromFirestore(d)).toList())
        .map((list) {
      return list
          .where((r) => r.performances.any((p) => p.dateTime.compareTo(now) >= 0))
          .toList()
        ..sort((a, b) {
          Timestamp nextA = a.performances
              .map((p) => p.dateTime)
              .where((t) => t.compareTo(now) >= 0)
              .fold<Timestamp?>(null, (prev, t) => (prev == null || t.compareTo(prev) < 0) ? t : prev) ?? now;
          Timestamp nextB = b.performances
              .map((p) => p.dateTime)
              .where((t) => t.compareTo(now) >= 0)
              .fold<Timestamp?>(null, (prev, t) => (prev == null || t.compareTo(prev) < 0) ? t : prev) ?? now;
          return nextA.compareTo(nextB);
        });
    });
    return AppCache.instance.cacheFirstStream<List<PerformanceRequest>>(key, source);
  }

  Stream<List<PerformanceRequest>> streamPastComplete() {
    final key = 'perf_past_complete';
    final now = Timestamp.now();
    final source = _requests
        .where('status', isEqualTo: RequestStatus.complete.name)
        .snapshots()
        .map((s) => s.docs.map((d) => PerformanceRequest.fromFirestore(d)).toList())
        .map((list) {
      // Include any request that has at least one performance in the past
      final filtered = list.where((r) => r.performances.any((p) => p.dateTime.compareTo(now) < 0)).toList();
      // Sort by the most recent past performance date (descending)
      filtered.sort((a, b) {
        final pastA = a.performances.map((p) => p.dateTime).where((t) => t.compareTo(now) < 0);
        final pastB = b.performances.map((p) => p.dateTime).where((t) => t.compareTo(now) < 0);
        Timestamp lastPastA = pastA.reduce((prev, t) => t.compareTo(prev) > 0 ? t : prev);
        Timestamp lastPastB = pastB.reduce((prev, t) => t.compareTo(prev) > 0 ? t : prev);
        return lastPastB.compareTo(lastPastA);
      });
      return filtered;
    });
    return AppCache.instance.cacheFirstStream<List<PerformanceRequest>>(key, source);
  }
 
  Future<DocumentReference> addRequest(PerformanceRequest request) async {
    final docRef = await _requests.add(request.toJson());
    // Invalidate caches likely affected
    AppCache.instance.invalidate('perf_requests_all');
    AppCache.instance.invalidate('perf_upcoming_complete');
    AppCache.instance.invalidate('perf_past_complete');
    for (final w in request.works) {
      AppCache.instance.invalidate('perf_upcoming_for_title_$w');
    }
    return docRef;
  }

  Future<void> updateStatus(String id, RequestStatus status) async {
    await _requests.doc(id).update({'status': status.name});
    AppCache.instance.invalidate('perf_requests_all');
    AppCache.instance.invalidate('perf_upcoming_complete');
    AppCache.instance.invalidate('perf_past_complete');
  }

  Future<void> updateRequest(String id, PerformanceRequest request) async {
    await _requests.doc(id).update(request.toJson());
    AppCache.instance.invalidate('perf_requests_all');
    AppCache.instance.invalidate('perf_upcoming_complete');
    AppCache.instance.invalidate('perf_past_complete');
    for (final w in request.works) {
      AppCache.instance.invalidate('perf_upcoming_for_title_$w');
    }
  }

  Future<void> deleteRequest(String id) async {
    await _requests.doc(id).delete();
    AppCache.instance.invalidate('perf_requests_all');
    AppCache.instance.invalidate('perf_upcoming_complete');
    AppCache.instance.invalidate('perf_past_complete');
  }

  Future<void> addAdminMessageForRequest(PerformanceRequest request) async {
    await _db.collection('messages').add({
      'firstName': request.requester.firstName,
      'lastName': request.requester.lastName,
      'email': request.requester.email,
      'message': _formatAdminMessage(request),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  String _formatAdminMessage(PerformanceRequest r) {
    final works = r.works.isNotEmpty ? r.works.join(', ') : '(none)';
    final perfLines = r.performances.map((p) => '- ${p.venueName} | ${p.city}, ${p.region}, ${p.country} | ${p.dateTime.toDate().toIso8601String()} | ${p.ticketingLink}').join('\n');
    final requester = r.requester;
    final needBy = r.needBy != null
        ? '\n Score needed by: ${DateFormat('MMM d, yyyy').format(r.needBy!.toDate().toLocal())}'
        : '';
    return '''Score Request Submitted
 Status: ${r.status.name}
 Conductor: ${r.conductor}
 Ensemble: ${r.ensemble}
 Works: $works
 Performances:
 $perfLines
 Requester: ${requester.firstName} ${requester.lastName}
 Email: ${requester.email}
 Phone: ${requester.phone}
 Address: ${requester.address}
   Special Instructions: ${requester.specialInstructions}$needBy'''.trim();
  }
}