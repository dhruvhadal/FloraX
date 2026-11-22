import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TFLite Label & Alias Contract Verification', () {
    test('100% of labels.txt classes map cleanly into class_alias_map.json', () {
      final labelsFile = File('assets/models/labels.txt');
      expect(labelsFile.existsSync(), isTrue, reason: 'labels.txt must exist in assets/models/');

      final aliasFile = File('assets/models/class_alias_map.json');
      expect(aliasFile.existsSync(), isTrue, reason: 'class_alias_map.json must exist in assets/models/');

      final rawLabelsText = labelsFile.readAsStringSync();
      // Test with both Windows \r\n and Unix \n normalization
      final rawLabels = const LineSplitter()
          .convert(rawLabelsText)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(rawLabels.length, equals(69), reason: 'Model must have exactly 69 raw output classes');

      final Map<String, dynamic> aliasMap = jsonDecode(aliasFile.readAsStringSync());
      final Set<String> canonicalClasses = {};

      for (int i = 0; i < rawLabels.length; i++) {
        final rawLabel = rawLabels[i];
        expect(aliasMap.containsKey(rawLabel), isTrue,
            reason: 'Raw label [$rawLabel] at index $i must exist as key in class_alias_map.json');

        final canonicalId = aliasMap[rawLabel]?.toString().trim() ?? '';
        expect(canonicalId, isNotEmpty, reason: 'Canonical ID for [$rawLabel] cannot be empty');
        canonicalClasses.add(canonicalId);
      }

      // Assert that canonical classes reduce to 50 distinct diseases/health states
      expect(canonicalClasses.length, equals(50),
          reason: 'Class alias map must consolidate 69 raw classes into exactly 50 canonical classes');
    });

    test('Canonical probability distribution merges duplicate raw classes and sums to 1.0', () {
      final labelsFile = File('assets/models/labels.txt');
      final aliasFile = File('assets/models/class_alias_map.json');

      final rawLabels = const LineSplitter()
          .convert(labelsFile.readAsStringSync())
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final Map<String, dynamic> aliasMap = jsonDecode(aliasFile.readAsStringSync());

      // Create a normalized synthetic probability distribution for 69 classes
      final List<double> rawProbs = List.filled(69, 0.0);
      // Put 80% on Tomato Early Blight (index in labels.txt) and distribute remaining 20%
      final int tomatoIndex = rawLabels.indexWhere((l) => l.contains('Tomato___Early_blight'));
      expect(tomatoIndex, greaterThanOrEqualTo(0));

      rawProbs[tomatoIndex] = 0.80;
      final double remaining = 0.20 / (69 - 1);
      for (int i = 0; i < 69; i++) {
        if (i != tomatoIndex) rawProbs[i] = remaining;
      }

      // Assert raw probs sum to 1.0
      final double rawSum = rawProbs.reduce((a, b) => a + b);
      expect(rawSum, closeTo(1.0, 1e-4));

      // Merge into canonical distribution
      final Map<String, double> canonicalDist = {};
      for (int i = 0; i < rawProbs.length; i++) {
        final rawLabel = rawLabels[i];
        final canonicalId = aliasMap[rawLabel]?.toString().trim() ?? rawLabel;
        canonicalDist[canonicalId] = (canonicalDist[canonicalId] ?? 0.0) + rawProbs[i];
      }

      final double canonicalSum = canonicalDist.values.fold(0.0, (acc, p) => acc + p);
      expect(canonicalSum, closeTo(1.0, 1e-4));

      final sorted = canonicalDist.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      expect(sorted.first.key, equals('tomato_early_blight'));
      expect(sorted.first.value, greaterThanOrEqualTo(0.80));
      expect(sorted.first.value, greaterThanOrEqualTo(0.02),
          reason: 'Top-1 confidence must exceed minimum benchmark threshold');
    });

    test('Windows CRLF in labels.txt does not corrupt alias dictionary lookup', () {
      final aliasFile = File('assets/models/class_alias_map.json');
      final Map<String, dynamic> aliasMap = jsonDecode(aliasFile.readAsStringSync());

      // Simulate a raw string with Windows \r\n line endings
      const String simulatedWindowsText =
          "Apple___Apple_scab\r\nApple___Black_rot\r\nApple___Cedar_apple_rust\r\n";
      final parsed = const LineSplitter()
          .convert(simulatedWindowsText)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (final label in parsed) {
        expect(label.contains('\r'), isFalse, reason: 'LineSplitter + trim must strip carriage return');
        expect(aliasMap.containsKey(label), isTrue,
            reason: 'Cleaned label "$label" must match key in aliasMap');
      }
    });
  });
}
