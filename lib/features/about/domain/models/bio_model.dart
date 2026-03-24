import 'package:cloud_firestore/cloud_firestore.dart';

class BioPageModel {
  final Map<String, dynamic> bio100Words;
  final Map<String, dynamic> bio250Words;
  final Map<String, dynamic> bio450Words;
  final Map<String, dynamic> bio850Words;
  final Map<String, dynamic> cvContent;

  BioPageModel({
    required this.bio100Words,
    required this.bio250Words,
    required this.bio450Words,
    required this.bio850Words,
    required this.cvContent,
  });

  // Helper to safely extract Quill Delta JSON from Firestore data
  static Map<String, dynamic> _getDelta(Map<String, dynamic> data, String key) {
    try {
      final content = data[key];
      // During migration, we stored the delta in the 'ops' key.
      if (content is Map<String, dynamic> && content.containsKey('ops')) {
        return content;
      }
      // Return a default empty delta if not found or malformed
      return {'ops': [{'insert': '\n'}]};
    } catch (e) {
      return {'ops': [{'insert': '\n'}]};
    }
  }

  factory BioPageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return BioPageModel(
      bio100Words: _getDelta(data, 'bio100Words'),
      bio250Words: _getDelta(data, 'bio250Words'),
      bio450Words: _getDelta(data, 'bio450Words'),
      bio850Words: _getDelta(data, 'bio850Words'),
      cvContent: _getDelta(data, 'cvContent'),
    );
  }
}