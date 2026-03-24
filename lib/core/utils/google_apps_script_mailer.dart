import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:john_estacio_website/core/constants/app_constants.dart';
import 'package:john_estacio_website/features/performances/domain/models/performance_models.dart';

/// Lightweight client for posting score request emails to a Google Apps Script Web App.
class GoogleAppsScriptMailer {
  GoogleAppsScriptMailer({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sends the score request email payload to the configured Apps Script endpoint.
  /// Returns true on success (HTTP 200 and body contains 'Success').
  Future<bool> sendScoreRequestEmail(PerformanceRequest request) async {
    final url = Uri.parse(AppConstants.googleAppsScriptEmailUrl);

    final payload = _buildPayload(request);
    debugPrint('GoogleAppsScriptMailer: POST to $url');
    try {
      final res = await _client
          .post(
            url,
            // Use text/plain to keep this a CORS "simple request" and avoid
            // a browser preflight (OPTIONS) that Apps Script web apps don't handle.
            headers: const {'Content-Type': 'text/plain; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      final ok = res.statusCode == 200 && res.body.toLowerCase().contains('success');
      if (!ok) {
        debugPrint('GoogleAppsScriptMailer: non-OK response ${res.statusCode} body=${res.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('GoogleAppsScriptMailer: failed to send email: $e');
      return false;
    }
  }

  Map<String, dynamic> _buildPayload(PerformanceRequest r) {
    final worksText = r.works.isEmpty ? '(none listed)' : r.works.join(', ');
    final dateFmt = DateFormat('MMM d, yyyy – h:mm a');
    final dateOnlyFmt = DateFormat('MMM d, yyyy');

    final performances = <Map<String, dynamic>>[];
    for (var i = 0; i < r.performances.length; i++) {
      final p = r.performances[i];
      final dt = p.dateTime.millisecondsSinceEpoch == 0 ? null : p.dateTime.toDate().toLocal();
      final location = [p.city.trim(), p.region.trim(), p.country.trim()]
          .where((e) => e.isNotEmpty)
          .join(', ');
      performances.add({
        'n': i + 1,
        'date': dt == null ? '' : dateFmt.format(dt),
        'venue': p.venueName,
        'location': location,
        if (p.ticketingLink.isNotEmpty) 'ticketingLink': p.ticketingLink,
      });
    }

    final requester = r.requester;
    final payload = <String, dynamic>{
      'ensemble': r.ensemble,
      'conductor': r.conductor,
      'works_text': worksText,
      'performances': performances,
      if (r.needBy != null) 'needBy': dateOnlyFmt.format(r.needBy!.toDate().toLocal()),
      'requester': {
        'fullName': '${requester.firstName} ${requester.lastName}'.trim(),
        'email': requester.email,
        'phone': requester.phone,
        'address': requester.address,
        'specialInstructions': requester.specialInstructions,
      },
      'submittedAt': DateTime.now().toIso8601String(),
    };

    return payload;
  }

  /// Sends a Contact form message to the Apps Script endpoint. The Apps Script
  /// will fan-out to admins and send an auto-reply to the user.
  ///
  /// - honeypot: hidden field value; if filled, server will silently drop
  /// - elapsedMs: time the form took before submission; used as a weak anti-spam signal
  Future<bool> sendContactMessageEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String message,
    String honeypot = '',
    int? elapsedMs,
  }) async {
    final url = Uri.parse(AppConstants.googleAppsScriptEmailUrl);

    final payload = <String, dynamic>{
      'type': 'contact',
      'contact': {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'message': message.trim(),
      },
      'meta': {
        'submittedAt': DateTime.now().toIso8601String(),
        if (elapsedMs != null) 'elapsedMs': elapsedMs,
        'honeypot': honeypot,
        'client': 'flutter-web',
      }
    };

    debugPrint('GoogleAppsScriptMailer: POST contact to $url');
    try {
      final res = await _client
          .post(
            url,
            headers: const {'Content-Type': 'text/plain; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      final ok = res.statusCode == 200 && res.body.toLowerCase().contains('success');
      if (!ok) {
        debugPrint('GoogleAppsScriptMailer(contact): non-OK response ${res.statusCode} body=${res.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('GoogleAppsScriptMailer(contact): failed to send email: $e');
      return false;
    }
  }
}
