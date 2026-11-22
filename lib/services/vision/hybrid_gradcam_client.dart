import 'dart:convert';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/florax_models.dart';
import 'isolate_lesion_analyzer.dart';
import 'tflite_isolate_service.dart';

/// Comprehensive diagnostic result unifying Edge TFLite and Cloud PyTorch Grad-CAM
@immutable
class HybridDiagnosticResult {
  /// Privacy-sanitized, EXIF-stripped image bytes ready for storage upload
  final Uint8List sanitizedImageBytes;

  /// Top 3 classified disease candidates
  final List<DiseasePrediction> topCandidates;

  /// Computed lesion-to-leaf area percentage
  final double lesionAreaPercent;

  /// Spatial explainability hotspots (derived from PyTorch Grad-CAM or local CIELAB centroids)
  final List<GradCamHotspot> gradCamHotspots;

  /// Optional base64 thermal heatmap visualization (returned by PyTorch Grad-CAM)
  final String? heatmapBase64;

  /// True if top candidate confidence < 75% requiring KVK scientist audit
  final bool requiresKvkReview;

  /// Diagnostic verification status ('AI_VERIFIED' or 'PENDING_KVK_REVIEW')
  final VerificationStatus verificationStatus;

  /// True if cloud PyTorch Grad-CAM responded; false if on-device TFLite fallback executed
  final bool isCloudInference;

  /// End-to-end processing latency in milliseconds
  final int totalLatencyMs;

  /// Feature #1: Spatial infected bounding regions
  final List<LesionRegion> lesionRegions;

  /// Feature #2: Stress etiology ('biotic_infectious_disease' | 'abiotic_nutrient_stress' | 'healthy')
  final String stressEtiology;

  const HybridDiagnosticResult({
    required this.sanitizedImageBytes,
    required this.topCandidates,
    required this.lesionAreaPercent,
    required this.gradCamHotspots,
    this.heatmapBase64,
    required this.requiresKvkReview,
    required this.verificationStatus,
    required this.isCloudInference,
    required this.totalLatencyMs,
    this.lesionRegions = const [],
    this.stressEtiology = 'biotic_infectious_disease',
  });
}

/// Principal Resilient Computer Vision Client
///
/// Orchestrates parallel edge vision (TFLite + HSV/CIELAB) and remote PyTorch
/// Grad-CAM inference. Guarantees zero UI crashes on 2G connections or offline fields.
class HybridGradCamClient {
  final Dio _dio;
  final TfliteIsolateService _tfliteService;

  // Default points to localhost (works over `adb reverse tcp:8000 tcp:8000` or configured cloud endpoint)
  static const String defaultEndpoint = AppConfig.fastApiGradCamBaseUrl;

