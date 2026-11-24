import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/florax_models.dart';

/// Lightweight representation of an inference scan result fed into the Crop Diary
@immutable
class ScanResult {
  final String scanId;
  final String crop; // e.g. 'tomato', 'cotton', 'paddy'
  final String canonicalId; // e.g. 'tomato_early_blight', 'cotton_healthy'
  final double confidence;
  final double normalizedEntropy;
  final SafetyState safetyState; // confirmedBiotic, needsReview, oodRejected, abioticStress
  final SeverityGrade severityGrade;
  final double lesionAreaPercentage;
  final String imageUrl;
  final String farmerMobile;
  final DateTime timestamp;

  const ScanResult({
    required this.scanId,
    required this.crop,
    required this.canonicalId,
    required this.confidence,
    this.normalizedEntropy = 0.0,
    required this.safetyState,
    this.severityGrade = SeverityGrade.mild,
    this.lesionAreaPercentage = 0.0,
    required this.imageUrl,
    this.farmerMobile = '',
    required this.timestamp,
  });

  factory ScanResult.fromScanLogEntry(ScanLogEntry entry) {
    return ScanResult(
      scanId: entry.flxScanId,
      crop: entry.crop,
      canonicalId: entry.canonicalId,
      confidence: entry.confidence,
      normalizedEntropy: entry.normalizedEntropy,
      safetyState: entry.safetyState,
      severityGrade: entry.severityGrade,
      lesionAreaPercentage: entry.lesionAreaPercentage,
      imageUrl: entry.imageUrl ?? '',
      farmerMobile: entry.farmerMobile,
      timestamp: entry.timestamp,
    );
  }
}

/// Dynamic Crop Plot Tracked in Field Recovery Diary
@immutable
class CropPlotEntry {
  final String cropId;
  final String cropSpecies; // 'paddy', 'tomato', 'cotton', 'corn', 'potato', 'wheat', 'sugarcane', 'pepper_bell', 'banana'
  final String cropName; // e.g. 'Cotton (कापूस) - Plot A'
  final String variety; // e.g. 'Bt RCH-659 • 2.5 Acres'
  final String condition; // e.g. 'Bacterial Blight (Recovery Phase)'
  final String canonicalId;
  final double recoveryPercent; // 0.0 - 1.0
  final DateTime firstScannedAt;
  final DateTime lastScannedAt;
  final int scanCount;
  final bool isImproving;
  final String status; // 'healthy', 'improving', 'needsAttention'
  final String lastAction;
  final String imagePath;
  final double baselineLesionPercent;
  final double latestLesionPercent;
  final double baselineConfidence;
  final String farmerMobile;

  const CropPlotEntry({
    required this.cropId,
    required this.cropSpecies,
    required this.cropName,
    required this.variety,
    required this.condition,
    required this.canonicalId,
    required this.recoveryPercent,
    required this.firstScannedAt,
    required this.lastScannedAt,
    this.scanCount = 1,
    required this.isImproving,
    required this.status,
    required this.lastAction,
    required this.imagePath,
    this.baselineLesionPercent = 0.0,
    this.latestLesionPercent = 0.0,
    this.baselineConfidence = 0.0,
    this.farmerMobile = '',
  });

  int get daysElapsed {
    final diff = DateTime.now().difference(firstScannedAt).inDays;
    return diff > 0 ? diff : 1;
  }

  Map<String, dynamic> toMap() => {
    'cropId': cropId,
    'cropSpecies': cropSpecies,
    'cropName': cropName,
    'variety': variety,
    'condition': condition,
    'canonicalId': canonicalId,
    'recoveryPercent': recoveryPercent,
    'firstScannedAt': firstScannedAt.toIso8601String(),
    'lastScannedAt': lastScannedAt.toIso8601String(),
    'scanCount': scanCount,
    'isImproving': isImproving,
    'status': status,
    'lastAction': lastAction,
    'imagePath': imagePath,
    'baselineLesionPercent': baselineLesionPercent,
    'latestLesionPercent': latestLesionPercent,
    'baselineConfidence': baselineConfidence,
    'farmerMobile': farmerMobile,
  };

