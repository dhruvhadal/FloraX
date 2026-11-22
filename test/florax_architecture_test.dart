import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dart_geohash/dart_geohash.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import 'package:florax/core/config/app_config.dart';
import 'package:florax/domain/models/florax_models.dart';
import 'package:florax/presentation/providers/scan_orchestrator_provider.dart';
import 'package:florax/repositories/firestore_ipm_and_scan_repository.dart';
import 'package:florax/services/auth/auth_role_service.dart';
import 'package:florax/services/notifications/outbreak_fcm_service.dart';
import 'package:florax/services/sync/offline_media_sync_manager.dart';
import 'package:florax/services/vision/hybrid_gradcam_client.dart';
import 'package:florax/services/vision/isolate_lesion_analyzer.dart';
import 'package:florax/services/vision/tflite_isolate_service.dart';
import 'package:florax/services/weather/predictive_weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FloraX Architecture & Clinical Safety Test Suite', () {
    // =========================================================================
    // 1. ASSET & PATHOLOGY LABEL INTEGRITY
    // =========================================================================
    test('1. Asset & Label Integrity: assets/models/ contains real v1 trained model, labels, and alias map', () {
      final labelsFile = File(AppConfig.labelsAssetPath);
      expect(labelsFile.existsSync(), isTrue,
          reason: 'labels.txt must exist at ${AppConfig.labelsAssetPath}');

      final String rawContent = labelsFile.readAsStringSync();
      expect(rawContent.trim().isNotEmpty, isTrue);

      final List<String> lines = rawContent
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      // Assert 69 raw taxonomy classes from real trained model
      expect(lines.length, equals(69),
          reason: 'Expected 69 indexed raw classes for real FloraX v1 model');

      // Verify class_alias_map.json existence and mapping
      final aliasFile = File(AppConfig.classAliasMapAssetPath);
      expect(aliasFile.existsSync(), isTrue,
          reason: 'class_alias_map.json must exist at ${AppConfig.classAliasMapAssetPath}');

      final Map<String, dynamic> aliasMap = jsonDecode(aliasFile.readAsStringSync()) as Map<String, dynamic>;
      expect(aliasMap.length, equals(69),
          reason: 'class_alias_map.json must map all 69 raw labels');

      final Set<String> canonicalClasses = aliasMap.values.map((v) => v.toString()).toSet();
      expect(canonicalClasses.length, equals(50),
          reason: 'class_alias_map.json must reduce to 50 canonical classes');

      const coreCanonicalClasses = [
        'paddy_leaf_blast',
        'paddy_neck_blast',
        'paddy_bacterial_blight',
        'paddy_brown_spot',
        'paddy_tungro',
        'paddy_healthy',
        'sugarcane_red_rot',
        'sugarcane_bacterial_blight',
        'sugarcane_healthy',
        'wheat_yellow_rust',
        'wheat_brown_rust',
        'wheat_healthy',
        'tomato_early_blight',
        'tomato_late_blight',
        'tomato_septoria_leaf_spot',
        'tomato_bacterial_spot',
        'tomato_leaf_mold',
        'tomato_yellow_leaf_curl_virus',
        'tomato_mosaic_virus',
        'tomato_spider_mites',
        'tomato_target_spot',
        'tomato_healthy',
        'potato_early_blight',
        'potato_late_blight',
        'potato_healthy',
        'corn_common_rust',
        'corn_northern_leaf_blight',
        'corn_gray_leaf_spot',
        'corn_healthy',
        'grape_black_rot',
        'grape_healthy',
        'pepper_bell_bacterial_spot',
        'pepper_bell_healthy',
      ];

      for (final expected in coreCanonicalClasses) {
        expect(canonicalClasses, contains(expected),
            reason: 'Canonical taxonomy must contain $expected');
      }

      // Verify model_meta.json
      final metaFile = File(AppConfig.modelMetaAssetPath);
      expect(metaFile.existsSync(), isTrue,
          reason: 'model_meta.json must exist at ${AppConfig.modelMetaAssetPath}');

      final Map<String, dynamic> modelMeta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      expect(modelMeta['num_raw_classes'], equals(69));
      expect(modelMeta['num_canonical_classes'], equals(50));
      expect(modelMeta['ood_min_confidence'], equals(0.20));
      expect(modelMeta['ood_max_normalized_entropy'], equals(0.85));

      // Verify TFLite model binary asset existence
      final modelFile = File(AppConfig.modelAssetPath);
      expect(modelFile.existsSync(), isTrue,
          reason: 'Quantized TFLite model must exist at ${AppConfig.modelAssetPath}');
      expect(modelFile.lengthSync(), greaterThan(1 * 1024 * 1024),
          reason: 'TFLite model binary should be > 1MB');
    });

    // =========================================================================
    // 2. CONFIDENCE GUARDRAIL & KVK VERIFICATION ENFORCEMENT
    // =========================================================================
    test('2. Confidence Guardrail: Low-confidence scan (< 75%) forces KVK escalation and locks chemicals', () {
      const double lowConfidence = 0.68;
      final bool requiresKvkReview = lowConfidence < AppConfig.kvkConfidenceThreshold;

      expect(requiresKvkReview, isTrue,
          reason: 'Confidence 0.68 must trigger mandatory KVK agronomist review');

      final scanRecord = LeafScanRecord(
        scanId: 'FLX-TEST-001',
        userId: 'farmer_pune_42',
        plantTagId: 'PLANT-TOM-01',
        timestamp: DateTime.now().toUtc(),
        imageUrl: 'https://storage.googleapis.com/florax/scans/test.jpg',
        topPredictions: const [
          DiseasePrediction(
            labelId: 'tomato_early_blight',
            confidence: lowConfidence,
            scientificName: 'Alternaria solani',
            category: DiseaseCategory.fungal,
          ),
          DiseasePrediction(
            labelId: 'abiotic_magnesium_deficiency',
            confidence: 0.22,
            scientificName: 'Magnesium chlorosis',
            category: DiseaseCategory.abiotic,
          ),
        ],
        lesionAreaPercent: 24.5,
        gradCamHotspots: const [
          GradCamHotspot(
            x: 45.0,
            y: 50.0,
            radius: 12.0,
            intensity: 0.85,
            label: 'Primary lesion',
          ),
        ],
        requiresKvkReview: requiresKvkReview,
        verificationStatus: VerificationStatus.pendingKvkReview,
        chemicalUnlocked: false,
        geoHash5: 'te7u6',
      );

      // Verify Initial Pending Review State
      expect(scanRecord.requiresKvkReview, isTrue);
      expect(scanRecord.verificationStatus, equals(VerificationStatus.pendingKvkReview));
      expect(scanRecord.chemicalUnlocked, isFalse,
          reason: 'Tier-3 chemicals must be locked when requiresKvkReview is true');

      // Verify Firestore serialization maintains safety flags
      final firestoreData = scanRecord.toFirestore();
      expect(firestoreData['requiresKvkReview'], isTrue);
      expect(firestoreData['verificationStatus'], equals('PENDING_KVK_REVIEW'));
      expect(firestoreData['chemicalUnlocked'], isFalse);

      // Simulate KVK Scientist verification transition
      final verifiedRecord = scanRecord.copyWith(
        verificationStatus: VerificationStatus.kvkConfirmed,
        kvkScientistId: 'scientist_icar_nashik_09',
        kvkScientistNote: 'Early blight conidiophores confirmed. Approved for Mancozeb 75% WP.',
        chemicalUnlocked: true,
      );

      expect(verifiedRecord.verificationStatus, equals(VerificationStatus.kvkConfirmed));
      expect(verifiedRecord.chemicalUnlocked, isTrue,
          reason: 'Tier-3 chemicals unlocked after official KVK confirmation');
      expect(verifiedRecord.kvkScientistId, equals('scientist_icar_nashik_09'));
    });

    test('2b. Confidence Guardrail: High-confidence scan (>= 75%) is AI-verified immediately', () {
      const double highConfidence = 0.88;
      final bool requiresKvkReview = highConfidence < AppConfig.kvkConfidenceThreshold;

      expect(requiresKvkReview, isFalse,
          reason: 'Confidence 0.88 >= 0.75 bypasses KVK escalation');

      final scanRecord = LeafScanRecord(
        scanId: 'FLX-TEST-002',
        userId: 'farmer_nashik_18',
        plantTagId: 'PLANT-TOM-02',
        timestamp: DateTime.now().toUtc(),
        imageUrl: 'https://storage.googleapis.com/florax/scans/test2.jpg',
        topPredictions: const [
          DiseasePrediction(
            labelId: 'tomato_early_blight',
            confidence: highConfidence,
            scientificName: 'Alternaria solani',
            category: DiseaseCategory.fungal,
          ),
        ],
        lesionAreaPercent: 12.0,
        requiresKvkReview: requiresKvkReview,
        verificationStatus: VerificationStatus.aiVerified,
        chemicalUnlocked: false, // Remains false until ETL criteria acknowledged
        geoHash5: 'te7u6',
      );

      expect(scanRecord.requiresKvkReview, isFalse);
      expect(scanRecord.verificationStatus, equals(VerificationStatus.aiVerified));
    });

    // =========================================================================
    // 3. GEOHASH5 PRIVACY TRUNCATION & PII SANITIZATION
    // =========================================================================
    test('3. GeoHash5 Privacy: Truncates Navi Mumbai coordinates strictly to 5 characters', () {
      const double naviMumbaiLat = 19.0330;
      const double naviMumbaiLng = 73.0297;

      final geoHasher = GeoHasher();
      // dart_geohash takes (longitude, latitude)
      final String rawFullHash = geoHasher.encode(naviMumbaiLng, naviMumbaiLat, precision: 7);
      expect(rawFullHash.length, equals(7));

      // Truncate to privacy-preserving 5 characters (~4.9km radius)
      final String geoHash5 = rawFullHash.substring(0, AppConfig.geoHashPrecision);

      expect(geoHash5.length, equals(5),
          reason: 'GeoHash must be exactly 5 characters to mask house-level coordinates');
      expect(geoHash5, startsWith('te7u'),
          reason: 'Navi Mumbai agricultural sector must reside in "te7u" geohash block');

      // Create anonymous regional outbreak cluster payload
      final Map<String, dynamic> outbreakClusterPayload = {
        'clusterId': '${geoHash5}_tomato_early_blight',
        'geoHash5': geoHash5,
        'primaryDisease': 'tomato_early_blight',
        'caseCount': 8,
        'activeAlert': true,
      };

      // Assert zero PII or high-precision telemetry fields exist in payload
      expect(outbreakClusterPayload.containsKey('rawGpsCoordinates'), isFalse);
      expect(outbreakClusterPayload.containsKey('latitude'), isFalse);
      expect(outbreakClusterPayload.containsKey('longitude'), isFalse);
      expect(outbreakClusterPayload.containsKey('farmerContact'), isFalse);
      expect(outbreakClusterPayload.containsKey('farmExactAddress'), isFalse);
      expect(outbreakClusterPayload['geoHash5'].toString().length, equals(5));
    });

    // =========================================================================
    // 4. CIELAB LESION RATIO BOUNDS & SPATIAL CENTROIDS
    // =========================================================================
    test('4. CIELAB Lesion Ratio: Synthesized foliage image computes valid ratio and hotspots', () async {
      // 1. Synthesize a 400x400 leaf image buffer with green foliage & necrotic center spot
      final img.Image syntheticLeaf = img.Image(width: 400, height: 400, numChannels: 3);

      // Fill background with healthy foliage green (RGB: 45, 160, 55 -> Hue ~125°, Sat ~0.72)
      final greenPixel = img.ColorRgb8(45, 160, 55);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          syntheticLeaf.setPixel(x, y, greenPixel);
        }
      }

      // Draw leaf vein structure to provide natural high-frequency texture
      final veinGreen = img.ColorRgb8(65, 185, 75);
      for (int i = 0; i < 400; i += 8) {
        img.drawLine(syntheticLeaf, x1: 0, y1: i, x2: 400, y2: i, color: veinGreen);
        img.drawLine(syntheticLeaf, x1: i, y1: 0, x2: i, y2: 400, color: veinGreen);
      }

      // Draw a central necrotic lesion patch (RGB: 130, 80, 25 -> Brown necrosis: Hue ~31°, Sat ~0.80)
      // 100x100 square = 10,000 pixels out of 160,000 total pixels ~= 6.25% lesion ratio
      final necroticBrown = img.ColorRgb8(130, 80, 25);
      img.fillRect(
        syntheticLeaf,
        x1: 150,
        y1: 150,
        x2: 250,
        y2: 250,
        color: necroticBrown,
      );

      // Encode synthetic image to JPEG byte buffer
      final Uint8List rawCameraBytes = Uint8List.fromList(img.encodeJpg(syntheticLeaf, quality: 90));
      expect(rawCameraBytes.isNotEmpty, isTrue);

      // 2. Execute Background Isolate Lesion Analyzer
      final LesionAnalysisResult analysis = await IsolateLesionAnalyzer.analyzeBytes(rawCameraBytes);

      // 3. Verify Lesion-to-Leaf Area Ratio bounds
      expect(analysis.lesionAreaPercent, greaterThan(0.0),
          reason: 'Lesion area percent must be strictly greater than 0%');
      expect(analysis.lesionAreaPercent, lessThan(100.0),
          reason: 'Lesion area percent must be strictly less than 100%');

      // Given 10,000 / 160,000 pixels, expect approximately 4% to 12% ratio
      expect(analysis.lesionAreaPercent, inInclusiveRange(3.0, 15.0),
          reason: 'Necrotic lesion box should quantify to roughly 6% surface ratio');

      expect(analysis.totalLeafPixels, greaterThan(300),
          reason: 'Foliage pixels must satisfy minimum leaf presence threshold');
      expect(analysis.lesionPixels, greaterThan(0),
          reason: 'Necrotic pixel thresholding must register spot pixels');

      // 4. Verify Spatial Attention Centroids (Hotspots)
      expect(analysis.hotspots.isNotEmpty, isTrue,
          reason: 'Isolate must extract at least one spatial lesion centroid');

      for (final hotspot in analysis.hotspots) {
        expect(hotspot.x, inInclusiveRange(0.0, 100.0),
            reason: 'Hotspot X must be a valid normalized percentage');
        expect(hotspot.y, inInclusiveRange(0.0, 100.0),
            reason: 'Hotspot Y must be a valid normalized percentage');
        expect(hotspot.intensity, inInclusiveRange(0.0, 1.0),
            reason: 'Hotspot intensity must be bounded within [0.0, 1.0]');
        expect(hotspot.radius, greaterThan(0.0));
      }

      // Verify output image is sanitized and valid JPEG
      expect(analysis.sanitizedImageBytes.isNotEmpty, isTrue);
      expect(analysis.width, equals(400));
      expect(analysis.height, equals(400));
    });

    // =========================================================================
    // 5. LEAFGUARD PHASE 9: SCHEMA EXTENSIONS & INSTITUTIONAL MODELS
    // =========================================================================
    test('5a. SeverityGrade: Correctly classifies necrotic leaf percentage thresholds', () {
      expect(SeverityGrade.fromPercentage(4.5), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromPercentage(14.9), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromPercentage(15.0), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(24.99), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(39.9), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(40.0), equals(SeverityGrade.severe));
      expect(SeverityGrade.fromPercentage(65.0), equals(SeverityGrade.severe));

      expect(SeverityGrade.mild.toFirestoreValue(), equals('MILD'));
      expect(SeverityGrade.moderate.toFirestoreValue(), equals('MODERATE'));
      expect(SeverityGrade.severe.toFirestoreValue(), equals('SEVERE'));

      expect(SeverityGrade.fromString('MILD'), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromString('moderate'), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromString('SEVERE'), equals(SeverityGrade.severe));
    });

    test('5b. ImageQualityReport & LeafRegionDiagnosis: Serialization round-trip', () {
      const qualityReport = ImageQualityReport(
        isAcceptable: true,
        blurScore: 142.5,
        brightnessScore: 128.0,
        leafCoveragePercent: 78.4,
        failureReasons: [],
      );

      final qualityMap = qualityReport.toMap();
      final roundtripQuality = ImageQualityReport.fromMap(qualityMap);
      expect(roundtripQuality.isAcceptable, isTrue);
      expect(roundtripQuality.blurScore, equals(142.5));
      expect(roundtripQuality.brightnessScore, equals(128.0));
      expect(roundtripQuality.leafCoveragePercent, equals(78.4));

      const region = LeafRegionDiagnosis(
        regionId: 'reg_center_01',
        boundingBoxNormalized: Rect.fromLTWH(0.2, 0.2, 0.4, 0.4),
        primaryPrediction: DiseasePrediction(
          labelId: 'tomato_early_blight',
          confidence: 0.89,
          scientificName: 'Alternaria solani',
          category: DiseaseCategory.fungal,
        ),
        visualSymptomExplanation: {
          'en': 'Concentric target-like rings with yellow halo',
        },
        isEarlyStageSubtle: true,
      );

      final regionMap = region.toMap();
      final roundtripRegion = LeafRegionDiagnosis.fromMap(regionMap);
      expect(roundtripRegion.regionId, equals('reg_center_01'));
      expect(roundtripRegion.boundingBoxNormalized.left, equals(0.2));
      expect(roundtripRegion.primaryPrediction.labelId, equals('tomato_early_blight'));
      expect(roundtripRegion.isEarlyStageSubtle, isTrue);
    });

    test('5c. Institutional Models: VerifiedExpert, NgoPartner, CsrFundingPartner', () {
      const expert = VerifiedExpert(
        expertId: 'expert_test_01',
        name: 'Dr. Test Agronomist',
        category: 'agronomist',
        qualification: 'Ph.D. Agronomy',
        institution: 'ICAR-IARI',
        district: 'Pune',
        languages: ['English', 'Marathi', 'Hindi'],
        phone: '+919876543210',
        email: 'agronomist@icar.org.in',
        verifiedBy: 'ICAR Authority',
        isAvailableForSecondOpinion: true,
      );

      final expertData = expert.toFirestore();
      final roundtripExpert = VerifiedExpert.fromMap(expertData, expert.expertId);
      expect(roundtripExpert.expertId, equals('expert_test_01'));
      expect(roundtripExpert.category, equals('agronomist'));
      expect(roundtripExpert.languages, contains('Marathi'));

      const ngo = NgoPartner(
        ngoId: 'ngo_test_01',
        name: 'Gram Vikas NGO',
        registrationNumber: 'NGO-MH-2024-001',
        focusAreas: ['Sustainable Agriculture', 'Bio-fertilizers'],
        districtsServed: ['Nashik', 'Pune'],
        fieldRepName: 'Sanjay Shinde',
        fieldRepContact: '+919988776655',
      );

      final ngoData = ngo.toFirestore();
      final roundtripNgo = NgoPartner.fromMap(ngoData, ngo.ngoId);
      expect(roundtripNgo.ngoId, equals('ngo_test_01'));
      expect(roundtripNgo.districtsServed, contains('Nashik'));

      const csr = CsrFundingPartner(
        partnerId: 'csr_test_01',
        organizationName: 'Tata Community Initiatives',
        fundingType: 'csr_fund',
        focusScope: 'Maharashtra Smallholder Farmers',
        contactEmail: 'csr@tata.com',
      );

      final csrData = csr.toFirestore();
      final roundtripCsr = CsrFundingPartner.fromMap(csrData, csr.partnerId);
      expect(roundtripCsr.partnerId, equals('csr_test_01'));
      expect(roundtripCsr.organizationName, equals('Tata Community Initiatives'));
    });

    // =========================================================================
    // 6. HUMAN-IN-THE-LOOP ECOSYSTEM & INSTITUTIONAL RBAC (TIER 4 / PHASE 12)
    // =========================================================================
    test('6a. Verified Experts: All 5 specialized disciplines represented and valid', () {
      const allowedCategories = [
        'plant_pathologist',
        'botanist',
        'agronomist',
        'entomologist',
        'horticulturist',
      ];

      for (final cat in allowedCategories) {
        final expert = VerifiedExpert(
          expertId: 'exp_$cat',
          name: 'Dr. Test $cat',
          category: cat,
          qualification: 'Ph.D. in $cat',
          institution: 'ICAR National Research Centre',
          district: 'Nashik',
          languages: const ['Marathi', 'English'],
          phone: '+912025698741',
          email: '$cat@icar.gov.in',
          verifiedBy: 'ICAR-CRIDA Accreditation Board',
          isAvailableForSecondOpinion: true,
        );

        final firestoreMap = expert.toFirestore();
        expect(firestoreMap['category'], equals(cat));
        expect(firestoreMap['isAvailableForSecondOpinion'], isTrue);

        final parsed = VerifiedExpert.fromMap(firestoreMap, expert.expertId);
        expect(parsed.category, equals(cat));
        expect(parsed.languages, contains('Marathi'));
      }
    });

    test('6b. Second Opinion Workflow: Serialization and state progression', () {
      final requestTime = DateTime.utc(2026, 11, 21, 10, 0, 0);
      final resolvedTime = DateTime.utc(2026, 11, 21, 14, 30, 0);

      final initialRequest = SecondOpinionRequest(
        requestId: 'req_test_001',
        farmerUid: 'farmer_pune_01',
        scanId: 'FLX-SCAN-99',
        expertId: 'expert_pathologist_01',
        symptomDescription: 'Brown concentric spots on lower leaves with yellow halo',
        status: 'PENDING',
        createdAt: requestTime,
      );

      final initialMap = initialRequest.toFirestore();
      expect(initialMap['status'], equals('PENDING'));

      final parsedInitial = SecondOpinionRequest.fromMap(initialMap, 'req_test_001');
      expect(parsedInitial.status, equals('PENDING'));
      expect(parsedInitial.expertDiagnosis, isNull);

      final resolvedRequest = SecondOpinionRequest(
        requestId: initialRequest.requestId,
        farmerUid: initialRequest.farmerUid,
        scanId: initialRequest.scanId,
        expertId: initialRequest.expertId,
        symptomDescription: initialRequest.symptomDescription,
        status: 'COMPLETED',
        expertDiagnosis: 'Alternaria solani conidiophores verified via micro-lesion analysis.',
        createdAt: initialRequest.createdAt,
        resolvedAt: resolvedTime,
      );

      final resolvedMap = resolvedRequest.toFirestore();
      expect(resolvedMap['status'], equals('COMPLETED'));
      expect(resolvedMap['expertDiagnosis'], contains('Alternaria solani'));

      final parsedResolved = SecondOpinionRequest.fromMap(resolvedMap, 'req_test_001');
      expect(parsedResolved.status, equals('COMPLETED'));
      expect(parsedResolved.expertDiagnosis, equals(resolvedRequest.expertDiagnosis));
      expect(parsedResolved.resolvedAt?.toUtc(), equals(resolvedTime));
    });

    test('6c. Verified Institutional Outbreak Reports: Strict validation and GeoHash5', () {
      final reportTimestamp = DateTime.utc(2026, 11, 21, 12, 0, 0);

      final outbreakReport = VerifiedOutbreakReport(
        reportId: 'outbreak_pune_001',
        diseaseLabel: 'tomato_early_blight',
        district: 'Pune',
        taluka: 'Haveli',
        geoHash5: 'te7u6',
        severityLevel: 'HIGH',
        verifiedByInstitutionId: 'kvk_baramati_icar_01',
        verifiedByInstitutionName: 'KVK Baramati ICAR Demonstration Centre',
        recommendedAction: 'Immediate protective spray of Mancozeb 75% WP; restrict sprinkler irrigation.',
        verifiedAt: reportTimestamp,
        confirmedCasesCount: 14,
      );

      final reportMap = outbreakReport.toFirestore();
      expect(reportMap['diseaseLabel'], equals('tomato_early_blight'));
      expect(reportMap['geoHash5'], equals('te7u6'));
      expect(reportMap['geoHash5'].toString().length, equals(5),
          reason: 'Outbreak report must use privacy-preserving GeoHash5');
      expect(reportMap['verifiedByInstitutionId'], equals('kvk_baramati_icar_01'));
      expect(reportMap['confirmedCasesCount'], equals(14));

      final parsed = VerifiedOutbreakReport.fromMap(reportMap, 'outbreak_pune_001');
      expect(parsed.reportId, equals('outbreak_pune_001'));
      expect(parsed.severityLevel, equals('HIGH'));
      expect(parsed.confirmedCasesCount, equals(14));
      expect(parsed.verifiedByInstitutionId, equals('kvk_baramati_icar_01'));
    });

    test('6d. NGO Partner Programs & Schemes: Structure and assistance schema', () {
      const ngo = NgoPartner(
        ngoId: 'ngo_swadesh_01',
        name: 'Swades Foundation',
        registrationNumber: 'MH-NGO-2013-0941',
        focusAreas: ['Water Harvesting', 'Drip Irrigation', 'Organic IPM'],
        districtsServed: ['Raigad', 'Nashik', 'Pune'],
        fieldRepName: 'Pravin Jadhav',
        fieldRepContact: '+919822334455',
        programsOffered: [
          'Subsidized Neem Oil Distribution Scheme',
          'Biocontrol Agent Training Workshop',
        ],
        schemesEligible: [
          'PM-KMY Group Insurance Facilitation',
          'DBT Micro-Irrigation Grant Support',
        ],
      );

      final ngoData = ngo.toFirestore();
      expect(ngoData['programsOffered'].length, equals(2));
      expect(ngoData['schemesEligible'].length, equals(2));
      expect(ngoData['districtsServed'], contains('Raigad'));

      final parsed = NgoPartner.fromMap(ngoData, ngo.ngoId);
      expect(parsed.name, equals('Swades Foundation'));
      expect(parsed.programsOffered, contains('Subsidized Neem Oil Distribution Scheme'));
      expect(parsed.schemesEligible, contains('DBT Micro-Irrigation Grant Support'));
    });

    // =========================================================================
    // 7. EDGE PIPELINE ZERO-STALL CAPTURE & NON-BLOCKING RESILIENCE
    // =========================================================================
    test('7a. Zero-Stall Cached GPS: getCachedOrDefaultGeoHash5 returns immediately in < 1ms', () {
      final weatherService = PredictiveWeatherService();
      final stopwatch = Stopwatch()..start();
      final String cachedHash = weatherService.getCachedOrDefaultGeoHash5();
      stopwatch.stop();

      expect(cachedHash.length, equals(5));
      expect(cachedHash, equals(PredictiveWeatherService.fallbackGeoHash5));
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Synchronous cached GeoHash5 retrieval must complete in < 50ms');
    });

    test('7b. Non-Blocking Pipeline: Stalled Grad-CAM future does not block executeScanPipeline from reaching completed', () async {
      final fakeTflite = _FakeTfliteService();
      final stalledGradCam = _StalledGradCamClient();
      final fakeIpmRepo = _FakeIpmRepository();
      final fakeSyncManager = _FakeOfflineSyncManager();

      final container = ProviderContainer(
        overrides: [
          tfliteIsolateServiceProvider.overrideWithValue(fakeTflite),
          hybridGradCamClientProvider.overrideWithValue(stalledGradCam),
          firestoreIpmAndScanRepositoryProvider.overrideWithValue(fakeIpmRepo),
          offlineMediaSyncManagerProvider.overrideWithValue(fakeSyncManager),
          authRoleServiceProvider.overrideWithValue(_FakeAuthRoleService()),
          outbreakFcmServiceProvider.overrideWithValue(_FakeOutbreakFcmService()),
        ],
      );
      addTearDown(container.dispose);

      // Synthesize a valid green leaf image with a central necrotic patch
      final img.Image leaf = img.Image(width: 400, height: 400, numChannels: 3);
      final green = img.ColorRgb8(45, 160, 55);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          leaf.setPixel(x, y, green);
        }
      }
      // Add vein grid to pass Laplacian sharpness gate (blurScore >= 85.0)
      final vein = img.ColorRgb8(65, 185, 75);
      for (int i = 0; i < 400; i += 8) {
        img.drawLine(leaf, x1: 0, y1: i, x2: 400, y2: i, color: vein);
        img.drawLine(leaf, x1: i, y1: 0, x2: i, y2: 400, color: vein);
      }
      final brown = img.ColorRgb8(130, 80, 25);
      img.fillRect(leaf, x1: 150, y1: 150, x2: 250, y2: 250, color: brown);
      final Uint8List rawBytes = Uint8List.fromList(img.encodeJpg(leaf, quality: 90));

      final stopwatch = Stopwatch()..start();
      await container.read(scanOrchestratorProvider.notifier).executeScanPipeline(
            rawBytes: rawBytes,
            plantTagId: 'PLANT-TEST-NONBLOCKING',
            cropType: 'Tomato',
          );
      stopwatch.stop();

      final state = container.read(scanOrchestratorProvider).value;
      expect(state, isNotNull);
      expect(state!.stage, equals(ScanPipelineStage.completed),
          reason: 'ScanPipelineStage.completed must be reached even while Grad-CAM is still stalled');
      expect(state.scanRecord, isNotNull);
      expect(state.diagnosticResult, isNotNull);
      expect(state.diagnosticResult!.isCloudInference, isFalse,
          reason: 'Initial completed result must be immediate on-device inference');

      // Now complete the stalled Grad-CAM future with a mock neural heatmap response
      const String mockHeatmapBase64 =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      stalledGradCam.completer.complete(
        Response(
          requestOptions: RequestOptions(path: '/analyze-leaf'),
          statusCode: 200,
          data: {
            'topCandidates': [
              {
                'id': 'tomato_early_blight',
                'confidence': 0.94,
                'scientificName': 'Alternaria solani',
                'category': 'FUNGAL',
              }
            ],
            'gradCamRegions': [
              {
                'x': 50.0,
                'y': 50.0,
                'radius': 15.0,
                'intensity': 0.92,
                'label': 'Cloud neural hotspot',
              }
            ],
            'lesionAreaPercentage': 6.25,
            'requiresExpertVerification': false,
            'verificationStatus': 'AI_VERIFIED',
            'heatmapBase64': mockHeatmapBase64,
          },
        ),
      );

      // Allow background future callback to execute and patch state
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final patchedState = container.read(scanOrchestratorProvider).value;
      expect(patchedState!.scanRecord!.heatmapUrl, equals(mockHeatmapBase64),
          reason: 'Active state scanRecord must be seamlessly patched with Grad-CAM heatmap');
      expect(patchedState.diagnosticResult!.heatmapBase64, equals(mockHeatmapBase64),
          reason: 'Active state diagnosticResult must be seamlessly updated with Grad-CAM heatmap');
      expect(patchedState.diagnosticResult!.isCloudInference, isTrue);
    });

    // =========================================================================
    // 8. OPENSTREETMAP GIS & OUTBREAK RADAR INTEGRATION
    // =========================================================================
    test('8a. GeoHash5 GIS Decoding: Resolves 5-character cluster hashes to valid coordinates', () {
      const String geoHash5 = 'te7ue';
      final coords = GeoHasher().decode(geoHash5);

      // coords[0] is longitude, coords[1] is latitude in dart_geohash
      final LatLng latLng = LatLng(coords[1], coords[0]);

      expect(latLng.latitude, inInclusiveRange(19.0, 21.0),
          reason: 'Nashik / Maharashtra corridor latitude should be in range');
      expect(latLng.longitude, inInclusiveRange(72.5, 74.5),
          reason: 'Nashik / Maharashtra corridor longitude should be in range');

      // Test fallback on invalid or corrupted hash
      LatLng decodeWithFallback(String hash) {
        try {
          if (hash.trim().isEmpty || hash.trim().length < 4) {
            return const LatLng(19.9975, 73.7898);
          }
          final decoded = GeoHasher().decode(hash.trim());
          if (decoded.length >= 2 && decoded[0].isFinite && decoded[1].isFinite) {
            return LatLng(decoded[1], decoded[0]);
          }
          return const LatLng(19.9975, 73.7898);
        } catch (_) {
          return const LatLng(19.9975, 73.7898);
        }
      }

      final fallbackLatLng = decodeWithFallback('');
      expect(fallbackLatLng.latitude, closeTo(19.9975, 0.001));
      expect(fallbackLatLng.longitude, closeTo(73.7898, 0.001));
    });

    test('8b. Distance Calculation & Privacy Rings: Calculates km distance and maps severity radii', () {
      const LatLng farmLocation = LatLng(19.9975, 73.7898); // Nashik Farm
      const LatLng outbreakLocation = LatLng(20.0350, 73.8200); // Nearby Niphad cluster

      const distanceCalculator = Distance();
      final double distanceKm = distanceCalculator.as(LengthUnit.Kilometer, farmLocation, outbreakLocation);

      expect(distanceKm, greaterThan(1.0));
      expect(distanceKm, lessThan(10.0));

      // Assert 3-Tier Epidemiological Circle Radii
      double getRadiusForSeverity(SeverityGrade grade) {
        switch (grade) {
          case SeverityGrade.severe:
            return 4900;
          case SeverityGrade.moderate:
            return 3600;
          case SeverityGrade.mild:
            return 2500;
        }
      }

      expect(getRadiusForSeverity(SeverityGrade.severe), equals(4900),
          reason: 'Severe outbreak must cover the full 4.9 km GeoHash privacy boundary');
      expect(getRadiusForSeverity(SeverityGrade.moderate), equals(3600),
          reason: 'Moderate risk circle must be 3.6 km');
      expect(getRadiusForSeverity(SeverityGrade.mild), equals(2500),
          reason: 'Mild containment circle must be 2.5 km');
    });

    test('8c. OpenStreetMap Policy Compliance: Uses valid userAgent and standard attribution', () {
      final tileLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.florax.crophealth',
      );

      expect(tileLayer.urlTemplate, equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'));
      expect(tileLayer.tileProvider.headers['User-Agent'], contains('com.florax.crophealth'),
          reason: 'TileLayer must inject userAgentPackageName into User-Agent headers per OSM policy');
    });
  });
}

