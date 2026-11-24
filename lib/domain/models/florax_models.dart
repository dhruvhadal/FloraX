import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// =============================================================================
// DOMAIN ENUMS & VALUE OBJECTS
// =============================================================================

/// Pathological and physiological categorization of crop health conditions
enum DiseaseCategory {
  fungal,
  bacterial,
  viral,
  nutrient,
  pest,
  healthy,
  abiotic;

  String toFirestoreValue() {
    switch (this) {
      case DiseaseCategory.fungal:
        return 'FUNGAL';
      case DiseaseCategory.bacterial:
        return 'BACTERIAL';
      case DiseaseCategory.viral:
        return 'VIRAL';
      case DiseaseCategory.nutrient:
        return 'NUTRIENT';
      case DiseaseCategory.pest:
        return 'PEST';
      case DiseaseCategory.healthy:
        return 'HEALTHY';
      case DiseaseCategory.abiotic:
        return 'ABIOTIC';
    }
  }

  static DiseaseCategory fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'FUNGAL':
        return DiseaseCategory.fungal;
      case 'BACTERIAL':
        return DiseaseCategory.bacterial;
      case 'VIRAL':
        return DiseaseCategory.viral;
      case 'NUTRIENT':
        return DiseaseCategory.nutrient;
      case 'PEST':
        return DiseaseCategory.pest;
      case 'HEALTHY':
        return DiseaseCategory.healthy;
      default:
        return DiseaseCategory.fungal;
    }
  }
}

/// Clinical verification lifecycle state for computer vision inferences
enum VerificationStatus {
  aiVerified,
  pendingKvkReview,
  kvkConfirmed;

  String toFirestoreValue() {
    switch (this) {
      case VerificationStatus.aiVerified:
        return 'AI_VERIFIED';
      case VerificationStatus.pendingKvkReview:
        return 'PENDING_KVK_REVIEW';
      case VerificationStatus.kvkConfirmed:
        return 'KVK_CONFIRMED';
    }
  }

  static VerificationStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'AI_VERIFIED':
        return VerificationStatus.aiVerified;
      case 'PENDING_KVK_REVIEW':
        return VerificationStatus.pendingKvkReview;
      case 'KVK_CONFIRMED':
        return VerificationStatus.kvkConfirmed;
      default:
        return VerificationStatus.pendingKvkReview;
    }
  }
}

/// Deterministic 4-state clinical safety evaluation state
enum ClinicalSafetyState {
  oodRejected,
  abioticStress,
  needsReview,
  confirmedBiotic;

  String toFirestoreValue() {
    switch (this) {
      case ClinicalSafetyState.oodRejected:
        return 'OOD_REJECTED';
      case ClinicalSafetyState.abioticStress:
        return 'ABIOTIC_STRESS';
      case ClinicalSafetyState.needsReview:
        return 'NEEDS_REVIEW';
      case ClinicalSafetyState.confirmedBiotic:
        return 'CONFIRMED_BIOTIC';
    }
  }

  static ClinicalSafetyState fromString(String? val) {
    switch (val?.toUpperCase().trim()) {
      case 'OOD_REJECTED':
      case 'OODREJECTED':
        return ClinicalSafetyState.oodRejected;
      case 'ABIOTIC_STRESS':
      case 'ABIOTICSTRESS':
        return ClinicalSafetyState.abioticStress;
      case 'NEEDS_REVIEW':
      case 'NEEDSREVIEW':
        return ClinicalSafetyState.needsReview;
      case 'CONFIRMED_BIOTIC':
      case 'CONFIRMEDBIOTIC':
      default:
        return ClinicalSafetyState.confirmedBiotic;
    }
  }
}

/// Backward compatibility alias for ClinicalSafetyState
typedef SafetyState = ClinicalSafetyState;

/// Deterministic 4-state clinical diagnosis decision evaluator
@immutable
class ClinicalDiagnosisDecision {
  final ClinicalSafetyState safetyState;
  final String canonicalId;
  final double top1Confidence;
  final double normalizedEntropy;
  final bool locksChemicalFungicides;
  final bool routesToKvkExpert;
  final String clinicalRationale;

  const ClinicalDiagnosisDecision({
    required this.safetyState,
    required this.canonicalId,
    required this.top1Confidence,
    required this.normalizedEntropy,
    required this.locksChemicalFungicides,
    required this.routesToKvkExpert,
    required this.clinicalRationale,
  });

  bool get isOodRejected => safetyState == ClinicalSafetyState.oodRejected;
  bool get isAbioticStress => safetyState == ClinicalSafetyState.abioticStress;
  bool get isNeedsReview => safetyState == ClinicalSafetyState.needsReview;
  bool get isConfirmedBiotic => safetyState == ClinicalSafetyState.confirmedBiotic;

  Map<String, dynamic> toMap() => {
    'safetyState': safetyState.toFirestoreValue(),
    'canonicalId': canonicalId,
    'top1Confidence': top1Confidence,
    'normalizedEntropy': normalizedEntropy,
    'locksChemicalFungicides': locksChemicalFungicides,
    'routesToKvkExpert': routesToKvkExpert,
    'clinicalRationale': clinicalRationale,
  };

