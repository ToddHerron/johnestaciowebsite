import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { newRequest, inProgress, complete, cancelled }

class PerformanceItem {
  final String venueName;
  /// UTC instant for the performance.
  ///
  /// Stored as a Firestore Timestamp (an instant), but we always interpret it
  /// as UTC in code.
  final Timestamp dateTime;

  /// IANA time zone ID for the performance location (e.g. "America/Toronto").
  ///
  /// Used for DST-safe formatting and for converting a chosen wall-clock time
  /// into a UTC instant at creation time.
  final String timeZoneId;
  final String city;
  final String region;
  final String country;
  final String ticketingLink;

  const PerformanceItem({
    required this.venueName,
    required this.dateTime,
    required this.timeZoneId,
    required this.city,
    required this.region,
    required this.country,
    required this.ticketingLink,
  });

  DateTime get dateTimeUtc => dateTime.toDate().toUtc();

  factory PerformanceItem.fromMap(Map<String, dynamic> map) {
    return PerformanceItem(
      venueName: (map['venueName'] ?? '').toString(),
      dateTime: (map['dateTime'] is Timestamp)
          ? (map['dateTime'] as Timestamp)
          : Timestamp.now(),
      timeZoneId: (map['timeZoneId'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      region: (map['region'] ?? '').toString(),
      country: (map['country'] ?? '').toString(),
      ticketingLink: (map['ticketingLink'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'venueName': venueName,
        'dateTime': dateTime,
        'timeZoneId': timeZoneId,
        'city': city,
        'region': region,
        'country': country,
        'ticketingLink': ticketingLink,
      };
}

class RequesterInfo {
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String address;
  final String specialInstructions;

  const RequesterInfo({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.specialInstructions = '',
  });

  bool get isEmpty =>
      firstName.isEmpty && lastName.isEmpty && phone.isEmpty && email.isEmpty && address.isEmpty && specialInstructions.isEmpty;

  factory RequesterInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const RequesterInfo();
    return RequesterInfo(
      firstName: (map['firstName'] ?? '').toString(),
      lastName: (map['lastName'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      specialInstructions: (map['specialInstructions'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'email': email,
        'address': address,
        'specialInstructions': specialInstructions,
      };
}

class PerformanceRequest {
  final String id;
  final List<String> works; // titles or IDs; we store titles for simplicity
  final String conductor;
  final String ensemble;
  final List<PerformanceItem> performances;
  final RequesterInfo requester;
  /// Date the requester needs the scores by (no time component required)
  final Timestamp? needBy;
  final RequestStatus status;
  final Timestamp createdAt;

  const PerformanceRequest({
    required this.id,
    required this.works,
    required this.conductor,
    required this.ensemble,
    required this.performances,
    required this.requester,
    this.needBy,
    required this.status,
    required this.createdAt,
  });

  factory PerformanceRequest.empty() => PerformanceRequest(
        id: '',
        works: const [],
        conductor: '',
        ensemble: '',
        performances: const [],
        requester: const RequesterInfo(),
        needBy: null,
        status: RequestStatus.newRequest,
        createdAt: Timestamp.now(),
      );

  factory PerformanceRequest.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    final statusString = (data['status'] ?? 'newRequest').toString();
    final status = RequestStatus.values.firstWhere(
      (e) => e.name == statusString,
      orElse: () => RequestStatus.newRequest,
    );

    final performances = (data['performances'] as List<dynamic>? ?? [])
        .map((e) => PerformanceItem.fromMap(e as Map<String, dynamic>))
        .toList();

    return PerformanceRequest(
      id: doc.id,
      works: List<String>.from(data['works'] ?? const []),
      conductor: (data['conductor'] ?? '').toString(),
      ensemble: (data['ensemble'] ?? '').toString(),
      performances: performances,
      requester: RequesterInfo.fromMap(data['requester'] as Map<String, dynamic>?),
      needBy: data['needBy'] is Timestamp ? data['needBy'] as Timestamp : null,
      status: status,
      createdAt: (data['createdAt'] is Timestamp) ? data['createdAt'] as Timestamp : Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'works': works,
        'conductor': conductor,
        'ensemble': ensemble,
        'performances': performances.map((e) => e.toJson()).toList(),
        'requester': requester.toJson(),
        'needBy': needBy,
        'status': status.name,
        'createdAt': createdAt,
      };
}