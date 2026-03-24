import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsRepository {
  final DocumentReference _settingsDocRef;

  SettingsRepository({FirebaseFirestore? firestore})
      : _settingsDocRef = (firestore ?? FirebaseFirestore.instance).collection('settings').doc('contact');

  Future<String> getRecipientEmail() async {
    try {
      final doc = await _settingsDocRef.get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['recipientEmail'] ?? '';
      }
    } catch (e) {
      print('Error fetching recipient email: $e');
    }
    return '';
  }

  Future<void> updateRecipientEmail(String email) async {
    await _settingsDocRef.set({'recipientEmail': email});
  }
}