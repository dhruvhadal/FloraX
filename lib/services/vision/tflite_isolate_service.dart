import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/florax_models.dart';
import 'isolate_lesion_analyzer.dart';

/// Structured inference result returned by the on-device TFLite Isolate Engine
@immutable
class TfliteInferenceResult {
  /// Top 3 classified disease candidates sorted descending by confidence
  final List<DiseasePrediction> topPredictions;

  /// Safety Guardrail: Flagged true if top candidate confidence is < 75%
  final bool requiresKvkReview;

  /// Lifecycle verification status ('AI_VERIFIED' or 'PENDING_KVK_REVIEW')
  final VerificationStatus verificationStatus;

  /// Total inference latency in milliseconds
  final int inferenceDurationMs;

  /// Optional model inference error description (null when successful)
  final String? inferenceError;

  const TfliteInferenceResult({
    required this.topPredictions,
    required this.requiresKvkReview,
    required this.verificationStatus,
    required this.inferenceDurationMs,
    this.inferenceError,
  });
}

/// Principal On-Device TFLite Inference Service
///
/// Executes all tensor operations and quantization decoding off the main UI thread
/// using TFLite's C-bindings `IsolateInterpreter` and background Dart Isolates.
class TfliteIsolateService {
  static const String _modelAsset = AppConfig.modelAssetPath;
  static const String _labelsAsset = AppConfig.labelsAssetPath;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = [];
  Map<String, String> _classAliasMap = {};
  double _oodMinConfidence = AppConfig.oodMinConfidence;
  double _oodMaxNormalizedEntropy = AppConfig.oodMaxNormalizedEntropy;
  bool _isInitialized = false;
  String? _lastInferenceError;

  bool get isReady => _isInitialized && (_interpreter != null || _isolateInterpreter != null);
  String? get lastInferenceError => _lastInferenceError;

  /// Initializes the TFLite runtime, loads the quantized model, and configures the interpreter
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[FloraX TFLite] Loading model asset: $_modelAsset');

      // 1. Configure Interpreter options (threads, hardware acceleration)
      final options = InterpreterOptions()..threads = 4;

      // 2. Load model bytes directly using rootBundle.load with exact offset and length
      // This prevents the famous Android memory-mapped asset offset bug in tflite_flutter
      try {
        final ByteData rawAsset = await rootBundle.load(_modelAsset);
        final Uint8List modelBytes = rawAsset.buffer.asUint8List(
          rawAsset.offsetInBytes,
          rawAsset.lengthInBytes,
        );
        _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
        debugPrint(
          '[FloraX TFLite] Successfully loaded Interpreter.fromBuffer (${modelBytes.length} bytes, address=${_interpreter?.address})',
        );
      } catch (bufferErr, bufferStack) {
        _lastInferenceError = 'fromBuffer failed: $bufferErr';
        debugPrint('[FloraX TFLite ERROR] fromBuffer failed: $bufferErr\n$bufferStack. Trying fromAsset fallback.');
        try {
          _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
          debugPrint('[FloraX TFLite] Successfully loaded Interpreter.fromAsset');
        } catch (assetErr, assetStack) {
          _lastInferenceError = 'Both fromBuffer and fromAsset failed: $assetErr';
          debugPrint('[FloraX TFLite ERROR] Both fromBuffer and fromAsset failed: $assetErr\n$assetStack');
        }
      }

      // Assert & inspect tensor contracts
      if (_interpreter != null) {
        try {
          final inTensor = _interpreter!.getInputTensor(0);
          final outTensor = _interpreter!.getOutputTensor(0);
          debugPrint(
            '[FloraX TFLite] Input Tensor: name=${inTensor.name}, shape=${inTensor.shape}, type=${inTensor.type}',
          );
          debugPrint(
            '[FloraX TFLite] Output Tensor: name=${outTensor.name}, shape=${outTensor.shape}, type=${outTensor.type}',
          );
        } catch (tErr) {
          debugPrint('[FloraX TFLite] Warning inspecting tensor details: $tErr');
        }
      }

      // 3. Spawn IsolateInterpreter for optional isolate execution
      if (_interpreter != null) {
        try {
          _isolateInterpreter = await IsolateInterpreter.create(
            address: _interpreter!.address,
          );
          debugPrint('[FloraX TFLite] IsolateInterpreter created successfully.');
        } catch (isoErr) {
          debugPrint('[FloraX TFLite] Note: IsolateInterpreter create deferred: $isoErr (using direct C++ interpreter)');
        }
      }

      // 4. Load label mappings with robust CRLF normalization
      try {
        final labelsData = await rootBundle.loadString(_labelsAsset);
        _labels = const LineSplitter()
            .convert(labelsData)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        debugPrint('[FloraX TFLite] Loaded ${_labels.length} raw labels from $_labelsAsset');
      } catch (e, st) {
        _lastInferenceError = 'Labels load failed: $e';
        debugPrint('[FloraX TFLite ERROR] Warning: labels asset not loaded: $e\n$st');
      }

