import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_data_schema.dart';

/// Base repository class for common Firestore operations
abstract class BaseFirestoreRepository<T extends FirestoreDocument> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath;

  BaseFirestoreRepository(this.collectionPath);

  /// Convert Firestore document to model
  T fromFirestore(DocumentSnapshot doc);

  /// Get collection reference
  CollectionReference get collection => _firestore.collection(collectionPath);

  /// Create a new document
  Future<void> create(T item) async {
    await collection.doc(item.id).set(item.toJson());
  }

  /// Update an existing document
  Future<void> update(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = Timestamp.now();
    await collection.doc(id).update(updates);
  }

  /// Delete a document
  Future<void> delete(String id) async {
    await collection.doc(id).delete();
  }

  /// Get a single document by ID
  Future<T?> getById(String id) async {
    final doc = await collection.doc(id).get();
    return doc.exists ? fromFirestore(doc) : null;
  }

  /// Get all documents
  Future<List<T>> getAll({int? limit}) async {
    Query query = collection;
    if (limit != null) {
      query = query.limit(limit);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Listen to a single document
  Stream<T?> streamById(String id) {
    return collection.doc(id).snapshots().map((doc) => 
        doc.exists ? fromFirestore(doc) : null);
  }

  /// Listen to all documents
  Stream<List<T>> streamAll({int? limit}) {
    Query query = collection;
    if (limit != null) {
      query = query.limit(limit);
    }
    
    return query.snapshots().map((snapshot) => 
        snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }
}

/// Repository for Composition documents
class CompositionRepository extends BaseFirestoreRepository<Composition> {
  CompositionRepository() : super('compositions');

  @override
  Composition fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Composition.fromJson(data);
  }

  /// Get featured compositions
  Future<List<Composition>> getFeatured({int limit = 10}) async {
    final snapshot = await collection
        .where('is_featured', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Get compositions by category
  Future<List<Composition>> getByCategory(String category, {int limit = 20}) async {
    final snapshot = await collection
        .where('category', isEqualTo: category)
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Stream featured compositions
  Stream<List<Composition>> streamFeatured({int limit = 10}) {
    return collection
        .where('is_featured', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }
}

/// Repository for Event documents
class EventRepository extends BaseFirestoreRepository<Event> {
  EventRepository() : super('events');

  @override
  Event fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Event.fromJson(data);
  }

  /// Get upcoming events
  Future<List<Event>> getUpcoming({int limit = 10}) async {
    final now = Timestamp.now();
    final snapshot = await collection
        .where('event_date', isGreaterThan: now)
        .where('is_public', isEqualTo: true)
        .orderBy('event_date')
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Get featured events
  Future<List<Event>> getFeatured({int limit = 5}) async {
    final snapshot = await collection
        .where('is_featured', isEqualTo: true)
        .where('is_public', isEqualTo: true)
        .orderBy('event_date')
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Stream upcoming events
  Stream<List<Event>> streamUpcoming({int limit = 10}) {
    final now = Timestamp.now();
    return collection
        .where('event_date', isGreaterThan: now)
        .where('is_public', isEqualTo: true)
        .orderBy('event_date')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }
}

/// Repository for Bio documents
class BioRepository extends BaseFirestoreRepository<Bio> {
  BioRepository() : super('bio');

  @override
  Bio fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Bio.fromJson(data);
  }

  /// Get the main bio document
  Future<Bio?> getMainBio() async {
    final snapshot = await collection.limit(1).get();
    return snapshot.docs.isNotEmpty ? fromFirestore(snapshot.docs.first) : null;
  }

  /// Stream the main bio document
  Stream<Bio?> streamMainBio() {
    return collection.limit(1).snapshots().map((snapshot) => 
        snapshot.docs.isNotEmpty ? fromFirestore(snapshot.docs.first) : null);
  }
}

/// Repository for Media documents
class MediaRepository extends BaseFirestoreRepository<Media> {
  MediaRepository() : super('media');

  @override
  Media fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return Media.fromJson(data);
  }

  /// Get media by type
  Future<List<Media>> getByType(String mediaType, {int limit = 20}) async {
    final snapshot = await collection
        .where('media_type', isEqualTo: mediaType)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Get featured media
  Future<List<Media>> getFeatured({int limit = 10}) async {
    final snapshot = await collection
        .where('is_featured', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Get media for a specific composition
  Future<List<Media>> getForComposition(String compositionId) async {
    final snapshot = await collection
        .where('associated_composition_id', isEqualTo: compositionId)
        .orderBy('created_at', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }
}

/// Repository for Contact messages
class ContactRepository extends BaseFirestoreRepository<ContactMessage> {
  ContactRepository() : super('contacts');

  @override
  ContactMessage fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return ContactMessage.fromJson(data);
  }

  /// Get unread messages
  Future<List<ContactMessage>> getUnread({int limit = 50}) async {
    final snapshot = await collection
        .where('is_read', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  /// Mark message as read
  Future<void> markAsRead(String id) async {
    await update(id, {'is_read': true});
  }

  /// Submit a new contact message
  Future<void> submitMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    final now = DateTime.now();
    final contactMessage = ContactMessage(
      id: collection.doc().id,
      name: name,
      email: email,
      subject: subject,
      message: message,
      isRead: false,
      createdAt: now,
      updatedAt: now,
    );
    
    await create(contactMessage);
  }
}

/// Repository for User profiles
class UserRepository extends BaseFirestoreRepository<UserProfile> {
  UserRepository() : super('users');

  @override
  UserProfile fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return UserProfile.fromJson(data);
  }

  /// Create or update user profile from Firebase Auth user
  Future<void> createOrUpdateFromAuth(User user, {bool isAdmin = false}) async {
    final userProfile = UserProfile(
      id: user.uid,
      displayName: user.displayName ?? user.email ?? 'User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      isAdmin: isAdmin,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await collection.doc(user.uid).set(userProfile.toJson(), SetOptions(merge: true));
  }

  /// Check if user is admin
  Future<bool> isAdmin(String userId) async {
    final user = await getById(userId);
    return user?.isAdmin ?? false;
  }
}

/// Repository for Site settings
class SettingsRepository extends BaseFirestoreRepository<SiteSettings> {
  SettingsRepository() : super('settings');

  @override
  SiteSettings fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return SiteSettings.fromJson(data);
  }

  /// Get the main site settings
  Future<SiteSettings?> getMainSettings() async {
    final snapshot = await collection.limit(1).get();
    return snapshot.docs.isNotEmpty ? fromFirestore(snapshot.docs.first) : null;
  }

  /// Stream the main site settings
  Stream<SiteSettings?> streamMainSettings() {
    return collection.limit(1).snapshots().map((snapshot) => 
        snapshot.docs.isNotEmpty ? fromFirestore(snapshot.docs.first) : null);
  }
}

/// Central Firestore service class
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final CompositionRepository compositions = CompositionRepository();
  final EventRepository events = EventRepository();
  final BioRepository bio = BioRepository();
  final MediaRepository media = MediaRepository();
  final ContactRepository contacts = ContactRepository();
  final UserRepository users = UserRepository();
  final SettingsRepository settings = SettingsRepository();

  /// Initialize with sample data (only for development/testing)
  Future<void> initializeSampleData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Create sample settings
    final sampleSettings = SiteSettings(
      id: 'main',
      siteTitle: 'John Estacio - Composer',
      siteDescription: 'Official website of composer John Estacio',
      socialLinks: {
        'twitter': 'https://twitter.com/johnestacio',
        'facebook': 'https://facebook.com/johnestacio',
        'instagram': 'https://instagram.com/johnestacio',
      },
      contactEmail: 'john@estacio.com',
      adminId: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await settings.create(sampleSettings);

    // Create sample bio
    final sampleBio = Bio(
      id: 'main',
      content: 'John Estacio is a renowned composer known for his innovative orchestral and chamber works.',
      achievements: [
        'Juno Award Winner',
        'Order of Canada Recipient',
        'Multiple SOCAN Awards',
      ],
      awards: [
        'Juno Award for Classical Composition',
        'Western Canadian Music Award',
        'Calgary Arts Development Award',
      ],
      ownerId: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await bio.create(sampleBio);

    // Create sample compositions
    final sampleCompositions = [
      Composition(
        id: 'composition_1',
        title: 'Frenergy',
        description: 'A high-energy orchestral work inspired by the frenetic pace of modern life.',
        category: 'orchestral',
        yearComposed: 2018,
        duration: '12 minutes',
        instrumentation: ['Full Orchestra'],
        isFeatured: true,
        ownerId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Composition(
        id: 'composition_2',
        title: 'String Quartet No. 2',
        description: 'An intimate chamber work exploring themes of memory and place.',
        category: 'chamber',
        yearComposed: 2020,
        duration: '18 minutes',
        instrumentation: ['2 Violins', 'Viola', 'Cello'],
        isFeatured: true,
        ownerId: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final composition in sampleCompositions) {
      await compositions.create(composition);
    }
  }
}