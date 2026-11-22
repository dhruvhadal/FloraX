import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../domain/models/florax_models.dart';
import '../services/sync/offline_media_sync_manager.dart';

/// Epidemiological recovery progression trend between sequential crop scans
enum ProgressionTrend {
  recovering,
  stable,
  spreading,
  insufficientData;

  String get label {
    switch (this) {
      case ProgressionTrend.recovering:
        return 'RECOVERING';
      case ProgressionTrend.stable:
        return 'STABLE';
      case ProgressionTrend.spreading:
        return 'SPREADING';
      case ProgressionTrend.insufficientData:
        return 'BASELINE_ESTABLISHED';
    }
  }
}

/// Comprehensive plant recovery progression analytics payload
@immutable
class PlantProgressionReport {
  final String plantTagId;
  final List<LeafScanRecord> scans;
  final ProgressionTrend trend;
  final double deltaPercent;
  final double latestLesionPercent;
  final DateTime? firstScanDate;
  final DateTime? latestScanDate;

  const PlantProgressionReport({
    required this.plantTagId,
    required this.scans,
    required this.trend,
    required this.deltaPercent,
    required this.latestLesionPercent,
    this.firstScanDate,
    this.latestScanDate,
  });
}

/// Principal Repository for Live Cloud Firestore IPM Knowledge & Scan Synchronization
/// Spark-Safe: Uses local disk cache for full-res images + compact Firestore Base64 thumbnails.
class FirestoreIpmAndScanRepository {
  final FirebaseFirestore? _firestoreInstance;
  final OfflineMediaSyncManager? _offlineMediaSyncManager;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  FirestoreIpmAndScanRepository({
    FirebaseFirestore? firestore,
    OfflineMediaSyncManager? offlineMediaSyncManager,
  })  : _firestoreInstance = firestore,
        _offlineMediaSyncManager = offlineMediaSyncManager;

  static Map<String, IcarIpmProtocol>? _offlineProtocolsCache;

