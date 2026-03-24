import 'package:cloud_firestore/cloud_firestore.dart';

class BioPhotoItem {
  final String id;
  final String imageUrl; // May be empty if only storagePath is provided
  final String storagePath; // Firebase Storage fullPath (e.g., users/uid/uploads/file.jpg)
  final String title;
  final String description;
  final bool visible; // Controls whether shown on public gallery
  final int order; // for manual ordering
  final DateTime createdAt;
  final DateTime updatedAt;

  const BioPhotoItem({
    required this.id,
    required this.imageUrl,
    required this.storagePath,
    required this.title,
    required this.description,
    required this.visible,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BioPhotoItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    return BioPhotoItem(
      id: doc.id,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      visible: (data['visible'] ?? true) == true,
      order: (data['order'] ?? 0) is int
          ? (data['order'] as int)
          : int.tryParse((data['order'] ?? '0').toString()) ?? 0,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'title': title,
      'description': description,
      'visible': visible,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BioPhotoItem copyWith({
    String? id,
    String? imageUrl,
    String? storagePath,
    String? title,
    String? description,
    bool? visible,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BioPhotoItem(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      title: title ?? this.title,
      description: description ?? this.description,
      visible: visible ?? this.visible,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
