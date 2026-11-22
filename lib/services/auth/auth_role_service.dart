import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/app_config.dart';

/// User Role Classification for RBAC and KVK Review Audits
enum UserRole {
  farmer,
  kvkScientist,
  admin;

  String get value {
    switch (this) {
      case UserRole.farmer:
        return 'farmer';
      case UserRole.kvkScientist:
        return 'kvk_scientist';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'kvk_scientist':
        return UserRole.kvkScientist;
      case 'admin':
        return UserRole.admin;
      case 'farmer':
      default:
        return UserRole.farmer;
    }
  }
}

/// Principal Authentication & Role-Based Access Control Service
class AuthRoleService {
  final FirebaseAuth? _authInstance;
  final FirebaseFirestore? _firestoreInstance;
  final FlutterSecureStorage _secureStorage;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  static const String _roleStorageKey = 'florax_active_user_role';

  AuthRoleService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
  })  : _authInstance = auth,
        _firestoreInstance = firestore,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }
  UserRole _cachedRole = UserRole.farmer;
  UserRole get currentRole => _cachedRole;

  /// Ensures an active authenticated session on app launch so rural farmers
  /// never encounter PERMISSION_DENIED on Firestore collections or Storage buckets.
  Future<User?> ensureAuthenticatedSession() async {
    User? user = _auth.currentUser;

    if (user == null) {
      try {
        debugPrint('[FloraX Auth] No active session found. Signing in anonymously...');
        final userCredential = await _auth.signInAnonymously();
        user = userCredential.user;

        if (user != null) {
          debugPrint('[FloraX Auth] Anonymous authentication successful. UID: ${user.uid}');
          await _upsertUserProfile(user.uid);
        }
      } catch (e) {
        debugPrint('[FloraX Auth] Anonymous authentication failed (continuing in offline mode): $e');
      }
    } else {
      debugPrint('[FloraX Auth] Existing authenticated session found: ${user.uid}');
      await _upsertUserProfile(user.uid);
    }

    return user;
  }

  /// Upserts users/{uid} profile preserving custom evaluator roles if already set
  Future<void> _upsertUserProfile(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final snapshot = await userDocRef.get();

      // Read locally cached secure role if available (for offline evaluator persistence)
      final storedRole = await _secureStorage.read(key: _roleStorageKey);

      if (!snapshot.exists || snapshot.data() == null) {
        final initialRole = storedRole ?? UserRole.farmer.value;
        await userDocRef.set({
          'uid': uid,
          'role': initialRole,
          'language': AppConfig.defaultLanguage,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isAnonymous': _auth.currentUser?.isAnonymous ?? true,
        }, SetOptions(merge: true));
        debugPrint('[FloraX Auth] Created initial user profile for UID: $uid with role: $initialRole');
      } else {
        // Document exists - update heartbeat and sync local secure storage
        final data = snapshot.data()!;
        final firestoreRole = data['role'] as String? ?? UserRole.farmer.value;

        await _secureStorage.write(key: _roleStorageKey, value: firestoreRole);
        await userDocRef.update({
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[FloraX Auth] Synced user profile for UID: $uid (Role: $firestoreRole)');
      }
    } catch (e) {
      debugPrint('[FloraX Auth WARNING] Profile upsert error (continuing offline): $e');
    }
  }

  /// Formats 10-digit mobile number into secure internal Firebase Auth email identifier
  static String mobileToEmail(String mobile) {
    final clean = mobile.replaceAll(RegExp(r'\D'), '').trim();
    return '$clean@florax.farm';
  }

  /// Authenticates registered farmer via mobile number and secure password (Req 2D)
  Future<UserCredential> loginWithMobileAndPassword({
    required String mobileNumber,
    required String password,
  }) async {
    final email = mobileToEmail(mobileNumber);
    debugPrint('[FloraX Auth] Logging in with mobile: $mobileNumber ($email)');
    
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid != null) {
      // Sync user profile from Firestore to local storage
      final profile = await fetchUserProfile(uid);
      if (profile != null) {
        final role = profile['role'] as String? ?? UserRole.farmer.value;
        await _secureStorage.write(key: _roleStorageKey, value: role);
        _cachedRole = UserRole.fromString(role);
      }
    }
    return credential;
  }

  /// Registers a new farmer account with profile details, state, and secure password (Req 2B, 2E)
  Future<UserCredential> registerWithMobileAndPassword({
    required String fullName,
    required String mobileNumber,
    required String password,
    required String state,
    required String language,
  }) async {
    final email = mobileToEmail(mobileNumber);
    debugPrint('[FloraX Auth] Registering new farmer: $fullName, $mobileNumber ($email)');

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName.trim(),
        'mobileNumber': mobileNumber.replaceAll(RegExp(r'\D'), '').trim(),
        'state': state.trim(),
        'language': language.trim(),
        'role': UserRole.farmer.value,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isAnonymous': false,
      }, SetOptions(merge: true));

      await _secureStorage.write(key: _roleStorageKey, value: UserRole.farmer.value);
      _cachedRole = UserRole.farmer;
    }
    return credential;
  }

  /// Fetches saved user profile from Firestore
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('[FloraX Auth] Error fetching profile for $uid: $e');
    }
    return null;
  }

  /// Updates farmer profile fields (state, language, etc.)
  Future<void> updateUserProfile(String uid, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FloraX Auth] Error updating profile for $uid: $e');
    }
  }

  /// Authenticates official Krishi Vigyan Kendra specialist with email and password
  Future<UserCredential> signInAsKvkScientist(String email, String password) async {
    debugPrint('[FloraX Auth] Attempting KVK Scientist sign-in for: $email');
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'role': UserRole.kvkScientist.value,
        'email': email,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _secureStorage.write(
        key: _roleStorageKey,
        value: UserRole.kvkScientist.value,
      );
    }

    return credential;
  }

  /// Secure Evaluator / Demo Role Switcher:
  /// Toggles the current user's role between 'farmer' and 'kvk_scientist' in both
  /// Firestore (`users/{uid}.role`) and local `FlutterSecureStorage`.
  /// Enables hackathon judges and evaluators to test KVK confirmation on any device seamlessly.
  Future<UserRole> toggleDemoKvkRole() async {
    final user = await ensureAuthenticatedSession();
    final uid = user?.uid ?? 'offline_evaluator_demo';

    UserRole currentRole = _cachedRole;
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final snapshot = await userDocRef.get();
      final currentRoleStr = snapshot.data()?['role'] as String? ?? _cachedRole.value;
      currentRole = UserRole.fromString(currentRoleStr);
    } catch (_) {}

    final UserRole newRole = (currentRole == UserRole.kvkScientist)
        ? UserRole.farmer
        : UserRole.kvkScientist;

    debugPrint('[FloraX Auth] Toggling user role from ${currentRole.value} to ${newRole.value} for UID: $uid');

    // 1. Update Firestore user document if online
    try {
      await _firestore.collection('users').doc(uid).set({
        'role': newRole.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // 2. Persist to local secure storage
    await _secureStorage.write(key: _roleStorageKey, value: newRole.value);
    _cachedRole = newRole;

    return newRole;
  }

  /// Retrieves the active role for the current user (checking token claims, Firestore, and secure storage)
  Future<UserRole> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      return UserRole.farmer;
    }

    // 1. Check JWT token custom claims first
    try {
      final tokenResult = await user.getIdTokenResult(false);
      final claimRole = tokenResult.claims?['role'] as String?;
      if (claimRole != null) {
        return UserRole.fromString(claimRole);
      }
    } catch (_) {}

    // 2. Check local secure storage
    try {
      final storedRole = await _secureStorage.read(key: _roleStorageKey);
      if (storedRole != null) {
        return UserRole.fromString(storedRole);
      }
    } catch (_) {}

    // 3. Fallback to Firestore users/{uid} document
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserRole.fromString(doc.data()?['role'] as String?);
      }
    } catch (_) {}

    return UserRole.farmer;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _secureStorage.delete(key: _roleStorageKey);
  }
}

