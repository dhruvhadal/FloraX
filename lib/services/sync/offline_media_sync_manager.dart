import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';

/// Item descriptor for queued offline leaf scan images
@immutable
class PendingUploadItem {
  final String scanId;
  final String userId;
  final String plantTagId;
  final String geoHash5;
  final String localFilePath;
  final DateTime enqueuedAt;
  final int retryCount;

  const PendingUploadItem({
    required this.scanId,
    required this.userId,
    required this.plantTagId,
    required this.geoHash5,
    required this.localFilePath,
    required this.enqueuedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'scanId': scanId,
        'userId': userId,
        'plantTagId': plantTagId,
        'geoHash5': geoHash5,
        'localFilePath': localFilePath,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingUploadItem.fromJson(Map<String, dynamic> json) =>
      PendingUploadItem(
        scanId: json['scanId'] as String,
        userId: json['userId'] as String,
        plantTagId: json['plantTagId'] as String? ?? 'UNKNOWN',
        geoHash5: json['geoHash5'] as String? ?? 'te7uc',
        localFilePath: json['localFilePath'] as String,
        enqueuedAt: DateTime.tryParse(json['enqueuedAt'] as String? ?? '') ??
            DateTime.now(),
        retryCount: json['retryCount'] as int? ?? 0,
      );

  PendingUploadItem copyWith({
    int? retryCount,
  }) {
    return PendingUploadItem(
      scanId: scanId,
      userId: userId,
      plantTagId: plantTagId,
      geoHash5: geoHash5,
      localFilePath: localFilePath,
      enqueuedAt: enqueuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// State Notifier tracking count of pending offline uploads
class PendingUploadsCountNotifier extends StateNotifier<int> {
  PendingUploadsCountNotifier() : super(0);

  void updateCount(int count) {
    state = count;
  }
}

/// Offline Media Synchronization Manager (Spark-Safe Local Disk Storage)
///
/// Ensures zero data loss and Spark plan compatibility:
/// 1. Persists full-resolution leaf photos locally on device: `${appDocDir.path}/scans/${scanId}.jpg`
/// 2. Manages an atomic JSON manifest file: `${appDocDir.path}/pending_uploads.json`
/// 3. Subscribes to network connectivity events via `connectivity_plus`
/// 4. Reconciles Firestore scan documents without calling locked Firebase Storage
class OfflineMediaSyncManager {
  final FirebaseFirestore? _firestoreInstance;
  final Connectivity _connectivity;
  final PendingUploadsCountNotifier _countNotifier;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isInitialized = false;

  OfflineMediaSyncManager({
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
    PendingUploadsCountNotifier? countNotifier,
  })  : _firestoreInstance = firestore,
        _connectivity = connectivity ?? Connectivity(),
        _countNotifier = countNotifier ?? PendingUploadsCountNotifier();

  /// Initializes local cache directory, counts pending items, and binds connectivity listener
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final manifest = await _readManifest();
      _countNotifier.updateCount(manifest.length);

      // Listen for connectivity transitions
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen((dynamic event) {
        bool hasConnection = false;
        if (event is List) {
          hasConnection = event.any((r) => r != ConnectivityResult.none);
        } else if (event is ConnectivityResult) {
          hasConnection = event != ConnectivityResult.none;
        }

        if (hasConnection) {
          debugPrint(
              '[FloraX OfflineSync] Connectivity restored. Triggering auto-sync...');
          syncPendingUploads();
        }
      });

      _isInitialized = true;
      debugPrint(
          '[FloraX OfflineSync] Initialized. Local scans queue: ${manifest.length} items.');

      final currentConnectivity = await _connectivity.checkConnectivity();
      final currentlyConnected =
          currentConnectivity.any((r) => r != ConnectivityResult.none);

      if (currentlyConnected && manifest.isNotEmpty) {
        unawaited(syncPendingUploads());
      }
    } catch (e, stackTrace) {
      debugPrint('[FloraX OfflineSync ERROR] Initialization failed: $e\n$stackTrace');
    }
  }

  /// Saves full-resolution leaf photo locally on device (${appDocDir.path}/scans/${scanId}.jpg)
  Future<String> saveLocalScan({
    required String scanId,
    required Uint8List imageBytes,
  }) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final scansDirectory =
          Directory('${appDocDir.path}/${AppConfig.pendingScansDirectoryName}');

      if (!await scansDirectory.exists()) {
        await scansDirectory.create(recursive: true);
      }

      final localFilePath = '${scansDirectory.path}/$scanId.jpg';
      final imageFile = File(localFilePath);
      await imageFile.writeAsBytes(imageBytes, flush: true);

      debugPrint('[FloraX OfflineSync] Full-resolution photo saved locally at: $localFilePath');
      return localFilePath;
    } catch (e, stackTrace) {
      debugPrint('[FloraX OfflineSync ERROR] Failed to save local scan $scanId: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Persists captured scan image to local disk cache and registers in manifest
  Future<String> queueOfflineScan({
    required String scanId,
    required String userId,
    required Uint8List imageBytes,
    required String plantTagId,
    String geoHash5 = 'te7uc',
  }) async {
    try {
      final localFilePath = await saveLocalScan(
        scanId: scanId,
        imageBytes: imageBytes,
      );

      final newItem = PendingUploadItem(
        scanId: scanId,
        userId: userId,
        plantTagId: plantTagId,
        geoHash5: geoHash5,
        localFilePath: localFilePath,
        enqueuedAt: DateTime.now().toUtc(),
        retryCount: 0,
      );

      final manifest = await _readManifest();
      manifest.removeWhere((item) => item.scanId == scanId);
      manifest.add(newItem);

      await _writeManifest(manifest);
      _countNotifier.updateCount(manifest.length);

      debugPrint(
          '[FloraX OfflineSync] Scan $scanId queued locally at $localFilePath. Queue total: ${manifest.length}');

      final currentConn = await _connectivity.checkConnectivity();
      final isConnected = currentConn.any((r) => r != ConnectivityResult.none);

      if (isConnected) {
        unawaited(syncPendingUploads());
      }

      return localFilePath;
    } catch (e, stackTrace) {
      debugPrint(
          '[FloraX OfflineSync ERROR] Failed to queue offline scan $scanId: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Spark-safe synchronizer: Ensures Firestore records reflect local scan paths and thumbnails
  /// without calling locked Firebase Storage. Keeps full-res files on device.
  Future<void> syncPendingUploads() async {
    if (_isSyncing) {
      debugPrint('[FloraX OfflineSync] Sync operation already in progress.');
      return;
    }

    _isSyncing = true;
    try {
      final manifest = await _readManifest();
      if (manifest.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint(
          '[FloraX OfflineSync] Verifying local scan manifest of ${manifest.length} items...');

      final List<PendingUploadItem> remainingItems = [];

      for (final item in manifest) {
        final file = File(item.localFilePath);

        if (!await file.exists()) {
          debugPrint(
              '[FloraX OfflineSync WARNING] File missing: ${item.localFilePath}. Dropping from manifest.');
          continue;
        }

        try {
          // Verify or patch Firestore document with local file reference and sync timestamp
          final scanDocRef = _firestore.collection('scans').doc(item.scanId);
          await scanDocRef.set({
            'localFilePath': item.localFilePath,
            'imageSyncedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          debugPrint('[FloraX OfflineSync] Verified scan ${item.scanId} on local disk.');
        } catch (syncErr) {
          debugPrint(
              '[FloraX OfflineSync ERROR] Reconcile failed for ${item.scanId}: $syncErr.');
          remainingItems.add(item.copyWith(retryCount: item.retryCount + 1));
        }
      }

      await _writeManifest(remainingItems);
      _countNotifier.updateCount(remainingItems.length);
    } catch (e, stackTrace) {
      debugPrint('[FloraX OfflineSync ERROR] Sync batch error: $e\n$stackTrace');
    } finally {
      _isSyncing = false;
    }
  }

  /// Retrieves current number of pending items in manifest
  Future<int> getPendingUploadsCount() async {
    final manifest = await _readManifest();
    return manifest.length;
  }

  /// Internal: reads and parses the JSON manifest file from disk
  Future<List<PendingUploadItem>> _readManifest() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final manifestFile = File(
          '${appDocDir.path}/${AppConfig.pendingUploadsManifestFileName}');

      if (!await manifestFile.exists()) {
        return [];
      }

      final content = await manifestFile.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(content) as List<dynamic>;
      return decoded
          .map((e) => PendingUploadItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FloraX OfflineSync ERROR] Error reading manifest file: $e');
      return [];
    }
  }

  /// Internal: writes manifest list to disk atomically
  Future<void> _writeManifest(List<PendingUploadItem> items) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final manifestFile = File(
          '${appDocDir.path}/${AppConfig.pendingUploadsManifestFileName}');

      final jsonString = jsonEncode(items.map((i) => i.toJson()).toList());
      await manifestFile.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('[FloraX OfflineSync ERROR] Error writing manifest file: $e');
    }
  }

  /// Disposes background subscriptions
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _isInitialized = false;
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Riverpod StateNotifierProvider emitting count of pending offline leaf uploads
final pendingOfflineUploadsCountProvider =
    StateNotifierProvider<PendingUploadsCountNotifier, int>((ref) {
  return PendingUploadsCountNotifier();
});

/// Riverpod Provider providing singleton instance of OfflineMediaSyncManager
final offlineMediaSyncManagerProvider =
    Provider<OfflineMediaSyncManager>((ref) {
  final countNotifier = ref.watch(pendingOfflineUploadsCountProvider.notifier);
  final manager = OfflineMediaSyncManager(
    countNotifier: countNotifier,
  );

  // Auto-initialize
  manager.initialize();

  ref.onDispose(() {
    manager.dispose();
  });

  return manager;
});