  /// Loads bundled offline ICAR protocols from JSON asset
  static Future<Map<String, IcarIpmProtocol>> getOrLoadOfflineProtocols() async {
    if (_offlineProtocolsCache != null) return _offlineProtocolsCache!;
    try {
      final jsonStr = await rootBundle.loadString(AppConfig.offlineIcarProtocolsAssetPath);
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final map = <String, IcarIpmProtocol>{};
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String?;
          if (id != null && id.isNotEmpty) {
            map[id] = IcarIpmProtocol.fromMap(item, id);
          }
        }
      }
      _offlineProtocolsCache = map;
      debugPrint('[FloraX Repo] Bundled offline protocols loaded: ${map.length} protocols available.');
      return map;
    } catch (e) {
      debugPrint('[FloraX Repo] Failed to load offline bundled protocols: $e');
      return {};
    }
  }

  /// Sets offline cache directly (useful for unit testing)
  @visibleForTesting
  static void setOfflineProtocolsCache(Map<String, IcarIpmProtocol> cache) {
    _offlineProtocolsCache = cache;
  }

  // ===========================================================================
  // 1. ICAR / KVK IPM KNOWLEDGE PROTOCOL RETRIEVAL
  // ===========================================================================

  /// Fetches the verified ICAR/CIB&RC treatment document for a pathology label.
  /// Follows a resilient 3-tier offline-first chain:
  /// 1. Firestore live / SQLite persistence cache (fast 1.8s timeout)
  /// 2. Bundled assets/data/offline_icar_protocols.json (cold-start Airplane Mode)
  /// 3. Safe Generic IPM fallback (never returns null or crashes)
  Future<IcarIpmProtocol?> fetchVerifiedIpmProtocol(String labelId) async {
    try {
      debugPrint('[FloraX Repo] Fetching IPM protocol for disease ID: $labelId');

      final docRef = _firestore.collection('icar_ipm_protocols').doc(labelId);

      // Tier 1: Attempt Firestore server/cache with 1.8s timeout
      try {
        final snapshot = await docRef
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(milliseconds: 1800));
        if (snapshot.exists && snapshot.data() != null) {
          return IcarIpmProtocol.fromFirestore(snapshot, null);
        }
      } catch (networkErr) {
        debugPrint('[FloraX Repo] Live Firestore timeout/unreachable ($networkErr). Checking SQLite cache...');
        try {
          final cachedSnap = await docRef.get(const GetOptions(source: Source.cache));
          if (cachedSnap.exists && cachedSnap.data() != null) {
            return IcarIpmProtocol.fromFirestore(cachedSnap, null);
          }
        } catch (_) {}
      }

      // Tier 2: Bundled offline ICAR protocols asset (instant offline cold-start)
      final offlineMap = await getOrLoadOfflineProtocols();
      if (offlineMap.containsKey(labelId)) {
        debugPrint('[FloraX Repo] Resolved protocol $labelId from bundled offline asset.');
        return offlineMap[labelId];
      }

      // Tier 3: Safe Generic IPM Fallback
      debugPrint('[FloraX Repo] Protocol $labelId not in Firestore or offline asset. Returning safe generic fallback.');
      return buildGenericSafeIpmProtocol(labelId);
    } catch (e, stackTrace) {
      debugPrint('[FloraX Repo ERROR] Failed to fetch IPM protocol ($labelId): $e\n$stackTrace');
      final offlineMap = await getOrLoadOfflineProtocols();
      if (offlineMap.containsKey(labelId)) {
        return offlineMap[labelId];
      }
      return buildGenericSafeIpmProtocol(labelId);
    }
  }

  /// Generates a clean, non-null Generic Safe IPM Advisory for secondary crops
  /// with Tier 1 Cultural hygiene + KVK Second Opinion CTA, and Tier 3 Chemicals strictly locked.
  static IcarIpmProtocol buildGenericSafeIpmProtocol(String labelId) {
    final String readableName = labelId
        .split('_')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    final bool isHealthy = labelId.toLowerCase().contains('healthy');
    final bool isAbiotic = labelId.toLowerCase().startsWith('abiotic_') ||
        labelId.toLowerCase().contains('deficiency');

    final DiseaseCategory category = isHealthy
        ? DiseaseCategory.healthy
        : (isAbiotic
            ? DiseaseCategory.nutrient
            : (labelId.toLowerCase().contains('bacterial')
                ? DiseaseCategory.bacterial
                : (labelId.toLowerCase().contains('virus')
                    ? DiseaseCategory.viral
                    : DiseaseCategory.fungal)));

    return IcarIpmProtocol(
      id: labelId,
      diseaseName: {
        'en': 'Standard Crop Advisory ($readableName)',
        'hi': 'मानक फसल स्वास्थ्य सलाह ($readableName)',
        'mr': 'प्रमाणित पीक सल्ला ($readableName)',
      },
      scientificName: isHealthy
          ? 'Healthy Foliage Specimen'
          : (isAbiotic
              ? 'Abiotic Physiological Imbalance'
              : 'Secondary / Unlisted Foliar Pathology ($readableName)'),
      category: category,
      affectedCrops: [readableName.split(' ').first],
      isAbioticNutrientDeficiency: isAbiotic,
      causalAgent: {
        'en': isHealthy
            ? 'Optimal vegetative equilibrium; zero active pathogen.'
            : 'Foliar symptom unlisted in primary core vault. Second opinion advised.',
        'hi': isHealthy
            ? 'पौधा पूर्णतः स्वस्थ है।'
            : 'द्वितीयक लक्षण दर्ज। विशेषज्ञ द्वितीय राय आवश्यक।',
        'mr': isHealthy
            ? 'झाड पूर्णतः निरोगी व तणावमुक्त आहे.'
            : 'दुय्यम लक्षणे आढळली. तज्ज्ञांचे द्वितीय मत आवश्यक.',
      },
      favourableConditions: {
        'en': 'Monitor ambient microclimate, humidity fluctuations, and soil moisture.',
        'hi': 'हवामान, आर्द्रता और मिट्टी की नमी की निगरानी करें।',
        'mr': 'हवामान, हवेतील आर्द्रता आणि जमिनीतील ओलावा यावर लक्ष ठेवा.',
      },
      distinguishingSymptoms: {
        'en': [
          'Foliar discoloration or surface lesions detected on secondary/unlisted crop.',
          'Cultural hygiene and preventive monitoring recommended pending expert second opinion.',
        ],
        'hi': [
          'पत्तियों पर असमान रंग अथवा धब्बे।',
          'विशेषज्ञ राय मिलने तक खेत स्वच्छता और निगरानी बनाए रखें।',
        ],
        'mr': [
          'पानांवर चट्टे किंवा पिवळेपणाची लक्षणे.',
          'तज्ज्ञांचे मत मिळेपर्यंत शेतात स्वच्छता राखा आणि निरीक्षण करा.',
        ],
      },
      clarifyingFollowUpQuestions: {
        'en': [
          'Are symptoms spreading to adjacent rows?',
          'Have similar foliar symptoms been observed in previous seasons?',
        ],
        'hi': [
          'क्या यह लक्षण पास के पौधों में भी फैल रहे हैं?',
        ],
        'mr': [
          'ही लक्षणे शेजारील ओळींमधील झाडांवर पसरत आहेत का?',
        ],
      },
      verifiedSources: const [
        VerifiedSource(
          name: 'FloraX General Agronomy & IPM Safety Protocol',
          url: 'https://icar.org.in',
          referenceCode: 'FLX-GENERIC-SAFE-IPM',
        ),
      ],
      tier1Cultural: {
        'en': [
          'Field Sanitation & Cultural Hygiene: Prune and safely remove blighted or chlorotic leaves; dispose of debris away from the field.',
          'Canopy Aeration: Avoid dense planting and provide adequate airflow to lower canopy humidity.',
          'Irrigation Management: Avoid overhead sprinkler irrigation to keep leaf surfaces dry.',
          'KVK Second Opinion: Schedule an in-person or digital second opinion with your local Krishi Vigyan Kendra agronomist.',
        ],
        'hi': [
          'खेत स्वच्छता: रोगग्रस्त या पीली पत्तियों को तोड़कर खेत से दूर नष्ट करें।',
          'वायु संचार: पौधों के बीच उचित दूरी रखें ताकि पत्तियों में हवा लग सके।',
          'सिंचाई प्रबंधन: फव्वारा सिंचाई से बचें ताकि पत्तियों पर पानी न ठहरे।',
          'केवीके द्वितीय राय: सटीक पहचान के लिए स्थानीय कृषि विज्ञान केंद्र से संपर्क करें।',
        ],
        'mr': [
          'शेत स्वच्छता: रोगट किंवा पिवळी पडलेली पाने काढून शेताबाहेर नष्ट करा.',
          'हवा खेळती ठेवणे: पिकात योग्य अंतर ठेवून हवा खेळती राहील याची काळजी घ्या.',
          'पाणी व्यवस्थापन: तुषार सिंचन टाळा जेणेकरून पानांवर पाणी साचणार नाही.',
          'केव्हीके द्वितीय मत: अचूक मार्गदर्शनासाठी कृषी विज्ञान केंद्रातील तज्ज्ञांचा सल्ला घ्या.',
        ],
      },
      tier2Biological: {
        'en': [
          'Preventive Bio-agent: Foliar spray of Trichoderma viride or Pseudomonas fluorescens @ 5g/L water.',
          'Organic Botanical Spray: Cold-pressed Neem oil (Azadirachtin 1500 ppm @ 3-5 ml/L) as a broad-spectrum deterrent.',
          'Immunity Boost: Foliar spray of Cow Urine distillate (10% v/v) or Panchagavya (3% v/v).',
        ],
        'hi': [
          'जैविक नियंत्रण: ट्राइकोडर्मा या स्यूडोमोनास (5 ग्राम/लीटर पानी) का सुरक्षात्मक छिड़काव करें।',
          'नीम अर्क: 1500 पीपीएम नीम का तेल (3-5 मिली/लीटर) छिड़कें।',
          'रोगप्रतिकारक घोल: 10% गोमूत्र अर्क या 3% पंचगव्य का छिड़काव करें।',
        ],
        'mr': [
          'जैविक प्रतिबंध: ट्रायकोडर्मा किंवा स्यूडोमोनास ५ ग्रॅम प्रति लिटर पाण्यात मिसळून प्रतिबंधात्मक फवारणी करा.',
          'निंबोळी अर्क: निंबोळी तेल १५०० पीपीएम (३ ते ५ मिली/लिटर) फवारा.',
          'प्रतिकारक्षमता वाढवणे: १०% गोमूत्र किंवा ३% पंचगव्य द्रावण फवारा.',
        ],
      },
      tier3Chemical: const ChemicalControlProtocol(
        formulationName: 'CHEMICALS_LOCKED_MANDATORY_KVK_REVIEW',
        dosagePerLitre: '0 ml/L (Awaiting Expert Agronomist Confirmation)',
        waitingPeriodDays: 0,
        etlCriteria: {
          'en': 'Chemical pesticides strictly locked. Mandatory Krishi Vigyan Kendra (KVK) review required before chemical application.',
          'hi': 'रासायनिक कीटनाशक पूर्णतः लॉक हैं। रासायनिक छिड़काव से पहले केवीके वैज्ञानिक समीक्षा अनिवार्य है।',
          'mr': 'रासायनिक कीटकनाशके कुलुपबंद आहेत. रासायनिक फवारणीपूर्वी कृषी विज्ञान केंद्र शास्त्रज्ञांचे मार्गदर्शन अनिवार्य आहे.',
        },
        ppeWarnings: {
          'en': [
            'Do NOT apply synthetic chemical fungicides or pesticides without verified prescription from a certified agronomist.',
            'Always adhere to label safety instructions and wear full PPE when chemicals are officially approved.',
          ],
          'hi': [
            'प्रमाणित कृषि विशेषज्ञ की पर्ची के बिना किसी भी रासायनिक कीटनाशक का प्रयोग न करें।',
          ],
          'mr': [
            'प्रमाणित कृषी तज्ज्ञांच्या सल्ल्याशिवाय कोणतेही रासायनिक कीटकनाशक वापरू नका.',
          ],
        },
      ),
    );
  }

  // ===========================================================================
  // 2. SCAN METADATA & TELEMETRY SYNCHRONIZATION
  // ===========================================================================

  /// Persists the diagnostic scan record immediately to Firestore (with compact Base64 thumbnail),
  /// keeps full-resolution leaf photos on local disk, logs KVK escalation tickets,
  /// and increments anonymous disease counters in regional outbreak clusters.
  Future<LeafScanRecord> saveAndSyncScan({
    required LeafScanRecord scanRecord,
    required Uint8List sanitizedImageBytes,
  }) async {
    final String scanId = scanRecord.scanId;
    final String userId = scanRecord.userId;
    debugPrint('[FloraX Repo] Initiating synchronization for scan: $scanId (User: $userId)');

    // 1. Save full-resolution leaf photo locally on device (${appDocDir.path}/scans/${scanId}.jpg)
    String localPath = scanRecord.imageUrl;
    if (_offlineMediaSyncManager != null) {
      try {
        localPath = await _offlineMediaSyncManager!.saveLocalScan(
          scanId: scanId,
          imageBytes: sanitizedImageBytes,
        );
      } catch (e) {
        debugPrint('[FloraX Repo WARNING] Local disk save error: $e');
      }
    }

    final updatedRecord = scanRecord.copyWith(
      imageUrl: localPath.isNotEmpty ? localPath : scanRecord.imageUrl,
    );

    // 2. Stage metadata and compact thumbnail to Cloud Firestore
    final scanDocRef = _firestore.collection('scans').doc(scanId);
    await scanDocRef.set(updatedRecord.toFirestore(), SetOptions(merge: true));
    debugPrint('[FloraX Repo] Scan metadata staged to Firestore collection "scans/$scanId".');

    // 3. Clinical Workflow Branches based on Safety Guardrail
    final topPrediction = scanRecord.topPredictions.isNotEmpty
        ? scanRecord.topPredictions.first
        : null;
    final String labelId = topPrediction?.labelId ?? 'unknown_pathology';

    if (scanRecord.requiresKvkReview) {
      // --- ESCALATION BRANCH (< 75% Confidence) ---
      // Post high-priority escalation ticket for Krishi Vigyan Kendra agronomists
      debugPrint('[FloraX Repo] Escalating low-confidence scan to "kvk_escalations/$scanId"...');
      final escalationDocRef = _firestore.collection('kvk_escalations').doc(scanId);

      await escalationDocRef.set({
        'scanId': scanId,
        'userId': userId,
        'plantTagId': scanRecord.plantTagId,
        'topCandidate': topPrediction?.toMap(),
        'topConfidence': topPrediction?.confidence ?? 0.0,
        'lesionAreaPercent': scanRecord.lesionAreaPercent,
        'geoHash5': scanRecord.geoHash5,
        'imageUrl': updatedRecord.imageUrl,
        'thumbnailBase64': scanRecord.thumbnailBase64,
        'status': 'PENDING_REVIEW',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'priority': topPrediction != null && topPrediction.confidence < 0.50 ? 'URGENT' : 'STANDARD',
      }, SetOptions(merge: true));
    } else {
      // --- OUTBREAK CLUSTER BRANCH (>= 75% Confidence) ---
      // Anonymously increment disease frequency counter in regional taluka cluster
      final String clusterDocId = '${scanRecord.geoHash5}_$labelId';
      debugPrint('[FloraX Repo] Incrementing outbreak cluster counter: $clusterDocId');

      final clusterDocRef = _firestore.collection('outbreak_clusters').doc(clusterDocId);
      try {
        await clusterDocRef.set({
          'clusterId': clusterDocId,
          'geoHash5': scanRecord.geoHash5,
          'primaryDisease': labelId,
          'diseaseCategory': topPrediction?.category.toFirestoreValue() ?? 'FUNGAL',
          'confirmedCases': FieldValue.increment(1),
          'activeFarmerAlerts': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (clusterErr) {
        // Strict Firestore rules restrict writes to outbreak_clusters to authorized KVK/NGO/Admin roles
        debugPrint('[FloraX Repo] Outbreak cluster update deferred or restricted: $clusterErr');
      }
    }

    return updatedRecord;
  }

  // ===========================================================================
  // 3. REAL-TIME PLANT PROGRESSION TRACKING
  // ===========================================================================

  /// Streams all historical scans for a specific tagged crop specimen,
  /// computing whether the lesion progression is RECOVERING, STABLE, or SPREADING.
  Stream<PlantProgressionReport> watchPlantProgression(String userId, String plantTagId) {
    debugPrint('[FloraX Repo] Subscribing to progression stream for plant: $plantTagId (User: $userId)');

    return _firestore
        .collection('scans')
        .where('userId', isEqualTo: userId)
        .where('plantTagId', isEqualTo: plantTagId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((querySnapshot) {
      final List<LeafScanRecord> scans = querySnapshot.docs
          .map((doc) => LeafScanRecord.fromFirestore(doc, null))
          .toList();

      if (scans.isEmpty) {
        return PlantProgressionReport(
          plantTagId: plantTagId,
          scans: const [],
          trend: ProgressionTrend.insufficientData,
          deltaPercent: 0.0,
          latestLesionPercent: 0.0,
        );
      }

      if (scans.length == 1) {
        final single = scans.first;
        return PlantProgressionReport(
          plantTagId: plantTagId,
          scans: scans,
          trend: ProgressionTrend.insufficientData,
          deltaPercent: 0.0,
          latestLesionPercent: single.lesionAreaPercent,
          firstScanDate: single.timestamp,
          latestScanDate: single.timestamp,
        );
      }

      // Multi-temporal differential analysis
      final LeafScanRecord latestScan = scans.last;
      final LeafScanRecord previousScan = scans[scans.length - 2];

      final double delta = double.parse(
        (latestScan.lesionAreaPercent - previousScan.lesionAreaPercent).toStringAsFixed(1),
      );

      // Epidemiological threshold: > 2.0% change flags recovery or spreading
      ProgressionTrend trend;
      if (delta < -2.0) {
        trend = ProgressionTrend.recovering;
      } else if (delta > 2.0) {
        trend = ProgressionTrend.spreading;
      } else {
        trend = ProgressionTrend.stable;
      }

      return PlantProgressionReport(
        plantTagId: plantTagId,
        scans: scans,
        trend: trend,
        deltaPercent: delta,
        latestLesionPercent: latestScan.lesionAreaPercent,
        firstScanDate: scans.first.timestamp,
        latestScanDate: latestScan.timestamp,
      );
    });
  }

  // ===========================================================================
  // 4. REAL-TIME KVK EXPERT VERIFICATION LISTENER
  // ===========================================================================

  /// Real-time listener that fires immediately when a KVK scientist confirms
  /// a diagnosis or unlocks chemical advisories on the live Firestore backend.
  Stream<LeafScanRecord?> watchScanVerification(String scanId) {
    return _firestore.collection('scans').doc(scanId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return LeafScanRecord.fromFirestore(doc, null);
    });
  }

  // ===========================================================================
  // 5. REAL-TIME USER PLANT PLOTS & CROPS (Feature #9)
  // ===========================================================================

  /// Streams distinct plant plots/tags registered for the specified user from live scans
  Stream<List<PlantPlotInfo>> watchUserPlantPlots(String userId) {
    return _firestore
        .collection('scans')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final Map<String, PlantPlotInfo> plots = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tag = (data['plantTagId'] as String?)?.trim();
        if (tag != null && tag.isNotEmpty && !plots.containsKey(tag)) {
          final cropType = (data['cropType'] as String?) ?? 'Crop';
          plots[tag] = PlantPlotInfo(
            id: tag,
            name: tag,
            cropType: cropType,
            vernacular: _resolveVernacularCropName(cropType, tag),
          );
        }
      }
      return plots.values.toList();
    });
  }

  static String _resolveVernacularCropName(String cropType, String tag) {
    final combined = '$cropType $tag'.toLowerCase();
    if (combined.contains('tom')) return 'टोमॅटो';
    if (combined.contains('pad') || combined.contains('rice') || combined.contains('भात')) return 'भात पीक';
    if (combined.contains('cot') || combined.contains('कापूस')) return 'कापूस';
    if (combined.contains('soy')) return 'सोयाबीन';
    if (combined.contains('chilli') || combined.contains('pepper') || combined.contains('मिरची')) return 'मिरची';
    return 'पीक प्लॉट';
  }
}

