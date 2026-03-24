import 'package:cloud_firestore/cloud_firestore.dart';

class SourceDataRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getSourceWebsiteData() async {
    try {
      final docSnapshot = await _firestore
          .collection('userWebsites')
          .doc('gXxIBi8EaGtOogn8VlOZ')
          .get();
      
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>;
      } else {
        throw Exception('Source document "gXxIBi8EaGtOogn8VlOZ" not found in "userWebsites" collection.');
      }
    } catch (e) {
      print('Error fetching source data: $e');
      rethrow;
    }
  }
}