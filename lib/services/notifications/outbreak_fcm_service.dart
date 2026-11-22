import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_role_service.dart';

/// Top-level background message handler for native OS background notifications
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
      '[FloraX FCM Background] Received background message: ${message.messageId}, Type: ${message.data['type']}');
}

/// Category classification of incoming push alerts
enum NotificationCategory {
  outbreakSpike,
  kvkPrescriptionUnlocked,
  generalAlert;

  static NotificationCategory fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'OUTBREAK_SPIKE':
        return NotificationCategory.outbreakSpike;
      case 'KVK_VERIFIED':
      case 'KVK_PRESCRIPTION_UNLOCKED':
        return NotificationCategory.kvkPrescriptionUnlocked;
      default:
        return NotificationCategory.generalAlert;
    }
  }
}

/// Structured push alert payload parsed from Firebase Cloud Messaging
@immutable
class OutbreakNotificationPayload {
  final String title;
  final String body;
  final NotificationCategory category;
  final String? geoHash5;
  final String? scanId;
  final String? diseaseName;
  final DateTime receivedAt;
  final Map<String, dynamic> rawData;

  const OutbreakNotificationPayload({
    required this.title,
    required this.body,
    required this.category,
    this.geoHash5,
    this.scanId,
    this.diseaseName,
    required this.receivedAt,
    required this.rawData,
  });

  factory OutbreakNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final cat = NotificationCategory.fromString(data['type'] as String?);

    return OutbreakNotificationPayload(
      title: message.notification?.title ??
          data['title'] as String? ??
          'FloraX Crop Alert',
      body: message.notification?.body ??
          data['body'] as String? ??
          'New regional crop health advisory available.',
      category: cat,
      geoHash5: data['geoHash5'] as String?,
      scanId: data['scanId'] as String?,
      diseaseName: data['diseaseName'] as String?,
      receivedAt: DateTime.now().toUtc(),
      rawData: data,
    );
  }
}

/// Principal Push Notification Service for Regional Outbreaks & KVK Prescriptions
class OutbreakFcmService {
  final FirebaseMessaging? _fcmInstance;
  FirebaseMessaging get _fcm => _fcmInstance ?? FirebaseMessaging.instance;

  final StreamController<OutbreakNotificationPayload> _notificationStreamController =
      StreamController<OutbreakNotificationPayload>.broadcast();

  String? _currentSubscribedGeoHash5;
  String? _currentSubscribedUserId;
  bool _isInitialized = false;

  OutbreakFcmService({FirebaseMessaging? fcm}) : _fcmInstance = fcm;

  Stream<OutbreakNotificationPayload> get onNotificationReceived =>
      _notificationStreamController.stream;

  /// Initializes messaging permissions, listens to foreground messages and binds handlers
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[FloraX FCM] Requesting notification permissions...');

      // 1. Request permissions on Android 13+ (POST_NOTIFICATIONS) and iOS
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
          '[FloraX FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            '[FloraX FCM Foreground] Message arrived: ${message.notification?.title} - ${message.notification?.body}');
        final payload = OutbreakNotificationPayload.fromRemoteMessage(message);
        _notificationStreamController.add(payload);
      });

      // 4. Notification interaction listener (when user taps notification in system tray)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            '[FloraX FCM Click] User tapped notification: ${message.data}');
        final payload = OutbreakNotificationPayload.fromRemoteMessage(message);
        _notificationStreamController.add(payload);
      });

      // 5. Configure foreground presentation options (iOS / macOS)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _isInitialized = true;
      debugPrint('[FloraX FCM] Outbreak FCM Service initialized successfully.');
    } catch (e, stackTrace) {
      debugPrint('[FloraX FCM ERROR] Initialization failed: $e\n$stackTrace');
    }
  }

  /// Automatically binds topics based on current GeoHash5 and user session
  Future<void> syncSubscriptions({
    required String geoHash5,
    required String userId,
  }) async {
    await subscribeToOutbreakTopic(geoHash5);
    await subscribeToKvkUpdates(userId);
  }

  /// Subscribes to anonymous regional taluka outbreak topic `outbreak_${geoHash5}` (~4.9km radius)
  /// Automatically unsubscribes from obsolete geographic topic when farmer travels.
  Future<void> subscribeToOutbreakTopic(String geoHash5) async {
    final cleanHash = geoHash5.trim().toLowerCase();
    if (cleanHash.isEmpty) return;

    if (_currentSubscribedGeoHash5 == cleanHash) {
      return; // Already subscribed to this regional sector
    }

    try {
      // Unsubscribe from previous sector if active
      if (_currentSubscribedGeoHash5 != null) {
        final oldTopic = 'outbreak_$_currentSubscribedGeoHash5';
        await _fcm.unsubscribeFromTopic(oldTopic);
        debugPrint('[FloraX FCM] Unsubscribed from previous topic: $oldTopic');
      }

      final newTopic = 'outbreak_$cleanHash';
      await _fcm.subscribeToTopic(newTopic);
      _currentSubscribedGeoHash5 = cleanHash;
      debugPrint(
          '[FloraX FCM] Successfully subscribed to regional topic: $newTopic');
    } catch (e) {
      debugPrint(
          '[FloraX FCM ERROR] Failed to subscribe to topic outbreak_$cleanHash: $e');
    }
  }

  /// Subscribes the device to private KVK prescription unlocks: `kvk_updates_${userId}`
  Future<void> subscribeToKvkUpdates(String userId) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;

    if (_currentSubscribedUserId == cleanUid) {
      return;
    }

    try {
      if (_currentSubscribedUserId != null) {
        final oldTopic = 'kvk_updates_$_currentSubscribedUserId';
        await _fcm.unsubscribeFromTopic(oldTopic);
        debugPrint('[FloraX FCM] Unsubscribed from old user topic: $oldTopic');
      }

      final topic = 'kvk_updates_$cleanUid';
      await _fcm.subscribeToTopic(topic);
      _currentSubscribedUserId = cleanUid;
      debugPrint(
          '[FloraX FCM] Successfully subscribed to KVK verification topic: $topic');
    } catch (e) {
      debugPrint(
          '[FloraX FCM ERROR] Failed to subscribe to topic kvk_updates_$cleanUid: $e');
    }
  }

  /// Retrieves current APNS or FCM device registration token
  Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[FloraX FCM ERROR] Failed to fetch token: $e');
      return null;
    }
  }

  void dispose() {
    _notificationStreamController.close();
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Global Riverpod Provider for Outbreak FCM Service
final outbreakFcmServiceProvider = Provider<OutbreakFcmService>((ref) {
  final service = OutbreakFcmService();
  service.initialize();

  // Auto-subscribe based on user session and location
  final authService = ref.watch(authRoleServiceProvider);
  final user = authService.currentUser;

  if (user != null) {
    service.subscribeToKvkUpdates(user.uid);
  }

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// StreamProvider exposing live foreground/background incoming notification payloads
final outbreakNotificationsStreamProvider =
    StreamProvider<OutbreakNotificationPayload>((ref) {
  final service = ref.watch(outbreakFcmServiceProvider);
  return service.onNotificationReceived;
});