/// Metadata model representing a distinct agricultural plot or crop tag
@immutable
class PlantPlotInfo {
  final String id;
  final String name;
  final String cropType;
  final String vernacular;

  const PlantPlotInfo({
    required this.id,
    required this.name,
    required this.cropType,
    required this.vernacular,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlantPlotInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// =============================================================================
// RIVERPOD DEPENDENCY INJECTION PROVIDERS
// =============================================================================

/// Global Riverpod Provider for the Firestore IPM and Scan Repository
final firestoreIpmAndScanRepositoryProvider =
    Provider<FirestoreIpmAndScanRepository>((ref) {
  final offlineSyncManager = ref.watch(offlineMediaSyncManagerProvider);
  return FirestoreIpmAndScanRepository(
    offlineMediaSyncManager: offlineSyncManager,
  );
});

/// Parameter class for plant progression streams
@immutable
class PlantProgressionParams {
  final String userId;
  final String plantTagId;

  const PlantProgressionParams({
    required this.userId,
    required this.plantTagId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlantProgressionParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          plantTagId == other.plantTagId;

  @override
  int get hashCode => userId.hashCode ^ plantTagId.hashCode;
}

/// Auto-disposing StreamProvider for real-time plant progression tracking
final plantProgressionStreamProvider = StreamProvider.autoDispose
    .family<PlantProgressionReport, PlantProgressionParams>((ref, params) {
  final repo = ref.watch(firestoreIpmAndScanRepositoryProvider);
  return repo.watchPlantProgression(params.userId, params.plantTagId);
});

/// Auto-disposing StreamProvider watching live KVK scientist sign-offs
final scanVerificationStreamProvider =
    StreamProvider.autoDispose.family<LeafScanRecord?, String>((ref, scanId) {
  final repo = ref.watch(firestoreIpmAndScanRepositoryProvider);
  return repo.watchScanVerification(scanId);
});

/// Auto-disposing StreamProvider streaming distinct plant plots for a farmer
final userPlantPlotsStreamProvider = StreamProvider.autoDispose
    .family<List<PlantPlotInfo>, String>((ref, userId) {
  final repo = ref.watch(firestoreIpmAndScanRepositoryProvider);
  return repo.watchUserPlantPlots(userId);
});