  factory ClinicalDiagnosisDecision.fromMap(Map<String, dynamic> map) {
    return ClinicalDiagnosisDecision(
      safetyState: ClinicalSafetyState.fromString(map['safetyState'] as String?),
      canonicalId: map['canonicalId'] as String? ?? 'unknown',
      top1Confidence: (map['top1Confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedEntropy: (map['normalizedEntropy'] as num?)?.toDouble() ?? 0.0,
      locksChemicalFungicides: map['locksChemicalFungicides'] as bool? ?? false,
      routesToKvkExpert: map['routesToKvkExpert'] as bool? ?? false,
      clinicalRationale: map['clinicalRationale'] as String? ?? '',
    );
  }

  /// Evaluates deterministic 4-state clinical diagnosis:
  /// - oodRejected: not_a_leaf_background OR top1 < 0.45 OR normEntropy > 0.65
  /// - abioticStress: canonicalId.startsWith('abiotic_') (locks chemical fungicides)
  /// - needsReview: Biotic disease with top1 < 0.75 (locks Chemical tab -> routes to KVK Expert)
  /// - confirmedBiotic: Biotic disease with top1 >= 0.75 (or healthy when endsWith('_healthy'))
  static ClinicalDiagnosisDecision evaluate({
    required String canonicalId,
    required double top1Confidence,
    required double normalizedEntropy,
    double oodMinConfidence = 0.45,
    double oodMaxEntropy = 0.65,
    double clinicalLockThreshold = 0.75,
  }) {
    final lower = canonicalId.toLowerCase().trim();

    // 1. oodRejected: not_a_leaf_background OR top1 < 0.45 OR normEntropy > 0.65
    if (lower == 'not_a_leaf_background' ||
        top1Confidence < oodMinConfidence ||
        normalizedEntropy > oodMaxEntropy) {
      return ClinicalDiagnosisDecision(
        safetyState: ClinicalSafetyState.oodRejected,
        canonicalId: canonicalId,
        top1Confidence: top1Confidence,
        normalizedEntropy: normalizedEntropy,
        locksChemicalFungicides: true,
        routesToKvkExpert: true,
        clinicalRationale:
            'Out-Of-Distribution rejection: non-leaf surface or low model confidence / high entropy.',
      );
    }

    // 2. abioticStress: canonicalId.startsWith('abiotic_') (locks chemical fungicides)
    if (lower.startsWith('abiotic_')) {
      return ClinicalDiagnosisDecision(
        safetyState: ClinicalSafetyState.abioticStress,
        canonicalId: canonicalId,
        top1Confidence: top1Confidence,
        normalizedEntropy: normalizedEntropy,
        locksChemicalFungicides: true,
        routesToKvkExpert: top1Confidence < clinicalLockThreshold,
        clinicalRationale:
            'Abiotic physiological/nutrient deficiency detected. Chemical fungicides locked.',
      );
    }

    // 3. needsReview: Biotic disease with top1 < 0.75 (locks Chemical tab -> routes to KVK Expert)
    if (top1Confidence < clinicalLockThreshold && !lower.endsWith('_healthy')) {
      return ClinicalDiagnosisDecision(
        safetyState: ClinicalSafetyState.needsReview,
        canonicalId: canonicalId,
        top1Confidence: top1Confidence,
        normalizedEntropy: normalizedEntropy,
        locksChemicalFungicides: true,
        routesToKvkExpert: true,
        clinicalRationale:
            'Biotic disease below ICAR safety threshold (< ${(clinicalLockThreshold * 100).toInt()}%). Chemical locked pending KVK review.',
      );
    }

    // 4. confirmedBiotic: Biotic disease with top1 >= 0.75 (or healthy when endsWith('_healthy'))
    return ClinicalDiagnosisDecision(
      safetyState: ClinicalSafetyState.confirmedBiotic,
      canonicalId: canonicalId,
      top1Confidence: top1Confidence,
      normalizedEntropy: normalizedEntropy,
      locksChemicalFungicides: false,
      routesToKvkExpert: false,
      clinicalRationale: lower.endsWith('_healthy')
          ? 'Healthy crop foliar tissue confirmed.'
          : 'Biotic infection confirmed above ICAR safety threshold.',
    );
  }
}

/// Structured natural and organic remedy step aligned with AgriSage Organics
@immutable
class NaturalRemedyStep {
  final int stepNumber;
  final Map<String, String> title; // Trilingual ('en', 'hi', 'mr')
  final Map<String, String> instructions; // Trilingual ('en', 'hi', 'mr')
  final String dosage;
  final String timing;
  final List<String> ingredients;
  final Map<String, String> safetyPrecaution;

  const NaturalRemedyStep({
    required this.stepNumber,
    required this.title,
    required this.instructions,
    this.dosage = '',
    this.timing = '',
    this.ingredients = const [],
    this.safetyPrecaution = const {},
  });

  Map<String, dynamic> toMap() => {
    'stepNumber': stepNumber,
    'title': title,
    'instructions': instructions,
    'dosage': dosage,
    'timing': timing,
    'ingredients': ingredients,
    'safetyPrecaution': safetyPrecaution,
  };

  factory NaturalRemedyStep.fromMap(Map<String, dynamic> map) {
    final rawTitle = map['title'];
    final Map<String, String> parsedTitle = {};
    if (rawTitle is Map) {
      rawTitle.forEach((k, v) => parsedTitle[k.toString()] = v.toString());
    } else if (rawTitle is String) {
      parsedTitle['en'] = rawTitle;
    }

    final rawInst = map['instructions'] ?? map['preparation'];
    final Map<String, String> parsedInst = {};
    if (rawInst is Map) {
      rawInst.forEach((k, v) => parsedInst[k.toString()] = v.toString());
    } else if (rawInst is String) {
      parsedInst['en'] = rawInst;
    }

    final rawPrec = map['safetyPrecaution'];
    final Map<String, String> parsedPrec = {};
    if (rawPrec is Map) {
      rawPrec.forEach((k, v) => parsedPrec[k.toString()] = v.toString());
    } else if (rawPrec is String) {
      parsedPrec['en'] = rawPrec;
    }

    final rawIng = map['ingredients'];
    final List<String> parsedIng =
        rawIng is List ? rawIng.map((e) => e.toString()).toList() : [];

    return NaturalRemedyStep(
      stepNumber: (map['stepNumber'] as num?)?.toInt() ?? 1,
      title: parsedTitle,
      instructions: parsedInst,
      dosage: map['dosage']?.toString() ?? '',
      timing: map['timing']?.toString() ?? '',
      ingredients: parsedIng,
      safetyPrecaution: parsedPrec,
    );
  }
}

/// Feature #8: Standardized 3-tier severity grade based on necrotic/chlorotic leaf ratio
enum SeverityGrade {
  mild,
  moderate,
  severe;

  /// Standardized phytopathology severity bands:
  /// Mild: < 15.0%
  /// Moderate: 15.0% - 39.9%
  /// Severe: >= 40.0%
  static SeverityGrade fromPercentage(double pct) {
    if (pct < 15.0) return SeverityGrade.mild;
    if (pct < 40.0) return SeverityGrade.moderate;
    return SeverityGrade.severe;
  }

  String toFirestoreValue() {
    switch (this) {
      case SeverityGrade.mild:
        return 'MILD';
      case SeverityGrade.moderate:
        return 'MODERATE';
      case SeverityGrade.severe:
        return 'SEVERE';
    }
  }

  static SeverityGrade fromString(String? val) {
    switch (val?.toUpperCase().trim()) {
      case 'SEVERE':
        return SeverityGrade.severe;
      case 'MODERATE':
        return SeverityGrade.moderate;
      case 'MILD':
      default:
        return SeverityGrade.mild;
    }
  }

  String get label {
    switch (this) {
      case SeverityGrade.mild:
        return 'Mild (<15%)';
      case SeverityGrade.moderate:
        return 'Moderate (15-40%)';
      case SeverityGrade.severe:
        return 'Severe (>=40%)';
    }
  }
}


// =============================================================================
// 1. DISEASE PREDICTION & IMAGE QUALITY MODELS
// =============================================================================

/// Individual disease candidate generated by the on-device MobileNetV3 TFLite engine
@immutable
class DiseasePrediction {
  final String labelId;
  final double confidence; // Normalized [0.0 - 1.0] or percentage [0.0 - 100.0]
  final String scientificName;
  final DiseaseCategory category;
  final String distinguishingSymptom; // Feature #6: 1-line distinctive diagnostic visual cue
  final String plainName; // Feature #6: Plain-language human-readable name

  const DiseasePrediction({
    required this.labelId,
    required this.confidence,
    required this.scientificName,
    required this.category,
    this.distinguishingSymptom = '',
    this.plainName = '',
  });

  DiseasePrediction copyWith({
    String? labelId,
    double? confidence,
    String? scientificName,
    DiseaseCategory? category,
    String? distinguishingSymptom,
    String? plainName,
  }) {
    return DiseasePrediction(
      labelId: labelId ?? this.labelId,
      confidence: confidence ?? this.confidence,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      distinguishingSymptom: distinguishingSymptom ?? this.distinguishingSymptom,
      plainName: plainName ?? this.plainName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'labelId': labelId,
      'confidence': confidence,
      'scientificName': scientificName,
      'category': category.toFirestoreValue(),
      'distinguishingSymptom': distinguishingSymptom,
      'plainName': plainName,
    };
  }

  factory DiseasePrediction.fromMap(Map<String, dynamic> map) {
    return DiseasePrediction(
      labelId: map['labelId'] as String? ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      scientificName: map['scientificName'] as String? ?? 'Unknown pathogen',
      category: DiseaseCategory.fromString(map['category'] as String?),
      distinguishingSymptom: map['distinguishingSymptom'] as String? ?? '',
      plainName: map['plainName'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiseasePrediction &&
          runtimeType == other.runtimeType &&
          labelId == other.labelId &&
          confidence == other.confidence &&
          scientificName == other.scientificName &&
          category == other.category &&
          distinguishingSymptom == other.distinguishingSymptom &&
          plainName == other.plainName;

  @override
  int get hashCode =>
      labelId.hashCode ^
      confidence.hashCode ^
      scientificName.hashCode ^
      category.hashCode ^
      distinguishingSymptom.hashCode ^
      plainName.hashCode;
}

/// Feature #5: Pre-inference Image Quality Guardrail Report
@immutable
class ImageQualityReport {
  final bool isAcceptable;
  final double blurScore; // Variance of Laplacian (optimal > 100.0)
  final double brightnessScore; // Mean luminance [0 - 255] (optimal 80 - 220)
  final double leafCoveragePercent; // Foliage pixel ratio [0 - 100%]
  final List<String> failureReasons;
  final String? failureCode; // 'tooDark' | 'tooBright' | 'blurry' | 'noLeafDetected' | 'lowConfidenceOod'

  const ImageQualityReport({
    required this.isAcceptable,
    required this.blurScore,
    required this.brightnessScore,
    required this.leafCoveragePercent,
    this.failureReasons = const [],
    this.failureCode,
  });

  bool get isTooDark =>
      failureCode == 'tooDark' ||
      failureReasons.any((r) => r.toLowerCase().contains('dark') || r.toLowerCase().contains('underexposed'));

  bool get isTooBright =>
      failureCode == 'tooBright' ||
      failureReasons.any((r) => r.toLowerCase().contains('glare') || r.toLowerCase().contains('bright'));

  bool get isBlurry =>
      failureCode == 'blurry' ||
      failureReasons.any((r) => r.toLowerCase().contains('blur'));

  bool get isNoLeafDetected =>
      failureCode == 'noLeafDetected' ||
      failureReasons.any((r) => r.toLowerCase().contains('leaf not') || r.toLowerCase().contains('no leaf') || r.toLowerCase().contains('foliage'));

  bool get isLowConfidenceOod => failureCode == 'lowConfidenceOod';

  ImageQualityReport copyWith({
    bool? isAcceptable,
    double? blurScore,
    double? brightnessScore,
    double? leafCoveragePercent,
    List<String>? failureReasons,
    String? failureCode,
  }) {
    return ImageQualityReport(
      isAcceptable: isAcceptable ?? this.isAcceptable,
      blurScore: blurScore ?? this.blurScore,
      brightnessScore: brightnessScore ?? this.brightnessScore,
      leafCoveragePercent: leafCoveragePercent ?? this.leafCoveragePercent,
      failureReasons: failureReasons ?? this.failureReasons,
      failureCode: failureCode ?? this.failureCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isAcceptable': isAcceptable,
      'blurScore': blurScore,
      'brightnessScore': brightnessScore,
      'leafCoveragePercent': leafCoveragePercent,
      'failureReasons': failureReasons,
      'failureCode': failureCode,
    };
  }

  factory ImageQualityReport.fromMap(Map<String, dynamic> map) {
    final rawReasons = map['failureReasons'];
    final List<String> parsedReasons = rawReasons is List
        ? rawReasons.map((e) => e.toString()).toList()
        : const [];

    return ImageQualityReport(
      isAcceptable: map['isAcceptable'] as bool? ?? true,
      blurScore: (map['blurScore'] as num?)?.toDouble() ?? 120.0,
      brightnessScore: (map['brightnessScore'] as num?)?.toDouble() ?? 135.0,
      leafCoveragePercent: (map['leafCoveragePercent'] as num?)?.toDouble() ?? 82.0,
      failureReasons: parsedReasons,
      failureCode: map['failureCode'] as String?,
    );
  }
}

/// Feature #1: Spatial Lesion Region extracted via 2D connected-component / grid-cluster segmentation
@immutable
class LesionRegion {
  final int id;
  final Rect boundingBoxNormalized; // Relative [0.0 - 1.0] coordinates
  final double areaPercent; // Local infected percentage of leaf blade
  final String lesionType; // 'necrotic' vs 'chlorotic'

  const LesionRegion({
    required this.id,
    required this.boundingBoxNormalized,
    required this.areaPercent,
    required this.lesionType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boundingBox': {
        'left': boundingBoxNormalized.left,
        'top': boundingBoxNormalized.top,
        'width': boundingBoxNormalized.width,
        'height': boundingBoxNormalized.height,
      },
      'areaPercent': areaPercent,
      'lesionType': lesionType,
    };
  }

  factory LesionRegion.fromMap(Map<String, dynamic> map) {
    final rawBox = map['boundingBox'];
    Rect parsedRect = Rect.zero;
    if (rawBox is Map) {
      parsedRect = Rect.fromLTWH(
        (rawBox['left'] as num?)?.toDouble() ?? 0.0,
        (rawBox['top'] as num?)?.toDouble() ?? 0.0,
        (rawBox['width'] as num?)?.toDouble() ?? 0.0,
        (rawBox['height'] as num?)?.toDouble() ?? 0.0,
      );
    }
    return LesionRegion(
      id: (map['id'] as num?)?.toInt() ?? 1,
      boundingBoxNormalized: parsedRect,
      areaPercent: (map['areaPercent'] as num?)?.toDouble() ?? 0.0,
      lesionType: map['lesionType'] as String? ?? 'necrotic',
    );
  }
}

/// Features #1, #3, #4: Spatial Sub-Region Diagnosis (Multi-Disease Co-occurrence & Explainability)
@immutable
class LeafRegionDiagnosis {
  final String regionId;
  final Rect boundingBoxNormalized; // Relative [0.0 - 1.0] coordinates
  final DiseasePrediction primaryPrediction;
  final List<DiseasePrediction> secondaryPredictions;
  final Map<String, String> visualSymptomExplanation; // Trilingual ('en', 'hi', 'mr')
  final bool isEarlyStageSubtle;

  const LeafRegionDiagnosis({
    required this.regionId,
    required this.boundingBoxNormalized,
    required this.primaryPrediction,
    this.secondaryPredictions = const [],
    this.visualSymptomExplanation = const {},
    this.isEarlyStageSubtle = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'regionId': regionId,
      'boundingBox': {
        'left': boundingBoxNormalized.left,
        'top': boundingBoxNormalized.top,
        'width': boundingBoxNormalized.width,
        'height': boundingBoxNormalized.height,
      },
      'primaryPrediction': primaryPrediction.toMap(),
      'secondaryPredictions': secondaryPredictions.map((p) => p.toMap()).toList(),
      'visualSymptomExplanation': visualSymptomExplanation,
      'isEarlyStageSubtle': isEarlyStageSubtle,
    };
  }

  factory LeafRegionDiagnosis.fromMap(Map<String, dynamic> map) {
    final rawBox = map['boundingBox'];
    Rect parsedRect = Rect.zero;
    if (rawBox is Map) {
      parsedRect = Rect.fromLTWH(
        (rawBox['left'] as num?)?.toDouble() ?? 0.0,
        (rawBox['top'] as num?)?.toDouble() ?? 0.0,
        (rawBox['width'] as num?)?.toDouble() ?? 1.0,
        (rawBox['height'] as num?)?.toDouble() ?? 1.0,
      );
    }

    final rawPrimary = map['primaryPrediction'];
    final DiseasePrediction primary = rawPrimary is Map
        ? DiseasePrediction.fromMap(Map<String, dynamic>.from(rawPrimary))
        : const DiseasePrediction(
            labelId: 'unknown',
            confidence: 0.0,
            scientificName: 'Unknown',
            category: DiseaseCategory.fungal,
          );

    final rawSecondaries = map['secondaryPredictions'];
    final List<DiseasePrediction> secondaries = [];
    if (rawSecondaries is List) {
      for (final s in rawSecondaries) {
        if (s is Map) {
          secondaries.add(DiseasePrediction.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    final rawExpl = map['visualSymptomExplanation'];
    final Map<String, String> expl = {};
    if (rawExpl is Map) {
      rawExpl.forEach((k, v) => expl[k.toString()] = v.toString());
    }

    return LeafRegionDiagnosis(
      regionId: map['regionId'] as String? ?? 'region_0',
      boundingBoxNormalized: parsedRect,
      primaryPrediction: primary,
      secondaryPredictions: secondaries,
      visualSymptomExplanation: expl,
      isEarlyStageSubtle: map['isEarlyStageSubtle'] as bool? ?? false,
    );
  }
}


// =============================================================================
// 2. GRAD-CAM ATTENTION HOTSPOT MODEL
// =============================================================================

/// Spatial attention region mapped onto the leaf surface for visual explainability
@immutable
class GradCamHotspot {
  final double x; // Normalized coordinate percentage [0.0 - 100.0]
  final double y; // Normalized coordinate percentage [0.0 - 100.0]
  final double radius;
  final double intensity; // Weight [0.0 - 1.0]
  final String label;

  const GradCamHotspot({
    required this.x,
    required this.y,
    required this.radius,
    required this.intensity,
    required this.label,
  });

  GradCamHotspot copyWith({
    double? x,
    double? y,
    double? radius,
    double? intensity,
    String? label,
  }) {
    return GradCamHotspot(
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius ?? this.radius,
      intensity: intensity ?? this.intensity,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'radius': radius,
      'intensity': intensity,
      'label': label,
    };
  }

  factory GradCamHotspot.fromMap(Map<String, dynamic> map) {
    return GradCamHotspot(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      radius: (map['radius'] as num?)?.toDouble() ?? 10.0,
      intensity: (map['intensity'] as num?)?.toDouble() ?? 1.0,
      label: map['label'] as String? ?? 'Lesion region',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradCamHotspot &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          radius == other.radius &&
          intensity == other.intensity &&
          label == other.label;

  @override
  int get hashCode =>
      x.hashCode ^
      y.hashCode ^
      radius.hashCode ^
      intensity.hashCode ^
      label.hashCode;
}


// =============================================================================
// 3. TIER-3 CHEMICAL CONTROL & VERIFIED SOURCES
// =============================================================================

/// CIB&RC-approved chemical specification with strict safety waiting days and PPE warnings
@immutable
class ChemicalControlProtocol {
  final String formulationName;
  final String dosagePerLitre;
  final int waitingPeriodDays; // Pre-Harvest Interval (PHI)
  final Map<String, String> etlCriteria; // Trilingual ('en', 'hi', 'mr')
  final Map<String, List<String>> ppeWarnings; // Trilingual ('en', 'hi', 'mr')

  // Tier 3 compatibility fields
  final String? activeIngredient;
  final String? cibrcRegistrationNumber;
  final String? economicThreshold;
  final String? antidoteStatement;
  final String? toxicityBand;

  const ChemicalControlProtocol({
    required this.formulationName,
    required this.dosagePerLitre,
    required this.waitingPeriodDays,
    this.etlCriteria = const {},
    this.ppeWarnings = const {},
    this.activeIngredient,
    this.cibrcRegistrationNumber,
    this.economicThreshold,
    this.antidoteStatement,
    this.toxicityBand,
  });

  ChemicalControlProtocol copyWith({
    String? formulationName,
    String? dosagePerLitre,
    int? waitingPeriodDays,
    Map<String, String>? etlCriteria,
    Map<String, List<String>>? ppeWarnings,
  }) {
    return ChemicalControlProtocol(
      formulationName: formulationName ?? this.formulationName,
      dosagePerLitre: dosagePerLitre ?? this.dosagePerLitre,
      waitingPeriodDays: waitingPeriodDays ?? this.waitingPeriodDays,
      etlCriteria: etlCriteria ?? this.etlCriteria,
      ppeWarnings: ppeWarnings ?? this.ppeWarnings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formulationName': formulationName,
      'dosagePerLitre': dosagePerLitre,
      'waitingPeriodDays': waitingPeriodDays,
      'etlCriteria': etlCriteria,
      'ppeWarnings': ppeWarnings,
    };
  }

  factory ChemicalControlProtocol.fromMap(Map<String, dynamic> map) {
    final rawEtl = map['etlCriteria'];
    final Map<String, String> parsedEtl = {};
    if (rawEtl is Map) {
      rawEtl.forEach((key, value) {
        parsedEtl[key.toString()] = value.toString();
      });
    }

    final rawPpe = map['ppeWarnings'];
    final Map<String, List<String>> parsedPpe = {};
    if (rawPpe is Map) {
      rawPpe.forEach((key, value) {
        if (value is List) {
          parsedPpe[key.toString()] =
              value.map((item) => item.toString()).toList();
        }
      });
    }

    return ChemicalControlProtocol(
      formulationName: map['formulationName'] as String? ?? 'N/A',
      dosagePerLitre: map['dosagePerLitre'] as String? ?? 'N/A',
      waitingPeriodDays: (map['waitingPeriodDays'] as num?)?.toInt() ?? 0,
      etlCriteria: parsedEtl,
      ppeWarnings: parsedPpe,
      activeIngredient: map['activeIngredient'] as String?,
      cibrcRegistrationNumber: map['cibrcRegistrationNumber'] as String?,
      economicThreshold: map['economicThreshold'] as String?,
      antidoteStatement: map['antidoteStatement'] as String?,
      toxicityBand: map['toxicityBand'] as String?,
    );
  }
}

typedef Tier3ChemicalControl = ChemicalControlProtocol;

/// Longitudinal Crop Recovery progression entry
@immutable
class LeafProgressionEntry {
  final String scanId;
  final String plantTagId;
  final DateTime timestamp;
  final double lesionAreaPercent;
  final SeverityGrade severityGrade;
  final String imageUrl;

  const LeafProgressionEntry({
    required this.scanId,
    required this.plantTagId,
    required this.timestamp,
    required this.lesionAreaPercent,
    required this.severityGrade,
    required this.imageUrl,
  });
}

/// Feature #7: Verified Agronomic Source Citation (ICAR, SAU, TNAU)
@immutable
class VerifiedSource {
  final String name;
  final String url;
  final String referenceCode;

  const VerifiedSource({
    required this.name,
    required this.url,
    required this.referenceCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'referenceCode': referenceCode,
    };
  }

  factory VerifiedSource.fromMap(Map<String, dynamic> map) {
    return VerifiedSource(
      name: map['name'] as String? ?? 'ICAR Certified Source',
      url: map['url'] as String? ?? 'https://icar.org.in',
      referenceCode: map['referenceCode'] as String? ?? 'ICAR-KB-2026',
    );
  }
}


// =============================================================================
// 4. ICAR / KVK IPM PROTOCOL MODEL (EXTENDED)
// =============================================================================

/// Comprehensive 3-tier Integrated Pest Management protocol with trilingual localization
/// Extended with Abiotic Deficiencies, Differential Diagnosis, and Verified Citations
@immutable
class IcarIpmProtocol {
  final String id;
  final Map<String, String> diseaseName; // Trilingual ('en', 'hi', 'mr')
  final String scientificName;
  final DiseaseCategory category;
  final List<String> affectedCrops;
  final Map<String, List<String>> tier1Cultural; // ICAR spacing, pruning, sanitation
  final Map<String, List<String>> tier2Biological; // Bioagents (Trichoderma, NSKE, VAM)
  final ChemicalControlProtocol tier3Chemical; // CIB&RC approved formulation

  // Feature #2 & #6 & #7 Extensions
  final bool isAbioticNutrientDeficiency;
  final Map<String, String> causalAgent; // Trilingual
  final Map<String, String> favourableConditions; // Trilingual
  final Map<String, List<String>> distinguishingSymptoms; // Trilingual differential diagnosis
  final Map<String, List<String>> clarifyingFollowUpQuestions; // Trilingual follow-up questions
  final List<VerifiedSource> verifiedSources;
  final List<NaturalRemedyStep> naturalRemedySteps;

  const IcarIpmProtocol({
    String? id,
    String? diseaseId,
    required this.diseaseName,
    required this.scientificName,
    required this.category,
    this.affectedCrops = const [],
    required this.tier1Cultural,
    required this.tier2Biological,
    required this.tier3Chemical,
    this.isAbioticNutrientDeficiency = false,
    this.causalAgent = const {},
    this.favourableConditions = const {},
    this.distinguishingSymptoms = const {},
    this.clarifyingFollowUpQuestions = const {},
    this.verifiedSources = const [],
    this.naturalRemedySteps = const [],
  }) : id = id ?? diseaseId ?? '';

  String get diseaseId => id;

  IcarIpmProtocol copyWith({
    String? id,
    Map<String, String>? diseaseName,
    String? scientificName,
    DiseaseCategory? category,
    List<String>? affectedCrops,
    Map<String, List<String>>? tier1Cultural,
    Map<String, List<String>>? tier2Biological,
    ChemicalControlProtocol? tier3Chemical,
    bool? isAbioticNutrientDeficiency,
    Map<String, String>? causalAgent,
    Map<String, String>? favourableConditions,
    Map<String, List<String>>? distinguishingSymptoms,
    Map<String, List<String>>? clarifyingFollowUpQuestions,
    List<VerifiedSource>? verifiedSources,
    List<NaturalRemedyStep>? naturalRemedySteps,
  }) {
    return IcarIpmProtocol(
      id: id ?? this.id,
      diseaseName: diseaseName ?? this.diseaseName,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      affectedCrops: affectedCrops ?? this.affectedCrops,
      tier1Cultural: tier1Cultural ?? this.tier1Cultural,
      tier2Biological: tier2Biological ?? this.tier2Biological,
      tier3Chemical: tier3Chemical ?? this.tier3Chemical,
      isAbioticNutrientDeficiency:
          isAbioticNutrientDeficiency ?? this.isAbioticNutrientDeficiency,
      causalAgent: causalAgent ?? this.causalAgent,
      favourableConditions: favourableConditions ?? this.favourableConditions,
      distinguishingSymptoms:
          distinguishingSymptoms ?? this.distinguishingSymptoms,
      clarifyingFollowUpQuestions:
          clarifyingFollowUpQuestions ?? this.clarifyingFollowUpQuestions,
      verifiedSources: verifiedSources ?? this.verifiedSources,
      naturalRemedySteps: naturalRemedySteps ?? this.naturalRemedySteps,
    );
  }

  /// Firestore type-safe serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'diseaseName': diseaseName,
      'scientificName': scientificName,
      'category': category.toFirestoreValue(),
      'affectedCrops': affectedCrops,
      'tier1_cultural': tier1Cultural,
      'tier2_biological': tier2Biological,
      'tier3_chemical': tier3Chemical.toMap(),
      'isAbioticNutrientDeficiency': isAbioticNutrientDeficiency,
      'causalAgent': causalAgent,
      'favourableConditions': favourableConditions,
      'distinguishingSymptoms': distinguishingSymptoms,
      'clarifyingFollowUpQuestions': clarifyingFollowUpQuestions,
      'verifiedSources': verifiedSources.map((s) => s.toMap()).toList(),
      'naturalRemedySteps': naturalRemedySteps.map((s) => s.toMap()).toList(),
    };
  }

  factory IcarIpmProtocol.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot deserialize empty snapshot into IcarIpmProtocol');
    }
    return IcarIpmProtocol.fromMap(data, snapshot.id);
  }

  factory IcarIpmProtocol.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawName = map['diseaseName'];
    final Map<String, String> parsedName = {};
    if (rawName is Map) {
      rawName.forEach((k, v) => parsedName[k.toString()] = v.toString());
    }

    final rawCrops = map['affectedCrops'];
    final List<String> parsedCrops =
        rawCrops is List ? rawCrops.map((e) => e.toString()).toList() : [];

    final rawCultural = map['tier1_cultural'] ?? map['tier1Cultural'];
    final Map<String, List<String>> parsedCultural = {};
    if (rawCultural is Map) {
      rawCultural.forEach((k, v) {
        if (v is List) {
          parsedCultural[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    final rawBiological = map['tier2_biological'] ?? map['tier2Biological'];
    final Map<String, List<String>> parsedBiological = {};
    if (rawBiological is Map) {
      rawBiological.forEach((k, v) {
        if (v is List) {
          parsedBiological[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    final rawChemical = map['tier3_chemical'] ?? map['tier3Chemical'];
    final chemicalProtocol = rawChemical is Map<String, dynamic>
        ? ChemicalControlProtocol.fromMap(rawChemical)
        : ChemicalControlProtocol.fromMap(
            Map<String, dynamic>.from(rawChemical as Map? ?? {}));

    // Parse causalAgent & favourableConditions
    final rawCausal = map['causalAgent'];
    final Map<String, String> parsedCausal = {};
    if (rawCausal is Map) {
      rawCausal.forEach((k, v) => parsedCausal[k.toString()] = v.toString());
    }

    final rawConditions = map['favourableConditions'];
    final Map<String, String> parsedConditions = {};
    if (rawConditions is Map) {
      rawConditions.forEach((k, v) => parsedConditions[k.toString()] = v.toString());
    }

    // Parse distinguishingSymptoms
    final rawDistinguishing = map['distinguishingSymptoms'];
    final Map<String, List<String>> parsedDistinguishing = {};
    if (rawDistinguishing is Map) {
      rawDistinguishing.forEach((k, v) {
        if (v is List) {
          parsedDistinguishing[k.toString()] =
              v.map((e) => e.toString()).toList();
        }
      });
    }

    // Parse clarifyingFollowUpQuestions
    final rawQuestions = map['clarifyingFollowUpQuestions'];
    final Map<String, List<String>> parsedQuestions = {};
    if (rawQuestions is Map) {
      rawQuestions.forEach((k, v) {
        if (v is List) {
          parsedQuestions[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    // Parse verifiedSources
    final rawSources = map['verifiedSources'];
    final List<VerifiedSource> parsedSources = [];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (s is Map) {
          parsedSources.add(VerifiedSource.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    // Parse naturalRemedySteps
    final rawRemedies = map['naturalRemedySteps'] ?? map['natural_remedy_steps'];
    final List<NaturalRemedyStep> parsedRemedies = [];
    if (rawRemedies is List) {
      for (final r in rawRemedies) {
        if (r is Map) {
          parsedRemedies.add(NaturalRemedyStep.fromMap(Map<String, dynamic>.from(r)));
        }
      }
    }

    return IcarIpmProtocol(
      id: docId ?? (map['id'] as String? ?? 'unknown_protocol'),
      diseaseName: parsedName,
      scientificName: map['scientificName'] as String? ?? 'Unknown',
      category: DiseaseCategory.fromString(map['category'] as String?),
      affectedCrops: parsedCrops,
      tier1Cultural: parsedCultural,
      tier2Biological: parsedBiological,
      tier3Chemical: chemicalProtocol,
      isAbioticNutrientDeficiency:
          map['isAbioticNutrientDeficiency'] as bool? ?? false,
      causalAgent: parsedCausal,
      favourableConditions: parsedConditions,
      distinguishingSymptoms: parsedDistinguishing,
      clarifyingFollowUpQuestions: parsedQuestions,
      verifiedSources: parsedSources,
      naturalRemedySteps: parsedRemedies,
    );
  }
}


// =============================================================================
// 5. LEAF SCAN RECORD MODEL (EXTENDED)
// =============================================================================

/// Immutable diagnostic record of a scanned crop plant, stored in Firestore 'scans/{scanId}'
@immutable
class LeafScanRecord {
  final String scanId;
  final String userId;
  final String plantTagId;
  final DateTime timestamp;
  final String imageUrl;
  final String? thumbnailBase64;
  final String? heatmapUrl;
  final List<DiseasePrediction> topPredictions;
  final double lesionAreaPercent;
  final List<GradCamHotspot> gradCamHotspots;
  final bool requiresKvkReview;
  final VerificationStatus verificationStatus;
  final String? kvkScientistNote;
  final String? kvkScientistId;
  final bool chemicalUnlocked;
  final String geoHash5; // 5-character privacy-preserving regional hash

  // LeafGuard Extended Properties
  final ImageQualityReport? qualityReport;
  final List<LeafRegionDiagnosis> regionDiagnoses;
  final List<LesionRegion> lesionRegions;
  final SeverityGrade severityGrade;
  final bool isEarlyStageAlert;
  final String? secondOpinionExpertId;
  final String? stressEtiology; // 'biotic_infectious_disease' | 'abiotic_nutrient_stress' | 'healthy'

  const LeafScanRecord({
    required this.scanId,
    required this.userId,
    required this.plantTagId,
    required this.timestamp,
    required this.imageUrl,
    this.thumbnailBase64,
    this.heatmapUrl,
    required this.topPredictions,
    required this.lesionAreaPercent,
    this.gradCamHotspots = const [],
    required this.requiresKvkReview,
    required this.verificationStatus,
    this.kvkScientistNote,
    this.kvkScientistId,
    this.chemicalUnlocked = false,
    required this.geoHash5,
    this.qualityReport,
    this.regionDiagnoses = const [],
    this.lesionRegions = const [],
    this.severityGrade = SeverityGrade.mild,
    this.isEarlyStageAlert = false,
    this.secondOpinionExpertId,
    this.stressEtiology,
  });

  LeafScanRecord copyWith({
    String? scanId,
    String? userId,
    String? plantTagId,
    DateTime? timestamp,
    String? imageUrl,
    String? thumbnailBase64,
    String? heatmapUrl,
    List<DiseasePrediction>? topPredictions,
    double? lesionAreaPercent,
    List<GradCamHotspot>? gradCamHotspots,
    bool? requiresKvkReview,
    VerificationStatus? verificationStatus,
    String? kvkScientistNote,
    String? kvkScientistId,
    bool? chemicalUnlocked,
    String? geoHash5,
    ImageQualityReport? qualityReport,
    List<LeafRegionDiagnosis>? regionDiagnoses,
    List<LesionRegion>? lesionRegions,
    SeverityGrade? severityGrade,
    bool? isEarlyStageAlert,
    String? secondOpinionExpertId,
    String? stressEtiology,
  }) {
    return LeafScanRecord(
      scanId: scanId ?? this.scanId,
      userId: userId ?? this.userId,
      plantTagId: plantTagId ?? this.plantTagId,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      heatmapUrl: heatmapUrl ?? this.heatmapUrl,
      topPredictions: topPredictions ?? this.topPredictions,
      lesionAreaPercent: lesionAreaPercent ?? this.lesionAreaPercent,
      gradCamHotspots: gradCamHotspots ?? this.gradCamHotspots,
      requiresKvkReview: requiresKvkReview ?? this.requiresKvkReview,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      kvkScientistNote: kvkScientistNote ?? this.kvkScientistNote,
      kvkScientistId: kvkScientistId ?? this.kvkScientistId,
      chemicalUnlocked: chemicalUnlocked ?? this.chemicalUnlocked,
      geoHash5: geoHash5 ?? this.geoHash5,
      qualityReport: qualityReport ?? this.qualityReport,
      regionDiagnoses: regionDiagnoses ?? this.regionDiagnoses,
      lesionRegions: lesionRegions ?? this.lesionRegions,
      severityGrade: severityGrade ?? this.severityGrade,
      isEarlyStageAlert: isEarlyStageAlert ?? this.isEarlyStageAlert,
      secondOpinionExpertId:
          secondOpinionExpertId ?? this.secondOpinionExpertId,
      stressEtiology: stressEtiology ?? this.stressEtiology,
    );
  }

  /// Firestore type-safe serialization
  Map<String, dynamic> toFirestore() {
    return {
      'scanId': scanId,
      'userId': userId,
      'plantTagId': plantTagId,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'thumbnailBase64': thumbnailBase64,
      'heatmapUrl': heatmapUrl,
      'topPredictions': topPredictions.map((p) => p.toMap()).toList(),
      'lesionAreaPercent': lesionAreaPercent,
      'gradCamHotspots': gradCamHotspots.map((h) => h.toMap()).toList(),
      'requiresKvkReview': requiresKvkReview,
      'verificationStatus': verificationStatus.toFirestoreValue(),
      'kvkScientistNote': kvkScientistNote,
      'kvkScientistId': kvkScientistId,
      'chemicalUnlocked': chemicalUnlocked,
      'geoHash5': geoHash5,
      'qualityReport': qualityReport?.toMap(),
      'regionDiagnoses': regionDiagnoses.map((r) => r.toMap()).toList(),
      'lesionRegions': lesionRegions.map((r) => r.toMap()).toList(),
      'severityGrade': severityGrade.toFirestoreValue(),
      'isEarlyStageAlert': isEarlyStageAlert,
      'secondOpinionExpertId': secondOpinionExpertId,
      'stressEtiology': stressEtiology,
    };
  }

  factory LeafScanRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Cannot deserialize empty snapshot into LeafScanRecord');
    }
    return LeafScanRecord.fromMap(data, snapshot.id);
  }

  factory LeafScanRecord.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawTimestamp = map['timestamp'];
    DateTime parsedDate;
    if (rawTimestamp is Timestamp) {
      parsedDate = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedDate = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawPreds = map['topPredictions'];
    final List<DiseasePrediction> parsedPreds = [];
    if (rawPreds is List) {
      for (final item in rawPreds) {
        if (item is Map) {
          parsedPreds.add(
            DiseasePrediction.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawHotspots = map['gradCamHotspots'];
    final List<GradCamHotspot> parsedHotspots = [];
    if (rawHotspots is List) {
      for (final item in rawHotspots) {
        if (item is Map) {
          parsedHotspots.add(
            GradCamHotspot.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    // LeafGuard parsing
    final rawQuality = map['qualityReport'];
    final ImageQualityReport? parsedQuality = rawQuality is Map
        ? ImageQualityReport.fromMap(Map<String, dynamic>.from(rawQuality))
        : null;

    final rawRegions = map['regionDiagnoses'];
    final List<LeafRegionDiagnosis> parsedRegions = [];
    if (rawRegions is List) {
      for (final r in rawRegions) {
        if (r is Map) {
          parsedRegions.add(
            LeafRegionDiagnosis.fromMap(Map<String, dynamic>.from(r)),
          );
        }
      }
    }

    final rawLesionRegions = map['lesionRegions'];
    final List<LesionRegion> parsedLesionRegions = [];
    if (rawLesionRegions is List) {
      for (final lr in rawLesionRegions) {
        if (lr is Map) {
          parsedLesionRegions.add(
            LesionRegion.fromMap(Map<String, dynamic>.from(lr)),
          );
        }
      }
    }

    final double lesionPct =
        (map['lesionAreaPercent'] as num?)?.toDouble() ?? 0.0;
    final SeverityGrade parsedSeverity = map['severityGrade'] != null
        ? SeverityGrade.fromString(map['severityGrade'] as String?)
        : SeverityGrade.fromPercentage(lesionPct);

    return LeafScanRecord(
      scanId: docId ?? (map['scanId'] as String? ?? 'scan_unknown'),
      userId: map['userId'] as String? ?? '',
      plantTagId: map['plantTagId'] as String? ?? 'PLANT-001',
      timestamp: parsedDate,
      imageUrl: map['imageUrl'] as String? ?? (map['thumbnailBase64'] as String? ?? ''),
      thumbnailBase64: map['thumbnailBase64'] as String?,
      heatmapUrl: map['heatmapUrl'] as String?,
      topPredictions: parsedPreds,
      lesionAreaPercent: lesionPct,
      gradCamHotspots: parsedHotspots,
      requiresKvkReview: map['requiresKvkReview'] as bool? ?? false,
      verificationStatus: VerificationStatus.fromString(
        map['verificationStatus'] as String?,
      ),
      kvkScientistNote: map['kvkScientistNote'] as String?,
      kvkScientistId: map['kvkScientistId'] as String?,
      chemicalUnlocked: map['chemicalUnlocked'] as bool? ?? false,
      geoHash5: map['geoHash5'] as String? ?? '00000',
      qualityReport: parsedQuality,
      regionDiagnoses: parsedRegions,
      lesionRegions: parsedLesionRegions,
      severityGrade: parsedSeverity,
      isEarlyStageAlert: map['isEarlyStageAlert'] as bool? ?? false,
      secondOpinionExpertId: map['secondOpinionExpertId'] as String?,
      stressEtiology: map['stressEtiology'] as String?,
    );
  }
}


// =============================================================================
// 6. LEAFGUARD ECOSYSTEM MODELS
// =============================================================================

/// Feature #10: Verified Agricultural Expert / Scientist
@immutable
class VerifiedExpert {
  final String expertId;
  final String name;
  final String category; // 'plant_pathologist' | 'botanist' | 'agronomist' | 'entomologist' | 'horticulturist'
  final String qualification;
  final String institution;
  final String district;
  final List<String> languages;
  final String phone;
  final String email;
  final String verifiedBy;
  final bool isAvailableForSecondOpinion;

  const VerifiedExpert({
    required this.expertId,
    required this.name,
    required this.category,
    required this.qualification,
    required this.institution,
    required this.district,
    required this.languages,
    required this.phone,
    required this.email,
    required this.verifiedBy,
    this.isAvailableForSecondOpinion = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'expertId': expertId,
      'name': name,
      'category': category,
      'qualification': qualification,
      'institution': institution,
      'district': district,
      'languages': languages,
      'phone': phone,
      'email': email,
      'verifiedBy': verifiedBy,
      'isAvailableForSecondOpinion': isAvailableForSecondOpinion,
    };
  }

  factory VerifiedExpert.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Empty snapshot for VerifiedExpert');
    return VerifiedExpert.fromMap(data, snapshot.id);
  }

  factory VerifiedExpert.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawLangs = map['languages'];
    final List<String> parsedLangs =
        rawLangs is List ? rawLangs.map((e) => e.toString()).toList() : [];

    return VerifiedExpert(
      expertId: docId ?? (map['expertId'] as String? ?? 'expert_unknown'),
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'plant_pathologist',
      qualification: map['qualification'] as String? ?? '',
      institution: map['institution'] as String? ?? '',
      district: map['district'] as String? ?? '',
      languages: parsedLangs,
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      verifiedBy: map['verifiedBy'] as String? ?? 'ICAR-KVK Authority',
      isAvailableForSecondOpinion:
          map['isAvailableForSecondOpinion'] as bool? ?? true,
    );
  }
}

/// Feature #11: NGO Partner (LeafGuard Connect Ground Ecosystem)
@immutable
class NgoPartner {
  final String ngoId;
  final String name;
  final String registrationNumber;
  final List<String> focusAreas;
  final List<String> districtsServed;
  final String fieldRepName;
  final String fieldRepContact;
  final List<String> activeAwarenessPrograms;
  final List<String> farmerSupportSchemes;

  const NgoPartner({
    required this.ngoId,
    required this.name,
    this.registrationNumber = '',
    this.focusAreas = const [],
    this.districtsServed = const [],
    this.fieldRepName = '',
    this.fieldRepContact = '',
    List<String>? activeAwarenessPrograms,
    List<String>? programsOffered,
    List<String>? farmerSupportSchemes,
    List<String>? schemesEligible,
  })  : activeAwarenessPrograms =
            activeAwarenessPrograms ?? programsOffered ?? const [],
        farmerSupportSchemes =
            farmerSupportSchemes ?? schemesEligible ?? const [];

  List<String> get programsOffered => activeAwarenessPrograms;
  List<String> get schemesEligible => farmerSupportSchemes;

  Map<String, dynamic> toFirestore() {
    return {
      'ngoId': ngoId,
      'name': name,
      'registrationNumber': registrationNumber,
      'focusAreas': focusAreas,
      'districtsServed': districtsServed,
      'fieldRepName': fieldRepName,
      'fieldRepContact': fieldRepContact,
      'activeAwarenessPrograms': activeAwarenessPrograms,
      'farmerSupportSchemes': farmerSupportSchemes,
      'programsOffered': programsOffered,
      'schemesEligible': schemesEligible,
    };
  }

  factory NgoPartner.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Empty snapshot for NgoPartner');
    return NgoPartner.fromMap(data, snapshot.id);
  }

  factory NgoPartner.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawFocus = map['focusAreas'];
    final rawDistricts = map['districtsServed'];
    final rawPrograms = map['activeAwarenessPrograms'];
    final rawSchemes = map['farmerSupportSchemes'];

    return NgoPartner(
      ngoId: docId ?? (map['ngoId'] as String? ?? 'ngo_unknown'),
      name: map['name'] as String? ?? '',
      registrationNumber: map['registrationNumber'] as String? ?? '',
      focusAreas: rawFocus is List ? rawFocus.map((e) => e.toString()).toList() : [],
      districtsServed:
          rawDistricts is List ? rawDistricts.map((e) => e.toString()).toList() : [],
      fieldRepName: map['fieldRepName'] as String? ?? '',
      fieldRepContact: map['fieldRepContact'] as String? ?? '',
      activeAwarenessPrograms:
          rawPrograms is List ? rawPrograms.map((e) => e.toString()).toList() : [],
      farmerSupportSchemes:
          rawSchemes is List ? rawSchemes.map((e) => e.toString()).toList() : [],
    );
  }
}

/// Feature #14: Institution-Authenticated Verified Outbreak Report
@immutable
class VerifiedOutbreakReport {
  final String reportId;
  final String submittedByUid;
  final String organizationName;
  final String organizationType; // 'kvk' | 'verified_ngo' | 'agri_expert' | 'authorized_field_org'
  final String cropName;
  final String diseaseId;
  final SeverityGrade severityGrade;
  final String geoHash5;
  final String district;
  final String taluka;
  final String imageUrl;
  final DateTime verifiedAt;
  final int confirmedCasesCount;
  final String verifiedByInstitutionId;
  final String verifiedByInstitutionName;
  final String recommendedAction;

  const VerifiedOutbreakReport({
    required this.reportId,
    String? submittedByUid,
    String? organizationName,
    String? organizationType,
    String? cropName,
    String? diseaseId,
    String? diseaseLabel,
    SeverityGrade? severityGrade,
    String? severityLevel,
    required this.geoHash5,
    required this.district,
    required this.taluka,
    String? imageUrl,
    required this.verifiedAt,
    this.confirmedCasesCount = 1,
    String? verifiedByInstitutionId,
    String? verifiedByInstitutionName,
    this.recommendedAction = '',
  })  : submittedByUid = submittedByUid ?? verifiedByInstitutionId ?? 'anonymous',
        organizationName = organizationName ?? verifiedByInstitutionName ?? 'KVK Institution',
        verifiedByInstitutionName = verifiedByInstitutionName ?? organizationName ?? 'KVK Institution',
        organizationType = organizationType ?? 'kvk',
        cropName = cropName ?? 'General Crop',
        diseaseId = diseaseId ?? diseaseLabel ?? 'unknown_disease',
        severityGrade = severityGrade ??
            (severityLevel == 'HIGH' ? SeverityGrade.severe : SeverityGrade.moderate),
        imageUrl = imageUrl ?? '',
        verifiedByInstitutionId = verifiedByInstitutionId ?? submittedByUid ?? '';

  String get diseaseLabel => diseaseId;
  String get severityLevel => severityGrade == SeverityGrade.severe
      ? 'HIGH'
      : (severityGrade == SeverityGrade.moderate ? 'MEDIUM' : 'LOW');

  Map<String, dynamic> toFirestore() {
    return {
      'reportId': reportId,
      'submittedByUid': submittedByUid,
      'organizationName': organizationName,
      'organizationType': organizationType,
      'cropName': cropName,
      'diseaseId': diseaseId,
      'diseaseLabel': diseaseLabel,
      'severityGrade': severityGrade.toFirestoreValue(),
      'severityLevel': severityLevel,
      'geoHash5': geoHash5,
      'district': district,
      'taluka': taluka,
      'imageUrl': imageUrl,
      'verifiedAt': Timestamp.fromDate(verifiedAt),
      'confirmedCasesCount': confirmedCasesCount,
      'verifiedByInstitutionId': verifiedByInstitutionId,
      'verifiedByInstitutionName': verifiedByInstitutionName,
      'recommendedAction': recommendedAction,
    };
  }

  factory VerifiedOutbreakReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Empty snapshot for VerifiedOutbreakReport');
    return VerifiedOutbreakReport.fromMap(data, snapshot.id);
  }

  factory VerifiedOutbreakReport.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawDate = map['verifiedAt'];
    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return VerifiedOutbreakReport(
      reportId: docId ?? (map['reportId'] as String? ?? 'rep_unknown'),
      submittedByUid: map['submittedByUid'] as String? ?? '',
      organizationName: map['organizationName'] as String? ?? '',
      organizationType: map['organizationType'] as String? ?? 'kvk',
      cropName: map['cropName'] as String? ?? '',
      diseaseId: (map['diseaseId'] ?? map['diseaseLabel']) as String? ?? '',
      severityGrade: SeverityGrade.fromString(map['severityGrade'] as String?),
      geoHash5: map['geoHash5'] as String? ?? '00000',
      district: map['district'] as String? ?? '',
      taluka: map['taluka'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      verifiedAt: parsedDate,
      confirmedCasesCount: (map['confirmedCasesCount'] as num?)?.toInt() ?? 1,
      verifiedByInstitutionId: map['verifiedByInstitutionId'] as String?,
      verifiedByInstitutionName: map['verifiedByInstitutionName'] as String? ?? '',
      recommendedAction: map['recommendedAction'] as String? ?? '',
    );
  }
}

/// Feature #16: CSR / Agritech Funding Partner
@immutable
class CsrFundingPartner {
  final String partnerId;
  final String organizationName;
  final String fundingType; // 'ngo_grant' | 'csr_fund' | 'agri_innovation_grant' | 'university_mou' | 'incubator'
  final String focusScope;
  final String contactEmail;
  final String status; // 'active' | 'review' | 'mou_signed' | 'completed'

  const CsrFundingPartner({
    required this.partnerId,
    required this.organizationName,
    required this.fundingType,
    required this.focusScope,
    required this.contactEmail,
    this.status = 'active',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'partnerId': partnerId,
      'organizationName': organizationName,
      'fundingType': fundingType,
      'focusScope': focusScope,
      'contactEmail': contactEmail,
      'status': status,
    };
  }

  factory CsrFundingPartner.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Empty snapshot for CsrFundingPartner');
    return CsrFundingPartner.fromMap(data, snapshot.id);
  }

  factory CsrFundingPartner.fromMap(Map<String, dynamic> map, [String? docId]) {
    return CsrFundingPartner(
      partnerId: docId ?? (map['partnerId'] as String? ?? 'partner_unknown'),
      organizationName: map['organizationName'] as String? ?? '',
      fundingType: map['fundingType'] as String? ?? 'csr_fund',
      focusScope: map['focusScope'] as String? ?? '',
      contactEmail: map['contactEmail'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }
}

/// Feature #11: Farmer Assistance Request to NGO Partner
@immutable
class NgoAssistanceRequest {
  final String requestId;
  final String farmerUid;
  final String farmerName;
  final String farmerPhone;
  final String ngoId;
  final String district;
  final String taluka;
  final String cropName;
  final String issueDescription;
  final String status; // 'PENDING' | 'IN_PROGRESS' | 'RESOLVED'
  final DateTime createdAt;

  const NgoAssistanceRequest({
    required this.requestId,
    required this.farmerUid,
    required this.farmerName,
    required this.farmerPhone,
    required this.ngoId,
    required this.district,
    required this.taluka,
    required this.cropName,
    required this.issueDescription,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'farmerUid': farmerUid,
      'farmerName': farmerName,
      'farmerPhone': farmerPhone,
      'ngoId': ngoId,
      'district': district,
      'taluka': taluka,
      'cropName': cropName,
      'issueDescription': issueDescription,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NgoAssistanceRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawDate = map['createdAt'];
    DateTime parsed = DateTime.now();
    if (rawDate is Timestamp) parsed = rawDate.toDate();
    return NgoAssistanceRequest(
      requestId: docId ?? (map['requestId'] as String? ?? ''),
      farmerUid: map['farmerUid'] as String? ?? '',
      farmerName: map['farmerName'] as String? ?? '',
      farmerPhone: map['farmerPhone'] as String? ?? '',
      ngoId: map['ngoId'] as String? ?? '',
      district: map['district'] as String? ?? '',
      taluka: map['taluka'] as String? ?? '',
      cropName: map['cropName'] as String? ?? '',
      issueDescription: map['issueDescription'] as String? ?? '',
      status: map['status'] as String? ?? 'PENDING',
      createdAt: parsed,
    );
  }
}

/// Feature #10: Formal Second Opinion Request from Verified Expert
@immutable
class SecondOpinionRequest {
  final String requestId;
  final String farmerUid;
  final String scanId;
  final String assignedExpertId;
  final String status; // 'PENDING' | 'IN_REVIEW' | 'COMPLETED'
  final String farmerQuery;
  final String? expertFeedback;
  final String? thumbnailBase64;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const SecondOpinionRequest({
    required this.requestId,
    required this.farmerUid,
    required this.scanId,
    String? assignedExpertId,
    String? expertId,
    this.status = 'PENDING',
    String? farmerQuery,
    String? symptomDescription,
    String? expertFeedback,
    String? expertDiagnosis,
    this.thumbnailBase64,
    this.imageUrl,
    required this.createdAt,
    this.resolvedAt,
  })  : assignedExpertId = assignedExpertId ?? expertId ?? '',
        farmerQuery = farmerQuery ?? symptomDescription ?? '',
        expertFeedback = expertFeedback ?? expertDiagnosis;

  String get expertId => assignedExpertId;
  String? get expertDiagnosis => expertFeedback;
  String get symptomDescription => farmerQuery;

  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'farmerUid': farmerUid,
      'scanId': scanId,
      'assignedExpertId': assignedExpertId,
      'expertId': expertId,
      'status': status,
      'farmerQuery': farmerQuery,
      'expertFeedback': expertFeedback,
      'expertDiagnosis': expertDiagnosis,
      'thumbnailBase64': thumbnailBase64,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  factory SecondOpinionRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawCreated = map['createdAt'];
    DateTime parsedCreated = DateTime.now();
    if (rawCreated is Timestamp) parsedCreated = rawCreated.toDate();

    final rawResolved = map['resolvedAt'];
    DateTime? parsedResolved;
    if (rawResolved is Timestamp) parsedResolved = rawResolved.toDate();

    return SecondOpinionRequest(
      requestId: docId ?? (map['requestId'] as String? ?? ''),
      farmerUid: map['farmerUid'] as String? ?? '',
      scanId: map['scanId'] as String? ?? '',
      assignedExpertId: (map['assignedExpertId'] ?? map['expertId']) as String? ?? '',
      status: map['status'] as String? ?? 'PENDING',
      farmerQuery: map['farmerQuery'] as String? ?? '',
      expertFeedback: (map['expertFeedback'] ?? map['expertDiagnosis']) as String?,
      thumbnailBase64: map['thumbnailBase64'] as String?,
      imageUrl: map['imageUrl'] as String?,
      createdAt: parsedCreated,
      resolvedAt: parsedResolved,
    );
  }
}

/// Feature #16: Institutional & CSR Partnership Inquiry
@immutable
class PartnershipInquiry {
  final String inquiryId;
  final String organizationName;
  final String contactPerson;
  final String email;
  final String phone;
  final String partnershipType; // 'csr_funding_grant' | 'field_pilot' | 'kvk_onboarding' | 'agri_incubator' | 'philanthropic_mou'
  final String proposedScope;
  final List<String> targetDistricts;
  final double? estimatedBudgetInr;
  final DateTime submittedAt;
  final String status; // 'SUBMITTED' | 'IN_REVIEW' | 'ACCEPTED'

  const PartnershipInquiry({
    required this.inquiryId,
    required this.organizationName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.partnershipType,
    required this.proposedScope,
    required this.targetDistricts,
    this.estimatedBudgetInr,
    required this.submittedAt,
    this.status = 'SUBMITTED',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'inquiryId': inquiryId,
      'organizationName': organizationName,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'partnershipType': partnershipType,
      'proposedScope': proposedScope,
      'targetDistricts': targetDistricts,
      'estimatedBudgetInr': estimatedBudgetInr,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
    };
  }

  factory PartnershipInquiry.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawDate = map['submittedAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) parsedDate = rawDate.toDate();

    return PartnershipInquiry(
      inquiryId: docId ?? (map['inquiryId'] as String? ?? ''),
      organizationName: map['organizationName'] as String? ?? '',
      contactPerson: map['contactPerson'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      partnershipType: map['partnershipType'] as String? ?? 'csr_funding_grant',
      proposedScope: map['proposedScope'] as String? ?? '',
      targetDistricts: (map['targetDistricts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      estimatedBudgetInr: (map['estimatedBudgetInr'] as num?)?.toDouble(),
      submittedAt: parsedDate,
      status: map['status'] as String? ?? 'SUBMITTED',
    );
  }
}

/// Feature #16: Live Aggregated Impact Telemetry
@immutable
class ImpactTelemetry {
  final int totalScansCount;
  final int nutrientDeficienciesDiverted;
  final int expertSecondOpinionsCompleted;
  final int verifiedOutbreakAlertsIssued;
  final DateTime lastUpdated;

  const ImpactTelemetry({
    required this.totalScansCount,
    required this.nutrientDeficienciesDiverted,
    required this.expertSecondOpinionsCompleted,
    required this.verifiedOutbreakAlertsIssued,
    required this.lastUpdated,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'totalScansCount': totalScansCount,
      'nutrientDeficienciesDiverted': nutrientDeficienciesDiverted,
      'expertSecondOpinionsCompleted': expertSecondOpinionsCompleted,
      'verifiedOutbreakAlertsIssued': verifiedOutbreakAlertsIssued,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory ImpactTelemetry.fromMap(Map<String, dynamic> map) {
    final rawDate = map['lastUpdated'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) parsedDate = rawDate.toDate();

    return ImpactTelemetry(
      totalScansCount: (map['totalScansCount'] as num?)?.toInt() ?? 0,
      nutrientDeficienciesDiverted:
          (map['nutrientDeficienciesDiverted'] as num?)?.toInt() ?? 0,
      expertSecondOpinionsCompleted:
          (map['expertSecondOpinionsCompleted'] as num?)?.toInt() ?? 0,
      verifiedOutbreakAlertsIssued:
          (map['verifiedOutbreakAlertsIssued'] as num?)?.toInt() ?? 0,
      lastUpdated: parsedDate,
    );
  }
}

// =============================================================================
// UNIFIED KISANSETU DATA LAYER MODELS
// =============================================================================

/// Farmer Profile stored in Firestore `farmers/{mobileE164}`
@immutable
class FarmerProfile {
  final String mobileE164; // e.g. "+919876543210"
  final String fullName;
  final String village;
  final String district;
  final String state;
  final String pincode;
  final String preferredLanguage; // 'mr', 'hi', 'en'
  final bool notificationsEnabled;
  final bool voiceGuidanceEnabled;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isRegistered;

  const FarmerProfile({
    required this.mobileE164,
    required this.fullName,
    required this.village,
    required this.district,
    required this.state,
    this.pincode = '',
    this.preferredLanguage = 'mr',
    this.notificationsEnabled = true,
    this.voiceGuidanceEnabled = true,
    required this.createdAt,
    required this.lastLoginAt,
    this.isRegistered = true,
  });

  Map<String, dynamic> toMap() => {
    'mobileE164': mobileE164,
    'fullName': fullName,
    'village': village,
    'district': district,
    'state': state,
    'pincode': pincode,
    'preferredLanguage': preferredLanguage,
    'notificationsEnabled': notificationsEnabled,
    'voiceGuidanceEnabled': voiceGuidanceEnabled,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastLoginAt': Timestamp.fromDate(lastLoginAt),
    'isRegistered': isRegistered,
  };

  factory FarmerProfile.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawCreated = map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    }

    final rawLogin = map['lastLoginAt'];
    DateTime lastLoginAt = DateTime.now();
    if (rawLogin is Timestamp) {
      lastLoginAt = rawLogin.toDate();
    } else if (rawLogin is String) {
      lastLoginAt = DateTime.tryParse(rawLogin) ?? DateTime.now();
    }

    return FarmerProfile(
      mobileE164: docId ?? map['mobileE164']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? map['name']?.toString() ?? '',
      village: map['village']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      pincode: map['pincode']?.toString() ?? '',
      preferredLanguage: map['preferredLanguage']?.toString() ?? 'mr',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      voiceGuidanceEnabled: map['voiceGuidanceEnabled'] as bool? ?? true,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isRegistered: map['isRegistered'] as bool? ?? true,
    );
  }

  FarmerProfile copyWith({
    String? mobileE164,
    String? fullName,
    String? village,
    String? district,
    String? state,
    String? pincode,
    String? preferredLanguage,
    bool? notificationsEnabled,
    bool? voiceGuidanceEnabled,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isRegistered,
  }) {
    return FarmerProfile(
      mobileE164: mobileE164 ?? this.mobileE164,
      fullName: fullName ?? this.fullName,
      village: village ?? this.village,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}

/// Unified scan log stored in Firestore `scan_logs/{flxScanId}`
@immutable
class ScanLogEntry {
  final String flxScanId;
  final String farmerMobile;
  final String canonicalId;
  final String crop;
  final double confidence;
  final double normalizedEntropy;
  final double latitude;
  final double longitude;
  final String geoHash;
  final ClinicalSafetyState safetyState;
  final VerificationStatus verificationStatus;
  final double lesionAreaPercentage;
  final SeverityGrade severityGrade;
  final String? imageUrl;
  final String? thumbnailBase64;
  final DateTime timestamp;

  const ScanLogEntry({
    required this.flxScanId,
    required this.farmerMobile,
    required this.canonicalId,
    required this.crop,
    required this.confidence,
    required this.normalizedEntropy,
    required this.latitude,
    required this.longitude,
    required this.geoHash,
    required this.safetyState,
    required this.verificationStatus,
    this.lesionAreaPercentage = 0.0,
    this.severityGrade = SeverityGrade.mild,
    this.imageUrl,
    this.thumbnailBase64,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'flxScanId': flxScanId,
    'farmerMobile': farmerMobile,
    'canonicalId': canonicalId,
    'crop': crop,
    'confidence': confidence,
    'normalizedEntropy': normalizedEntropy,
    'latitude': latitude,
    'longitude': longitude,
    'geoHash': geoHash,
    'safetyState': safetyState.toFirestoreValue(),
    'verificationStatus': verificationStatus.toFirestoreValue(),
    'lesionAreaPercentage': lesionAreaPercentage,
    'severityGrade': severityGrade.toFirestoreValue(),
    'imageUrl': imageUrl,
    'thumbnailBase64': thumbnailBase64,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory ScanLogEntry.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawTime = map['timestamp'];
    DateTime time = DateTime.now();
    if (rawTime is Timestamp) {
      time = rawTime.toDate();
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    return ScanLogEntry(
      flxScanId: docId ?? map['flxScanId']?.toString() ?? '',
      farmerMobile: map['farmerMobile']?.toString() ?? '',
      canonicalId: map['canonicalId']?.toString() ?? 'unknown',
      crop: map['crop']?.toString() ?? 'Crop',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      normalizedEntropy: (map['normalizedEntropy'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      geoHash: map['geoHash']?.toString() ?? '',
      safetyState: ClinicalSafetyState.fromString(map['safetyState'] as String?),
      verificationStatus: VerificationStatus.fromString(map['verificationStatus'] as String?),
      lesionAreaPercentage: (map['lesionAreaPercentage'] as num?)?.toDouble() ?? 0.0,
      severityGrade: SeverityGrade.fromString(map['severityGrade'] as String?),
      imageUrl: map['imageUrl'] as String?,
      thumbnailBase64: map['thumbnailBase64'] as String?,
      timestamp: time,
    );
  }
}

/// Six polymorphic assistance categories supported by KisanSetu / LeafGuard Connect
enum AssistanceCategory {
  financial,
  inputs,
  equipment,
  emergency,
  technical,
  ngo;

  String get value => name;

  static AssistanceCategory fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'financial':
        return AssistanceCategory.financial;
      case 'inputs':
        return AssistanceCategory.inputs;
      case 'equipment':
        return AssistanceCategory.equipment;
      case 'emergency':
        return AssistanceCategory.emergency;
      case 'technical':
        return AssistanceCategory.technical;
      case 'ngo':
      default:
        return AssistanceCategory.ngo;
    }
  }
}

/// Unified polymorphic assistance application stored in Firestore `assistance_applications/{appId}`
@immutable
class AssistanceApplication {
  final String appId;
  final String farmerMobile;
  final String farmerName;
  final String district;
  final String state;
  final String pinCode;
  final AssistanceCategory category;
  final String programId;
  final String programTitle;
  final String details;
  final double requestedAmount;
  final String status; // 'PENDING', 'APPROVED', 'DISBURSED', 'REJECTED'
  final DateTime appliedAt;
  final Map<String, dynamic> metadata;

  const AssistanceApplication({
    required this.appId,
    required this.farmerMobile,
    required this.farmerName,
    required this.district,
    required this.state,
    this.pinCode = '',
    required this.category,
    required this.programId,
    required this.programTitle,
    required this.details,
    this.requestedAmount = 0.0,
    this.status = 'PENDING',
    required this.appliedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
    'appId': appId,
    'farmerMobile': farmerMobile,
    'farmerName': farmerName,
    'district': district,
    'state': state,
    'pinCode': pinCode,
    'category': category.value,
    'programId': programId,
    'programTitle': programTitle,
    'details': details,
    'requestedAmount': requestedAmount,
    'status': status,
    'appliedAt': Timestamp.fromDate(appliedAt),
    'metadata': metadata,
  };

  factory AssistanceApplication.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawTime = map['appliedAt'];
    DateTime time = DateTime.now();
    if (rawTime is Timestamp) {
      time = rawTime.toDate();
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    return AssistanceApplication(
      appId: docId ?? map['appId']?.toString() ?? '',
      farmerMobile: map['farmerMobile']?.toString() ?? '',
      farmerName: map['farmerName']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      pinCode: map['pinCode']?.toString() ?? '',
      category: AssistanceCategory.fromString(map['category'] as String?),
      programId: map['programId']?.toString() ?? '',
      programTitle: map['programTitle']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      requestedAmount: (map['requestedAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'PENDING',
      appliedAt: time,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}

/// Available government or NGO assistance program stored in Firestore `available_programs/{programId}`
@immutable
class AidProgram {
  final String programId;
  final AssistanceCategory category;
  final Map<String, String> title; // Trilingual ('en', 'hi', 'mr')
  final Map<String, String> description;
  final String eligibleState; // "ALL" or specific state
  final String sponsoringAgency;
  final double maxBenefitAmount;
  final List<String> requiredDocuments;
  final bool isActive;
  final bool isInformationalOnly;

  const AidProgram({
    required this.programId,
    required this.category,
    required this.title,
    required this.description,
    this.eligibleState = 'ALL',
    required this.sponsoringAgency,
    this.maxBenefitAmount = 0.0,
    this.requiredDocuments = const [],
    this.isActive = true,
    this.isInformationalOnly = false,
  });

  Map<String, dynamic> toMap() => {
    'programId': programId,
    'category': category.value,
    'title': title,
    'description': description,
    'eligibleState': eligibleState,
    'sponsoringAgency': sponsoringAgency,
    'maxBenefitAmount': maxBenefitAmount,
    'requiredDocuments': requiredDocuments,
    'isActive': isActive,
    'isInformationalOnly': isInformationalOnly,
  };

  factory AidProgram.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawTitle = map['title'];
    final Map<String, String> parsedTitle = {};
    if (rawTitle is Map) {
      rawTitle.forEach((k, v) => parsedTitle[k.toString()] = v.toString());
    } else if (rawTitle is String) {
      parsedTitle['en'] = rawTitle;
    }

    final rawDesc = map['description'];
    final Map<String, String> parsedDesc = {};
    if (rawDesc is Map) {
      rawDesc.forEach((k, v) => parsedDesc[k.toString()] = v.toString());
    } else if (rawDesc is String) {
      parsedDesc['en'] = rawDesc;
    }

    final rawDocs = map['requiredDocuments'];
    final List<String> parsedDocs =
        rawDocs is List ? rawDocs.map((e) => e.toString()).toList() : [];

    return AidProgram(
      programId: docId ?? map['programId']?.toString() ?? '',
      category: AssistanceCategory.fromString(map['category'] as String?),
      title: parsedTitle,
      description: parsedDesc,
      eligibleState: map['eligibleState']?.toString() ?? 'ALL',
      sponsoringAgency: map['sponsoringAgency']?.toString() ?? '',
      maxBenefitAmount: (map['maxBenefitAmount'] as num?)?.toDouble() ?? 0.0,
      requiredDocuments: parsedDocs,
      isActive: map['isActive'] as bool? ?? true,
      isInformationalOnly: map['isInformationalOnly'] as bool? ?? false,
    );
  }
}

/// Expert consultation tracking stored in Firestore `consultations/{consultId}`
@immutable
class ConsultationRequest {
  final String consultId;
  final String farmerMobile;
  final String farmerName;
  final String expertId;
  final String expertName;
  final String crop;
  final String canonicalId;
  final String? scanId;
  final String farmerQuery;
  final String? expertResponse;
  final String status; // 'PENDING', 'IN_REVIEW', 'COMPLETED'
  final DateTime submittedAt;
  final DateTime? resolvedAt;

  const ConsultationRequest({
    required this.consultId,
    required this.farmerMobile,
    required this.farmerName,
    required this.expertId,
    required this.expertName,
    required this.crop,
    required this.canonicalId,
    this.scanId,
    required this.farmerQuery,
    this.expertResponse,
    this.status = 'PENDING',
    required this.submittedAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
    'consultId': consultId,
    'farmerMobile': farmerMobile,
    'farmerName': farmerName,
    'expertId': expertId,
    'expertName': expertName,
    'crop': crop,
    'canonicalId': canonicalId,
    'scanId': scanId,
    'farmerQuery': farmerQuery,
    'expertResponse': expertResponse,
    'status': status,
    'submittedAt': Timestamp.fromDate(submittedAt),
    'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
  };

  factory ConsultationRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawSub = map['submittedAt'];
    DateTime submittedAt = DateTime.now();
    if (rawSub is Timestamp) {
      submittedAt = rawSub.toDate();
    } else if (rawSub is String) {
      submittedAt = DateTime.tryParse(rawSub) ?? DateTime.now();
    }

    final rawRes = map['resolvedAt'];
    DateTime? resolvedAt;
    if (rawRes is Timestamp) {
      resolvedAt = rawRes.toDate();
    } else if (rawRes is String) {
      resolvedAt = DateTime.tryParse(rawRes);
    }

    return ConsultationRequest(
      consultId: docId ?? map['consultId']?.toString() ?? '',
      farmerMobile: map['farmerMobile']?.toString() ?? '',
      farmerName: map['farmerName']?.toString() ?? '',
      expertId: map['expertId']?.toString() ?? '',
      expertName: map['expertName']?.toString() ?? '',
      crop: map['crop']?.toString() ?? '',
      canonicalId: map['canonicalId']?.toString() ?? '',
      scanId: map['scanId']?.toString(),
      farmerQuery: map['farmerQuery']?.toString() ?? '',
      expertResponse: map['expertResponse']?.toString(),
      status: map['status']?.toString() ?? 'PENDING',
      submittedAt: submittedAt,
      resolvedAt: resolvedAt,
    );
  }
}