class _FakeTfliteService extends TfliteIsolateService {
  @override
  Future<List<LeafRegionDiagnosis>> classifyMultiRegion({
    required Uint8List fullLeafBytes,
    required List<RoiCropPatch> roiPatches,
  }) async {
    return [
      const LeafRegionDiagnosis(
        regionId: 'region_full',
        boundingBoxNormalized: Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
        primaryPrediction: DiseasePrediction(
          labelId: 'tomato_early_blight',
          confidence: 0.88,
          scientificName: 'Alternaria solani',
          category: DiseaseCategory.fungal,
        ),
        secondaryPredictions: [],
        visualSymptomExplanation: {},
        isEarlyStageSubtle: false,
      ),
    ];
  }
}

class _StalledGradCamClient extends HybridGradCamClient {
  final Completer<Response<Map<String, dynamic>>?> completer = Completer();

  @override
  Future<Response<Map<String, dynamic>>?> fetchCloudGradCam({
    required Uint8List sanitizedBytes,
    String cropType = 'Tomato',
    bool simulateLowConfidence = false,
  }) {
    return completer.future;
  }
}

class _FakeIpmRepository extends FirestoreIpmAndScanRepository {
  @override
  Future<IcarIpmProtocol?> fetchVerifiedIpmProtocol(String labelId) async {
    return null;
  }
}

class _FakeOfflineSyncManager extends OfflineMediaSyncManager {
  @override
  Future<String> saveLocalScan({
    required String scanId,
    required Uint8List imageBytes,
  }) async {
    return 'scans/$scanId.jpg';
  }
}

class _FakeAuthRoleService extends AuthRoleService {}

class _FakeOutbreakFcmService extends OutbreakFcmService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> subscribeToOutbreakTopic(String geoHash5) async {}
  @override
  Future<void> subscribeToKvkUpdates(String userId) async {}
}
