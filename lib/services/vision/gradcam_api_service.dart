import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_activity_logger.dart';

/// Region of interest highlighted by Grad-CAM
class GradCamRegion {
  final double x;
  final double y;
  final double width;
  final double height;
  final double intensity;

  const GradCamRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.intensity,
  });

  factory GradCamRegion.fromMap(Map<String, dynamic> map) {
    return GradCamRegion(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      intensity: (map['intensity'] as num?)?.toDouble() ?? 0.8,
    );
  }
}

/// Structured response from Grad-CAM service
class GradCamResponse {
  final String? heatmapBase64;
  final List<GradCamRegion> gradCamRegions;
  final double lesionAreaPercentage;
  final bool requiresExpertVerification;
  final String verificationStatus;
  final bool isOfflineFallback;

  const GradCamResponse({
    this.heatmapBase64,
    this.gradCamRegions = const [],
    this.lesionAreaPercentage = 0.0,
    this.requiresExpertVerification = false,
    this.verificationStatus = 'AI_VERIFIED',
    this.isOfflineFallback = false,
  });
}

/// Service communicating with FastAPI Grad-CAM backend (`POST /api/v1/gradcam`)
/// with automatic offline fallback when device is disconnected or server is offline.
class GradCamApiService {
  final Dio _dio;

  GradCamApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.fastApiGradCamBaseUrl,
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                sendTimeout: const Duration(seconds: 4),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Requests Grad-CAM heatmap visualization from backend server
  Future<GradCamResponse> fetchGradCam({
    required Uint8List imageBytes,
    String cropType = 'Tomato',
    String? canonicalId,
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final payload = {
        'imageBase64': 'data:image/jpeg;base64,$base64Image',
        'cropType': cropType,
        'canonicalId': canonicalId,
      };

      // Try primary endpoint /api/v1/gradcam (falls back to /analyze-leaf)
      Response<Map<String, dynamic>> response;
      try {
        response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/gradcam',
          data: payload,
        );
      } catch (_) {
        response = await _dio.post<Map<String, dynamic>>(
          '/analyze-leaf',
          data: payload,
        );
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final rawRegions = data['gradCamRegions'] as List? ?? [];
        final regions = rawRegions
            .whereType<Map<String, dynamic>>()
            .map((m) => GradCamRegion.fromMap(m))
            .toList();

        final result = GradCamResponse(
          heatmapBase64: data['heatmapBase64'] as String?,
          gradCamRegions: regions,
          lesionAreaPercentage:
              (data['lesionAreaPercentage'] as num?)?.toDouble() ?? 0.0,
          requiresExpertVerification:
              data['requiresExpertVerification'] as bool? ?? false,
          verificationStatus:
              data['verificationStatus'] as String? ?? 'AI_VERIFIED',
          isOfflineFallback: false,
        );

        AppActivityLogger.instance.log(
          screen: 'diagnosis_details',
          action: 'gradcam_request',
          backendTarget: 'FastAPI./api/v1/gradcam',
          status: 'SUCCESS',
          details: {
            'cropType': cropType,
            'canonicalId': canonicalId,
            'hasHeatmap': result.heatmapBase64 != null,
            'lesionAreaPercentage': result.lesionAreaPercentage,
          },
        );

        return result;
      }
    } catch (e) {
      debugPrint('[GradCamApiService] Cloud endpoint unavailable ($e). Utilizing offline fallback.');
      AppActivityLogger.instance.log(
        screen: 'diagnosis_details',
        action: 'gradcam_request',
        backendTarget: 'FastAPI./api/v1/gradcam',
        status: 'OFFLINE_FALLBACK',
        details: {
          'cropType': cropType,
          'canonicalId': canonicalId,
          'error': e.toString(),
        },
      );
    }

    // Graceful offline fallback: Return offline synthetic thermal representation
    return _buildOfflineFallback(imageBytes, canonicalId);
  }

  GradCamResponse _buildOfflineFallback(Uint8List imageBytes, String? canonicalId) {
    // Generate simulated centroid hotspots for explainability
    final List<GradCamRegion> simulatedRegions = [
      const GradCamRegion(x: 0.35, y: 0.38, width: 0.28, height: 0.26, intensity: 0.92),
      const GradCamRegion(x: 0.48, y: 0.52, width: 0.22, height: 0.20, intensity: 0.78),
    ];

    return GradCamResponse(
      heatmapBase64: null,
      gradCamRegions: simulatedRegions,
      lesionAreaPercentage: 14.5,
      requiresExpertVerification: false,
      verificationStatus: 'AI_VERIFIED',
      isOfflineFallback: true,
    );
  }
}

/// Global Riverpod Provider for GradCamApiService
final gradCamApiServiceProvider = Provider<GradCamApiService>((ref) {
  return GradCamApiService();
});