  HybridGradCamClient({
    Dio? dio,
    TfliteIsolateService? tfliteService,
    String baseUrl = defaultEndpoint,
  })  : _tfliteService = tfliteService ?? TfliteIsolateService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                sendTimeout: const Duration(seconds: 4),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Executes resilient hybrid leaf analysis:
  /// 1. Runs background Isolate lesion analyzer (EXIF stripping, HSV/CIELAB thresholding)
  /// 2. Spawns on-device TFLite inference in parallel
  /// 3. Concurrently calls FastAPI PyTorch Grad-CAM microservice with Firebase App Check
  /// 4. Gracefully falls back to local edge results if cloud times out (> 4s) or is unreachable
  Future<HybridDiagnosticResult> diagnoseLeaf({
    required Uint8List rawCameraBytes,
    String cropType = 'Tomato',
    bool simulateLowConfidence = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Mandatory local processing: strip EXIF and extract HSV/CIELAB lesion geometry
    final LesionAnalysisResult localAnalysis = await IsolateLesionAnalyzer.analyze(
      rawCameraBytes: rawCameraBytes,
    );

    // 2. Prepare Cloud PyTorch Request & Local TFLite concurrently
    Future<Response<Map<String, dynamic>>?> cloudRequestFuture = _fetchCloudGradCam(
      sanitizedBytes: localAnalysis.sanitizedImageBytes,
      cropType: cropType,
      simulateLowConfidence: simulateLowConfidence,
    );

    Future<TfliteInferenceResult> localInferenceFuture = _tfliteService.classifyImageBytes(
      localAnalysis.sanitizedImageBytes,
    );

    // 3. Await cloud response with safe exception interception
    Response<Map<String, dynamic>>? cloudResponse;
    try {
      cloudResponse = await cloudRequestFuture;
    } catch (e) {
      debugPrint('[FloraX Hybrid] Cloud request intercepted: $e');
      cloudResponse = null;
    }

    // 4. Resolve: Cloud PyTorch Success vs. Local Edge Fallback
    if (cloudResponse != null && cloudResponse.statusCode == 200 && cloudResponse.data != null) {
      try {
        final data = cloudResponse.data!;
        debugPrint('[FloraX Hybrid] Cloud PyTorch Grad-CAM response received successfully.');

        final rawCandidates = data['topCandidates'] as List<dynamic>? ?? [];
        final List<DiseasePrediction> cloudPredictions = rawCandidates.map((c) {
          final map = c as Map<String, dynamic>;
          final double conf = (map['confidence'] as num?)?.toDouble() ?? 0.0;
          // Normalize percentage to 0.0 - 1.0 if returned as 0 - 100
          final double normalizedConf = conf > 1.0 ? conf / 100.0 : conf;

          return DiseasePrediction(
            labelId: map['id'] as String? ?? 'unknown',
            confidence: double.parse(normalizedConf.toStringAsFixed(4)),
            scientificName: map['scientificName'] as String? ?? 'Alternaria solani',
            category: DiseaseCategory.fromString(map['category'] as String?),
          );
        }).toList();

        final rawRegions = data['gradCamRegions'] as List<dynamic>? ?? [];
        final List<GradCamHotspot> cloudHotspots = rawRegions.map((r) {
          return GradCamHotspot.fromMap(Map<String, dynamic>.from(r as Map));
        }).toList();

        final double cloudLesionPct = (data['lesionAreaPercentage'] as num?)?.toDouble() ??
            localAnalysis.lesionAreaPercent;

        final bool requiresKvk = data['requiresExpertVerification'] as bool? ??
            (cloudPredictions.isNotEmpty && cloudPredictions.first.confidence < 0.75);

        final VerificationStatus status = VerificationStatus.fromString(
          data['verificationStatus'] as String?,
        );

        final rawAffected = data['affectedRegions'] as List<dynamic>? ?? [];
        final List<LesionRegion> cloudRegions = rawAffected.isNotEmpty
            ? rawAffected.map((r) => LesionRegion.fromMap(Map<String, dynamic>.from(r as Map))).toList()
            : localAnalysis.lesionRegions;

        stopwatch.stop();
        return HybridDiagnosticResult(
          sanitizedImageBytes: localAnalysis.sanitizedImageBytes,
          topCandidates: cloudPredictions,
          lesionAreaPercent: cloudLesionPct,
          gradCamHotspots: cloudHotspots.isNotEmpty ? cloudHotspots : localAnalysis.hotspots,
          heatmapBase64: data['heatmapBase64'] as String?,
          requiresKvkReview: requiresKvk,
          verificationStatus: status,
          isCloudInference: true,
          totalLatencyMs: stopwatch.elapsedMilliseconds,
          lesionRegions: cloudRegions,
          stressEtiology: localAnalysis.stressEtiology,
        );
      } catch (parseErr) {
        debugPrint('[FloraX Hybrid] Failed to parse cloud payload: $parseErr. Falling back to edge.');
      }
    }

    // --- FALLBACK PATH: On-Device TFLite + Isolate CIELAB ---
    debugPrint('[FloraX Hybrid] Seamless fallback to on-device TFLite + CIELAB Engine.');
    final TfliteInferenceResult edgeResult = await localInferenceFuture;

    stopwatch.stop();
    return HybridDiagnosticResult(
      sanitizedImageBytes: localAnalysis.sanitizedImageBytes,
      topCandidates: edgeResult.topPredictions,
      lesionAreaPercent: localAnalysis.lesionAreaPercent,
      gradCamHotspots: localAnalysis.hotspots,
      heatmapBase64: null,
      requiresKvkReview: edgeResult.requiresKvkReview,
      verificationStatus: edgeResult.verificationStatus,
      isCloudInference: false,
      totalLatencyMs: stopwatch.elapsedMilliseconds,
      lesionRegions: localAnalysis.lesionRegions,
      stressEtiology: localAnalysis.stressEtiology,
    );
  }

  /// Sends request to Python FastAPI PyTorch Grad-CAM microservice with Firebase App Check
  Future<Response<Map<String, dynamic>>?> fetchCloudGradCam({
    required Uint8List sanitizedBytes,
    String cropType = 'Tomato',
    bool simulateLowConfidence = false,
  }) async {
    return _fetchCloudGradCam(
      sanitizedBytes: sanitizedBytes,
      cropType: cropType,
      simulateLowConfidence: simulateLowConfidence,
    );
  }

  /// Internal handler sending request to Python FastAPI PyTorch Grad-CAM microservice with Firebase App Check
  Future<Response<Map<String, dynamic>>?> _fetchCloudGradCam({
    required Uint8List sanitizedBytes,
    required String cropType,
    required bool simulateLowConfidence,
  }) async {
    // 1. Retrieve Firebase App Check Token for backend request attestation
    String? appCheckToken;
    try {
      final tokenResult = await FirebaseAppCheck.instance.getToken();
      appCheckToken = tokenResult;
    } catch (e) {
      debugPrint('[FloraX Hybrid] App Check token acquisition skipped: $e');
    }

    // 2. Base64 encode the sanitized image in a background isolate (drops zero UI frames)
    final String encodedBytes = await Isolate.run(() => base64Encode(sanitizedBytes));
    final String base64Payload = 'data:image/jpeg;base64,$encodedBytes';

    // 3. Dispatch POST request with strict 4s timeouts
    return await _dio.post<Map<String, dynamic>>(
      '/analyze-leaf',
      data: {
        'imageBase64': base64Payload,
        'cropType': cropType,
        'simulateLowConfidence': simulateLowConfidence,
      },
      options: Options(
        headers: {
          if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
        },
      ),
    );
  }

  void dispose() {
    _tfliteService.dispose();
  }
}

/// Riverpod Provider exposing the resilient Hybrid Vision Client
final hybridGradCamClientProvider = Provider<HybridGradCamClient>((ref) {
  final client = HybridGradCamClient();
  ref.onDispose(() => client.dispose());
  return client;
});
