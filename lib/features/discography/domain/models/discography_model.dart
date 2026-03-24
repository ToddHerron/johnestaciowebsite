import 'package:cloud_firestore/cloud_firestore.dart';

class DiscographyItem {
  final String id;
  final String title;
  final String embedHtml;
  final int order;

  DiscographyItem({
    required this.id,
    required this.title,
    required this.embedHtml,
    required this.order,
  });

  factory DiscographyItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return DiscographyItem(
      id: doc.id,
      title: data['title'] ?? '',
      embedHtml: data['embedHtml'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'embedHtml': embedHtml,
      'order': order,
    };
  }

  DiscographyItem copyWith({
    String? id,
    String? title,
    String? embedHtml,
    int? order,
  }) {
    return DiscographyItem(
      id: id ?? this.id,
      title: title ?? this.title,
      embedHtml: embedHtml ?? this.embedHtml,
      order: order ?? this.order,
    );
  }
}