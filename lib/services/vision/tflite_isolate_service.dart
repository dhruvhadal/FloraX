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
  /// Top classified disease candidates sorted descending by confidence
  final List<DiseasePrediction> topPredictions;

  /// Safety Guardrail: Flagged true if top candidate confidence is < 75% or OOD
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

/// Principal Dynamic Metadata-Driven EdgeLiteRT / TFLite Inference Service
///
/// Dynamically reads `assets/models/model_meta.json` at initialization to detect
/// `.tflite` model filename, input tensor shape ([1, 224, 224, 3] or [1, 300, 300, 3]),
/// number of classes (45), and clinical OOD thresholds.
///
/// Executes 2-View Test-Time Augmentation (TTA) and maps indices directly to `labels.txt`.
class TfliteIsolateService {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = [];

  // Metadata-driven parameters (defaults dynamically overwritten by model_meta.json)
  String _modelVersion = 'florax_v2_45c_efficientnetv2b0';
  String _modelFilename = 'florax_v2_45c_fp16.tflite';
  List<int> _inputShape = [1, 224, 224, 3];
  int _inputWidth = 224;
  int _inputHeight = 224;
  int _inputChannels = 3;
  int _numClasses = 45;
  double _oodMinConfidence = 0.45;
  double _oodMaxNormalizedEntropy = 0.65;
  double _clinicalChemicalLockThreshold = 0.75;

  bool _isInitialized = false;
  String? _lastInferenceError;

  bool get isReady => _isInitialized && (_interpreter != null || _isolateInterpreter != null);
  String? get lastInferenceError => _lastInferenceError;
  String get modelVersion => _modelVersion;
  List<int> get inputShape => List.unmodifiable(_inputShape);
  int get inputChannels => _inputChannels;
  int get numClasses => _numClasses;
  double get clinicalChemicalLockThreshold => _clinicalChemicalLockThreshold;

  /// Initializes the runtime via dynamic metadata, loading bytes on the main isolate
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[FloraX TFLite] Initializing Dynamic 45-Class EdgeLiteRT Engine...');

      // 1. Load model_meta.json dynamically first
      try {
        final metaData = await rootBundle.loadString(AppConfig.modelMetaAssetPath);
        final dynamic decodedMeta = jsonDecode(metaData);
        if (decodedMeta is Map) {
          if (decodedMeta['model_version'] != null) {
            _modelVersion = decodedMeta['model_version'].toString();
          }
          if (decodedMeta['model_file'] != null) {
            _modelFilename = decodedMeta['model_file'].toString();
          } else if (decodedMeta['model_version'] != null) {
            _modelFilename = '${decodedMeta['model_version']}.tflite';
          }

          if (decodedMeta['input_shape'] is List) {
            final shapeList = (decodedMeta['input_shape'] as List).map((e) => (e as num).toInt()).toList();
            if (shapeList.length == 4) {
              _inputShape = shapeList;
              _inputHeight = shapeList[1];
              _inputWidth = shapeList[2];
              _inputChannels = shapeList[3];
            }
          }

          if (decodedMeta['num_classes'] is num) {
            _numClasses = (decodedMeta['num_classes'] as num).toInt();
          }
          if (decodedMeta['ood_min_confidence'] is num) {
            _oodMinConfidence = (decodedMeta['ood_min_confidence'] as num).toDouble();
          }
          if (decodedMeta['ood_max_normalized_entropy'] is num) {
            _oodMaxNormalizedEntropy = (decodedMeta['ood_max_normalized_entropy'] as num).toDouble();
          }
          if (decodedMeta['clinical_chemical_lock_threshold'] is num) {
            _clinicalChemicalLockThreshold = (decodedMeta['clinical_chemical_lock_threshold'] as num).toDouble();
          }
        }
        debugPrint(
          '[FloraX TFLite] Metadata detected: model=$_modelVersion, file=$_modelFilename, '
          'shape=$_inputShape, classes=$_numClasses, oodMinConf=$_oodMinConfidence',
        );
      } catch (metaErr) {
        debugPrint('[FloraX TFLite WARNING] Could not parse model_meta.json ($metaErr). Using default v2 configuration.');
      }