      // 5. Load class alias map
      try {
        final aliasData = await rootBundle.loadString(AppConfig.classAliasMapAssetPath);
        final dynamic decoded = jsonDecode(aliasData);
        if (decoded is Map) {
          _classAliasMap = decoded.map((k, v) => MapEntry(k.toString().trim(), v.toString().trim()));
        }
        debugPrint('[FloraX TFLite] Loaded ${_classAliasMap.length} aliases from ${AppConfig.classAliasMapAssetPath}');
      } catch (e, st) {
        _lastInferenceError = 'Alias map load failed: $e';
        debugPrint('[FloraX TFLite ERROR] Warning: class alias map not loaded: $e\n$st');
      }

      // 6. Load model meta
      try {
        final metaData = await rootBundle.loadString(AppConfig.modelMetaAssetPath);
        final dynamic decodedMeta = jsonDecode(metaData);
        if (decodedMeta is Map) {
          if (decodedMeta['ood_min_confidence'] != null) {
            _oodMinConfidence = (decodedMeta['ood_min_confidence'] as num).toDouble();
          }
          if (decodedMeta['ood_max_normalized_entropy'] != null) {
            _oodMaxNormalizedEntropy = (decodedMeta['ood_max_normalized_entropy'] as num).toDouble();
          }
        }
      } catch (e) {
        debugPrint('[FloraX TFLite] Warning: model meta not loaded: $e');
      }

