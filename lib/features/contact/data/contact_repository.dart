import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:john_estacio_website/core/utils/google_apps_script_mailer.dart';

class ContactRepository {
  final FirebaseFirestore _firestore;
  final GoogleAppsScriptMailer _mailer;

  ContactRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _mailer = GoogleAppsScriptMailer();

  Future<void> sendMessage({
    required String firstName,
    required String lastName,
    required String email,
    required String message,
    String honeypot = '',
    int? elapsedMs,
  }) async {
    try {
      await _firestore.collection('messages').add({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Fire-and-forget email sending to Apps Script. Silent failure by design.
      // Do not block the UX on this network call.
      // ignore: discarded_futures
      _mailer
          .sendContactMessageEmail(
            firstName: firstName,
            lastName: lastName,
            email: email,
            message: message,
            honeypot: honeypot,
            elapsedMs: elapsedMs,
          )
          .then((ok) {
        if (!ok) debugPrint('ContactRepository: Apps Script email not sent (silent).');
      }).catchError((e) {
        debugPrint('ContactRepository: Apps Script email error (silent): $e');
      });
    } catch (e) {
      // In a real app, you might have more robust error handling
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }
}