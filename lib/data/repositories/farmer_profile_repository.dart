import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_activity_logger.dart';
import '../../domain/models/florax_models.dart';

/// Thrown when attempting to register a mobile number that is already registered
class DuplicateFarmerException implements Exception {
  final String message;
  const DuplicateFarmerException(this.message);
  @override
  String toString() => message;
}

/// Thrown when attempting to log in with an unregistered mobile number
class UnregisteredFarmerException implements Exception {
  final String message;
  const UnregisteredFarmerException(this.message);
  @override
  String toString() => message;
}

/// Thrown when the entered farmer name does not match the registered name
class CredentialMismatchException implements Exception {
  final String message;
  const CredentialMismatchException(this.message);
  @override
  String toString() => message;
}

/// Offline-first repository managing farmer authentication and profile data.
/// Backed by Cloud Firestore `farmers/{mobileE164}` with SharedPreferences local persistence.
class FarmerProfileRepository {
  final FirebaseFirestore _firestore;
  static const String _prefKeyActiveFarmer = 'florax_active_farmer_profile';
  static const String _prefKeyRegistry = 'registered_farmers_registry';
  static const String _collectionPath = 'farmers';

  FarmerProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Normalizes farmer full name for case- and whitespace-insensitive matching
  static String normalizeNameKey(String name) => name.trim().toLowerCase();

  /// Extracts clean 10 digits from any raw mobile input
  static String normalizeMobile10(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  /// Sanitizes raw mobile input to standard E.164 format (+91XXXXXXXXXX)
  static String formatMobileE164(String input) {
    final digits10 = normalizeMobile10(input);
    if (digits10.length == 10) {
      return '+91$digits10';
    }
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      return '+$digits';
    }
    return input.trim();
  }

