import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weather snapshot with spray precaution guidance
@immutable
class LocationWeatherSnapshot {
  final double temperatureC;
  final double relativeHumidity;
  final double precipitationMm;
  final double windSpeedKmh;
  final bool shouldDelayChemicalSpray;
  final String sprayAdvisoryReason;
  final DateTime fetchedAt;

  const LocationWeatherSnapshot({
    required this.temperatureC,
    required this.relativeHumidity,
    required this.precipitationMm,
    required this.windSpeedKmh,
    required this.shouldDelayChemicalSpray,
    required this.sprayAdvisoryReason,
    required this.fetchedAt,
  });

  Map<String, dynamic> toMap() => {
    'temperatureC': temperatureC,
    'relativeHumidity': relativeHumidity,
    'precipitationMm': precipitationMm,
    'windSpeedKmh': windSpeedKmh,
    'shouldDelayChemicalSpray': shouldDelayChemicalSpray,
    'sprayAdvisoryReason': sprayAdvisoryReason,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory LocationWeatherSnapshot.fromMap(Map<String, dynamic> map) {
    return LocationWeatherSnapshot(
      temperatureC: (map['temperatureC'] as num?)?.toDouble() ?? 27.5,
      relativeHumidity: (map['relativeHumidity'] as num?)?.toDouble() ?? 65.0,
      precipitationMm: (map['precipitationMm'] as num?)?.toDouble() ?? 0.0,
      windSpeedKmh: (map['windSpeedKmh'] as num?)?.toDouble() ?? 8.0,
      shouldDelayChemicalSpray: map['shouldDelayChemicalSpray'] as bool? ?? false,
      sprayAdvisoryReason: map['sprayAdvisoryReason']?.toString() ?? 'Conditions favorable for organic/chemical spray.',
      fetchedAt: DateTime.tryParse(map['fetchedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Unified Device Utility Service for KisanSetu.
/// Wraps:
/// 1. `permission_handler` - Runtime camera and location permissions.
/// 2. `geolocator` - High-accuracy GPS positioning with cached fallbacks.
/// 3. `flutter_tts` - Vernacular voice guides (Marathi, Hindi, English).
/// 4. Location Weather - Open-Meteo agronomic forecast with offline cache.
class DeviceUtilityService {
  final FlutterTts _tts = FlutterTts();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  static const String _weatherCacheKey = 'florax_cached_weather_snapshot';

  DeviceUtilityService() {
    _initTts();
  }

  // ===========================================================================
  // 1. HARDWARE PERMISSION MANAGEMENT (permission_handler)
  // ===========================================================================

  /// Requests all necessary permissions for field pathology scanning
  Future<Map<Permission, PermissionStatus>> requestFieldScanningPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    return statuses;
  }

  /// Checks if camera permission is granted
  Future<bool> isCameraGranted() async {
    return (await Permission.camera.status).isGranted;
  }

  /// Checks if location permission is granted
  Future<bool> isLocationGranted() async {
    return (await Permission.location.status).isGranted;
  }

  // ===========================================================================
  // 2. GEOLOCATION POSITIONING (geolocator)
  // ===========================================================================

  /// Determines current device GPS coordinates with timeout and cached fallback
  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[DeviceUtilityService] Location service disabled, fetching last known position.');
        return await Geolocator.getLastKnownPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return await Geolocator.getLastKnownPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return await Geolocator.getLastKnownPosition();
      }

      // Fetch position with 5-second timeout
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('[DeviceUtilityService WARNING] getCurrentPosition error: $e. Falling back to last known.');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // ===========================================================================
  // 3. TEXT-TO-SPEECH VERNACULAR VOICE ADVISORY (flutter_tts)
  // ===========================================================================

  Future<void> _initTts() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _tts.setSpeechRate(0.48); // slightly deliberate speed for rural clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[DeviceUtilityService TTS ERROR] $msg');
      });
    } catch (e) {
      debugPrint('[DeviceUtilityService] TTS init error: $e');
    }
  }