      // 2. Load labels with robust LineSplitter (stripping Windows \r\n endings)
      try {
        final labelsData = await rootBundle.loadString(AppConfig.labelsAssetPath);
        _labels = const LineSplitter()
            .convert(labelsData)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (_labels.isNotEmpty) {
          _numClasses = _labels.length;
        }
        debugPrint('[FloraX TFLite] Loaded ${_labels.length} canonical labels from ${AppConfig.labelsAssetPath}');
      } catch (labelErr, labelStack) {
        _lastInferenceError = 'Labels load failed: $labelErr';
        debugPrint('[FloraX TFLite ERROR] Labels asset not loaded: $labelErr\n$labelStack');
        rethrow;
      }

      // 3. Configure Interpreter options (4 CPU threads)
      final options = InterpreterOptions()..threads = 4;

      // 4. Load .tflite bytes on the main isolate via rootBundle.load
      // Never call Interpreter.fromAsset inside an isolate.
      final String modelAssetPath = _modelFilename.startsWith('assets/')
          ? _modelFilename
          : 'assets/models/$_modelFilename';
      debugPrint('[FloraX TFLite] Loading model bytes from rootBundle: $modelAssetPath');

      final ByteData rawAsset = await rootBundle.load(modelAssetPath);
      final Uint8List modelBytes = rawAsset.buffer.asUint8List(
        rawAsset.offsetInBytes,
        rawAsset.lengthInBytes,
      );

      _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      debugPrint(
        '[FloraX TFLite] Successfully instantiated Interpreter.fromBuffer (${modelBytes.length} bytes, address=${_interpreter?.address})',
      );

      // Verify tensor contract
      try {
        final inTensor = _interpreter!.getInputTensor(0);
        final outTensor = _interpreter!.getOutputTensor(0);
        debugPrint(
          '[FloraX TFLite] Verified Tensor Contract: In=${inTensor.shape} (${inTensor.type}) -> Out=${outTensor.shape} (${outTensor.type})',
        );
      } catch (tErr) {
        debugPrint('[FloraX TFLite] Note verifying tensor shapes: $tErr');
      }

      // 5. Optionally spawn IsolateInterpreter from address on main isolate
      try {
        _isolateInterpreter = await IsolateInterpreter.create(
          address: _interpreter!.address,
        );
        debugPrint('[FloraX TFLite] IsolateInterpreter created successfully.');
      } catch (isoErr) {
        debugPrint('[FloraX TFLite] Note: IsolateInterpreter fallback to direct C++ interpreter: $isoErr');
      }