  /// Internal helper: loads local registered farmers registry ledger
  Future<Map<String, dynamic>> _getLocalRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyRegistry);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[FarmerProfileRepository] _getLocalRegistry error: $e');
    }
    return {};
  }

  /// Internal helper: finds farmer in local ledger
  Future<FarmerProfile?> _getFromLocalRegistry(String mobileE164) async {
    final registry = await _getLocalRegistry();
    final rawEntry = registry[mobileE164];
    if (rawEntry != null) {
      try {
        final Map<String, dynamic> map = rawEntry is String
            ? jsonDecode(rawEntry)
            : Map<String, dynamic>.from(rawEntry as Map);
        return FarmerProfile.fromMap(map, mobileE164);
      } catch (e) {
        debugPrint('[FarmerProfileRepository] _getFromLocalRegistry parse error: $e');
      }
    }
    return null;
  }

  /// Internal helper: updates local registered farmers registry ledger
  Future<void> _saveToLocalRegistry(FarmerProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registry = await _getLocalRegistry();
      registry[profile.mobileE164] = profile.toMap();
      await prefs.setString(_prefKeyRegistry, jsonEncode(registry));
    } catch (e) {
      debugPrint('[FarmerProfileRepository] _saveToLocalRegistry error: $e');
    }
  }

  /// Strict Farmer Registration.
  /// Validates full name and 10-digit mobile number.
  /// Checks local ledger and Cloud Firestore (5s timeout fallback).
  /// Throws [DuplicateFarmerException] if already registered.
  Future<FarmerProfile> registerFarmer({
    required String fullName,
    required String mobile10Digits,
    String? village,
    String? district,
    String? state,
    String? pincode,
    String? preferredLanguage,
    bool notificationsEnabled = true,
    bool voiceGuidanceEnabled = true,
  }) async {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Full name cannot be empty.');
    }

    final digits10 = normalizeMobile10(mobile10Digits);
    if (digits10.length != 10) {
      throw ArgumentError('Please enter a valid 10-digit Indian mobile number.');
    }

    final mobileE164 = '+91$digits10';
    final nameKey = normalizeNameKey(trimmedName);

    // 1. Check local registry first
    final localExisting = await _getFromLocalRegistry(mobileE164);
    if (localExisting != null) {
      throw DuplicateFarmerException(
        'Account already registered for $mobileE164. Please log in instead.',
      );
    }

    // 2. Check Cloud Firestore with 5s timeout fallback
    try {
      final docRef = _firestore.collection(_collectionPath).doc(mobileE164);
      final docSnap = await docRef
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (docSnap.exists && docSnap.data() != null) {
        final existingProfile = FarmerProfile.fromMap(docSnap.data()!, docSnap.id);
        await _saveToLocalRegistry(existingProfile);

        throw DuplicateFarmerException(
          'Account already registered for $mobileE164 in Cloud Firestore. Please log in instead.',
        );
      }
    } on DuplicateFarmerException {
      rethrow;
    } catch (e) {
      debugPrint('[FarmerProfileRepository] Firestore registration check note (offline fallback): $e');
    }

    // Also check if any existing account has same nameKey + mobileE164
    final registry = await _getLocalRegistry();
    for (final entry in registry.values) {
      try {
        final map = entry is String ? jsonDecode(entry) : Map<String, dynamic>.from(entry as Map);
        final regMobile = map['mobileE164']?.toString();
        final regName = map['fullName']?.toString() ?? '';
        if (regMobile == mobileE164 || (normalizeNameKey(regName) == nameKey && regMobile == mobileE164)) {
          throw DuplicateFarmerException(
            'Account already registered for $mobileE164. Please log in instead.',
          );
        }
      } catch (e) {
        if (e is DuplicateFarmerException) rethrow;
      }
    }

    // 3. Create fresh new profile
    final now = DateTime.now();
    final newProfile = FarmerProfile(
      mobileE164: mobileE164,
      fullName: trimmedName,
      village: village ?? '',
      district: district ?? '',
      state: state ?? 'Maharashtra',
      pincode: pincode ?? '',
      preferredLanguage: preferredLanguage ?? 'mr',
      notificationsEnabled: notificationsEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled,
      createdAt: now,
      lastLoginAt: now,
      isRegistered: true,
    );

    // Persist to local registry, active profile cache, and Cloud Firestore
    await _saveToLocalRegistry(newProfile);
    await saveProfile(newProfile);

    AppActivityLogger.instance.log(
      screen: 'welcome_registration',
      action: 'farmer_registration',
      backendTarget: 'Firestore.farmers',
      status: 'SUCCESS',
      details: {
        'mobileE164': newProfile.mobileE164,
        'fullName': newProfile.fullName,
        'district': newProfile.district,
        'state': newProfile.state,
      },
    );

    return newProfile;
  }

  /// Strict Farmer Login.
  /// Checks Firestore (5s timeout) falling back to local registry ledger.
  /// Throws [UnregisteredFarmerException] if no record exists for mobile.
  /// Throws [CredentialMismatchException] if stored name does not match nameKey.
  Future<FarmerProfile> loginFarmer({
    required String fullName,
    required String mobile10Digits,
  }) async {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Full name cannot be empty.');
    }

    final digits10 = normalizeMobile10(mobile10Digits);
    if (digits10.length != 10) {
      throw ArgumentError('Please enter a valid 10-digit Indian mobile number.');
    }

    final mobileE164 = '+91$digits10';
    final nameKey = normalizeNameKey(trimmedName);

    FarmerProfile? foundProfile;

    // 1. Check Firestore with 5-second timeout
    try {
      final docRef = _firestore.collection(_collectionPath).doc(mobileE164);
      final docSnap = await docRef
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (docSnap.exists && docSnap.data() != null) {
        foundProfile = FarmerProfile.fromMap(docSnap.data()!, docSnap.id);
        await _saveToLocalRegistry(foundProfile);
      }
    } catch (e) {
      debugPrint('[FarmerProfileRepository] Firestore login fetch note (falling back to local): $e');
    }

    // 2. Fallback to local registry if Firestore didn't return
    if (foundProfile == null) {
      foundProfile = await _getFromLocalRegistry(mobileE164);
    }

    // 3. If NO record exists for mobileE164, throw UnregisteredFarmerException
    if (foundProfile == null || !foundProfile.isRegistered) {
      throw UnregisteredFarmerException(
        'No registered farmer found for $mobileE164. Please register first.',
      );
    }

    // 4. Validate stored name matches nameKey
    final storedNameKey = normalizeNameKey(foundProfile.fullName);
    if (storedNameKey != nameKey) {
      throw CredentialMismatchException(
        'Entered name does not match the registered profile for $mobileE164.',
      );
    }

    // 5. Hydrate active session
    final updated = foundProfile.copyWith(lastLoginAt: DateTime.now());
    await _saveToLocalRegistry(updated);
    await saveProfile(updated);

    AppActivityLogger.instance.log(
      screen: 'welcome_registration',
      action: 'farmer_login',
      backendTarget: 'Firestore.farmers',
      status: 'SUCCESS',
      details: {
        'mobileE164': updated.mobileE164,
        'fullName': updated.fullName,
      },
    );

    return updated;
  }

  /// Passwordless Login or Registration adapter for backwards compatibility
  Future<FarmerProfile> loginOrRegisterPasswordless({
    required String rawMobile,
    String? fullName,
    String? village,
    String? district,
    String? state,
    String? pincode,
    String? preferredLanguage,
    bool notificationsEnabled = true,
    bool voiceGuidanceEnabled = true,
  }) async {
    final mobile10 = normalizeMobile10(rawMobile);
    final effectiveName = fullName?.trim() ?? '';

    // Check if account already exists
    final mobileE164 = formatMobileE164(rawMobile);
    final local = await _getFromLocalRegistry(mobileE164);
    if (local != null) {
      if (effectiveName.isNotEmpty) {
        try {
          return await loginFarmer(fullName: effectiveName, mobile10Digits: mobile10);
        } catch (_) {}
      }
      return local;
    }

    // Try register
    try {
      return await registerFarmer(
        fullName: effectiveName.isNotEmpty ? effectiveName : 'Kisan Mitra',
        mobile10Digits: mobile10,
        village: village,
        district: district,
        state: state,
        pincode: pincode,
        preferredLanguage: preferredLanguage,
        notificationsEnabled: notificationsEnabled,
        voiceGuidanceEnabled: voiceGuidanceEnabled,
      );
    } catch (e) {
      if (e is DuplicateFarmerException && effectiveName.isNotEmpty) {
        return await loginFarmer(fullName: effectiveName, mobile10Digits: mobile10);
      }
      rethrow;
    }
  }

  /// Saves or updates the farmer profile locally and syncs with Firestore
  Future<void> saveProfile(FarmerProfile profile) async {
    // 1. Save locally to SharedPreferences for instant offline access
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = {
        'mobileE164': profile.mobileE164,
        'fullName': profile.fullName,
        'village': profile.village,
        'district': profile.district,
        'state': profile.state,
        'pincode': profile.pincode,
        'preferredLanguage': profile.preferredLanguage,
        'notificationsEnabled': profile.notificationsEnabled,
        'voiceGuidanceEnabled': profile.voiceGuidanceEnabled,
        'createdAt': profile.createdAt.toIso8601String(),
        'lastLoginAt': profile.lastLoginAt.toIso8601String(),
        'isRegistered': profile.isRegistered,
      };
      await prefs.setString(_prefKeyActiveFarmer, jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('[FarmerProfileRepository ERROR] Local cache save failed: $e');
    }

    // 2. Sync to Cloud Firestore
    try {
      final docRef = _firestore.collection(_collectionPath).doc(profile.mobileE164);
      await docRef.set(profile.toMap(), SetOptions(merge: true));
      debugPrint('[FarmerProfileRepository] Synced profile to Firestore: ${profile.mobileE164}');
      AppActivityLogger.instance.log(
        screen: 'welcome_registration',
        action: 'onboarding_save',
        backendTarget: 'Firestore.farmers',
        status: 'SUCCESS',
        details: {
          'mobileE164': profile.mobileE164,
          'fullName': profile.fullName,
          'district': profile.district,
          'state': profile.state,
        },
      );
    } catch (e) {
      debugPrint('[FarmerProfileRepository WARNING] Cloud sync failed (offline): $e');
      AppActivityLogger.instance.log(
        screen: 'welcome_registration',
        action: 'onboarding_save',
        backendTarget: 'Firestore.farmers',
        status: 'OFFLINE_FALLBACK',
        details: {
          'mobileE164': profile.mobileE164,
          'error': e.toString(),
        },
      );
    }
  }

  /// Retrieves the active profile from local cache or Firestore
  Future<FarmerProfile?> getProfile(String rawMobile) async {
    final mobileE164 = formatMobileE164(rawMobile);

    // Try local cache first
    final local = await getLocalProfile();
    if (local != null && local.mobileE164 == mobileE164) {
      return local;
    }

    // Try Firestore
    try {
      final docSnap = await _firestore.collection(_collectionPath).doc(mobileE164).get();
      if (docSnap.exists && docSnap.data() != null) {
        final profile = FarmerProfile.fromMap(docSnap.data()!, docSnap.id);
        await saveProfile(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('[FarmerProfileRepository] getProfile cloud lookup error: $e');
    }

    return local;
  }

  /// Retrieves the currently cached profile on the device
  Future<FarmerProfile?> getLocalProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyActiveFarmer);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(raw);
        return FarmerProfile.fromMap(map);
      }
    } catch (e) {
      debugPrint('[FarmerProfileRepository] getLocalProfile error: $e');
    }
    return null;
  }

  /// Real-time stream of farmer profile updates
  Stream<FarmerProfile?> watchProfile(String rawMobile) {
    final mobileE164 = formatMobileE164(rawMobile);
    return _firestore
        .collection(_collectionPath)
        .doc(mobileE164)
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        return FarmerProfile.fromMap(snap.data()!, snap.id);
      }
      return null;
    });
  }

  /// Updates specific user preferences (voice, notifications, language)
  Future<void> updatePreferences({
    required String rawMobile,
    String? language,
    bool? notificationsEnabled,
    bool? voiceGuidanceEnabled,
  }) async {
    final current = await getProfile(rawMobile);
    if (current == null) return;

    final updated = current.copyWith(
      preferredLanguage: language ?? current.preferredLanguage,
      notificationsEnabled: notificationsEnabled ?? current.notificationsEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? current.voiceGuidanceEnabled,
    );

    await saveProfile(updated);
  }

  /// Clears active farmer session from local storage
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyActiveFarmer);
    } catch (e) {
      debugPrint('[FarmerProfileRepository] logout error: $e');
    }
  }
}

/// Global Riverpod Provider for FarmerProfileRepository
final farmerProfileRepositoryProvider = Provider<FarmerProfileRepository>((ref) {
  return FarmerProfileRepository();
});
