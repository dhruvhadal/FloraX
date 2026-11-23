import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Central Configuration Registry for the FloraX Mobile Platform
class AppConfig {
  AppConfig._();

  // ===========================================================================
  // 1. CLOUD ENDPOINTS & MICROSERVICES
  // ===========================================================================

  /// Base URL for the FastAPI PyTorch Grad-CAM & Lesion Vision Engine.
  /// Defaults to http://127.0.0.1:8000 which works immediately over USB `adb reverse tcp:8000 tcp:8000`.
  /// Overridable at compile/run time via: --dart-define=FASTAPI_GRADCAM_URL=http://<PC_LAN_IP>:8000
  static const String fastApiGradCamBaseUrl = String.fromEnvironment(
    'FASTAPI_GRADCAM_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Open-Meteo Weather API Base URL
  static const String openMeteoBaseUrl = 'https://api.open-meteo.com/v1/forecast';

  // ===========================================================================
  // 2. CLINICAL & EPIDEMIOLOGICAL THRESHOLDS
  // ===========================================================================

  /// KVK Scientist Escalation Guardrail: Diagnoses below 75% confidence
  /// require mandatory review before unlocking Tier 3 chemical advisories.
  static const double kvkConfidenceThreshold = 0.75;

  /// Privacy-preserving regional GeoHash precision (5 characters ~= 4.9 km)
  /// House-level GPS coordinates are truncated to this resolution.
  static const int geoHashPrecision = 5;

  /// Detailed clustering GeoHash precision (7 characters ~= 152 m)
  static const int geoHashClusterPrecision = 7;

  /// High-risk spore germination relative humidity trigger (%)
  static const double highFungalHumidityThreshold = 80.0;

  /// Max allowed leaf scan upload size in bytes (5MB limit)
  static const int maxImageUploadSizeBytes = 5 * 1024 * 1024;

  /// Network timeout duration in seconds for resilient micro-service calls
  static const int apiTimeoutSeconds = 4;

  // ===========================================================================
  // 3. ASSET PATHS & DYNAMIC TAXONOMY PARSING
  // ===========================================================================

  static const String modelAssetPath = 'assets/models/florax_v2_45c_fp16.tflite';
  static const String labelsAssetPath = 'assets/models/labels.txt';
  static const String modelMetaAssetPath = 'assets/models/model_meta.json';
  static const String offlineIcarProtocolsAssetPath = 'assets/data/offline_icar_protocols.json';

  /// Out-Of-Distribution (OOD) Guardrail Thresholds
  /// Relaxed to allow real-world leaf photos with complex backgrounds to reach the model.
  /// The KVK escalation system (< 75% confidence) already handles uncertain predictions safely.
  static const double oodMinConfidence = 0.20;
  static const double oodMaxNormalizedEntropy = 0.85;

  /// Dynamically parses all indexed pathology classes from `assets/models/labels.txt`
  /// rather than hardcoding class counts.
  static Future<List<String>> loadDynamicPathologyLabels() async {
    try {
      final String rawContent = await rootBundle.loadString(labelsAssetPath);
      final List<String> parsed = rawContent
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      debugPrint('[FloraX AppConfig] Dynamically loaded ${parsed.length} classes from $labelsAssetPath');
      return parsed;
    } catch (e) {
      debugPrint('[FloraX AppConfig ERROR] Failed reading $labelsAssetPath: $e. Using fallback.');
      return const [
        'abiotic_magnesium_deficiency',
        'abiotic_nitrogen_deficiency',
        'abiotic_potassium_deficiency',
        'cotton_leaf_curl',
        'not_a_leaf_background',
        'paddy_leaf_blast',
        'tomato_early_blight',
        'tomato_healthy',
      ];
    }
  }

  // ===========================================================================
  // 4. OFFLINE STORAGE & CACHE DIRECTORIES
  // ===========================================================================

  static const String pendingScansDirectoryName = 'scans';
  static const String pendingUploadsManifestFileName = 'pending_uploads.json';
  static const String defaultLanguage = 'mr';
}