      if (_interpreter != null || _isolateInterpreter != null) {
        _isInitialized = true;
      }
      debugPrint('[FloraX TFLite] Engine initialized. Loaded ${_labels.length} raw labels, ${_classAliasMap.length} aliases.');
    } catch (e, stackTrace) {
      _lastInferenceError = 'Initialization failed: $e';
      debugPrint('[FloraX TFLite ERROR] Initialization failed: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Ergonomic alias classifying leaf image bytes
  Future<TfliteInferenceResult> classifyLeaf(Uint8List imageBytes) =>
      classifyImageBytes(imageBytes);

  /// Classifies raw camera bytes or sanitized JPEG bytes in a background isolate
  Future<TfliteInferenceResult> classifyImageBytes(Uint8List imageBytes) async {
    if (!_isInitialized || (_interpreter == null && _isolateInterpreter == null)) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();

    // 1. Preprocess 224x224 float32 input tensor inside a background isolate
    final List<List<List<List<double>>>> inputTensor = await Isolate.run(() {
      return _preprocessImageTo4DTensor(imageBytes);
    });

    // 2. Prepare output tensor buffer: shape [1, num_classes] (69 raw classes)
    final int numClasses = _labels.isNotEmpty ? _labels.length : 69;
    final outputBuffer = List.generate(
      1,
      (_) => List<double>.filled(numClasses, 0.0),
    );

    // 3. Execute inference:
    // First try direct native C++ interpreter execution (4 threads, ~15ms execution time)
    bool inferenceSuccess = false;
    if (_interpreter != null) {
      try {
        _interpreter!.run(inputTensor, outputBuffer);
        final double rawSum = outputBuffer[0].fold(0.0, (acc, v) => acc + v);
        inferenceSuccess = outputBuffer[0].any((p) => p > 0.0) && rawSum > 0.10;
        if (inferenceSuccess) {
          debugPrint('[FloraX TFLite] Direct C++ interpreter executed successfully. Raw sum: ${rawSum.toStringAsFixed(4)}');
        }
      } catch (directErr, directStack) {
        _lastInferenceError = 'Direct interpreter run error: $directErr';
        debugPrint('[FloraX TFLite ERROR] Direct interpreter run error: $directErr\n$directStack');
      }
    }

    // Secondary fallback: IsolateInterpreter if direct interpreter did not populate output
    if (!inferenceSuccess && _isolateInterpreter != null) {
      try {
        await _isolateInterpreter!.run(inputTensor, outputBuffer);
        final double rawSum = outputBuffer[0].fold(0.0, (acc, v) => acc + v);
        inferenceSuccess = outputBuffer[0].any((p) => p > 0.0) && rawSum > 0.10;
        if (inferenceSuccess) {
          debugPrint('[FloraX TFLite] IsolateInterpreter executed successfully. Raw sum: ${rawSum.toStringAsFixed(4)}');
        }
      } catch (isoErr, isoStack) {
        _lastInferenceError = 'IsolateInterpreter run error: $isoErr';
        debugPrint('[FloraX TFLite ERROR] IsolateInterpreter run error: $isoErr\n$isoStack');
      }
    }

    // 4. Extract raw probabilities
    final List<double> rawProbabilities = outputBuffer[0];
    final double rawProbSum = rawProbabilities.fold(0.0, (acc, p) => acc + p);

    // Print top raw probability before alias mapping via debugPrint
    double maxRawProb = -1.0;
    int maxRawIndex = -1;
    for (int i = 0; i < rawProbabilities.length; i++) {
      if (rawProbabilities[i] > maxRawProb) {
        maxRawProb = rawProbabilities[i];
        maxRawIndex = i;
      }
    }
    final String topRawLabel = (maxRawIndex >= 0 && maxRawIndex < _labels.length)
        ? _labels[maxRawIndex]
        : 'idx_$maxRawIndex';
    debugPrint(
      '[FloraX TFLite] Top raw probability: ${(maxRawProb * 100).toStringAsFixed(2)}% (raw class: $topRawLabel, sum: ${rawProbSum.toStringAsFixed(4)})',
    );

    // Never swallow inference failure silently; return informative error result
    if (!inferenceSuccess || rawProbSum < 0.10) {
      final errorMsg = _lastInferenceError ??
          'AI Model Inference Failure: Model produced flat zero probabilities (raw sum: ${rawProbSum.toStringAsFixed(4)})';
      _lastInferenceError = errorMsg;
      debugPrint('[FloraX TFLite ERROR] $errorMsg');

      return TfliteInferenceResult(
        topPredictions: [
          DiseasePrediction(
            labelId: 'model_inference_error',
            confidence: 0.0,
            scientificName: 'TFLite Model Error',
            category: DiseaseCategory.fungal,
            plainName: 'AI Model Inference Error',
            distinguishingSymptom: errorMsg,
          ),
        ],
        requiresKvkReview: true,
        verificationStatus: VerificationStatus.pendingKvkReview,
        inferenceDurationMs: stopwatch.elapsedMilliseconds,
        inferenceError: errorMsg,
      );
    }

    // Inference succeeded! Clear any prior inference error
    _lastInferenceError = null;

    // 5. Sum probabilities across duplicate raw labels sharing the same canonical ID in class_alias_map.json
    final Map<String, double> canonicalDistribution = {};
    for (int i = 0; i < rawProbabilities.length; i++) {
      final String rawLabel = i < _labels.length ? _labels[i] : 'class_$i';
      final String canonicalId = _classAliasMap[rawLabel] ?? rawLabel;
      canonicalDistribution[canonicalId] = (canonicalDistribution[canonicalId] ?? 0.0) + rawProbabilities[i];
    }

    // Normalize canonical distribution
    final double sumProbs = canonicalDistribution.values.fold(0.0, (acc, p) => acc + p);
    if (sumProbs > 0.0) {
      for (final key in canonicalDistribution.keys) {
        canonicalDistribution[key] = canonicalDistribution[key]! / sumProbs;
      }
    }

    // 6. Compute normalized Shannon entropy H_norm = -sum(p * ln(p)) / ln(K)
    final int k = canonicalDistribution.length > 1 ? canonicalDistribution.length : 50;
    final double lnK = math.log(k);
    double shannonEntropy = 0.0;
    for (final p in canonicalDistribution.values) {
      if (p > 1e-12) {
        shannonEntropy -= p * math.log(p);
      }
    }
    final double normalizedEntropy = lnK > 0 ? (shannonEntropy / lnK) : 0.0;

    // 7. Sort canonical classes descending by merged probability
    final List<MapEntry<String, double>> sortedCanonical = canonicalDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double top1Confidence = sortedCanonical.isNotEmpty ? sortedCanonical.first.value : 0.0;

    // 8. Out-Of-Distribution (OOD) Guardrail:
    // Determine if prediction distribution is excessively flat (high entropy) or low confidence.
    final bool isOod = top1Confidence < _oodMinConfidence || normalizedEntropy > _oodMaxNormalizedEntropy;
    if (isOod) {
      debugPrint(
        '[FloraX TFLite] OOD Flagged: '
        'top1Conf=${(top1Confidence * 100).toStringAsFixed(1)}% (<${(_oodMinConfidence * 100).toStringAsFixed(0)}%) '
        'OR normEntropy=${normalizedEntropy.toStringAsFixed(3)} (>${_oodMaxNormalizedEntropy.toStringAsFixed(2)}). '
        'Preserving model predictions and routing to mandatory KVK scientist review.',
      );
    }

    final List<DiseasePrediction> top3 = [];
    final int topK = math.min(3, sortedCanonical.length);
    for (int i = 0; i < topK; i++) {
      final entry = sortedCanonical[i];
      final double confidence = double.parse(entry.value.clamp(0.0, 1.0).toStringAsFixed(4));
      final meta = _resolvePathologyMetadata(entry.key);
      top3.add(
        DiseasePrediction(
          labelId: entry.key,
          confidence: confidence,
          scientificName: meta.scientificName,
          category: meta.category,
          plainName: meta.plainName,
          distinguishingSymptom: meta.distinguishingSymptom,
        ),
      );
    }

    stopwatch.stop();

    // 9. Safety Guardrail: Flag KVK expert review if top candidate confidence is < 75% or OOD
    final double topConfidence = top3.isNotEmpty ? top3.first.confidence : 0.0;
    final bool requiresKvkReview = isOod ||
        topConfidence < AppConfig.kvkConfidenceThreshold;
    final VerificationStatus verificationStatus = requiresKvkReview
        ? VerificationStatus.pendingKvkReview
        : VerificationStatus.aiVerified;

    return TfliteInferenceResult(
      topPredictions: top3,
      requiresKvkReview: requiresKvkReview,
      verificationStatus: verificationStatus,
      inferenceDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Feature #1 & #2: Multi-Region Disease Detection & Abiotic Nutrient vs. Infection Differentiation
  ///
  /// Runs IsolateInterpreter on the full leaf AND independently on each cropped ROI patch,
  /// determining Top-3 predictions, confidence scores, and differential visual explanations.
  Future<List<LeafRegionDiagnosis>> classifyMultiRegion({
    required Uint8List fullLeafBytes,
    required List<RoiCropPatch> roiPatches,
  }) async {
    if (!_isInitialized || (_interpreter == null && _isolateInterpreter == null)) {
      await initialize();
    }

    final List<LeafRegionDiagnosis> diagnoses = [];

    // 1. Primary Full Leaf Classification
    final fullLeafResult = await classifyImageBytes(fullLeafBytes);
    final primaryPrediction = fullLeafResult.topPredictions.isNotEmpty
        ? fullLeafResult.topPredictions.first
        : const DiseasePrediction(
            labelId: 'unknown',
            confidence: 0.0,
            scientificName: 'Unknown Foliage',
            category: DiseaseCategory.fungal,
          );

    final secondaryPredictions = fullLeafResult.topPredictions.length > 1
        ? fullLeafResult.topPredictions.sublist(1)
        : <DiseasePrediction>[];

    final bool isAbiotic = _isAbioticDeficiency(primaryPrediction.labelId, primaryPrediction.category);
    final fullLeafExplanation = _generateSymptomExplanation(
      labelId: primaryPrediction.labelId,
      scientificName: primaryPrediction.scientificName,
      isAbiotic: isAbiotic,
      category: primaryPrediction.category,
      regionName: 'Full Leaf Blade',
    );

    diagnoses.add(
      LeafRegionDiagnosis(
        regionId: 'region_full',
        boundingBoxNormalized: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
        primaryPrediction: primaryPrediction,
        secondaryPredictions: secondaryPredictions,
        visualSymptomExplanation: fullLeafExplanation,
        isEarlyStageSubtle: false,
      ),
    );

    // 2. Independent Classification of each Cropped Connected-Component ROI Patch
    for (int i = 0; i < roiPatches.length; i++) {
      final patch = roiPatches[i];
      final patchResult = await classifyImageBytes(patch.imageBytes);

      final patchPrimary = patchResult.topPredictions.isNotEmpty
          ? patchResult.topPredictions.first
          : primaryPrediction;

      final patchSecondaries = patchResult.topPredictions.length > 1
          ? patchResult.topPredictions.sublist(1)
          : <DiseasePrediction>[];

      final bool patchIsAbiotic = _isAbioticDeficiency(patchPrimary.labelId, patchPrimary.category);
      final patchExplanation = _generateSymptomExplanation(
        labelId: patchPrimary.labelId,
        scientificName: patchPrimary.scientificName,
        isAbiotic: patchIsAbiotic,
        category: patchPrimary.category,
        regionName: 'Foliar Sub-Region #${i + 1}',
      );

      diagnoses.add(
        LeafRegionDiagnosis(
          regionId: patch.regionId,
          boundingBoxNormalized: patch.boundingBoxNormalized,
          primaryPrediction: patchPrimary,
          secondaryPredictions: patchSecondaries,
          visualSymptomExplanation: patchExplanation,
          isEarlyStageSubtle: patch.isSubtleEarlyStage,
        ),
      );
    }

    return diagnoses;
  }

  /// Feature #2: Differentiation logic for Abiotic Nutrient Deficiency vs. Infectious Pathogen
  static bool _isAbioticDeficiency(String labelId, DiseaseCategory category) {
    if (category == DiseaseCategory.nutrient) return true;
    final lower = labelId.toLowerCase();
    return lower.startsWith('abiotic_') ||
        lower.contains('deficiency') ||
        lower.contains('chlorosis') ||
        lower.contains('scorch');
  }

  /// Feature #2: Generates trilingual diagnostic explanations distinguishing abiotic vs biotic signs
  static Map<String, String> _generateSymptomExplanation({
    required String labelId,
    required String scientificName,
    required bool isAbiotic,
    required DiseaseCategory category,
    required String regionName,
  }) {
    if (labelId == 'not_a_leaf_background') {
      return {
        'en': '$regionName: Non-Crop Surface. No foliar tissue or active pathology detected.',
        'hi': '$regionName: फसल की पत्ती नहीं है। कोई रोग लक्षण नहीं मिला।',
        'mr': '$regionName: पिकाचे पान नाही. कोणतेही रोगाचे लक्षण आढळले नाही.',
      };
    } else if (isAbiotic) {
      return {
        'en': '$regionName: Abiotic Nutrient Deficiency ($scientificName). Interveinal chlorosis or marginal leaf scorch without active fungal pathogen fruiting bodies.',
        'hi': '$regionName: अजैविक पोषक तत्वों की कमी ($scientificName)। फंगल बीजाणुओं के बिना नसों के बीच पीलापन या पत्तियों के किनारों का झुलसना।',
        'mr': '$regionName: अजैविक पोषणद्रव्यांची कमतरता ($scientificName). बुरशीजन्य बीजाणूंशिवाय पानांच्या शिरांमधील पिवळेपणा किंवा कडा करपणे.',
      };
    } else if (category == DiseaseCategory.healthy) {
      return {
        'en': '$regionName: Optimal Foliar Health ($scientificName). Normal chlorophyll pigmentation with zero necrotic spots or chlorotic halos.',
        'hi': '$regionName: उत्तम पत्ती स्वास्थ्य ($scientificName)। बिना किसी घाव के सामान्य क्लोरोफिल रंगद्रव्य।',
        'mr': '$regionName: पिकाचे उत्तम आरोग्य ($scientificName). कोणत्याही डागांशिवाय सामान्य हरितद्रव्य.',
      };
    } else {
      return {
        'en': '$regionName: Infectious Pathology ($scientificName - ${category.name.toUpperCase()}). Pathogen lesion activity displaying active concentric margins or viral leaf curl.',
        'hi': '$regionName: संक्रामक रोग ($scientificName - ${category.name.toUpperCase()})। संक्रामक रोगजनक घाव जो सक्रिय छल्ले या पत्ती के मुड़ने को प्रदर्शित करते हैं।',
        'mr': '$regionName: संसर्गजन्य रोग ($scientificName - ${category.name.toUpperCase()}). सक्रिय डाग, बुरशीचे थर किंवा विषाणूजन्य पानांचा चुरमुरणे दर्शविणारे लक्षण.',
      };
    }
  }

  /// Converts image bytes into a normalized 4D tensor `[1, 224, 224, 3]`
  static List<List<List<List<double>>>> _preprocessImageTo4DTensor(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Failed to decode image for TFLite preprocessing.');
    }

    // Resize strictly to MobileNetV3 standard input dimension (224x224)
    final img.Image resized = img.copyResize(
      decoded,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );

    // Build float32 buffer [1, 224, 224, 3] with [0.0 - 255.0] range expected by MobileNetV3 preprocess_input
    final List<List<List<double>>> imageGrid = List.generate(
      224,
      (y) => List.generate(
        224,
        (x) {
          final p = resized.getPixel(x, y);
          return [
            p.r.toDouble(),
            p.g.toDouble(),
            p.b.toDouble(),
          ];
        },
      ),
    );

    return [imageGrid];
  }

  /// Resolves scientific taxonomy, plain name, and distinguishing symptom based on canonical label ID
  static _PathologyMeta _resolvePathologyMetadata(String labelId) {
    switch (labelId.toLowerCase().trim()) {
      // Background / Non-Leaf
      case 'not_a_leaf_background':
        return const _PathologyMeta(
          scientificName: 'Non-Biological Foliage Object',
          category: DiseaseCategory.healthy,
          plainName: 'Non-Leaf Object',
          distinguishingSymptom: 'Frame does not contain recognisable crop foliage.',
        );

      // Abiotic Nutrient Deficiencies
      case 'abiotic_magnesium_deficiency':
        return const _PathologyMeta(
          scientificName: 'Physiological Chlorosis (Mg)',
          category: DiseaseCategory.nutrient,
          plainName: 'Magnesium Deficiency',
          distinguishingSymptom: 'Interveinal yellowing with veins staying green on older lower leaves.',
        );
      case 'abiotic_nitrogen_deficiency':
        return const _PathologyMeta(
          scientificName: 'General Foliar Nitrogen Chlorosis',
          category: DiseaseCategory.nutrient,
          plainName: 'Nitrogen Deficiency',
          distinguishingSymptom: 'Uniform pale yellowing progressing from bottom older leaves upwards.',
        );
      case 'abiotic_potassium_deficiency':
        return const _PathologyMeta(
          scientificName: 'Marginal Foliar Potassium Scorch',
          category: DiseaseCategory.nutrient,
          plainName: 'Potassium Deficiency',
          distinguishingSymptom: 'Marginal leaf scorch, tip burn, and necrosis along leaf outer edges.',
        );

      // Paddy / Rice
      case 'paddy_leaf_blast':
        return const _PathologyMeta(
          scientificName: 'Magnaporthe oryzae',
          category: DiseaseCategory.fungal,
          plainName: 'Rice Leaf Blast',
          distinguishingSymptom: 'Spindle-shaped elliptical lesions with gray centers and dark brown borders.',
        );
      case 'paddy_neck_blast':
        return const _PathologyMeta(
          scientificName: 'Magnaporthe oryzae (Neck Blast)',
          category: DiseaseCategory.fungal,
          plainName: 'Rice Neck Blast',
          distinguishingSymptom: 'Dark necrotic girdling at panicle base causing blank, chaffy grains.',
        );
      case 'paddy_bacterial_blight':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas oryzae pv. oryzae',
          category: DiseaseCategory.bacterial,
          plainName: 'Rice Bacterial Leaf Blight',
          distinguishingSymptom: 'Wavy yellowish-white water-soaked stripes running down leaf margins.',
        );
      case 'paddy_brown_spot':
        return const _PathologyMeta(
          scientificName: 'Bipolaris oryzae',
          category: DiseaseCategory.fungal,
          plainName: 'Rice Brown Spot',
          distinguishingSymptom: 'Small oval to circular dark brown spots resembling sesame seeds.',
        );
      case 'paddy_tungro':
        return const _PathologyMeta(
          scientificName: 'Rice Tungro Spherical/Bacilliform Virus',
          category: DiseaseCategory.viral,
          plainName: 'Rice Tungro Virus',
          distinguishingSymptom: 'Vibrant orange-yellow leaf discoloration starting from tips with stunted tillering.',
        );
      case 'paddy_healthy':
        return const _PathologyMeta(
          scientificName: 'Oryza sativa (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Rice Healthy Foliage',
          distinguishingSymptom: 'Uniform green erect tillers without necrotic borders or margins.',
        );

      // Sugarcane
      case 'sugarcane_red_rot':
        return const _PathologyMeta(
          scientificName: 'Colletotrichum falcatum',
          category: DiseaseCategory.fungal,
          plainName: 'Sugarcane Red Rot',
          distinguishingSymptom: 'Red lesions with white cross patches along midrib and stalk rotting.',
        );
      case 'sugarcane_bacterial_blight':
        return const _PathologyMeta(
          scientificName: 'Acidovorax avenae subsp. avenae',
          category: DiseaseCategory.bacterial,
          plainName: 'Sugarcane Bacterial Blight',
          distinguishingSymptom: 'Reddish-brown narrow stripes on leaf blade that rapidly coalesce.',
        );
      case 'sugarcane_healthy':
        return const _PathologyMeta(
          scientificName: 'Saccharum officinarum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Sugarcane Healthy Foliage',
          distinguishingSymptom: 'Long intact green foliage without red midrib streaks or stripes.',
        );

      // Wheat
      case 'wheat_yellow_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia striiformis',
          category: DiseaseCategory.fungal,
          plainName: 'Wheat Yellow (Stripe) Rust',
          distinguishingSymptom: 'Bright yellow powdery pustules arranged in parallel linear stripes.',
        );
      case 'wheat_brown_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia triticina',
          category: DiseaseCategory.fungal,
          plainName: 'Wheat Brown (Leaf) Rust',
          distinguishingSymptom: 'Round orange-brown pustules scattered randomly on upper leaf surface.',
        );
      case 'wheat_healthy':
        return const _PathologyMeta(
          scientificName: 'Triticum aestivum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Wheat Healthy Foliage',
          distinguishingSymptom: 'Uniform emerald green blades with intact veins and no rust pustules.',
        );

      // Tomato
      case 'tomato_early_blight':
        return const _PathologyMeta(
          scientificName: 'Alternaria solani',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Early Blight',
          distinguishingSymptom: 'Dark brown rings like a bullseye target on older leaves.',
        );
      case 'tomato_late_blight':
        return const _PathologyMeta(
          scientificName: 'Phytophthora infestans',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Late Blight',
          distinguishingSymptom: 'Water-soaked dark lesions with white mold on underside in humid air.',
        );
      case 'tomato_septoria_leaf_spot':
        return const _PathologyMeta(
          scientificName: 'Septoria lycopersici',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Septoria Leaf Spot',
          distinguishingSymptom: 'Many tiny circular spots with dark brown margins and pale grey centers.',
        );
      case 'tomato_bacterial_spot':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas perforans',
          category: DiseaseCategory.bacterial,
          plainName: 'Tomato Bacterial Spot',
          distinguishingSymptom: 'Small water-soaked dark spots with yellow chlorotic halos.',
        );
      case 'tomato_leaf_mold':
        return const _PathologyMeta(
          scientificName: 'Passalora fulva',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Leaf Mold',
          distinguishingSymptom: 'Pale yellow spots on upper leaf surface, olive-green velvety mold below.',
        );
      case 'tomato_yellow_leaf_curl_virus':
        return const _PathologyMeta(
          scientificName: 'Tomato yellow leaf curl virus (TYLCV)',
          category: DiseaseCategory.viral,
          plainName: 'Tomato Yellow Leaf Curl Virus',
          distinguishingSymptom: 'Severe upward leaf curling, cupping, yellow margins, and stunted growth.',
        );
      case 'tomato_mosaic_virus':
        return const _PathologyMeta(
          scientificName: 'Tomato mosaic virus (ToMV)',
          category: DiseaseCategory.viral,
          plainName: 'Tomato Mosaic Virus',
          distinguishingSymptom: 'Mottled alternating dark and light green mosaic pattern with distorted leaflets.',
        );
      case 'tomato_spider_mites':
        return const _PathologyMeta(
          scientificName: 'Tetranychus urticae',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Spider Mites',
          distinguishingSymptom: 'Fine yellow-white stippling on leaf surface with fine webbing underneath.',
        );
      case 'tomato_target_spot':
        return const _PathologyMeta(
          scientificName: 'Corynespora cassiicola',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Target Spot',
          distinguishingSymptom: 'Brown lesions with concentric rings and distinct yellow chlorotic halos.',
        );
      case 'tomato_healthy':
        return const _PathologyMeta(
          scientificName: 'Solanum lycopersicum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Tomato Healthy Foliage',
          distinguishingSymptom: 'Uniform vibrant green leaf blade with no lesions or spots.',
        );

      // Potato
      case 'potato_early_blight':
        return const _PathologyMeta(
          scientificName: 'Alternaria solani',
          category: DiseaseCategory.fungal,
          plainName: 'Potato Early Blight',
          distinguishingSymptom: 'Concentric dark target-board rings on lower potato leaves.',
        );
      case 'potato_late_blight':
        return const _PathologyMeta(
          scientificName: 'Phytophthora infestans',
          category: DiseaseCategory.fungal,
          plainName: 'Potato Late Blight',
          distinguishingSymptom: 'Rapid water-soaked lesions turning dark brown with white fuzz in damp conditions.',
        );
      case 'potato_healthy':
        return const _PathologyMeta(
          scientificName: 'Solanum tuberosum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Potato Healthy Foliage',
          distinguishingSymptom: 'Smooth intact green leaf blade without brown or black spots.',
        );

      // Corn / Maize
      case 'corn_common_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia sorghi',
          category: DiseaseCategory.fungal,
          plainName: 'Corn Common Rust',
          distinguishingSymptom: 'Golden-brown to cinnamon raised pustules scattered on both leaf surfaces.',
        );
      case 'corn_northern_leaf_blight':
        return const _PathologyMeta(
          scientificName: 'Exserohilum turcicum',
          category: DiseaseCategory.fungal,
          plainName: 'Corn Northern Leaf Blight',
          distinguishingSymptom: 'Long elliptical cigar-shaped grayish-green to tan lesions.',
        );
      case 'corn_gray_leaf_spot':
        return const _PathologyMeta(
          scientificName: 'Cercospora zeae-maydis',
          category: DiseaseCategory.fungal,
          plainName: 'Corn Gray Leaf Spot',
          distinguishingSymptom: 'Rectangular blocky lesions strictly delimited by parallel leaf veins.',
        );
      case 'corn_healthy':
        return const _PathologyMeta(
          scientificName: 'Zea mays (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Corn Healthy Foliage',
          distinguishingSymptom: 'Vibrant elongated green leaves with clear longitudinal venation.',
        );

      // Grape
      case 'grape_black_rot':
        return const _PathologyMeta(
          scientificName: 'Guignardia bidwellii',
          category: DiseaseCategory.fungal,
          plainName: 'Grape Black Rot',
          distinguishingSymptom: 'Small reddish-brown circular spots on leaves with tiny black pycnidia.',
        );
      case 'grape_esca_black_measles':
        return const _PathologyMeta(
          scientificName: 'Phaeomoniella chlamydospora',
          category: DiseaseCategory.fungal,
          plainName: 'Grape Esca (Black Measles)',
          distinguishingSymptom: 'Tiger-stripe interveinal necrosis with dried berry shriveling.',
        );
      case 'grape_leaf_blight_isariopsis_leaf_spot':
        return const _PathologyMeta(
          scientificName: 'Pseudocercospora cladosporioides',
          category: DiseaseCategory.fungal,
          plainName: 'Grape Leaf Blight',
          distinguishingSymptom: 'Irregular brown necrotic lesions on leaves leading to defoliation.',
        );
      case 'grape_healthy':
        return const _PathologyMeta(
          scientificName: 'Vitis vinifera (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Grape Healthy Foliage',
          distinguishingSymptom: 'Broad palmately lobed green leaves without necrotic margins or spots.',
        );

      // Bell Pepper
      case 'pepper_bell_bacterial_spot':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas campestris pv. vesicatoria',
          category: DiseaseCategory.bacterial,
          plainName: 'Pepper Bacterial Spot',
          distinguishingSymptom: 'Small water-soaked circular to irregular dark spots on leaves.',
        );
      case 'pepper_bell_healthy':
        return const _PathologyMeta(
          scientificName: 'Capsicum annuum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Pepper Healthy Foliage',
          distinguishingSymptom: 'Glossy smooth green leaves with unbroken margins.',
        );

      // Cotton
      case 'cotton_leaf_curl':
        return const _PathologyMeta(
          scientificName: 'Begomovirus (CLCuV)',
          category: DiseaseCategory.viral,
          plainName: 'Cotton Leaf Curl Virus',
          distinguishingSymptom: 'Upward or downward leaf curling, vein thickening, and enations on leaf underside.',
        );

      // Apple
      case 'apple_scab':
        return const _PathologyMeta(
          scientificName: 'Venturia inaequalis',
          category: DiseaseCategory.fungal,
          plainName: 'Apple Scab',
          distinguishingSymptom: 'Velvety olive-green to black spots with feathery margins on leaf surface.',
        );
      case 'apple_black_rot':
        return const _PathologyMeta(
          scientificName: 'Botryosphaeria obtusa',
          category: DiseaseCategory.fungal,
          plainName: 'Apple Black Rot',
          distinguishingSymptom: 'Frogeye leaf spots with purple margins and brown centers.',
        );
      case 'apple_cedar_rust':
        return const _PathologyMeta(
          scientificName: 'Gymnosporangium juniperi-virginianae',
          category: DiseaseCategory.fungal,
          plainName: 'Apple Cedar Rust',
          distinguishingSymptom: 'Bright yellow-orange spots on upper leaf with tube-like aecia beneath.',
        );
      case 'apple_healthy':
        return const _PathologyMeta(
          scientificName: 'Malus domestica (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Apple Healthy Foliage',
          distinguishingSymptom: 'Clean green serrated leaves with no rust or scab lesions.',
        );

      // Blueberry
      case 'blueberry_healthy':
        return const _PathologyMeta(
          scientificName: 'Vaccinium corymbosum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Blueberry Healthy Foliage',
          distinguishingSymptom: 'Glossy intact foliage with no spotting or chlorosis.',
        );

      // Cherry
      case 'cherry_including_sour_powdery_mildew':
        return const _PathologyMeta(
          scientificName: 'Podosphaera clandestina',
          category: DiseaseCategory.fungal,
          plainName: 'Cherry Powdery Mildew',
          distinguishingSymptom: 'White talcum-like powdery fungal patches on new leaf growth.',
        );
      case 'cherry_including_sour_healthy':
        return const _PathologyMeta(
          scientificName: 'Prunus cerasus (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Cherry Healthy Foliage',
          distinguishingSymptom: 'Smooth dark green leaves with uniform surface texture.',
        );

      // Orange
      case 'orange_haunglongbing_citrus_greening':
        return const _PathologyMeta(
          scientificName: 'Candidatus Liberibacter asiaticus',
          category: DiseaseCategory.bacterial,
          plainName: 'Citrus Greening (HLB)',
          distinguishingSymptom: 'Asymmetrical blotchy mottle chlorosis crossing leaf veins unevenly.',
        );

      // Peach
      case 'peach_bacterial_spot':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas arboricola pv. pruni',
          category: DiseaseCategory.bacterial,
          plainName: 'Peach Bacterial Spot',
          distinguishingSymptom: 'Angular water-soaked spots on leaves that drop out, giving a shot-hole appearance.',
        );
      case 'peach_healthy':
        return const _PathologyMeta(
          scientificName: 'Prunus persica (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Peach Healthy Foliage',
          distinguishingSymptom: 'Slender green lanceolate leaves with smooth unblemished margins.',
        );

      // Raspberry
      case 'raspberry_healthy':
        return const _PathologyMeta(
          scientificName: 'Rubus idaeus (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Raspberry Healthy Foliage',
          distinguishingSymptom: 'Compound green serrated leaflets without necrotic edges.',
        );

      // Soybean
      case 'soybean_healthy':
        return const _PathologyMeta(
          scientificName: 'Glycine max (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Soybean Healthy Foliage',
          distinguishingSymptom: 'Trifoliate clean green leaves with no bacterial pustules or rust.',
        );

      // Squash
      case 'squash_powdery_mildew':
        return const _PathologyMeta(
          scientificName: 'Podosphaera xanthii',
          category: DiseaseCategory.fungal,
          plainName: 'Squash Powdery Mildew',
          distinguishingSymptom: 'White talcum-like powdery growth spreading across broad leaf surface.',
        );

      // Strawberry
      case 'strawberry_leaf_scorch':
        return const _PathologyMeta(
          scientificName: 'Diplocarpon earlianum',
          category: DiseaseCategory.fungal,
          plainName: 'Strawberry Leaf Scorch',
          distinguishingSymptom: 'Dark purple to brown blotches without the white centers of leaf spot.',
        );
      case 'strawberry_healthy':
        return const _PathologyMeta(
          scientificName: 'Fragaria ananassa (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Strawberry Healthy Foliage',
          distinguishingSymptom: 'Trifoliate healthy green leaves with crisp serrated edges.',
        );

      default:
        final lower = labelId.toLowerCase();
        final DiseaseCategory cat;
        final String symptom;
        if (lower.contains('healthy')) {
          cat = DiseaseCategory.healthy;
          symptom = 'Uniform green foliage with zero active lesions or pathogen symptoms.';
        } else if (lower.contains('bacterial')) {
          cat = DiseaseCategory.bacterial;
          symptom = 'Water-soaked translucent lesions often bounded by leaf vein margins.';
        } else if (lower.contains('virus') || lower.contains('curl') || lower.contains('mosaic') || lower.contains('tungro')) {
          cat = DiseaseCategory.viral;
          symptom = 'Leaf curling, mosaic mottling, and vein clearing with stunted foliage.';
        } else if (lower.startsWith('abiotic_') || lower.contains('deficiency') || lower.contains('chlorosis')) {
          cat = DiseaseCategory.nutrient;
          symptom = 'Uniform interveinal or blade-wide chlorosis without fungal rings.';
        } else {
          cat = DiseaseCategory.fungal;
          symptom = 'Discrete necrotic lesions with fungal margins on leaf blade.';
        }
        final plain = labelId
            .split('_')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
        return _PathologyMeta(
          scientificName: labelId.replaceAll('_', ' '),
          category: cat,
          plainName: plain,
          distinguishingSymptom: symptom,
        );
    }
  }

  /// Closes and releases native memory handles
  Future<void> dispose() async {
    _isolateInterpreter?.close();
    _interpreter?.close();
    _isolateInterpreter = null;
    _interpreter = null;
    _isInitialized = false;
  }
}

class _PathologyMeta {
  final String scientificName;
  final DiseaseCategory category;
  final String plainName;
  final String distinguishingSymptom;

  const _PathologyMeta({
    required this.scientificName,
    required this.category,
    this.plainName = '',
    this.distinguishingSymptom = '',
  });
}

/// Global Riverpod Provider for TFLite Isolate Service
final tfliteIsolateServiceProvider = Provider<TfliteIsolateService>((ref) {
  final service = TfliteIsolateService();
  ref.onDispose(() => service.dispose());
  return service;
});