  factory CropPlotEntry.fromMap(Map<String, dynamic> map, [String? docId]) {
    return CropPlotEntry(
      cropId: docId ?? map['cropId']?.toString() ?? '',
      cropSpecies: map['cropSpecies']?.toString() ?? 'unknown',
      cropName: map['cropName']?.toString() ?? 'Crop Plot',
      variety: map['variety']?.toString() ?? 'Field Variety',
      condition: map['condition']?.toString() ?? 'Active Monitoring',
      canonicalId: map['canonicalId']?.toString() ?? '',
      recoveryPercent: (map['recoveryPercent'] as num?)?.toDouble() ?? 0.5,
      firstScannedAt: DateTime.tryParse(map['firstScannedAt']?.toString() ?? '') ?? DateTime.now(),
      lastScannedAt: DateTime.tryParse(map['lastScannedAt']?.toString() ?? '') ?? DateTime.now(),
      scanCount: (map['scanCount'] as num?)?.toInt() ?? 1,
      isImproving: map['isImproving'] as bool? ?? true,
      status: map['status']?.toString() ?? 'improving',
      lastAction: map['lastAction']?.toString() ?? 'Initial baseline scan recorded',
      imagePath: map['imagePath']?.toString() ?? '',
      baselineLesionPercent: (map['baselineLesionPercent'] as num?)?.toDouble() ?? 0.0,
      latestLesionPercent: (map['latestLesionPercent'] as num?)?.toDouble() ?? 0.0,
      baselineConfidence: (map['baselineConfidence'] as num?)?.toDouble() ?? 0.0,
      farmerMobile: map['farmerMobile']?.toString() ?? '',
    );
  }

  CropPlotEntry copyWith({
    String? cropId,
    String? cropSpecies,
    String? cropName,
    String? variety,
    String? condition,
    String? canonicalId,
    double? recoveryPercent,
    DateTime? firstScannedAt,
    DateTime? lastScannedAt,
    int? scanCount,
    bool? isImproving,
    String? status,
    String? lastAction,
    String? imagePath,
    double? baselineLesionPercent,
    double? latestLesionPercent,
    double? baselineConfidence,
    String? farmerMobile,
  }) {
    return CropPlotEntry(
      cropId: cropId ?? this.cropId,
      cropSpecies: cropSpecies ?? this.cropSpecies,
      cropName: cropName ?? this.cropName,
      variety: variety ?? this.variety,
      condition: condition ?? this.condition,
      canonicalId: canonicalId ?? this.canonicalId,
      recoveryPercent: recoveryPercent ?? this.recoveryPercent,
      firstScannedAt: firstScannedAt ?? this.firstScannedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      scanCount: scanCount ?? this.scanCount,
      isImproving: isImproving ?? this.isImproving,
      status: status ?? this.status,
      lastAction: lastAction ?? this.lastAction,
      imagePath: imagePath ?? this.imagePath,
      baselineLesionPercent: baselineLesionPercent ?? this.baselineLesionPercent,
      latestLesionPercent: latestLesionPercent ?? this.latestLesionPercent,
      baselineConfidence: baselineConfidence ?? this.baselineConfidence,
      farmerMobile: farmerMobile ?? this.farmerMobile,
    );
  }
}

/// 100% Dynamic Scan-Driven Crop Diary Repository
/// Starts with 0 crops on a fresh install and populates strictly from verified real leaf scans.
/// Backed by Cloud Firestore `user_crops` and local SharedPreferences JSON cache.
class CropTrackerRepository {
  final FirebaseFirestore _firestore;
  static const String _collectionPath = 'user_crops';
  static const String _prefKeyPrefix = 'farmer_dynamic_crops_';

  CropTrackerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const List<String> supportedSpecies = [
    'paddy',
    'tomato',
    'cotton',
    'corn',
    'potato',
    'wheat',
    'sugarcane',
    'pepper_bell',
    'banana',
  ];

  /// Detects canonical crop species from raw crop name or canonical pathology ID
  static String detectCropSpecies(String crop, String canonicalId) {
    final lowerCrop = crop.toLowerCase().trim();
    final lowerCanonical = canonicalId.toLowerCase().trim();

    for (final s in supportedSpecies) {
      if (lowerCrop.contains(s) || lowerCanonical.startsWith(s)) {
        return s;
      }
    }
    if (lowerCrop.contains('rice')) return 'paddy';
    if (lowerCrop.contains('maize')) return 'corn';
    if (lowerCrop.contains('chilli') || lowerCrop.contains('capsicum') || lowerCrop.contains('pepper')) {
      return 'pepper_bell';
    }
    return lowerCrop.isNotEmpty ? lowerCrop : 'field_crop';
  }

