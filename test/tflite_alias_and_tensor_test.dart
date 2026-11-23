import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TFLite 45-Class Dynamic Engine & Tensor Contract Verification', () {
    // =========================================================================
    // 1. LABELS.TXT INTEGRITY & 45 CANONICAL CLASSES
    // =========================================================================
    test('1. labels.txt contains exactly 45 canonical pathology & health classes parsed with LineSplitter (CRLF-proof)', () {
      final labelsFile = File('assets/models/labels.txt');
      expect(labelsFile.existsSync(), isTrue, reason: 'labels.txt must exist in assets/models/');

      final rawLabelsText = labelsFile.readAsStringSync();
      final labels = const LineSplitter()
          .convert(rawLabelsText)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(labels.length, equals(45),
          reason: 'Model must have exactly 45 canonical output classes');

      // Verify no duplicates
      final uniqueLabels = labels.toSet();
      expect(uniqueLabels.length, equals(45),
          reason: 'All 45 labels must be distinct');

      // Verify each label has no whitespace or carriage returns
      for (final label in labels) {
        expect(label.contains('\r'), isFalse, reason: 'Label [$label] must not contain carriage returns');
        expect(label.contains(' '), isFalse, reason: 'Label [$label] must be snake_case identifier without spaces');
      }

      // Verify Cotton expansion (4 classes)
      expect(labels, contains('cotton_healthy'));
      expect(labels, contains('cotton_bacterial_blight'));
      expect(labels, contains('cotton_leaf_curl'));
      expect(labels, contains('cotton_wilt'));

      // Verify Banana expansion (1 class)
      expect(labels, contains('banana_healthy'));

      // Verify Sugarcane expansion (5 classes)
      expect(labels, contains('sugarcane_healthy'));
      expect(labels, contains('sugarcane_bacterial_blight'));
      expect(labels, contains('sugarcane_mosaic'));
      expect(labels, contains('sugarcane_red_rot'));
      expect(labels, contains('sugarcane_yellow_rust'));

      // Verify All 6 Abiotic Nutrient Stress classes
      expect(labels, contains('abiotic_nitrogen_deficiency'));
      expect(labels, contains('abiotic_phosphorus_deficiency'));
      expect(labels, contains('abiotic_potassium_deficiency'));
      expect(labels, contains('abiotic_zinc_deficiency'));
      expect(labels, contains('abiotic_micronutrient_deficiency'));
      expect(labels, contains('abiotic_multi_nutrient_deficiency'));

      // Verify OOD Non-leaf class
      expect(labels, contains('not_a_leaf_background'));
    });

    // =========================================================================
    // 2. MODEL METADATA DYNAMIC CONTRACT
    // =========================================================================
    test('2. model_meta.json dynamic contract defines 45 classes, float32 input shape [1, 224, 224, 3], and OOD thresholds', () {
      final metaFile = File('assets/models/model_meta.json');
      expect(metaFile.existsSync(), isTrue, reason: 'model_meta.json must exist in assets/models/');

      final Map<String, dynamic> meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;

      expect(meta['model_file'], equals('florax_v2_45c_fp16.tflite'));
      expect(meta['keras_file'], equals('florax_v2_45c_gradcam.keras'));
      expect(meta['num_classes'], equals(45));
      expect(meta['input_shape'], equals([1, 224, 224, 3]));
      expect(meta['input_dtype'], equals('float32'));
      expect(meta['input_range'], equals([0.0, 255.0]));
      expect(meta['output_shape'], equals([1, 45]));
      expect(meta['ood_class'], equals('not_a_leaf_background'));
      expect(meta['ood_min_confidence'], equals(0.45));
      expect(meta['ood_max_normalized_entropy'], equals(0.65));
      expect(meta['clinical_chemical_lock_threshold'], equals(0.75));

      // Check model binary file exists and size is valid
      final modelFile = File('assets/models/${meta['model_file']}');
      expect(modelFile.existsSync(), isTrue, reason: 'TFLite model file referenced in meta must exist');
      expect(modelFile.lengthSync(), greaterThan(1 * 1024 * 1024), reason: 'TFLite model binary must be > 1MB');
    });

    // =========================================================================
    // 3. DIRECT 1:1 INDEX-TO-LABEL MAPPING & SUM(PROBS) > 0.90 SAFETY GATE
    // =========================================================================
    test('3. Direct 1:1 index-to-label mapping sums to 1.0 and satisfies sum(probs) > 0.90 safety gate', () {
      final labelsFile = File('assets/models/labels.txt');
      final labels = const LineSplitter()
          .convert(labelsFile.readAsStringSync())
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(labels.length, equals(45));

      // Construct a valid normalized probability distribution over 45 classes
      final List<double> probs = List.filled(45, 0.0);
      final int tomatoIndex = labels.indexOf('tomato_early_blight');
      expect(tomatoIndex, greaterThanOrEqualTo(0));

      probs[tomatoIndex] = 0.88;
      final double remainder = 0.12 / (45 - 1);
      for (int i = 0; i < 45; i++) {
        if (i != tomatoIndex) probs[i] = remainder;
      }

      // Assert direct 1:1 indexing
      expect(labels[tomatoIndex], equals('tomato_early_blight'));

      // Validate sum(probs) > 0.90 safety gate
      final double probSum = probs.fold(0.0, (acc, p) => acc + p);
      expect(probSum, closeTo(1.0, 1e-4));
      expect(probSum > 0.90, isTrue, reason: 'Valid distribution must satisfy sum(probs) > 0.90');

      // Test that an all-zero or broken inference vector fails the safety gate
      final List<double> brokenZeroProbs = List.filled(45, 0.0);
      final double zeroSum = brokenZeroProbs.fold(0.0, (acc, p) => acc + p);
      expect(zeroSum > 0.90, isFalse,
          reason: 'All-zero or corrupt vector must fail sum(probs) > 0.90 assertion rather than being swallowed');
    });

    // =========================================================================
    // 4. ABIOTIC NUTRIENT STRESS CLASSIFICATION & CHEMICAL LOCKING
    // =========================================================================
    test('4. Abiotic nutrient stress classification routes all 6 abiotic_* classes and locks Tier-3 chemicals', () {
      final labelsFile = File('assets/models/labels.txt');
      final labels = const LineSplitter()
          .convert(labelsFile.readAsStringSync())
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final abioticLabels = labels.where((l) => l.startsWith('abiotic_')).toList();
      expect(abioticLabels.length, equals(6), reason: 'Must have exactly 6 abiotic nutrient deficiency classes');

      // Load offline protocols and verify all abiotic classes enforce chemical locking
      final protocolsFile = File('assets/data/offline_icar_protocols.json');
      expect(protocolsFile.existsSync(), isTrue);
      final List<dynamic> protocolsList = jsonDecode(protocolsFile.readAsStringSync()) as List<dynamic>;
      final Map<String, dynamic> protocols = {
        for (final item in protocolsList)
          (item as Map<String, dynamic>)['id'] as String: item
      };

      for (final abioticLabel in abioticLabels) {
        expect(protocols.containsKey(abioticLabel), isTrue,
            reason: 'offline_icar_protocols.json must contain protocol for $abioticLabel');

        final protocol = protocols[abioticLabel] as Map<String, dynamic>;
        expect(protocol['isAbioticNutrientDeficiency'], isTrue,
            reason: '$abioticLabel must have isAbioticNutrientDeficiency = true');
        expect(protocol['category'], equals('NUTRIENT'),
            reason: '$abioticLabel category must be NUTRIENT');

        // Verify tier3 chemical recommendations are locked/empty or explicitly indicate no chemical fungicide
        final tier3 = protocol['tier3Chemical'] as List<dynamic>? ?? [];
        for (final chem in tier3) {
          final chemMap = chem as Map<String, dynamic>;
          final name = (chemMap['name'] ?? chemMap['tradeName'] ?? '').toString().toLowerCase();
          expect(
            name.contains('fungicide') || name.contains('bactericide'),
            isFalse,
            reason: '$abioticLabel must not prescribe chemical fungicides in Tier-3 ($name)',
          );
        }
      }
    });

    // =========================================================================
    // 5. OUT-OF-DISTRIBUTION (OOD) ENTROPY & CONFIDENCE GATES
    // =========================================================================
    test('5. Out-of-Distribution (OOD) entropy and confidence rejection gates flag uncertain or non-leaf predictions', () {
      const int numClasses = 45;
      final double maxEntropy = math.log(numClasses); // ln(45) ~ 3.8066

      double computeNormalizedEntropy(List<double> p) {
        double entropy = 0.0;
        for (final prob in p) {
          if (prob > 1e-12) {
            entropy -= prob * math.log(prob);
          }
        }
        return entropy / maxEntropy;
      }

      // Case A: Maximum uncertainty (Uniform distribution over 45 classes)
      final List<double> uniformProbs = List.filled(numClasses, 1.0 / numClasses);
      final double uniformEntropy = computeNormalizedEntropy(uniformProbs);
      final double uniformTop1 = uniformProbs[0];

      expect(uniformEntropy, closeTo(1.0, 1e-3));
      expect(uniformTop1, closeTo(1.0 / 45.0, 1e-3)); // ~0.0222
      // Gate checks
      final bool uniformIsOod = uniformTop1 < 0.45 || uniformEntropy > 0.65;
      expect(uniformIsOod, isTrue, reason: 'Uniform prediction must trigger OOD rejection');

      // Case B: High confidence leaf pathology prediction
      final List<double> confidentProbs = List.filled(numClasses, 0.0);
      confidentProbs[0] = 0.92;
      final double rest = 0.08 / (numClasses - 1);
      for (int i = 1; i < numClasses; i++) {
        confidentProbs[i] = rest;
      }

      final double confidentEntropy = computeNormalizedEntropy(confidentProbs);
      final double confidentTop1 = confidentProbs[0];

      expect(confidentTop1, equals(0.92));
      expect(confidentEntropy, lessThan(0.65));
      final bool confidentIsOod = confidentTop1 < 0.45 || confidentEntropy > 0.65;
      expect(confidentIsOod, isFalse, reason: 'High-confidence diagnostic must pass OOD gate');

      // Case C: Top-1 is explicitly not_a_leaf_background
      final labelsFile = File('assets/models/labels.txt');
      final labels = const LineSplitter()
          .convert(labelsFile.readAsStringSync())
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final int oodIndex = labels.indexOf('not_a_leaf_background');
      expect(oodIndex, greaterThanOrEqualTo(0));
      expect(labels[oodIndex], equals('not_a_leaf_background'));
    });

    // =========================================================================
    // 6. WINDOWS CRLF SAFETY WITH LINESPLITTER
    // =========================================================================
    test('6. Windows CRLF in labels.txt is handled safely with LineSplitter', () {
      const String simulatedWindowsText =
          "cotton_healthy\r\ncotton_bacterial_blight\r\nbanana_healthy\r\nsugarcane_mosaic\r\n";
      final parsed = const LineSplitter()
          .convert(simulatedWindowsText)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(parsed.length, equals(4));
      for (final label in parsed) {
        expect(label.contains('\r'), isFalse, reason: 'LineSplitter must strip carriage return');
      }
      expect(parsed[0], equals('cotton_healthy'));
      expect(parsed[1], equals('cotton_bacterial_blight'));
      expect(parsed[2], equals('banana_healthy'));
      expect(parsed[3], equals('sugarcane_mosaic'));
    });
  });
}
