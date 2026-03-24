// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firestore_data_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

// This file will be generated automatically when you run:
// dart run build_runner build
//
// To generate this file, run:
// flutter packages pub run build_runner build

Composition _$CompositionFromJson(Map<String, dynamic> json) => Composition(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      yearComposed: json['year_composed'] as int?,
      duration: json['duration'] as String?,
      instrumentation: (json['instrumentation'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      scoreUrl: json['score_url'] as String?,
      audioUrls: (json['audio_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      videoUrls: (json['video_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isFeatured: json['is_featured'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? true,
      ownerId: json['owner_id'] as String,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$CompositionToJson(Composition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'year_composed': instance.yearComposed,
      'duration': instance.duration,
      'instrumentation': instance.instrumentation,
      'score_url': instance.scoreUrl,
      'audio_urls': instance.audioUrls,
      'video_urls': instance.videoUrls,
      'is_featured': instance.isFeatured,
      'is_published': instance.isPublished,
      'owner_id': instance.ownerId,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      venue: json['venue'] as String,
      location: json['location'] as String?,
      eventDate: _timestampFromJson(json['event_date']),
      ticketUrl: json['ticket_url'] as String?,
      compositions: (json['compositions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isFeatured: json['is_featured'] as bool? ?? false,
      isPublic: json['is_public'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      ownerId: json['owner_id'] as String,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'venue': instance.venue,
      'location': instance.location,
      'event_date': _timestampToJson(instance.eventDate),
      'ticket_url': instance.ticketUrl,
      'compositions': instance.compositions,
      'is_featured': instance.isFeatured,
      'is_public': instance.isPublic,
      'image_url': instance.imageUrl,
      'owner_id': instance.ownerId,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };

Bio _$BioFromJson(Map<String, dynamic> json) => Bio(
      id: json['id'] as String,
      content: json['content'] as String,
      photoUrl: json['photo_url'] as String?,
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      awards: (json['awards'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      educationBackground: json['education_background'] as String?,
      ownerId: json['owner_id'] as String,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$BioToJson(Bio instance) => <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'photo_url': instance.photoUrl,
      'achievements': instance.achievements,
      'awards': instance.awards,
      'education_background': instance.educationBackground,
      'owner_id': instance.ownerId,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };

Media _$MediaFromJson(Map<String, dynamic> json) => Media(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      mediaType: json['media_type'] as String,
      fileUrl: json['file_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      associatedCompositionId: json['associated_composition_id'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      duration: json['duration'] as int?,
      ownerId: json['owner_id'] as String,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$MediaToJson(Media instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'media_type': instance.mediaType,
      'file_url': instance.fileUrl,
      'thumbnail_url': instance.thumbnailUrl,
      'associated_composition_id': instance.associatedCompositionId,
      'is_featured': instance.isFeatured,
      'duration': instance.duration,
      'owner_id': instance.ownerId,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };

ContactMessage _$ContactMessageFromJson(Map<String, dynamic> json) =>
    ContactMessage(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      subject: json['subject'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$ContactMessageToJson(ContactMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'subject': instance.subject,
      'message': instance.message,
      'is_read': instance.isRead,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String,
      photoUrl: json['photo_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'display_name': instance.displayName,
      'email': instance.email,
      'photo_url': instance.photoUrl,
      'is_admin': instance.isAdmin,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };

SiteSettings _$SiteSettingsFromJson(Map<String, dynamic> json) => SiteSettings(
      id: json['id'] as String,
      siteTitle: json['site_title'] as String,
      siteDescription: json['site_description'] as String?,
      logoUrl: json['logo_url'] as String?,
      socialLinks: Map<String, String>.from(json['social_links'] as Map? ?? {}),
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      adminId: json['admin_id'] as String,
      createdAt: _timestampFromJson(json['created_at']),
      updatedAt: _timestampFromJson(json['updated_at']),
    );

Map<String, dynamic> _$SiteSettingsToJson(SiteSettings instance) =>
    <String, dynamic>{
      'id': instance.id,
      'site_title': instance.siteTitle,
      'site_description': instance.siteDescription,
      'logo_url': instance.logoUrl,
      'social_links': instance.socialLinks,
      'contact_email': instance.contactEmail,
      'contact_phone': instance.contactPhone,
      'admin_id': instance.adminId,
      'created_at': _timestampToJson(instance.createdAt),
      'updated_at': _timestampToJson(instance.updatedAt),
    };