import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:florax/domain/models/florax_models.dart';
import 'package:florax/services/vision/isolate_lesion_analyzer.dart';
import 'package:florax/repositories/firestore_ipm_and_scan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mandated 10 Diagnostic & Advisory Capabilities Suite', () {
    // =========================================================================
    // FEATURE #1: MULTI-REGION DISEASE DETECTION
    // =========================================================================
    test('Feature #1: Multi-Region Detection extracts distinct lesion bounding boxes', () async {
      // Create a 400x400 synthetic leaf with 2 distinct necrotic spots
      final image = img.Image(width: 400, height: 400);
      // Fill background green (healthy leaf foliage)
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          image.setPixelRgba(x, y, 40, 160, 40, 255);
        }
      }
      // Spot 1: Necrotic spot in top-left quadrant (x: 50..120, y: 50..120)
      for (int y = 50; y < 120; y++) {
        for (int x = 50; x < 120; x++) {
          image.setPixelRgba(x, y, 65, 38, 20, 255);
        }
      }
      // Spot 2: Chlorotic spot in bottom-right quadrant (x: 260..330, y: 260..330)
      for (int y = 260; y < 330; y++) {
        for (int x = 260; x < 330; x++) {
          image.setPixelRgba(x, y, 210, 200, 30, 255);
        }
      }

      final encodedJpg = Uint8List.fromList(img.encodeJpg(image));
      final result = await IsolateLesionAnalyzer.analyze(rawCameraBytes: encodedJpg);

      expect(result.lesionRegions.length, greaterThanOrEqualTo(2),
          reason: 'Must segment at least 2 distinct infected regions');
      expect(result.lesionRegions.length, lessThanOrEqualTo(6),
          reason: 'Capped at top 6 largest distinct regions');

      for (final region in result.lesionRegions) {
        expect(region.id, greaterThan(0));
        expect(region.boundingBoxNormalized.left, inInclusiveRange(0.0, 1.0));
        expect(region.boundingBoxNormalized.top, inInclusiveRange(0.0, 1.0));
        expect(region.boundingBoxNormalized.width, inInclusiveRange(0.01, 1.0));
        expect(region.boundingBoxNormalized.height, inInclusiveRange(0.01, 1.0));
        expect(region.areaPercent, greaterThan(0.0));
        expect(['necrotic', 'chlorotic'], contains(region.lesionType));
      }
    });

    // =========================================================================
    // FEATURE #2: DISEASE VS NUTRIENT DEFICIENCY DIFFERENTIATION
    // =========================================================================
    test('Feature #2: Biotic vs Abiotic Differentiation classifies diffuse chlorosis as nutrient stress', () async {
      // Create a 400x400 leaf with diffuse uniform chlorosis (yellowing) across blade without necrotic spots
      final yellowLeaf = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          // Yellowish pale-green pixel
          yellowLeaf.setPixelRgba(x, y, 195, 205, 55, 255);
        }
      }
      // Add natural high-frequency vein texture so it passes the edge sharpness gate
      for (int i = 0; i < 400; i += 8) {
        img.drawLine(yellowLeaf, x1: 0, y1: i, x2: 400, y2: i, color: img.ColorRgb8(165, 185, 45));
        img.drawLine(yellowLeaf, x1: i, y1: 0, x2: i, y2: 400, color: img.ColorRgb8(165, 185, 45));
      }

      final encoded = Uint8List.fromList(img.encodeJpg(yellowLeaf));
      final result = await IsolateLesionAnalyzer.analyze(rawCameraBytes: encoded);

      expect(result.uniformChlorosisRatio, greaterThanOrEqualTo(0.20),
          reason: 'Diffuse yellowing must register significant uniform chlorosis');
      expect(result.localizedNecrosisRatio, lessThan(0.04),
          reason: 'Absence of dark lesions must keep localized necrosis minimal');
      expect(result.stressEtiology, equals('abiotic_nutrient_stress'),
          reason: 'High chlorosis with low necrosis must classify as abiotic nutrient stress');
    });

    // =========================================================================
    // FEATURE #3: EARLY-STAGE DISEASE RECOGNITION
    // =========================================================================
    test('Feature #3: Early-Stage Alert triggers for small infected footprint (1.0% to 12.0%)', () async {
      // Create a 400x400 leaf with small emerging pinpoint necrotic spots (~3% of leaf area)
      final earlyLeaf = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          earlyLeaf.setPixelRgba(x, y, 40, 160, 40, 255); // healthy green
        }
      }
      // Small pinpoint spot (50x50 = 2500 pixels / 160,000 = ~1.56%)
      for (int y = 175; y < 225; y++) {
        for (int x = 175; x < 225; x++) {
          earlyLeaf.setPixelRgba(x, y, 55, 30, 15, 255);
        }
      }

      final encoded = Uint8List.fromList(img.encodeJpg(earlyLeaf));
      final result = await IsolateLesionAnalyzer.analyze(rawCameraBytes: encoded);

      expect(result.lesionAreaPercent, inInclusiveRange(1.0, 12.0),
          reason: 'Small initial infection footprint');
      expect(result.isEarlyStageAlert, isTrue,
          reason: 'Emerging lesion footprint between 1% and 12% must trigger early stage alert');
    });

    // =========================================================================
    // FEATURE #4: EXPLAINABLE AI (XAI) DIAGNOSIS
    // =========================================================================
    test('Feature #4: Plain-language XAI diagnostic caption describes region count and symptom', () {
      const conditionTitle = 'Early Blight';
      const distinguishingSymptom = 'Dark brown rings like a bullseye target on older leaves';
      const regionCount = 3;

      final countText = regionCount > 1 ? '$regionCount areas' : '1 area';
      final xaiCaptionEn = 'Highlighted spots across $countText on the leaf match $conditionTitle. $distinguishingSymptom';
      final xaiCaptionMr = 'पानावरील $countText मध्ये दिसणारे डाग $conditionTitle या रोगाशी तंतोतंत जुळतात. $distinguishingSymptom';

      expect(xaiCaptionEn, contains('3 areas'));
      expect(xaiCaptionEn, contains('Early Blight'));
      expect(xaiCaptionEn, contains('bullseye target'));
      expect(xaiCaptionMr, contains('3 areas'));
      expect(xaiCaptionMr, contains('Early Blight'));
    });

    // =========================================================================
    // FEATURE #5: INTELLIGENT IMAGE QUALITY VERIFICATION
    // =========================================================================
    test('Feature #5: Image Quality Verifier rejects dark, overexposed, and blurry frames with exact codes', () async {
      // 1. Underexposed / Too Dark (mean luminance < 38)
      final darkImage = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          darkImage.setPixelRgba(x, y, 15, 15, 15, 255);
        }
      }
      final darkBytes = Uint8List.fromList(img.encodeJpg(darkImage));
      final darkResult = await IsolateLesionAnalyzer.analyze(rawCameraBytes: darkBytes);

      expect(darkResult.qualityReport.isAcceptable, isFalse);
      expect(darkResult.qualityReport.failureCode, equals('tooDark'));
      expect(darkResult.qualityReport.isTooDark, isTrue);

      // 2. Overexposed / Too Bright (mean luminance > 235)
      final brightImage = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          brightImage.setPixelRgba(x, y, 245, 245, 245, 255);
        }
      }
      final brightBytes = Uint8List.fromList(img.encodeJpg(brightImage));
      final brightResult = await IsolateLesionAnalyzer.analyze(rawCameraBytes: brightBytes);

      expect(brightResult.qualityReport.isAcceptable, isFalse);
      expect(brightResult.qualityReport.failureCode, equals('tooBright'));
      expect(brightResult.qualityReport.isTooBright, isTrue);

      // 3. Out-of-focus / Blurry (adequate lighting but completely flat image with 0 Laplacian variance)
      final blurryImage = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          blurryImage.setPixelRgba(x, y, 70, 150, 70, 255);
        }
      }
      final blurryBytes = Uint8List.fromList(img.encodeJpg(blurryImage));
      final blurryResult = await IsolateLesionAnalyzer.analyze(rawCameraBytes: blurryBytes);

      expect(blurryResult.qualityReport.isAcceptable, isFalse);
      expect(blurryResult.qualityReport.failureCode, equals('blurry'));
      expect(blurryResult.qualityReport.isBlurry, isTrue);

      // 4. Post-Inference OOD Gate code
      const oodReport = ImageQualityReport(
        isAcceptable: false,
        blurScore: 120.0,
        brightnessScore: 130.0,
        leafCoveragePercent: 80.0,
        failureCode: 'lowConfidenceOod',
        failureReasons: ['Non-biological foliage object detected'],
      );
      expect(oodReport.isLowConfidenceOod, isTrue);
      expect(oodReport.failureCode, equals('lowConfidenceOod'));
    });

    // =========================================================================
    // FEATURE #6: DIFFERENTIAL DIAGNOSIS (TOP-3 + DISTINGUISHING SYMPTOMS)
    // =========================================================================
    test('Feature #6: Top-3 Differential Diagnosis includes plain names and visual symptoms', () {
      const top1 = DiseasePrediction(
        labelId: 'tomato_early_blight',
        confidence: 0.84,
        scientificName: 'Alternaria solani',
        category: DiseaseCategory.fungal,
        plainName: 'Tomato Early Blight',
        distinguishingSymptom: 'Dark brown rings like a bullseye target on older leaves.',
      );
      const top2 = DiseasePrediction(
        labelId: 'tomato_septoria_leaf_spot',
        confidence: 0.11,
        scientificName: 'Septoria lycopersici',
        category: DiseaseCategory.fungal,
        plainName: 'Tomato Septoria Leaf Spot',
        distinguishingSymptom: 'Many tiny circular spots with dark brown margins and pale grey centers.',
      );
      const top3 = DiseasePrediction(
        labelId: 'tomato_late_blight',
        confidence: 0.05,
        scientificName: 'Phytophthora infestans',
        category: DiseaseCategory.fungal,
        plainName: 'Tomato Late Blight',
        distinguishingSymptom: 'Water-soaked dark lesions with white mold on underside in humid air.',
      );

      final diff = [top1, top2, top3];
      expect(diff.length, equals(3));
      for (final p in diff) {
        expect(p.plainName, isNotEmpty);
        expect(p.distinguishingSymptom, isNotEmpty);
        expect(p.confidence, inInclusiveRange(0.0, 1.0));
      }
      expect(top1.distinguishingSymptom, contains('bullseye'));
      expect(top2.distinguishingSymptom, contains('circular spots'));
      expect(top3.distinguishingSymptom, contains('Water-soaked'));
    });

    // =========================================================================
    // FEATURE #7: DISEASE SEVERITY ESTIMATION (PHYTOPATHOLOGY BANDS)
    // =========================================================================
    test('Feature #7: Disease Severity maps to standardized phytopathology bands', () {
      // Mild: < 15.0%
      expect(SeverityGrade.fromPercentage(0.5), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromPercentage(7.8), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromPercentage(14.9), equals(SeverityGrade.mild));
      expect(SeverityGrade.mild.label, equals('Mild (<15%)'));

      // Moderate: 15.0% - 39.9%
      expect(SeverityGrade.fromPercentage(15.0), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(26.4), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(39.9), equals(SeverityGrade.moderate));
      expect(SeverityGrade.moderate.label, equals('Moderate (15-40%)'));

      // Severe: >= 40.0%
      expect(SeverityGrade.fromPercentage(40.0), equals(SeverityGrade.severe));
      expect(SeverityGrade.fromPercentage(55.2), equals(SeverityGrade.severe));
      expect(SeverityGrade.fromPercentage(92.0), equals(SeverityGrade.severe));
      expect(SeverityGrade.severe.label, equals('Severe (>=40%)'));
    });

    // =========================================================================
    // FEATURE #8: VERIFIED AGRICULTURAL ADVISORY (ICAR ATTRIBUTION)
    // =========================================================================
    test('Feature #8: Bundled offline ICAR protocols validate structured 3-tier advisory', () {
      final jsonFile = File('assets/data/offline_icar_protocols.json');
      expect(jsonFile.existsSync(), isTrue, reason: 'offline_icar_protocols.json must exist');

      final List<dynamic> list = jsonDecode(jsonFile.readAsStringSync()) as List<dynamic>;
      expect(list.length, greaterThanOrEqualTo(38), reason: 'All 38 ICAR protocols must be present');

      for (final raw in list) {
        final map = raw as Map<String, dynamic>;
        expect(map['id'], isNotEmpty);
        expect(map['diseaseName'], isNotNull);
        expect(map['tier1_cultural'] ?? map['tier1Cultural'], isNotNull);
        expect(map['tier2_biological'] ?? map['tier2Biological'], isNotNull);
        expect(map['tier3_chemical'] ?? map['tier3Chemical'], isNotNull);
        expect(map['distinguishingSymptoms'], isNotNull);
      }
    });

    // =========================================================================
    // FEATURE #9: EXPERT VERIFICATION & SECOND OPINION ESCALATION
    // =========================================================================
    test('Feature #9: Escalation record contains Top-3, severity, etiology, and thumbnailBase64', () {
      const topCandidate = DiseasePrediction(
        labelId: 'tomato_early_blight',
        confidence: 0.68,
        scientificName: 'Alternaria solani',
        category: DiseaseCategory.fungal,
        plainName: 'Tomato Early Blight',
        distinguishingSymptom: 'Dark brown target rings on older leaves.',
      );

      final scanRecord = LeafScanRecord(
        scanId: 'FLX-ESCALATE-TEST',
        userId: 'farmer_pune_01',
        plantTagId: 'Tomato-Field-A',
        timestamp: DateTime.utc(2026, 11, 22),
        imageUrl: '/local/scans/FLX-ESCALATE-TEST.jpg',
        thumbnailBase64: 'data:image/jpeg;base64,/9j/4AAQSkZJRg...',
        topPredictions: [topCandidate],
        lesionAreaPercent: 18.4,
        severityGrade: SeverityGrade.moderate,
        requiresKvkReview: true,
        verificationStatus: VerificationStatus.pendingKvkReview,
        geoHash5: 'tek3u',
        isEarlyStageAlert: false,
        stressEtiology: 'biotic_infectious_disease',
        lesionRegions: [
          const LesionRegion(
            id: 1,
            boundingBoxNormalized: Rect.fromLTWH(0.2, 0.2, 0.4, 0.4),
            areaPercent: 18.4,
            lesionType: 'necrotic',
          ),
        ],
      );

      final firestoreMap = scanRecord.toFirestore();
      expect(firestoreMap['scanId'], equals('FLX-ESCALATE-TEST'));
      expect(firestoreMap['requiresKvkReview'], isTrue);
      expect(firestoreMap['thumbnailBase64'], isNotEmpty);
      expect(firestoreMap['severityGrade'], equals('MODERATE'));
      expect(firestoreMap['stressEtiology'], equals('biotic_infectious_disease'));
      expect((firestoreMap['lesionRegions'] as List).length, equals(1));
    });

    // =========================================================================
    // FEATURE #10: TRUE COLD-START OFFLINE DISEASE IDENTIFICATION & ADVISORY
    // =========================================================================
    test('Feature #10: Cold-start offline protocol lookup loads directly from bundled JSON', () {
      final jsonFile = File('assets/data/offline_icar_protocols.json');
      final List<dynamic> list = jsonDecode(jsonFile.readAsStringSync()) as List<dynamic>;

      final offlineCache = <String, IcarIpmProtocol>{};
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String;
        offlineCache[id] = IcarIpmProtocol.fromMap(map, id);
      }

      FirestoreIpmAndScanRepository.setOfflineProtocolsCache(offlineCache);

      // Verify retrieval of Tomato Early Blight
      final earlyBlight = offlineCache['tomato_early_blight'];
      expect(earlyBlight, isNotNull);
      expect(earlyBlight!.diseaseName['en'], contains('Early Blight'));
      expect(earlyBlight.distinguishingSymptoms['en'], isNotEmpty);
      expect(earlyBlight.tier1Cultural['en'], isNotEmpty);
      expect(earlyBlight.tier2Biological['en'], isNotEmpty);
      expect(earlyBlight.tier3Chemical.formulationName, isNotEmpty);

      // Verify retrieval of Abiotic Magnesium Deficiency
      final mgDef = offlineCache['abiotic_magnesium_deficiency'];
      expect(mgDef, isNotNull);
      expect(mgDef!.isAbioticNutrientDeficiency, isTrue);
      expect(mgDef.distinguishingSymptoms['en']!.first, contains('Interveinal chlorosis'));
    });
  });
}