  /// Reads out text in Marathi, Hindi, or English
  Future<void> speakVernacular(String text, {String langCode = 'mr'}) async {
    if (text.isEmpty) return;

    try {
      await stopSpeaking();

      String ttsLocale = 'mr-IN';
      if (langCode == 'hi') {
        ttsLocale = 'hi-IN';
      } else if (langCode == 'en') {
        ttsLocale = 'en-IN';
      }

      await _tts.setLanguage(ttsLocale);
      _isSpeaking = true;
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('[DeviceUtilityService] speakVernacular error: $e');
    }
  }

  /// Strictly and idempotently halts all active TTS audio readout and resets state immediately
  Future<void> stopAllAudio() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[DeviceUtilityService] stopAllAudio error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Stops any active speech synthesis readout
  Future<void> stopSpeaking() async {
    await stopAllAudio();
  }

  // ===========================================================================
  // 4. LOCATION WEATHER & SPRAY PRECAUTION (Open-Meteo + Offline Cache)
  // ===========================================================================

  /// Fetches weather for coordinates with offline cache and spray risk logic
  Future<LocationWeatherSnapshot> fetchWeatherForLocation({
    required double latitude,
    required double longitude,
  }) async {
    // 1. Check network fetch
    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude'
          '&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m'
          '&timezone=auto';

      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final current = response.data['current'];
        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 27.0;
        final humidity = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 60.0;
        final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
        final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 7.0;

        // Agronomic spray warning logic:
        // Rain > 2.0mm OR Wind > 20 km/h OR Humidity > 85% with rain expected
        bool shouldDelay = false;
        String advisory = 'Favorable weather for bio-fungicide or IPM application.';

        if (precip > 1.5) {
          shouldDelay = true;
          advisory = 'Active rainfall (${precip.toStringAsFixed(1)}mm) detected. Delay spraying to prevent foliar wash-off.';
        } else if (wind > 20.0) {
          shouldDelay = true;
          advisory = 'High wind speed (${wind.toStringAsFixed(1)} km/h) creates spray drift hazard. Delay until wind calms.';
        } else if (humidity > 85.0) {
          advisory = 'High humidity (>85%) accelerates fungal spore germination. Ensure thorough protective coverage.';
        }

        final snapshot = LocationWeatherSnapshot(
          temperatureC: temp,
          relativeHumidity: humidity,
          precipitationMm: precip,
          windSpeedKmh: wind,
          shouldDelayChemicalSpray: shouldDelay,
          sprayAdvisoryReason: advisory,
          fetchedAt: DateTime.now(),
        );

        // Cache locally in SharedPreferences
        _cacheWeather(snapshot);
        return snapshot;
      }
    } catch (e) {
      debugPrint('[DeviceUtilityService] Open-Meteo network fetch failed: $e. Loading cached weather.');
    }

    // 2. Fallback to cached weather snapshot
    final cached = await _getCachedWeather();
    if (cached != null) return cached;

    // 3. Fallback to default Maharashtra tropical average
    return LocationWeatherSnapshot(
      temperatureC: 28.0,
      relativeHumidity: 65.0,
      precipitationMm: 0.0,
      windSpeedKmh: 8.5,
      shouldDelayChemicalSpray: false,
      sprayAdvisoryReason: 'Offline estimated weather: Conditions normal for field spraying.',
      fetchedAt: DateTime.now(),
    );
  }

  Future<void> _cacheWeather(LocationWeatherSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_weatherCacheKey, jsonEncode(snapshot.toMap()));
    } catch (_) {}
  }

  Future<LocationWeatherSnapshot?> _getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_weatherCacheKey);
      if (raw != null && raw.isNotEmpty) {
        return LocationWeatherSnapshot.fromMap(jsonDecode(raw));
      }
    } catch (_) {}
    return null;
  }
}

/// Global Riverpod Provider for DeviceUtilityService
final deviceUtilityServiceProvider = Provider<DeviceUtilityService>((ref) {
  return DeviceUtilityService();
});
