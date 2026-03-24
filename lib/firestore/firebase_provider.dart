import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'firestore_repository.dart';
import 'firestore_data_schema.dart';

/// Main provider for Firebase services and data
class FirebaseProvider extends ChangeNotifier {
  static final FirebaseProvider _instance = FirebaseProvider._internal();
  factory FirebaseProvider() => _instance;
  FirebaseProvider._internal() {
    _initialize();
  }

  // Services
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Data streams
  Stream<List<Composition>>? _featuredCompositionsStream;
  Stream<List<Event>>? _upcomingEventsStream;
  Stream<Bio?>? _bioStream;
  Stream<SiteSettings?>? _settingsStream;

  // Cached data
  List<Composition> _featuredCompositions = [];
  List<Event> _upcomingEvents = [];
  Bio? _bio;
  SiteSettings? _settings;

  // Loading states
  bool _isLoading = false;
  String? _error;

  // Getters for services
  FirestoreService get firestore => _firestoreService;
  AuthService get auth => _authService;

  // Getters for data
  List<Composition> get featuredCompositions => _featuredCompositions;
  List<Event> get upcomingEvents => _upcomingEvents;
  Bio? get bio => _bio;
  SiteSettings? get settings => _settings;

  // Getters for state
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.isAuthenticated;
  User? get currentUser => _authService.currentUser;

  // Getters for data streams
  Stream<List<Composition>> get featuredCompositionsStream {
    _featuredCompositionsStream ??= _firestoreService.compositions.streamFeatured();
    return _featuredCompositionsStream!;
  }

  Stream<List<Event>> get upcomingEventsStream {
    _upcomingEventsStream ??= _firestoreService.events.streamUpcoming();
    return _upcomingEventsStream!;
  }

  Stream<Bio?> get bioStream {
    _bioStream ??= _firestoreService.bio.streamMainBio();
    return _bioStream!;
  }

  Stream<SiteSettings?> get settingsStream {
    _settingsStream ??= _firestoreService.settings.streamMainSettings();
    return _settingsStream!;
  }

  /// Initialize provider
  void _initialize() {
    _authService.addListener(_onAuthChanged);
    _loadInitialData();
    _setupDataStreams();
  }

  /// Handle authentication state changes
  void _onAuthChanged() {
    notifyListeners();
  }

  /// Load initial data
  Future<void> _loadInitialData() async {
    await _loadFeaturedCompositions();
    await _loadUpcomingEvents();
    await _loadBio();
    await _loadSettings();
  }

  /// Setup data stream listeners
  void _setupDataStreams() {
    featuredCompositionsStream.listen(
      (compositions) {
        _featuredCompositions = compositions;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load compositions: $error';
        notifyListeners();
      },
    );

    upcomingEventsStream.listen(
      (events) {
        _upcomingEvents = events;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load events: $error';
        notifyListeners();
      },
    );

    bioStream.listen(
      (bio) {
        _bio = bio;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load bio: $error';
        notifyListeners();
      },
    );

    settingsStream.listen(
      (settings) {
        _settings = settings;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load settings: $error';
        notifyListeners();
      },
    );
  }

  /// Load featured compositions
  Future<void> _loadFeaturedCompositions() async {
    try {
      final compositions = await _firestoreService.compositions.getFeatured();
      _featuredCompositions = compositions;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load compositions: $e';
      notifyListeners();
    }
  }

  /// Load upcoming events
  Future<void> _loadUpcomingEvents() async {
    try {
      final events = await _firestoreService.events.getUpcoming();
      _upcomingEvents = events;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load events: $e';
      notifyListeners();
    }
  }

  /// Load bio
  Future<void> _loadBio() async {
    try {
      final bio = await _firestoreService.bio.getMainBio();
      _bio = bio;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load bio: $e';
      notifyListeners();
    }
  }

  /// Load settings
  Future<void> _loadSettings() async {
    try {
      final settings = await _firestoreService.settings.getMainSettings();
      _settings = settings;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load settings: $e';
      notifyListeners();
    }
  }

  /// Refresh all data
  Future<void> refreshData() async {
    _setLoading(true);
    _error = null;
    
    try {
      await _loadInitialData();
    } catch (e) {
      _error = 'Failed to refresh data: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Get compositions by category
  Future<List<Composition>> getCompositionsByCategory(String category) async {
    try {
      return await _firestoreService.compositions.getByCategory(category);
    } catch (e) {
      throw Exception('Failed to load compositions by category: $e');
    }
  }

  /// Get media by type
  Future<List<Media>> getMediaByType(String mediaType) async {
    try {
      return await _firestoreService.media.getByType(mediaType);
    } catch (e) {
      throw Exception('Failed to load media by type: $e');
    }
  }

  /// Get media for composition
  Future<List<Media>> getMediaForComposition(String compositionId) async {
    try {
      return await _firestoreService.media.getForComposition(compositionId);
    } catch (e) {
      throw Exception('Failed to load media for composition: $e');
    }
  }

  /// Submit contact message
  Future<void> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      await _firestoreService.contacts.submitMessage(
        name: name,
        email: email,
        subject: subject,
        message: message,
      );
    } catch (e) {
      throw Exception('Failed to submit contact message: $e');
    }
  }

  /// Initialize sample data (for development)
  Future<void> initializeSampleData() async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to initialize sample data');
    }

    try {
      _setLoading(true);
      await _firestoreService.initializeSampleData();
      await refreshData();
    } catch (e) {
      _error = 'Failed to initialize sample data: $e';
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    return await _authService.isCurrentUserAdmin();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// Provider for composition-specific data
class CompositionProvider extends ChangeNotifier {
  final FirebaseProvider _firebaseProvider = FirebaseProvider();
  
  String? _selectedCategory;
  List<Composition> _compositions = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  String? get selectedCategory => _selectedCategory;
  List<Composition> get compositions => _compositions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load compositions by category
  Future<void> loadByCategory(String category) async {
    if (_selectedCategory == category && _compositions.isNotEmpty) return;

    _selectedCategory = category;
    _setLoading(true);
    _error = null;

    try {
      _compositions = await _firebaseProvider.getCompositionsByCategory(category);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Clear current selection
  void clearSelection() {
    _selectedCategory = null;
    _compositions = [];
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

/// Provider for media-specific data
class MediaProvider extends ChangeNotifier {
  final FirebaseProvider _firebaseProvider = FirebaseProvider();
  
  Map<String, List<Media>> _mediaByType = {};
  Map<String, List<Media>> _mediaByComposition = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get media by type
  List<Media> getByType(String mediaType) {
    return _mediaByType[mediaType] ?? [];
  }

  /// Get media for composition
  List<Media> getForComposition(String compositionId) {
    return _mediaByComposition[compositionId] ?? [];
  }

  /// Load media by type
  Future<void> loadByType(String mediaType) async {
    if (_mediaByType.containsKey(mediaType)) return;

    _setLoading(true);
    _error = null;

    try {
      final media = await _firebaseProvider.getMediaByType(mediaType);
      _mediaByType[mediaType] = media;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Load media for composition
  Future<void> loadForComposition(String compositionId) async {
    if (_mediaByComposition.containsKey(compositionId)) return;

    _setLoading(true);
    _error = null;

    try {
      final media = await _firebaseProvider.getMediaForComposition(compositionId);
      _mediaByComposition[compositionId] = media;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}