      _isInitialized = true;
      debugPrint(
        '[FloraX TFLite] 45-Class Engine Ready. Model=$_modelVersion, Shape=$_inputShape, Classes=$_numClasses',
      );
    } catch (e, stackTrace) {
      _lastInferenceError = 'Initialization failed: $e';
      debugPrint('[FloraX TFLite ERROR] Initialization failed: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Ergonomic alias classifying leaf image bytes
  Future<TfliteInferenceResult> classifyLeaf(Uint8List imageBytes) =>
      classifyImageBytes(imageBytes);

  /// Executes on-device inference with 2-View Test-Time Augmentation (TTA)
  ///
  /// View 1: Original image preprocessed to `[1, H, W, 3]` float32 in `[0.0, 255.0]`
  /// View 2: Horizontally flipped image preprocessed identically
  /// Averages prediction probability distributions and directly maps index `i` to `_labels[i]`.
  Future<TfliteInferenceResult> classifyImageBytes(Uint8List imageBytes) async {
    if (!_isInitialized || (_interpreter == null && _isolateInterpreter == null)) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();

    // 1. Run 2-View TTA preprocessing in background isolate (float32 [0.0, 255.0] RGB)
    final int width = _inputWidth;
    final int height = _inputHeight;
    final ttaPair = await Isolate.run(() {
      return _preprocessImageTtaPair(imageBytes, width, height);
    });

    final inputOriginal = ttaPair.item1;
    final inputFlipped = ttaPair.item2;

    // 2. Prepare output buffers [1, num_classes]
    final int classesCount = _numClasses > 0 ? _numClasses : (_labels.isNotEmpty ? _labels.length : 45);
    final outputOriginal = List.generate(1, (_) => List<double>.filled(classesCount, 0.0));
    final outputFlipped = List.generate(1, (_) => List<double>.filled(classesCount, 0.0));

    // 3. Execute inference for both views
    try {
      if (_interpreter != null) {
        _interpreter!.run(inputOriginal, outputOriginal);
        _interpreter!.run(inputFlipped, outputFlipped);
      } else if (_isolateInterpreter != null) {
        await _isolateInterpreter!.run(inputOriginal, outputOriginal);
        await _isolateInterpreter!.run(inputFlipped, outputFlipped);
      } else {
        throw StateError('Interpreter is null despite initialization');
      }
    } catch (infErr, infStack) {
      _lastInferenceError = 'Interpreter execution failed: $infErr';
      debugPrint('[FloraX TFLite ERROR] Interpreter execution failed: $infErr\n$infStack');
      rethrow;
    }

    // 4. Compute 2-View TTA averaged probabilities
    final List<double> avgProbs = List.generate(
      classesCount,
      (i) => (outputOriginal[0][i] + outputFlipped[0][i]) / 2.0,
    );

    final double sumProbs = avgProbs.fold(0.0, (acc, p) => acc + p);

    // Assert probability distribution integrity (> 0.90)
    // Never swallow exceptions into flat zeros
    if (sumProbs <= 0.90) {
      final msg = 'Model output distribution invalid: sum(probs) = ${sumProbs.toStringAsFixed(4)} (expected > 0.90)';
      _lastInferenceError = msg;
      debugPrint('[FloraX TFLite ERROR] $msg');
      throw StateError(msg);
    }

    // 5. Determine Top-1 candidate and log exact required format
    double maxScore = -1.0;
    int maxIndex = -1;
    for (int i = 0; i < avgProbs.length; i++) {
      if (avgProbs[i] > maxScore) {
        maxScore = avgProbs[i];
        maxIndex = i;
      }
    }
    final String top1Label = (maxIndex >= 0 && maxIndex < _labels.length)
        ? _labels[maxIndex]
        : 'class_$maxIndex';
    final double top1Pct = maxScore * 100.0;

    debugPrint(
      '[TFLite] Model=$_modelVersion Input=$_inputShape top1=$top1Label (${top1Pct.toStringAsFixed(2)}%) sum=${sumProbs.toStringAsFixed(4)}',
    );

    // Clear prior inference error on success
    _lastInferenceError = null;

    // 6. Direct 1:1 index mapping to labels[i] (no alias map required)
    final Map<String, double> canonicalDistribution = {};
    for (int i = 0; i < avgProbs.length; i++) {
      final String labelId = (i < _labels.length) ? _labels[i] : 'class_$i';
      canonicalDistribution[labelId] = avgProbs[i] / sumProbs;
    }

    // 7. Compute normalized Shannon entropy H_norm = -sum(p * ln(p)) / ln(K)
    final int k = canonicalDistribution.length > 1 ? canonicalDistribution.length : 45;
    final double lnK = math.log(k);
    double shannonEntropy = 0.0;
    for (final p in canonicalDistribution.values) {
      if (p > 1e-12) {
        shannonEntropy -= p * math.log(p);
      }
    }
    final double normalizedEntropy = lnK > 0 ? (shannonEntropy / lnK) : 0.0;

    // 8. Sort classes descending by probability
    final List<MapEntry<String, double>> sortedCanonical = canonicalDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double top1Confidence = sortedCanonical.isNotEmpty ? sortedCanonical.first.value : 0.0;

    // 9. Out-Of-Distribution (OOD) Guardrail
    final bool isOod = top1Confidence < _oodMinConfidence || normalizedEntropy > _oodMaxNormalizedEntropy;
    if (isOod) {
      debugPrint(
        '[FloraX TFLite] OOD Flagged: '
        'top1Conf=${(top1Confidence * 100).toStringAsFixed(1)}% (<${(_oodMinConfidence * 100).toStringAsFixed(0)}%) '
        'OR normEntropy=${normalizedEntropy.toStringAsFixed(3)} (>${_oodMaxNormalizedEntropy.toStringAsFixed(2)}). '
        'Routing to mandatory KVK scientist review.',
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

    // 10. Safety Guardrail: Flag KVK expert review if top candidate confidence is < 75% or OOD
    final double topConfidence = top3.isNotEmpty ? top3.first.confidence : 0.0;
    final bool requiresKvkReview = isOod ||
        topConfidence < _clinicalChemicalLockThreshold ||
        (top3.isNotEmpty && top3.first.labelId == 'not_a_leaf_background');

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

  /// Multi-Region Disease Detection & Abiotic Nutrient vs. Infection Differentiation
  ///
  /// Runs classification on the full leaf AND independently on each cropped ROI patch.
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

  /// Differentiation logic for Abiotic Nutrient Deficiency vs. Infectious Pathogen
  static bool _isAbioticDeficiency(String labelId, DiseaseCategory category) {
    if (category == DiseaseCategory.nutrient || category == DiseaseCategory.abiotic) return true;
    final lower = labelId.toLowerCase();
    return lower.startsWith('abiotic_') ||
        lower.contains('deficiency') ||
        lower.contains('chlorosis') ||
        lower.contains('scorch');
  }

  /// Generates trilingual diagnostic explanations distinguishing abiotic vs biotic signs
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

  /// Preprocessing helper generating (original, horizontally-flipped) 4D tensors in [0.0, 255.0] float32
  static _TtaPair _preprocessImageTtaPair(Uint8List bytes, int width, int height) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Failed to decode image bytes for TFLite inference.');
    }

    // View 1: Original resized
    final img.Image resizedOrig = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final tensorOrig = _build4DTensor(resizedOrig, width, height);

    // View 2: Horizontal flip resized
    final img.Image flipped = img.flipHorizontal(decoded);
    final img.Image resizedFlipped = img.copyResize(
      flipped,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final tensorFlipped = _build4DTensor(resizedFlipped, width, height);

    return _TtaPair(tensorOrig, tensorFlipped);
  }

  /// Builds float32 tensor [1, height, width, 3] with [0.0 - 255.0] range expected by EfficientNetV2
  static List<List<List<List<double>>>> _build4DTensor(img.Image image, int width, int height) {
    final List<List<List<double>>> grid = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) {
          final p = image.getPixel(x, y);
          return [
            p.r.toDouble(),
            p.g.toDouble(),
            p.b.toDouble(),
          ];
        },
      ),
    );
    return [grid];
  }

  /// Resolves scientific taxonomy, plain name, and distinguishing symptom for all 45 canonical classes
  static _PathologyMeta _resolvePathologyMetadata(String labelId) {
    switch (labelId.toLowerCase().trim()) {
      // 1. Background / Non-Leaf
      case 'not_a_leaf_background':
        return const _PathologyMeta(
          scientificName: 'Non-Biological Foliage Object',
          category: DiseaseCategory.healthy,
          plainName: 'Non-Leaf Object',
          distinguishingSymptom: 'Frame does not contain recognisable crop foliage.',
        );

      // 2. Abiotic Nutrient Deficiencies (6 canonical classes)
      case 'abiotic_micronutrient_deficiency':
        return const _PathologyMeta(
          scientificName: 'Physiological Micronutrient (Fe/Mn/B) Chlorosis',
          category: DiseaseCategory.nutrient,
          plainName: 'Micronutrient Deficiency',
          distinguishingSymptom: 'Fine interveinal reticulate chlorosis on youngest terminal leaves without necrotic target rings.',
        );
      case 'abiotic_multi_nutrient_deficiency':
        return const _PathologyMeta(
          scientificName: 'Complex Multi-Nutrient Chlorosis & Scorch',
          category: DiseaseCategory.nutrient,
          plainName: 'Multi-Nutrient Deficiency',
          distinguishingSymptom: 'Combined generalized foliar chlorosis, marginal tip scorch, and stunted internodal development.',
        );
      case 'abiotic_nitrogen_deficiency':
        return const _PathologyMeta(
          scientificName: 'General Foliar Nitrogen Chlorosis',
          category: DiseaseCategory.nutrient,
          plainName: 'Nitrogen Deficiency',
          distinguishingSymptom: 'Uniform pale yellowing progressing from bottom older leaves upwards without fungal fruiting bodies.',
        );
      case 'abiotic_phosphorus_deficiency':
        return const _PathologyMeta(
          scientificName: 'Foliar Phosphorus Purpling & Stunting',
          category: DiseaseCategory.nutrient,
          plainName: 'Phosphorus Deficiency',
          distinguishingSymptom: 'Abnormal dark green foliage with distinct purplish-bronze pigmentation along veins and lower leaf blades.',
        );
      case 'abiotic_potassium_deficiency':
        return const _PathologyMeta(
          scientificName: 'Marginal Foliar Potassium Scorch',
          category: DiseaseCategory.nutrient,
          plainName: 'Potassium Deficiency',
          distinguishingSymptom: 'Marginal leaf scorch, chlorotic rimming, and necrotic firing along the outer leaf margins.',
        );
      case 'abiotic_zinc_deficiency':
        return const _PathologyMeta(
          scientificName: 'Little Leaf & Interveinal Mottle (Zn)',
          category: DiseaseCategory.nutrient,
          plainName: 'Zinc Deficiency',
          distinguishingSymptom: 'Broad chlorotic bands between midrib and margins, rosette clustered leaves, and severe stunting.',
        );

      // 3. Banana
      case 'banana_healthy':
        return const _PathologyMeta(
          scientificName: 'Musa acuminata (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Healthy Banana Foliage',
          distinguishingSymptom: 'Broad emerald-green leaves with unblemished lamina and strong midrib without streaks or chlorosis.',
        );

      // 4. Corn / Maize (4 canonical classes)
      case 'corn_common_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia sorghi',
          category: DiseaseCategory.fungal,
          plainName: 'Corn Common Rust',
          distinguishingSymptom: 'Golden-brown to cinnamon raised powdery pustules scattered across both leaf surfaces.',
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
          distinguishingSymptom: 'Vibrant elongated green leaves with clear longitudinal venation and intact lamina.',
        );
      case 'corn_northern_leaf_blight':
        return const _PathologyMeta(
          scientificName: 'Exserohilum turcicum',
          category: DiseaseCategory.fungal,
          plainName: 'Corn Northern Leaf Blight',
          distinguishingSymptom: 'Long elliptical cigar-shaped grayish-green to tan lesions.',
        );

      // 5. Cotton (4 canonical classes)
      case 'cotton_bacterial_blight':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas citri pv. malvacearum',
          category: DiseaseCategory.bacterial,
          plainName: 'Cotton Bacterial Blight',
          distinguishingSymptom: 'Angular water-soaked leaf spots bounded by veinlets turning dark brown/black with black-arm stem lesions.',
        );
      case 'cotton_healthy':
        return const _PathologyMeta(
          scientificName: 'Gossypium hirsutum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Cotton Healthy Foliage',
          distinguishingSymptom: 'Uniform deep-green palmately lobed leaves free from angular lesions, curl, or vascular wilting.',
        );
      case 'cotton_leaf_curl':
        return const _PathologyMeta(
          scientificName: 'Begomovirus (Cotton Leaf Curl Virus)',
          category: DiseaseCategory.viral,
          plainName: 'Cotton Leaf Curl Virus',
          distinguishingSymptom: 'Upward or downward leaf curling, vein thickening, and enations on leaf underside.',
        );
      case 'cotton_wilt':
        return const _PathologyMeta(
          scientificName: 'Fusarium oxysporum f. sp. vasinfectum / Verticillium dahliae',
          category: DiseaseCategory.fungal,
          plainName: 'Cotton Vascular Wilt',
          distinguishingSymptom: 'Marginal and interveinal yellowing with diagnostic dark brown vascular discoloration inside the stem.',
        );

      // 6. Paddy / Rice (6 canonical classes)
      case 'paddy_bacterial_blight':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas oryzae pv. oryzae',
          category: DiseaseCategory.bacterial,
          plainName: 'Rice Bacterial Leaf Blight',
          distinguishingSymptom: 'Wavy yellowish-white water-soaked stripes running down leaf margins that turn grey-white.',
        );
      case 'paddy_brown_spot':
        return const _PathologyMeta(
          scientificName: 'Bipolaris oryzae',
          category: DiseaseCategory.fungal,
          plainName: 'Rice Brown Spot',
          distinguishingSymptom: 'Small oval to circular dark brown lesions resembling sesame seeds with yellow chlorotic halos.',
        );
      case 'paddy_healthy':
        return const _PathologyMeta(
          scientificName: 'Oryza sativa (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Rice Healthy Foliage',
          distinguishingSymptom: 'Uniform green erect tillers without necrotic borders or margins.',
        );
      case 'paddy_leaf_blast':
        return const _PathologyMeta(
          scientificName: 'Magnaporthe oryzae',
          category: DiseaseCategory.fungal,
          plainName: 'Rice Leaf Blast',
          distinguishingSymptom: 'Spindle-shaped elliptical lesions with grey centers and dark brown or reddish borders.',
        );
      case 'paddy_neck_blast':
        return const _PathologyMeta(
          scientificName: 'Magnaporthe oryzae (Neck Blast)',
          category: DiseaseCategory.fungal,
          plainName: 'Rice Neck Blast',
          distinguishingSymptom: 'Dark necrotic girdling at panicle base causing blank, chaffy grains and lodging.',
        );
      case 'paddy_tungro':
        return const _PathologyMeta(
          scientificName: 'Rice Tungro Spherical/Bacilliform Virus',
          category: DiseaseCategory.viral,
          plainName: 'Rice Tungro Virus',
          distinguishingSymptom: 'Vibrant orange-yellow leaf discoloration starting from tips with severe stunting and reduced tillers.',
        );

      // 7. Bell Pepper (2 canonical classes)
      case 'pepper_bell_bacterial_spot':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas campestris pv. vesicatoria',
          category: DiseaseCategory.bacterial,
          plainName: 'Bell Pepper Bacterial Spot',
          distinguishingSymptom: 'Small water-soaked circular to irregular dark spots on leaves with yellow haloes.',
        );
      case 'pepper_bell_healthy':
        return const _PathologyMeta(
          scientificName: 'Capsicum annuum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Bell Pepper Healthy Foliage',
          distinguishingSymptom: 'Glossy smooth green leaves with unbroken margins and uniform foliar health.',
        );

      // 8. Potato (3 canonical classes)
      case 'potato_early_blight':
        return const _PathologyMeta(
          scientificName: 'Alternaria solani',
          category: DiseaseCategory.fungal,
          plainName: 'Potato Early Blight',
          distinguishingSymptom: 'Concentric dark target-board rings on lower potato leaves surrounded by chlorotic tissue.',
        );
      case 'potato_healthy':
        return const _PathologyMeta(
          scientificName: 'Solanum tuberosum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Potato Healthy Foliage',
          distinguishingSymptom: 'Smooth intact green compound leaf blade without brown or black necrotic lesions.',
        );
      case 'potato_late_blight':
        return const _PathologyMeta(
          scientificName: 'Phytophthora infestans',
          category: DiseaseCategory.fungal,
          plainName: 'Potato Late Blight',
          distinguishingSymptom: 'Rapidly expanding water-soaked lesions turning dark brown with white fungal growth on underside in humid air.',
        );

      // 9. Sugarcane (5 canonical classes)
      case 'sugarcane_bacterial_blight':
        return const _PathologyMeta(
          scientificName: 'Acidovorax avenae subsp. avenae',
          category: DiseaseCategory.bacterial,
          plainName: 'Sugarcane Bacterial Blight',
          distinguishingSymptom: 'Reddish-brown narrow stripes on leaf blade that rapidly coalesce into long necrotic streaks.',
        );
      case 'sugarcane_healthy':
        return const _PathologyMeta(
          scientificName: 'Saccharum officinarum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Sugarcane Healthy Foliage',
          distinguishingSymptom: 'Long intact green foliage without red midrib streaks, rust pustules, or mosaic mottling.',
        );
      case 'sugarcane_mosaic':
        return const _PathologyMeta(
          scientificName: 'Sugarcane mosaic virus (SCMV)',
          category: DiseaseCategory.viral,
          plainName: 'Sugarcane Mosaic Virus',
          distinguishingSymptom: 'Contrasting islands of dark green against pale yellow-green elongated chlorotic stripes along veins.',
        );
      case 'sugarcane_red_rot':
        return const _PathologyMeta(
          scientificName: 'Colletotrichum falcatum',
          category: DiseaseCategory.fungal,
          plainName: 'Sugarcane Red Rot',
          distinguishingSymptom: 'Red lesions with white cross patches along leaf midrib and internal cane stalk rotting.',
        );
      case 'sugarcane_yellow_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia kuehnii',
          category: DiseaseCategory.fungal,
          plainName: 'Sugarcane Yellow Rust',
          distinguishingSymptom: 'Small elongated yellow to orange-brown powdery pustules oriented parallel to leaf venation.',
        );

      // 10. Tomato (10 canonical classes)
      case 'tomato_bacterial_spot':
        return const _PathologyMeta(
          scientificName: 'Xanthomonas perforans',
          category: DiseaseCategory.bacterial,
          plainName: 'Tomato Bacterial Spot',
          distinguishingSymptom: 'Small water-soaked dark spots with distinct yellow chlorotic halos.',
        );
      case 'tomato_early_blight':
        return const _PathologyMeta(
          scientificName: 'Alternaria solani',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Early Blight',
          distinguishingSymptom: 'Dark brown rings like a bullseye target on older leaves with chlorotic borders.',
        );
      case 'tomato_healthy':
        return const _PathologyMeta(
          scientificName: 'Solanum lycopersicum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Tomato Healthy Foliage',
          distinguishingSymptom: 'Uniform vibrant green leaf blade with intact margins and zero lesions.',
        );
      case 'tomato_late_blight':
        return const _PathologyMeta(
          scientificName: 'Phytophthora infestans',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Late Blight',
          distinguishingSymptom: 'Water-soaked dark lesions with white mold on underside in humid conditions.',
        );
      case 'tomato_leaf_mold':
        return const _PathologyMeta(
          scientificName: 'Passalora fulva',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Leaf Mold',
          distinguishingSymptom: 'Pale yellow chlorotic spots on upper leaf surface, olive-green velvety mold underneath.',
        );
      case 'tomato_mosaic_virus':
        return const _PathologyMeta(
          scientificName: 'Tomato mosaic virus (ToMV)',
          category: DiseaseCategory.viral,
          plainName: 'Tomato Mosaic Virus',
          distinguishingSymptom: 'Mottled alternating dark and light green mosaic pattern with distorted foliar leaflets.',
        );
      case 'tomato_septoria_leaf_spot':
        return const _PathologyMeta(
          scientificName: 'Septoria lycopersici',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Septoria Leaf Spot',
          distinguishingSymptom: 'Many tiny circular spots with dark brown margins and pale grey centers.',
        );
      case 'tomato_spider_mites':
        return const _PathologyMeta(
          scientificName: 'Tetranychus urticae',
          category: DiseaseCategory.pest,
          plainName: 'Tomato Spider Mites',
          distinguishingSymptom: 'Fine yellow-white stippling on upper leaf surface with fine delicate webbing underneath.',
        );
      case 'tomato_target_spot':
        return const _PathologyMeta(
          scientificName: 'Corynespora cassiicola',
          category: DiseaseCategory.fungal,
          plainName: 'Tomato Target Spot',
          distinguishingSymptom: 'Brown lesions with concentric rings and distinct yellow chlorotic halos.',
        );
      case 'tomato_yellow_leaf_curl_virus':
        return const _PathologyMeta(
          scientificName: 'Tomato yellow leaf curl virus (TYLCV)',
          category: DiseaseCategory.viral,
          plainName: 'Tomato Yellow Leaf Curl Virus',
          distinguishingSymptom: 'Severe upward leaf curling, cupping, yellow margins, and stunted bushy growth.',
        );

      // 11. Wheat (3 canonical classes)
      case 'wheat_brown_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia triticina',
          category: DiseaseCategory.fungal,
          plainName: 'Wheat Brown (Leaf) Rust',
          distinguishingSymptom: 'Round orange-brown pustules scattered randomly across the upper leaf surface.',
        );
      case 'wheat_healthy':
        return const _PathologyMeta(
          scientificName: 'Triticum aestivum (Healthy)',
          category: DiseaseCategory.healthy,
          plainName: 'Wheat Healthy Foliage',
          distinguishingSymptom: 'Uniform emerald green blades with intact veins and no rust pustules.',
        );
      case 'wheat_yellow_rust':
        return const _PathologyMeta(
          scientificName: 'Puccinia striiformis',
          category: DiseaseCategory.fungal,
          plainName: 'Wheat Yellow (Stripe) Rust',
          distinguishingSymptom: 'Bright yellow powdery pustules arranged in parallel linear stripes along leaf veins.',
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

class _TtaPair {
  final List<List<List<List<double>>>> item1;
  final List<List<List<List<double>>>> item2;
  const _TtaPair(this.item1, this.item2);
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