  /// Maps internal species name to bilingual display title
  static String formatCropName(String species) {
    switch (species.toLowerCase()) {
      case 'cotton':
        return 'Cotton (कापूस) - Plot A';
      case 'tomato':
        return 'Tomato (टोमॅटो) - Field Block';
      case 'sugarcane':
        return 'Sugarcane (ऊस) - Canal Side';
      case 'paddy':
        return 'Paddy / Rice (भात/धान) - Main Basin';
      case 'corn':
        return 'Corn / Maize (मका) - Terrace Plot';
      case 'potato':
        return 'Potato (बटाटा) - North Ridge';
      case 'wheat':
        return 'Wheat (गहू) - Winter Field';
      case 'pepper_bell':
        return 'Capsicum / Pepper (ढोबळी मिरची) - Polyhouse';
      case 'banana':
        return 'Banana (केळी) - Orchard Plot';
      default:
        return '${species[0].toUpperCase()}${species.substring(1)} - Field Plot';
    }
  }

  /// Formats disease condition label into clear readable agronomic string
  static String formatCondition(String canonicalId) {
    final lower = canonicalId.toLowerCase();
    if (lower.endsWith('_healthy')) {
      return 'Healthy Vigorous Canopy';
    }
    final clean = canonicalId.replaceAll('_', ' ').trim();
    return clean.split(' ').map((w) {
      if (w.isEmpty) return '';
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  String _getPrefKey(String? farmerMobile) {
    final clean = (farmerMobile != null && farmerMobile.isNotEmpty)
        ? farmerMobile.replaceAll(RegExp(r'\D'), '')
        : 'default_farmer';
    return '$_prefKeyPrefix$clean';
  }

  /// Retrieves list of dynamic crop diary entries from local cache
  Future<List<CropPlotEntry>> getCropPlots({String? farmerMobile}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getPrefKey(farmerMobile);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((e) => CropPlotEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (e) {
      debugPrint('[CropTrackerRepository] getCropPlots local cache read error: $e');
    }
    return [];
  }

  /// Real-time stream of farmer's crop plots with offline local fallback
  Stream<List<CropPlotEntry>> watchCropPlots({String? farmerMobile}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collectionPath)
        .orderBy('lastScannedAt', descending: true);

    if (farmerMobile != null && farmerMobile.isNotEmpty) {
      query = query.where('farmerMobile', isEqualTo: farmerMobile);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((d) => CropPlotEntry.fromMap(d.data(), d.id)).toList();
    }).handleError((err) async* {
      debugPrint('[CropTrackerRepository] watchCropPlots firestore error ($err), streaming local cache.');
      final local = await getCropPlots(farmerMobile: farmerMobile);
      yield local;
    });
  }

  /// Retrieves specific plot by ID
  Future<CropPlotEntry?> getCropPlotById(String cropId, {String? farmerMobile}) async {
    final localPlots = await getCropPlots(farmerMobile: farmerMobile);
    for (final p in localPlots) {
      if (p.cropId == cropId) return p;
    }
    try {
      final doc = await _firestore.collection(_collectionPath).doc(cropId).get();
      if (doc.exists && doc.data() != null) {
        return CropPlotEntry.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}
    return null;
  }

  /// Records a verified leaf scan into the Crop Diary.
  /// Strictly ignores non-leaf or OOD-rejected scans.
  Future<void> recordScanForCropDiary(ScanResult result, {String? targetCropId}) async {
    // 1. Strict OOD Gate: Ignore non-leaf / OOD scans to protect diary purity
    if (result.safetyState == SafetyState.oodRejected ||
        result.canonicalId.toLowerCase().contains('not_a_leaf') ||
        result.normalizedEntropy > 0.85) {
      debugPrint('[CropTrackerRepository] Scan ignored for crop diary (OOD/non-leaf): ${result.canonicalId}');
      return;
    }

    final species = detectCropSpecies(result.crop, result.canonicalId);
    final isHealthy = result.canonicalId.toLowerCase().endsWith('_healthy');
    final now = result.timestamp;

    final existingPlots = await getCropPlots(farmerMobile: result.farmerMobile);
    final List<CropPlotEntry> updatedList = List.from(existingPlots);

    // 2. Identify target plot
    CropPlotEntry? targetPlot;
    int targetIndex = -1;

    if (targetCropId != null && targetCropId.isNotEmpty) {
      targetIndex = updatedList.indexWhere((p) => p.cropId == targetCropId);
      if (targetIndex >= 0) targetPlot = updatedList[targetIndex];
    }

    if (targetPlot == null) {
      // Look for active plot of same species
      targetIndex = updatedList.indexWhere((p) => p.cropSpecies == species);
      if (targetIndex >= 0) targetPlot = updatedList[targetIndex];
    }

    if (targetPlot != null) {
      // 3. Update existing crop diary entry (Re-check scan)
      final baseline = targetPlot.baselineLesionPercent > 0
          ? targetPlot.baselineLesionPercent
          : (targetPlot.latestLesionPercent > 0 ? targetPlot.latestLesionPercent : 25.0);

      double newRecovery;
      bool improving;
      String status;

      if (isHealthy) {
        newRecovery = 1.0;
        improving = true;
        status = 'healthy';
      } else {
        final currentLesion = result.lesionAreaPercentage > 0
            ? result.lesionAreaPercentage
            : (result.confidence * 20.0);

        if (currentLesion <= baseline) {
          final reductionRatio = (baseline - currentLesion) / (baseline == 0 ? 1 : baseline);
          newRecovery = (0.5 + 0.5 * reductionRatio).clamp(0.0, 1.0);
          improving = true;
          status = 'improving';
        } else {
          final increaseRatio = (currentLesion - baseline) / 100.0;
          newRecovery = (0.5 - 0.5 * increaseRatio).clamp(0.0, 1.0);
          improving = false;
          status = 'needsAttention';
        }
      }

      final updatedPlot = targetPlot.copyWith(
        condition: formatCondition(result.canonicalId),
        canonicalId: result.canonicalId,
        recoveryPercent: newRecovery,
        lastScannedAt: now,
        scanCount: targetPlot.scanCount + 1,
        isImproving: improving,
        status: status,
        lastAction: isHealthy
            ? 'Canopy verified healthy & clear of foliar lesions'
            : (improving
                ? 'Follow-up foliar inspection: Symptoms subsiding'
                : 'Foliar inspection alert: Increased lesion activity detected'),
        imagePath: result.imageUrl,
        latestLesionPercent: result.lesionAreaPercentage,
      );

      updatedList[targetIndex] = updatedPlot;
      await _persistPlots(updatedList, result.farmerMobile, updatedPlot);
      debugPrint('[CropTrackerRepository] Updated crop plot diary: ${updatedPlot.cropId} (${updatedPlot.cropSpecies})');
    } else {
      // 4. Create new crop diary entry dynamically from real leaf scan
      final cropId = 'crop_${species}_${now.millisecondsSinceEpoch}';
      final initialRecovery = isHealthy
          ? 1.0
          : (1.0 - (result.lesionAreaPercentage / 100.0)).clamp(0.2, 0.85);
      final improving = isHealthy || initialRecovery >= 0.5;

      final newPlot = CropPlotEntry(
        cropId: cropId,
        cropSpecies: species,
        cropName: formatCropName(species),
        variety: 'ICAR Protocol Tracked Plot',
        condition: formatCondition(result.canonicalId),
        canonicalId: result.canonicalId,
        recoveryPercent: initialRecovery,
        firstScannedAt: now,
        lastScannedAt: now,
        scanCount: 1,
        isImproving: improving,
        status: isHealthy ? 'healthy' : (improving ? 'improving' : 'needsAttention'),
        lastAction: isHealthy
            ? 'Initial baseline: Clean canopy verified'
            : 'Initial baseline scan recorded • Diagnostic treatment initiated',
        imagePath: result.imageUrl,
        baselineLesionPercent: result.lesionAreaPercentage,
        latestLesionPercent: result.lesionAreaPercentage,
        baselineConfidence: result.confidence,
        farmerMobile: result.farmerMobile,
      );

      updatedList.insert(0, newPlot);
      await _persistPlots(updatedList, result.farmerMobile, newPlot);
      debugPrint('[CropTrackerRepository] Auto-created new crop plot entry from leaf scan: $cropId');
    }
  }

  /// Internal persistence to both SharedPreferences cache and Cloud Firestore
  Future<void> _persistPlots(
    List<CropPlotEntry> plots,
    String? farmerMobile,
    CropPlotEntry activeEntry,
  ) async {
    // 1. SharedPreferences local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getPrefKey(farmerMobile);
      final rawList = plots.map((p) => p.toMap()).toList();
      await prefs.setString(key, jsonEncode(rawList));
    } catch (e) {
      debugPrint('[CropTrackerRepository ERROR] Local cache write failed: $e');
    }

    // 2. Cloud Firestore `user_crops/{cropId}`
    try {
      final docRef = _firestore.collection(_collectionPath).doc(activeEntry.cropId);
      await docRef.set(activeEntry.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CropTrackerRepository WARNING] Firestore sync deferred (offline): $e');
    }
  }
}

/// Global Riverpod Provider for CropTrackerRepository
final cropTrackerRepositoryProvider = Provider<CropTrackerRepository>((ref) {
  return CropTrackerRepository();
});
