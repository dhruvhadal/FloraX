import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/florax_models.dart';

/// Unified offline-first Scan History Repository.
/// Synchronizes crop pathology scan telemetry to Cloud Firestore `scan_logs/{flxScanId}`
/// with persistent local SharedPreferences fallback.
class ScanHistoryRepository {
  final FirebaseFirestore _firestore;
  static const String _collectionPath = 'scan_logs';
  static const String _localScanLogsKey = 'florax_local_scan_logs_list';

  ScanHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Saves a newly recorded crop scan entry
  Future<void> saveScanLog(ScanLogEntry entry) async {
    // 1. Save locally in SharedPreferences immediately
    await _saveToLocalCache(entry);

    // 2. Persist to Cloud Firestore `scan_logs/{flxScanId}`
    try {
      final docRef = _firestore.collection(_collectionPath).doc(entry.flxScanId);
      await docRef.set(entry.toMap(), SetOptions(merge: true));
      debugPrint('[ScanHistoryRepository] Saved scan to Firestore: ${entry.flxScanId}');
    } catch (e) {
      debugPrint('[ScanHistoryRepository WARNING] Cloud persistence failed (offline mode): $e');
    }
  }

  /// Internal helper to save entry into local SharedPreferences list
  Future<void> _saveToLocalCache(ScanLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_localScanLogsKey) ?? [];

      final jsonEntry = jsonEncode({
        'flxScanId': entry.flxScanId,
        'farmerMobile': entry.farmerMobile,
        'canonicalId': entry.canonicalId,
        'crop': entry.crop,
        'confidence': entry.confidence,
        'normalizedEntropy': entry.normalizedEntropy,
        'latitude': entry.latitude,
        'longitude': entry.longitude,
        'geoHash': entry.geoHash,
        'safetyState': entry.safetyState.toFirestoreValue(),
        'verificationStatus': entry.verificationStatus.toFirestoreValue(),
        'lesionAreaPercentage': entry.lesionAreaPercentage,
        'severityGrade': entry.severityGrade.toFirestoreValue(),
        'imageUrl': entry.imageUrl,
        'thumbnailBase64': entry.thumbnailBase64,
        'timestamp': entry.timestamp.toIso8601String(),
      });

      // Avoid duplicate IDs
      final updatedList = [
        jsonEntry,
        ...rawList.where((raw) {
          try {
            final map = jsonDecode(raw);
            return map['flxScanId'] != entry.flxScanId;
          } catch (_) {
            return true;
          }
        }),
      ];

      // Keep up to 100 scans cached locally
      if (updatedList.length > 100) {
        updatedList.removeRange(100, updatedList.length);
      }

      await prefs.setStringList(_localScanLogsKey, updatedList);
    } catch (e) {
      debugPrint('[ScanHistoryRepository ERROR] Local cache write error: $e');
    }
  }

  /// Retrieves local scan entries from SharedPreferences
  Future<List<ScanLogEntry>> getLocalScanLogs({String? farmerMobile, int limit = 20}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_localScanLogsKey) ?? [];
      final List<ScanLogEntry> entries = [];

      for (final raw in rawList) {
        try {
          final Map<String, dynamic> map = jsonDecode(raw);
          if (farmerMobile != null &&
              farmerMobile.isNotEmpty &&
              map['farmerMobile'] != farmerMobile) {
            continue;
          }
          entries.add(ScanLogEntry.fromMap(map));
          if (entries.length >= limit) break;
        } catch (_) {}
      }
      return entries;
    } catch (e) {
      debugPrint('[ScanHistoryRepository] getLocalScanLogs error: $e');
      return [];
    }
  }

  /// Watches recent scans in real-time from Firestore with local fallback
  Stream<List<ScanLogEntry>> watchRecentScans({
    String? farmerMobile,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collectionPath)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (farmerMobile != null && farmerMobile.isNotEmpty) {
      query = query.where('farmerMobile', isEqualTo: farmerMobile);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ScanLogEntry.fromMap(doc.data(), doc.id);
      }).toList();
    }).handleError((err) async* {
      debugPrint('[ScanHistoryRepository] Firestore watch error ($err), streaming local cache.');
      final local = await getLocalScanLogs(farmerMobile: farmerMobile, limit: limit);
      yield local;
    });
  }

  /// Fetches a specific scan record by its unique ID
  Future<ScanLogEntry?> getScanById(String flxScanId) async {
    // 1. Try local cache
    final localList = await getLocalScanLogs(limit: 100);
    for (final s in localList) {
      if (s.flxScanId == flxScanId) return s;
    }

    // 2. Try Firestore
    try {
      final doc = await _firestore.collection(_collectionPath).doc(flxScanId).get();
      if (doc.exists && doc.data() != null) {
        return ScanLogEntry.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('[ScanHistoryRepository] getScanById cloud lookup error: $e');
    }

    return null;
  }

  /// Fetches historical scans filtered by crop name
  Future<List<ScanLogEntry>> getScansByCrop(String crop, {int limit = 10}) async {
    try {
      final snap = await _firestore
          .collection(_collectionPath)
          .where('crop', isEqualTo: crop)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => ScanLogEntry.fromMap(d.data(), d.id)).toList();
      }
    } catch (e) {
      debugPrint('[ScanHistoryRepository] getScansByCrop cloud query error: $e');
    }

    // Fallback to local
    final local = await getLocalScanLogs(limit: 50);
    return local
        .where((s) => s.crop.toLowerCase() == crop.toLowerCase())
        .take(limit)
        .toList();
  }
}

/// Global Riverpod Provider for ScanHistoryRepository
final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>((ref) {
  return ScanHistoryRepository();
});
