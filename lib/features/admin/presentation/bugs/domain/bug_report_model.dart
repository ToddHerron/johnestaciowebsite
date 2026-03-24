import 'package:cloud_firestore/cloud_firestore.dart';

enum BugStatus {
  newReport('New'),
  beingWorkedOn('Being worked on'),
  deferred('Deferred'),
  closed('Closed');

  final String label;
  const BugStatus(this.label);

  static BugStatus fromString(String? value) {
    if (value == null) return BugStatus.newReport;
    final v = value.trim().toLowerCase();
    // Be tolerant of legacy values
    if (v == 'closed') return BugStatus.closed;
    if (v == 'deferred' || v == 'on hold') return BugStatus.deferred;
    if (v == 'being worked on' || v == 'in progress' || v == 'working') {
      return BugStatus.beingWorkedOn;
    }
    if (v == 'new' || v == 'open') return BugStatus.newReport;
    // Fallback to exact known labels
    switch (value) {
      case 'Being worked on':
        return BugStatus.beingWorkedOn;
      case 'Deferred':
        return BugStatus.deferred;
      case 'Closed':
        return BugStatus.closed;
      case 'New':
      default:
        return BugStatus.newReport;
    }
  }

  String toStorage() => label;
}

enum BugKind {
  bug('Bug'),
  feature('Feature');

  final String label;
  const BugKind(this.label);

  static BugKind fromString(String? value) {
    if (value == null) return BugKind.bug;
    final v = value.trim().toLowerCase();
    if (v == 'feature' || v == 'feat' || v == 'enhancement') return BugKind.feature;
    if (v == 'bug' || v == 'issue') return BugKind.bug;
    // Fallback to exact labels
    switch (value) {
      case 'Feature':
        return BugKind.feature;
      case 'Bug':
      default:
        return BugKind.bug;
    }
  }

  String toStorage() => label;
}

class BugReportModel {
  final String id;
  final String title;
  final String body;
  final bool urgent;
  final BugStatus status;
  final BugKind kind;
  final int position; // for ordering in the list (lower = higher in list)
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const BugReportModel({
    required this.id,
    required this.title,
    required this.body,
    required this.urgent,
    required this.status,
    required this.kind,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  BugReportModel copyWith({
    String? id,
    String? title,
    String? body,
    bool? urgent,
    BugStatus? status,
    BugKind? kind,
    int? position,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return BugReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      urgent: urgent ?? this.urgent,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BugReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BugReportModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      urgent: (data['urgent'] ?? false) as bool,
      status: BugStatus.fromString(data['status'] as String?),
      kind: BugKind.fromString(data['kind'] as String?),
      position: (data['position'] ?? 0) as int,
      // If timestamps are missing on legacy documents, treat as very old so
      // they don't crowd out properly timestamped items in recency lists.
      createdAt: (data['created_at'] as Timestamp?) ?? Timestamp.fromMillisecondsSinceEpoch(0),
      updatedAt: (data['updated_at'] as Timestamp?) ?? Timestamp.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'urgent': urgent,
      'status': status.toStorage(),
      'kind': kind.toStorage(),
      'position': position,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
