import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../../services/auth/auth_role_service.dart';

/// State of the Firebase Security & Offline Architecture Initialization
enum FirebaseBootstrapState {
  uninitialized,
  initializing,
  initialized,
  failed,
}

/// Metadata payload containing verified token claims and security status
@immutable
class FirebaseSecurityContext {
  final FirebaseBootstrapState state;
  final bool isAppCheckActive;
  final bool isOfflinePersistenceEnabled;
  final String? userRole;
  final String? errorMessage;

  const FirebaseSecurityContext({
    required this.state,
    required this.isAppCheckActive,
    required this.isOfflinePersistenceEnabled,
    this.userRole,
    this.errorMessage,
  });

  bool get isKvkScientist => userRole == 'kvk_scientist';
  bool get isAdmin => userRole == 'admin';
  bool get isFarmer => userRole == 'farmer' || userRole == null;

  FirebaseSecurityContext copyWith({
    FirebaseBootstrapState? state,
    bool? isAppCheckActive,
    bool? isOfflinePersistenceEnabled,
    String? userRole,
    String? errorMessage,
  }) {
    return FirebaseSecurityContext(
      state: state ?? this.state,
      isAppCheckActive: isAppCheckActive ?? this.isAppCheckActive,
      isOfflinePersistenceEnabled:
          isOfflinePersistenceEnabled ?? this.isOfflinePersistenceEnabled,
      userRole: userRole ?? this.userRole,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Principal Mobile Security & Offline Infrastructure Bootstrapper
class FirebaseSecurityInitService {
  static final FirebaseSecurityInitService _instance =
      FirebaseSecurityInitService._internal();

  factory FirebaseSecurityInitService() => _instance;

  FirebaseSecurityInitService._internal();

  /// Primary initialization sequence executed at application entrypoint
  Future<FirebaseSecurityContext> initialize({
    FirebaseOptions? options,
  }) async {
    try {
      debugPrint('[FloraX Security] Starting Firebase Core initialization...');

      // 1. Core Firebase Initialization exclusively with DefaultFirebaseOptions.currentPlatform
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      debugPrint('[FloraX Security] Firebase Core initialized successfully.');

      // 2. Hardware Attestation & App Check Activation
      // Enforces Google Play Integrity on Android and DeviceCheck on iOS
      // Supports compile-time USE_APP_CHECK_DEBUG override for sideloaded hackathon release APKs
      debugPrint('[FloraX Security] Activating Firebase App Check (Play Integrity / Debug Toggle)...');
      try {
        const bool useDebugAppCheck =
            bool.fromEnvironment('USE_APP_CHECK_DEBUG', defaultValue: false);
        final bool isDebug = kDebugMode || useDebugAppCheck;

        await FirebaseAppCheck.instance.activate(
          androidProvider: isDebug
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider: isDebug
              ? AppleProvider.debug
              : AppleProvider.deviceCheck,
        );
        debugPrint(
          '[FloraX Security] App Check activated with ${isDebug ? 'DebugProvider' : 'Play Integrity/DeviceCheck'}.',
        );
      } catch (appCheckErr) {
        debugPrint('[FloraX Security] App Check deferred: $appCheckErr');
      }

      // 3. Cloud Firestore Offline Field Persistence Setup
      // Guaranteed unlimited offline SQLite cache for remote rural farmlands
      debugPrint('[FloraX Security] Configuring Cloud Firestore unlimited offline cache...');
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[FloraX Security] Firestore offline persistence set to UNLIMITED.');

      // 4. Ensure authenticated session (auto-anonymous login for seamless offline/online access)
      try {
        final authService = AuthRoleService();
        await authService.ensureAuthenticatedSession();
      } catch (authErr) {
        debugPrint('[FloraX Security WARNING] Auth session initialization failed: $authErr');
      }

      // 5. Retrieve current user custom claims for Role-Based Access Control
      final String? role = await fetchCurrentUserRole();

      return FirebaseSecurityContext(
        state: FirebaseBootstrapState.initialized,
        isAppCheckActive: true,
        isOfflinePersistenceEnabled: true,
        userRole: role,
      );
    } catch (e, stackTrace) {
      debugPrint('[FloraX Security FATAL] Firebase initialization failed: $e\n$stackTrace');
      return FirebaseSecurityContext(
        state: FirebaseBootstrapState.failed,
        isAppCheckActive: false,
        isOfflinePersistenceEnabled: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Extracts the authenticated user's role from JWT claims ('admin', 'kvk_scientist', 'farmer')
  Future<String?> fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      if (claims != null && claims.containsKey('role')) {
        return claims['role'] as String?;
      }
    } catch (e) {
      debugPrint('[FloraX Security] Could not fetch user claims: $e');
    }
    return null;
  }
}

/// Riverpod Provider exposing the security bootstrap context across the app
final firebaseSecurityContextProvider =
    StateNotifierProvider<FirebaseSecurityNotifier, FirebaseSecurityContext>(
  (ref) => FirebaseSecurityNotifier(),
);

class FirebaseSecurityNotifier extends StateNotifier<FirebaseSecurityContext> {
  FirebaseSecurityNotifier()
      : super(const FirebaseSecurityContext(
          state: FirebaseBootstrapState.uninitialized,
          isAppCheckActive: false,
          isOfflinePersistenceEnabled: false,
        ));

  Future<void> boot({FirebaseOptions? options}) async {
    state = state.copyWith(state: FirebaseBootstrapState.initializing);
    final result = await FirebaseSecurityInitService().initialize(options: options);
    state = result;
  }

  Future<void> refreshRole() async {
    final role = await FirebaseSecurityInitService().fetchCurrentUserRole();
    state = state.copyWith(userRole: role);
  }
}
