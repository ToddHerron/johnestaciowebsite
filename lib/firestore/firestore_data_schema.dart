import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'firestore_data_schema.g.dart';

/// Base class for all Firestore documents
abstract class FirestoreDocument {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  
  Map<String, dynamic> toJson();
}

/// Composition model for musical works
@JsonSerializable()
class Composition implements FirestoreDocument {
  @override
  final String id;
  final String title;
  final String? description;
  final String category; // e.g., "orchestral", "chamber", "vocal"
  final int? yearComposed;
  final String? duration; // e.g., "15 minutes"
  final List<String> instrumentation;
  final String? scoreUrl; // PDF download link
  final List<String> audioUrls; // Audio recordings
  final List<String> videoUrls; // Video recordings
  final bool isFeatured;
  final bool isPublished;
  final String ownerId;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const Composition({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.yearComposed,
    this.duration,
    this.instrumentation = const [],
    this.scoreUrl,
    this.audioUrls = const [],
    this.videoUrls = const [],
    this.isFeatured = false,
    this.isPublished = true,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Composition.fromJson(Map<String, dynamic> json) => _$CompositionFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$CompositionToJson(this);
}

/// Event model for concerts and performances
@JsonSerializable()
class Event implements FirestoreDocument {
  @override
  final String id;
  final String title;
  final String? description;
  final String venue;
  final String? location; // City, country
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime eventDate;
  
  final String? ticketUrl;
  final List<String> compositions; // Composition IDs being performed
  final bool isFeatured;
  final bool isPublic;
  final String? imageUrl;
  final String ownerId;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.title,
    this.description,
    required this.venue,
    this.location,
    required this.eventDate,
    this.ticketUrl,
    this.compositions = const [],
    this.isFeatured = false,
    this.isPublic = true,
    this.imageUrl,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$EventToJson(this);
}

/// Bio/About information
@JsonSerializable()
class Bio implements FirestoreDocument {
  @override
  final String id;
  final String content;
  final String? photoUrl;
  final List<String> achievements;
  final List<String> awards;
  final String? educationBackground;
  final String ownerId;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const Bio({
    required this.id,
    required this.content,
    this.photoUrl,
    this.achievements = const [],
    this.awards = const [],
    this.educationBackground,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bio.fromJson(Map<String, dynamic> json) => _$BioFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$BioToJson(this);
}

/// Media files (audio, video, images)
@JsonSerializable()
class Media implements FirestoreDocument {
  @override
  final String id;
  final String title;
  final String? description;
  final String mediaType; // "audio", "video", "image"
  final String fileUrl;
  final String? thumbnailUrl;
  final String? associatedCompositionId;
  final bool isFeatured;
  final int? duration; // in seconds for audio/video
  final String ownerId;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const Media({
    required this.id,
    required this.title,
    this.description,
    required this.mediaType,
    required this.fileUrl,
    this.thumbnailUrl,
    this.associatedCompositionId,
    this.isFeatured = false,
    this.duration,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

/// Contact messages from website visitors
@JsonSerializable()
class ContactMessage implements FirestoreDocument {
  @override
  final String id;
  final String name;
  final String email;
  final String subject;
  final String message;
  final bool isRead;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const ContactMessage({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContactMessage.fromJson(Map<String, dynamic> json) => _$ContactMessageFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$ContactMessageToJson(this);
}

/// User profile for admin/composer
@JsonSerializable()
class UserProfile implements FirestoreDocument {
  @override
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isAdmin;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

/// Site settings and configuration
@JsonSerializable()
class SiteSettings implements FirestoreDocument {
  @override
  final String id;
  final String siteTitle;
  final String? siteDescription;
  final String? logoUrl;
  final Map<String, String> socialLinks;
  final String? contactEmail;
  final String? contactPhone;
  final String adminId;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime createdAt;
  
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  @override
  final DateTime updatedAt;

  const SiteSettings({
    required this.id,
    required this.siteTitle,
    this.siteDescription,
    this.logoUrl,
    this.socialLinks = const {},
    this.contactEmail,
    this.contactPhone,
    required this.adminId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteSettings.fromJson(Map<String, dynamic> json) => _$SiteSettingsFromJson(json);
  
  @override
  Map<String, dynamic> toJson() => _$SiteSettingsToJson(this);
}

// Helper functions for Timestamp conversion
DateTime _timestampFromJson(dynamic timestamp) {
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  } else if (timestamp is int) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  } else if (timestamp is String) {
    return DateTime.parse(timestamp);
  }
  return DateTime.now();
}

dynamic _timestampToJson(DateTime dateTime) {
  return Timestamp.fromDate(dateTime);
}