// =============================================================================
// RIVERPOD DEPENDENCY INJECTION PROVIDERS
// =============================================================================

/// Global Riverpod Provider for AuthRoleService
final authRoleServiceProvider = Provider<AuthRoleService>((ref) {
  return AuthRoleService();
});

/// StreamProvider listening to Firebase Auth state changes
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// FutureProvider resolving the current user's role
final currentUserRoleProvider = FutureProvider<UserRole>((ref) async {
  final service = ref.watch(authRoleServiceProvider);
  return await service.getCurrentUserRole();
});

/// StateNotifierProvider for the demo role switcher
final demoRoleStateProvider = StateNotifierProvider<DemoRoleNotifier, AsyncValue<UserRole>>((ref) {
  final service = ref.watch(authRoleServiceProvider);
  return DemoRoleNotifier(service);
});

class DemoRoleNotifier extends StateNotifier<AsyncValue<UserRole>> {
  final AuthRoleService _service;

  DemoRoleNotifier(this._service) : super(const AsyncValue.loading()) {
    _initRole();
  }

  Future<void> _initRole() async {
    try {
      final role = await _service.getCurrentUserRole();
      state = AsyncValue.data(role);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<UserRole> toggleRole() async {
    state = const AsyncValue.loading();
    try {
      final newRole = await _service.toggleDemoKvkRole();
      state = AsyncValue.data(newRole);
      return newRole;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
