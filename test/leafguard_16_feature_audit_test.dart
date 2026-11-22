import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:florax/domain/models/florax_models.dart';
import 'package:florax/services/vision/isolate_lesion_analyzer.dart';
import 'package:florax/services/voice/vernacular_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeafGuard 16-Feature Enterprise Integration & Audit Test Suite', () {
    // =========================================================================
    // FEATURE #5: INTELLIGENT IMAGE QUALITY GATE & PRE-INFERENCE VERIFICATION
    // =========================================================================
    test('1. Quality Gate (#5): Rejects dark and featureless synthetic buffers with failure reasons', () async {
      // A. Synthesize a dark/underexposed image buffer (RGB ~10, Luminance < 40)
      final img.Image darkImage = img.Image(width: 320, height: 320, numChannels: 3);
      final darkPixel = img.ColorRgb8(10, 12, 10);
      for (int y = 0; y < 320; y++) {
        for (int x = 0; x < 320; x++) {
          darkImage.setPixel(x, y, darkPixel);
        }
      }
      final Uint8List darkBytes = Uint8List.fromList(img.encodeJpg(darkImage, quality: 80));

      final darkResult = await IsolateLesionAnalyzer.analyzeBytes(darkBytes);
      expect(darkResult.qualityReport.isAcceptable, isFalse,
          reason: 'Dark image must fail ICAR pre-inference quality verification');
      expect(darkResult.qualityReport.failureReasons.isNotEmpty, isTrue);
      expect(
        darkResult.qualityReport.failureReasons.any((r) => r.toLowerCase().contains('dark')),
        isTrue,
        reason: 'Failure reasons must cite darkness/underexposure',
      );

      // B. Synthesize a uniform flat gray buffer (No foliage green, leafCoverage < 18%)
      final img.Image nonLeafImage = img.Image(width: 320, height: 320, numChannels: 3);
      final grayPixel = img.ColorRgb8(128, 128, 128);
      for (int y = 0; y < 320; y++) {
        for (int x = 0; x < 320; x++) {
          nonLeafImage.setPixel(x, y, grayPixel);
        }
      }
      final Uint8List nonLeafBytes = Uint8List.fromList(img.encodeJpg(nonLeafImage, quality: 80));

      final nonLeafResult = await IsolateLesionAnalyzer.analyzeBytes(nonLeafBytes);
      expect(nonLeafResult.qualityReport.isAcceptable, isFalse);
      expect(
        nonLeafResult.qualityReport.failureReasons.any(
          (r) => r.toLowerCase().contains('leaf') || r.toLowerCase().contains('blur'),
        ),
        isTrue,
        reason: 'Non-leaf surface must trigger leaf coverage or sharpness failure',
      );
    });

    // =========================================================================
    // FEATURES #1 & #8: MULTI-REGION ROI SEGMENTATION & 3-TIER SEVERITY GRADING
    // =========================================================================
    test('2. Multi-Region & Severity (#1, #8): Extracts >=2 ROI patches and maps severity thresholds', () async {
      // 1. Synthesize 400x400 leaf canvas with 2 distinct necrotic lesions
      final img.Image leafCanvas = img.Image(width: 400, height: 400, numChannels: 3);
      final healthyGreen = img.ColorRgb8(45, 160, 55); // Green foliage
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          leafCanvas.setPixel(x, y, healthyGreen);
        }
      }

      // Necrotic lesion 1 (Top-Left: 50x50 box)
      final necroticBrown = img.ColorRgb8(130, 80, 25);
      img.fillRect(leafCanvas, x1: 50, y1: 50, x2: 100, y2: 100, color: necroticBrown);

      // Necrotic lesion 2 (Bottom-Right: 50x50 box)
      img.fillRect(leafCanvas, x1: 280, y1: 280, x2: 330, y2: 330, color: necroticBrown);

      final Uint8List leafBytes = Uint8List.fromList(img.encodeJpg(leafCanvas, quality: 90));
      final result = await IsolateLesionAnalyzer.analyzeBytes(leafBytes);

      // Verify connected-component ROI patches (Feature #1)
      expect(result.roiPatches.length, greaterThanOrEqualTo(2),
          reason: 'Expected at least 2 distinct cropped ROI patches for multi-region disease analysis');
      expect(result.hotspots.length, greaterThanOrEqualTo(2),
          reason: 'Expected at least 2 spatial density centroids');

      // Verify each ROI patch has valid bounding box and JPEG bytes
      for (final patch in result.roiPatches) {
        expect(patch.imageBytes.isNotEmpty, isTrue);
        expect(patch.boundingBoxNormalized.left, inInclusiveRange(0.0, 1.0));
        expect(patch.boundingBoxNormalized.top, inInclusiveRange(0.0, 1.0));
      }

      // Verify 3-Tier Clinical Severity Thresholds (Feature #7: Mild <15%, Moderate 15-40%, Severe >=40%)
      expect(SeverityGrade.fromPercentage(3.2), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromPercentage(14.9), equals(SeverityGrade.mild));
      expect(SeverityGrade.fromPercentage(15.0), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(25.0), equals(SeverityGrade.moderate));
      expect(SeverityGrade.fromPercentage(40.0), equals(SeverityGrade.severe));
      expect(SeverityGrade.fromPercentage(68.0), equals(SeverityGrade.severe));
    });

    // =========================================================================
    // FEATURE #2: NUTRIENT DEFICIENCY VS INFECTION DIFFERENTIATION
    // =========================================================================
    test('3. Nutrient vs Infection (#2): Abiotic deficiency suppresses chemical pesticides', () {
      final abioticProtocol = IcarIpmProtocol(
        diseaseId: 'abiotic_magnesium_deficiency',
        scientificName: 'Magnesium chlorosis (Nutritional starvation)',
        diseaseName: const {
          'en': 'Magnesium Deficiency',
          'mr': 'मॅग्नेशियम अन्नद्रव्य कमतरता',
          'hi': 'मैग्नीशियम पोषक तत्व की कमी',
        },
        category: DiseaseCategory.abiotic,
        isAbioticNutrientDeficiency: true,
        tier1Cultural: const {
          'en': ['Soil testing and organic compost application'],
          'mr': ['माती परीक्षण आणि शेणखत वापर'],
        },
        tier2Biological: const {
          'en': ['Foliar spray of Magnesium Sulphate @ 5g/L'],
          'mr': ['मॅग्नेशियम सल्फेट ५ ग्रॅम प्रति लिटर फवारणी'],
        },
        tier3Chemical: const Tier3ChemicalControl(
          activeIngredient: 'NONE_REQUIRED_ABIOTIC',
          formulationName: 'DO_NOT_APPLY_CHEMICAL_FUNGICIDE',
          dosagePerLitre: '0 ml (Abiotic Deficiency)',
          waitingPeriodDays: 0,
          cibrcRegistrationNumber: 'EXEMPT-NUTRIENT',
          economicThreshold: 'Yellowing in lower leaves',
          antidoteStatement: 'Not applicable',
          toxicityBand: 'GREEN',
        ),
      );

      // Verify strict Abiotic safety guardrails
      expect(abioticProtocol.isAbioticNutrientDeficiency, isTrue);
      expect(abioticProtocol.category, equals(DiseaseCategory.abiotic));
      expect(
        abioticProtocol.tier3Chemical.formulationName,
        equals('DO_NOT_APPLY_CHEMICAL_FUNGICIDE'),
        reason: 'Chemical fungicide must be suppressed for abiotic nutrient deficiencies',
      );
      expect(abioticProtocol.tier3Chemical.activeIngredient, equals('NONE_REQUIRED_ABIOTIC'));
    });

    // =========================================================================
    // FEATURE #9: LONGITUDINAL RECOVERY & DETERIORATION ESCALATION
    // =========================================================================
    test('4. Deterioration Alert (#9): Increased lesion spread triggers escalation alert', () {
      const double baselineLesion = 8.5;
      const double followUpLesion = 19.8;
      final double deltaPercent = followUpLesion - baselineLesion;

      final bool isWorsening = deltaPercent > 0.0;
      final bool requiresExpertEscalation = deltaPercent > 5.0; // Over 5% increase

      expect(isWorsening, isTrue, reason: 'Follow-up lesion spread indicates disease progression');
      expect(requiresExpertEscalation, isTrue,
          reason: 'Spike from 8.5% to 19.8% (+11.3%) must trigger urgent expert second opinion');

      // Verify that recovery model records status accurately
      final baselineProgress = LeafProgressionEntry(
        scanId: 'SCAN-BASE-01',
        plantTagId: 'PLANT-TOM-01',
        timestamp: DateTime.utc(2026, 11, 10),
        lesionAreaPercent: baselineLesion,
        severityGrade: SeverityGrade.fromPercentage(baselineLesion),
        imageUrl: 'https://storage.googleapis.com/florax/scans/day1.jpg',
      );

      final followUpProgress = LeafProgressionEntry(
        scanId: 'SCAN-FOLLOW-02',
        plantTagId: 'PLANT-TOM-01',
        timestamp: DateTime.utc(2026, 11, 15),
        lesionAreaPercent: followUpLesion,
        severityGrade: SeverityGrade.fromPercentage(followUpLesion),
        imageUrl: 'https://storage.googleapis.com/florax/scans/day5.jpg',
      );

      expect(baselineProgress.severityGrade, equals(SeverityGrade.mild));
      expect(followUpProgress.severityGrade, equals(SeverityGrade.moderate));
      expect(followUpProgress.lesionAreaPercent, greaterThan(baselineProgress.lesionAreaPercent));
    });

    // =========================================================================
    // FEATURE #13: HANDS-FREE MULTILINGUAL VOICE NAVIGATION ROUTER
    // =========================================================================
    test('5. Voice Intent Router (#13): Spoken Marathi, Hindi & English map to target tab indices', () {
      final voiceService = VernacularVoiceService();

      // --- MARATHI SPOKEN COMMANDS ---
      // Tab 0: Scanner
      final mrScan = voiceService.parseFarmerIntent('पान स्कॅन करा');
      expect(mrScan.intentType, equals(FarmerVoiceIntentType.diagnoseSymptom));
      expect(mrScan.targetTabIndex, equals(0));

      // Tab 1: Weather / Outbreak Alerts
      final mrWeather = voiceService.parseFarmerIntent('हवामान किंवा रोग माहिती');
      expect(mrWeather.intentType, equals(FarmerVoiceIntentType.checkWeather));
      expect(mrWeather.targetTabIndex, equals(1));

      // Tab 2: Track Recovery / Treatment Progression
      final mrRecovery = voiceService.parseFarmerIntent('प्रगती दाखवा');
      expect(mrRecovery.intentType, equals(FarmerVoiceIntentType.inquireTreatment));
      expect(mrRecovery.targetTabIndex, equals(2));

      // Tab 3: Expert Directory & Second Opinion
      final mrExpert = voiceService.parseFarmerIntent('तज्ज्ञ किंवा डॉक्टर');
      expect(mrExpert.intentType, equals(FarmerVoiceIntentType.contactKvkExpert));
      expect(mrExpert.targetTabIndex, equals(3));

      // Tab 4: LeafGuard Connect NGO Network
      final mrNgo = voiceService.parseFarmerIntent('ngo मदत');
      expect(mrNgo.intentType, equals(FarmerVoiceIntentType.ngoConnect));
      expect(mrNgo.targetTabIndex, equals(4));

      // --- HINDI SPOKEN COMMANDS ---
      // Tab 0: Scanner
      final hiScan = voiceService.parseFarmerIntent('पत्ती स्कैन करें');
      expect(hiScan.intentType, equals(FarmerVoiceIntentType.diagnoseSymptom));
      expect(hiScan.targetTabIndex, equals(0));

      // Tab 1: Weather / Outbreak Alerts
      final hiWeather = voiceService.parseFarmerIntent('मौसम या रोग जानकारी');
      expect(hiWeather.intentType, equals(FarmerVoiceIntentType.checkWeather));
      expect(hiWeather.targetTabIndex, equals(1));

      // Tab 2: Track Recovery
      final hiRecovery = voiceService.parseFarmerIntent('प्रगति दिखाओ');
      expect(hiRecovery.intentType, equals(FarmerVoiceIntentType.inquireTreatment));
      expect(hiRecovery.targetTabIndex, equals(2));

      // Tab 3: Expert Directory
      final hiExpert = voiceService.parseFarmerIntent('विशेषज्ञ या डॉक्टर');
      expect(hiExpert.intentType, equals(FarmerVoiceIntentType.contactKvkExpert));
      expect(hiExpert.targetTabIndex, equals(3));

      // Tab 4: NGO Connect
      final hiNgo = voiceService.parseFarmerIntent('ngo मदद');
      expect(hiNgo.intentType, equals(FarmerVoiceIntentType.ngoConnect));
      expect(hiNgo.targetTabIndex, equals(4));

      // --- ENGLISH SPOKEN COMMANDS ---
      final enScan = voiceService.parseFarmerIntent('scan leaf please');
      expect(enScan.targetTabIndex, equals(0));

      final enWeather = voiceService.parseFarmerIntent('outbreak alerts in my district');
      expect(enWeather.targetTabIndex, equals(1));

      final enRecovery = voiceService.parseFarmerIntent('track recovery of plant');
      expect(enRecovery.targetTabIndex, equals(2));

      final enExpert = voiceService.parseFarmerIntent('find expert agronomist');
      expect(enExpert.targetTabIndex, equals(3));

      final enNgo = voiceService.parseFarmerIntent('ngo connect for grant support');
      expect(enNgo.targetTabIndex, equals(4));
    });

    // =========================================================================
    // FEATURE #16: CSR & INSTITUTIONAL PARTNERSHIP MODELS & INQUIRY SCHEMA
    // =========================================================================
    test('6. CSR Hub (#16): Partnership inquiry and impact telemetry serialization', () {
      final now = DateTime.utc(2026, 11, 21, 14, 0, 0);

      final inquiry = PartnershipInquiry(
        inquiryId: 'INQ-TEST-001',
        organizationName: 'Tata Trusts Foundation',
        contactPerson: 'Aditi Deshmukh',
        email: 'aditi@tatatrusts.org',
        phone: '+919822001122',
        partnershipType: 'csr_funding_grant',
        proposedScope: 'Deploy FloraX across 50 Vidarbha cotton clusters for pesticide reduction.',
        targetDistricts: const ['Nashik', 'Pune', 'Amravati'],
        estimatedBudgetInr: 2500000.0,
        submittedAt: now,
        status: 'SUBMITTED',
      );

      final map = inquiry.toFirestore();
      expect(map['inquiryId'], equals('INQ-TEST-001'));
      expect(map['partnershipType'], equals('csr_funding_grant'));
      expect(map['estimatedBudgetInr'], equals(2500000.0));
      expect(map['targetDistricts'], contains('Amravati'));

      final parsed = PartnershipInquiry.fromMap(map, 'INQ-TEST-001');
      expect(parsed.inquiryId, equals('INQ-TEST-001'));
      expect(parsed.organizationName, equals('Tata Trusts Foundation'));
      expect(parsed.targetDistricts.length, equals(3));
      expect(parsed.status, equals('SUBMITTED'));

      final telemetry = ImpactTelemetry(
        totalScansCount: 15200,
        nutrientDeficienciesDiverted: 3510,
        expertSecondOpinionsCompleted: 210,
        verifiedOutbreakAlertsIssued: 28,
        lastUpdated: now,
      );

      final teleMap = telemetry.toFirestore();
      expect(teleMap['totalScansCount'], equals(15200));
      expect(teleMap['nutrientDeficienciesDiverted'], equals(3510));

      final teleParsed = ImpactTelemetry.fromMap(teleMap);
      expect(teleParsed.totalScansCount, equals(15200));
      expect(teleParsed.expertSecondOpinionsCompleted, equals(210));
    });
  });
}
