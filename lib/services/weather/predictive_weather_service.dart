import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/utils/ist_date_time_formatter.dart';
import '../notifications/outbreak_fcm_service.dart';

/// Epidemiological Risk Level Classification
enum WeatherRiskLevel {
  low,
  moderate,
  high,
  critical;

  String get label {
    switch (this) {
      case WeatherRiskLevel.low:
        return 'LOW';
      case WeatherRiskLevel.moderate:
        return 'MODERATE';
      case WeatherRiskLevel.high:
        return 'HIGH';
      case WeatherRiskLevel.critical:
        return 'CRITICAL';
    }
  }
}

/// Daily micro-climate risk assessment prediction
@immutable
class DailyWeatherRisk {
  final String date;
  final double tempMaxC;
  final double tempMinC;
  final double humidityMean;
  final double precipitationMm;
  final int riskScore; // [0 - 100]
  final WeatherRiskLevel riskLevel;
  final String primaryPathogenThreat;

  const DailyWeatherRisk({
    required this.date,
    required this.tempMaxC,
    required this.tempMinC,
    required this.humidityMean,
    required this.precipitationMm,
    required this.riskScore,
    required this.riskLevel,
    required this.primaryPathogenThreat,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'tempMaxC': tempMaxC,
      'tempMinC': tempMinC,
      'humidityMean': humidityMean,
      'precipitationMm': precipitationMm,
      'riskScore': riskScore,
      'riskLevel': riskLevel.label,
      'primaryPathogenThreat': primaryPathogenThreat,
    };
  }

  factory DailyWeatherRisk.fromMap(Map<String, dynamic> map) {
    return DailyWeatherRisk(
      date: map['date'] as String? ?? '',
      tempMaxC: (map['tempMaxC'] as num?)?.toDouble() ?? 25.0,
      tempMinC: (map['tempMinC'] as num?)?.toDouble() ?? 18.0,
      humidityMean: (map['humidityMean'] as num?)?.toDouble() ?? 70.0,
      precipitationMm: (map['precipitationMm'] as num?)?.toDouble() ?? 0.0,
      riskScore: (map['riskScore'] as num?)?.toInt() ?? 30,
      riskLevel: _parseRiskLevel(map['riskLevel'] as String?),
      primaryPathogenThreat: map['primaryPathogenThreat'] as String? ?? 'General Foliage Stress',
    );
  }

  static WeatherRiskLevel _parseRiskLevel(String? val) {
    switch (val?.toUpperCase()) {
      case 'CRITICAL':
        return WeatherRiskLevel.critical;
      case 'HIGH':
        return WeatherRiskLevel.high;
      case 'MODERATE':
        return WeatherRiskLevel.moderate;
      default:
        return WeatherRiskLevel.low;
    }
  }
}

/// Comprehensive 7-Day Spore Germination & Outbreak Risk Report
@immutable
class WeatherRiskReport {
  final String geoHash5; // Truncated for farmer privacy
  final double currentTempC;
  final double currentHumidity;
  final double currentPrecipitationMm;
  final double currentWindSpeedKmh; // PRD Req 6: Current wind condition
  final double precipitationProbability; // PRD Req 6: Rain probability %
  final int aggregateOutbreakScore; // 7-day index [0 - 100]
  final WeatherRiskLevel aggregateRiskLevel;
  final String primaryThreatName;
  final Map<String, String> localizedAdvisory; // Trilingual ('en', 'hi', 'mr')
  final List<DailyWeatherRisk> dailyForecasts;
  final DateTime syncedAt;
  final bool isFromOfflineCache;

  const WeatherRiskReport({
    required this.geoHash5,
    required this.currentTempC,
    required this.currentHumidity,
    required this.currentPrecipitationMm,
    this.currentWindSpeedKmh = 12.0,
    this.precipitationProbability = 15.0,
    required this.aggregateOutbreakScore,
    required this.aggregateRiskLevel,
    required this.primaryThreatName,
    required this.localizedAdvisory,
    required this.dailyForecasts,
    required this.syncedAt,
    this.isFromOfflineCache = false,
  });

  String get lastUpdatedIst => IstTimeUtils.formatDateTimeIst(syncedAt);
  String get lastUpdatedTimeIst => IstTimeUtils.formatTimeOnlyIst(syncedAt);

  Map<String, dynamic> toFirestore() {
    return {
      'geoHash5': geoHash5,
      'currentTempC': currentTempC,
      'currentHumidity': currentHumidity,
      'currentPrecipitationMm': currentPrecipitationMm,
      'currentWindSpeedKmh': currentWindSpeedKmh,
      'precipitationProbability': precipitationProbability,
      'aggregateOutbreakScore': aggregateOutbreakScore,
      'aggregateRiskLevel': aggregateRiskLevel.label,
      'primaryThreatName': primaryThreatName,
      'localizedAdvisory': localizedAdvisory,
      'dailyForecasts': dailyForecasts.map((d) => d.toMap()).toList(),
      'syncedAt': Timestamp.fromDate(syncedAt),
    };
  }

  factory WeatherRiskReport.fromFirestore(Map<String, dynamic> map, bool fromCache) {
    final rawDate = map['syncedAt'];
    final DateTime date = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.now();

    final rawDaily = map['dailyForecasts'] as List<dynamic>? ?? [];
    final daily = rawDaily
        .map((d) => DailyWeatherRisk.fromMap(Map<String, dynamic>.from(d as Map)))
        .toList();

    final rawAdv = map['localizedAdvisory'];
    final Map<String, String> adv = {};
    if (rawAdv is Map) {
      rawAdv.forEach((k, v) => adv[k.toString()] = v.toString());
    }

    return WeatherRiskReport(
      geoHash5: map['geoHash5'] as String? ?? '00000',
      currentTempC: (map['currentTempC'] as num?)?.toDouble() ?? 25.0,
      currentHumidity: (map['currentHumidity'] as num?)?.toDouble() ?? 70.0,
      currentPrecipitationMm: (map['currentPrecipitationMm'] as num?)?.toDouble() ?? 0.0,
      currentWindSpeedKmh: (map['currentWindSpeedKmh'] as num?)?.toDouble() ?? 12.0,
      precipitationProbability: (map['precipitationProbability'] as num?)?.toDouble() ?? 15.0,
      aggregateOutbreakScore: (map['aggregateOutbreakScore'] as num?)?.toInt() ?? 35,
      aggregateRiskLevel: DailyWeatherRisk._parseRiskLevel(map['aggregateRiskLevel'] as String?),
      primaryThreatName: map['primaryThreatName'] as String? ?? 'Early Blight Spore Inoculum',
      localizedAdvisory: adv,
      dailyForecasts: daily,
      syncedAt: date,
      isFromOfflineCache: fromCache,
    );
  }
}

/// Principal Predictive Weather & Pathogen Epidemiological Warning Service
class PredictiveWeatherService {
  final Dio _dio;
  final FirebaseFirestore? _firestoreInstance;
  final GeoHasher _geoHasher;
  final OutbreakFcmService? _outbreakFcmService;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  static const String fallbackGeoHash5 = 'te7uc';
  static String _cachedGeoHash5 = fallbackGeoHash5;

  PredictiveWeatherService({
    Dio? dio,
    FirebaseFirestore? firestore,
    OutbreakFcmService? outbreakFcmService,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            ),
        _firestoreInstance = firestore,
        _geoHasher = GeoHasher(),
        _outbreakFcmService = outbreakFcmService;

  /// Returns the last resolved GeoHash5 (or cached fallback) immediately in < 1ms,
  /// while triggering an unawaited background location refresh.
  String getCachedOrDefaultGeoHash5() {
    unawaited(refreshLocationInBackground());
    return _cachedGeoHash5;
  }

  /// Triggers a background refresh of the device coordinates and GeoHash5.
  Future<String> refreshLocationInBackground() async {
    try {
      final String freshHash = await getCurrentGeoHash5();
      _cachedGeoHash5 = freshHash;
      return freshHash;
    } catch (e) {
      debugPrint('[FloraX Weather] Background location refresh failed: $e');
      return _cachedGeoHash5;
    }
  }

  /// Resolves device coordinates and returns a privacy-preserving 5-character GeoHash (~4.9km)
  Future<String> getCurrentGeoHash5() async {
    try {
      final Position position = await _determinePosition();
      final String fullGeoHash = _geoHasher.encode(position.longitude, position.latitude, precision: 7);
      final String geoHash5 = fullGeoHash.substring(0, 5);
      _cachedGeoHash5 = geoHash5;
      if (geoHash5.length == 5) {
        _outbreakFcmService?.subscribeToOutbreakTopic(geoHash5);
      }
      return geoHash5;
    } catch (e) {
      debugPrint('[FloraX Weather] Failed to resolve GeoHash5 ($e). Using default Nashik hash.');
      const defaultHash = fallbackGeoHash5;
      _cachedGeoHash5 = defaultHash;
      _outbreakFcmService?.subscribeToOutbreakTopic(defaultHash);
      return defaultHash; // Default Maharashtra agricultural corridor
    }
  }

  /// Acquires farmer GPS, fetches live Open-Meteo telemetry, computes epidemiological
  /// risk scores, and caches results to Firestore SQLite for offline field survival.
  Future<WeatherRiskReport> getPredictiveDiseaseWarning() async {
    // 1. Acquire Coordinates with Permission Handling
    final Position position = await _determinePosition();
    final double lat = position.latitude;
    final double lng = position.longitude;

    // Truncate to 5-char GeoHash for farmer privacy (~4.9km radius)
    final String fullGeoHash = _geoHasher.encode(lng, lat, precision: 7);
    final String geoHash5 = fullGeoHash.substring(0, 5);
    _cachedGeoHash5 = geoHash5;

    debugPrint('[FloraX Weather] Acquired location: Lat $lat, Lng $lng -> GeoHash5: $geoHash5');
    if (geoHash5.length == 5) {
      _outbreakFcmService?.subscribeToOutbreakTopic(geoHash5);
    }

    // 2. Query Live Open-Meteo API
    final String url = 'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,relative_humidity_2m_mean'
        '&timezone=auto';

    try {
      debugPrint('[FloraX Weather] Dispatching Open-Meteo API request...');
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final report = _computeEpidemiologicalRisk(
          data: data,
          geoHash5: geoHash5,
        );

        // 3. Cache to Firestore (which automatically updates local SQLite persistence)
        try {
          await _firestore
              .collection('weather_telemetry_cache')
              .doc(geoHash5)
              .set(report.toFirestore(), SetOptions(merge: true));
          debugPrint('[FloraX Weather] Cached live weather telemetry to Firestore: $geoHash5');
        } catch (cacheErr) {
          debugPrint('[FloraX Weather WARNING] Local Firestore cache update failed: $cacheErr');
        }

        return report;
      }
    } catch (apiErr) {
      debugPrint('[FloraX Weather WARNING] Live Open-Meteo unreachable ($apiErr). Falling back to offline cache.');
    }

    // --- OFFLINE FALLBACK: Read from Firestore SQLite Persistence Cache ---
    try {
      final cachedDoc = await _firestore
          .collection('weather_telemetry_cache')
          .doc(geoHash5)
          .get(const GetOptions(source: Source.cache));

      if (cachedDoc.exists && cachedDoc.data() != null) {
        debugPrint('[FloraX Weather] Served weather telemetry from offline SQLite cache.');
        return WeatherRiskReport.fromFirestore(cachedDoc.data()!, true);
      }
    } catch (offlineErr) {
      debugPrint('[FloraX Weather WARNING] Offline cache miss: $offlineErr');
    }

    // Default baseline report if neither network nor prior cache exists
    return _buildDefaultFallbackReport(geoHash5);
  }

  /// Calculates deterministic 7-Day Spore Germination and Outbreak Risk Scores
  WeatherRiskReport _computeEpidemiologicalRisk({
    required Map<String, dynamic> data,
    required String geoHash5,
  }) {
    final current = data['current'] as Map<String, dynamic>? ?? {};
    final daily = data['daily'] as Map<String, dynamic>? ?? {};

    final double curTemp = (current['temperature_2m'] as num?)?.toDouble() ?? 25.0;
    final double curHumidity = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 75.0;
    final double curRain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
    final double curWindSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.0;
    final List<dynamic> precipProbList = daily['precipitation_probability_max'] as List<dynamic>? ?? [];
    final double precipProb = precipProbList.isNotEmpty ? (precipProbList.first as num?)?.toDouble() ?? 15.0 : 15.0;

    final List<dynamic> dates = daily['time'] as List<dynamic>? ?? [];
    final List<dynamic> maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
    final List<dynamic> minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
    final List<dynamic> precipSum = daily['precipitation_sum'] as List<dynamic>? ?? [];
    final List<dynamic> humidMean = daily['relative_humidity_2m_mean'] as List<dynamic>? ?? [];

    final List<DailyWeatherRisk> dailyRisks = [];
    double weightedScoreSum = 0.0;
    double totalWeights = 0.0;

    for (int i = 0; i < min(7, dates.length); i++) {
      final String d = dates[i].toString();
      final double tMax = (maxTemps[i] as num?)?.toDouble() ?? 28.0;
      final double tMin = (minTemps[i] as num?)?.toDouble() ?? 18.0;
      final double tMean = (tMax + tMin) / 2.0;
      final double pSum = (precipSum[i] as num?)?.toDouble() ?? 0.0;
      final double hMean = (humidMean[i] as num?)?.toDouble() ?? 70.0;

      // Deterministic Epidemiological Model:
      // Fungal pathogens (Early Blight, Paddy Blast, Downy Mildew)
      double dayScore = 0.0;
      String threat = 'Low Pathogen Activity';

      // 1. Temperature Window for Spore Germination (Optimal: 20 - 28°C)
      if (tMean >= 20.0 && tMean <= 28.0) {
        dayScore += 35.0;
      } else if (tMean >= 16.0 && tMean <= 32.0) {
        dayScore += 18.0;
      }

      // 2. Relative Humidity Factor (Crucial trigger: > 80%)
      if (hMean >= 85.0) {
        dayScore += 45.0;
        threat = 'Critical Fungal Spore Inoculum (Blight/Blast)';
      } else if (hMean >= 75.0) {
        dayScore += 30.0;
        threat = 'Fungal Conidia Germination (Alternaria)';
      } else if (hMean <= 50.0 && tMax >= 32.0 && pSum < 1.0) {
        // 3. Dry Spell Vector Multiplier (Whitefly / Thrips Viral Surge)
        dayScore += 38.0;
        threat = 'Whitefly Vector Population Surge (CLCuV)';
      }

      // 4. Rain Splash & Leaf Wetness Duration
      if (pSum >= 15.0) {
        dayScore += 20.0;
      } else if (pSum >= 3.0) {
        dayScore += 10.0;
      }

      final int finalDayScore = dayScore.clamp(5.0, 98.0).toInt();
      final WeatherRiskLevel level = _scoreToLevel(finalDayScore);

      dailyRisks.add(
        DailyWeatherRisk(
          date: d,
          tempMaxC: tMax,
          tempMinC: tMin,
          humidityMean: hMean,
          precipitationMm: pSum,
          riskScore: finalDayScore,
          riskLevel: level,
          primaryPathogenThreat: threat,
        ),
      );

      // Higher weight to the nearest 48 hours
      final double weight = max(1.0, 4.0 - i);
      weightedScoreSum += (finalDayScore * weight);
      totalWeights += weight;
    }

    final int aggregateScore = totalWeights > 0
        ? (weightedScoreSum / totalWeights).round()
        : 45;

    final WeatherRiskLevel aggLevel = _scoreToLevel(aggregateScore);

    // Multilingual ICAR warning advisories
    final Map<String, String> localizedAdvisories = _generateAdvisories(
      aggLevel: aggLevel,
      curHumidity: curHumidity,
      curTemp: curTemp,
    );

    return WeatherRiskReport(
      geoHash5: geoHash5,
      currentTempC: curTemp,
      currentHumidity: curHumidity,
      currentPrecipitationMm: curRain,
      currentWindSpeedKmh: curWindSpeed,
      precipitationProbability: precipProb,
      aggregateOutbreakScore: aggregateScore,
      aggregateRiskLevel: aggLevel,
      primaryThreatName: dailyRisks.isNotEmpty
          ? dailyRisks.first.primaryPathogenThreat
          : 'Early Blight Spore Pressure',
      localizedAdvisory: localizedAdvisories,
      dailyForecasts: dailyRisks,
      syncedAt: DateTime.now().toUtc(),
      isFromOfflineCache: false,
    );
  }

  static WeatherRiskLevel _scoreToLevel(int score) {
    if (score >= 80) return WeatherRiskLevel.critical;
    if (score >= 60) return WeatherRiskLevel.high;
    if (score >= 40) return WeatherRiskLevel.moderate;
    return WeatherRiskLevel.low;
  }

  static Map<String, String> _generateAdvisories({
    required WeatherRiskLevel aggLevel,
    required double curHumidity,
    required double curTemp,
  }) {
    if (aggLevel == WeatherRiskLevel.critical || aggLevel == WeatherRiskLevel.high) {
      return {
        'en': 'High Spore Alert: Sustained humidity ($curHumidity%) and moderate temperatures ($curTemp°C) favor rapid fungal blight expansion. Prophylactically apply bio-agents (Trichoderma viride @ 5g/L) or ensure drip lines keep foliage dry.',
        'hi': 'गंभीर रोग चेतावनी: लगातार उच्च आर्द्रता ($curHumidity%) और अनुकूल तापमान ($curTemp°C) से झुलसा रोग के बीजाणु तेजी से फैलने की आशंका है। ट्राइकोडर्मा विरिडी (5 ग्राम/लीटर) का तुरंत निवारक छिड़काव करें।',
        'mr': 'अतिधोका इशारा: हवेतील उच्च आर्द्रता ($curHumidity%) व पोषक वातावरणामुळे ($curTemp° से) करपा रोगाच्या बीजाणूंचा प्रचंड प्रसार संभवतो. ताबडतोब ट्रायकोडर्मा व्हिरिडी (५ ग्रॅम/लिटर) ची प्रतिबंधात्मक फवारणी करा.',
      };
    } else if (aggLevel == WeatherRiskLevel.moderate) {
      return {
        'en': 'Moderate Risk: Inspect lower leaves for early concentric necrotic spots. Maintain field aeration and refrain from overhead sprinkling.',
        'hi': 'मध्यम जोखिम: निचली पत्तियों पर भूरे धब्बों की निगरानी करें। खेतों में जलभराव न होने दें।',
        'mr': 'मध्यम धोका: झाडांच्या तळातील पानांवर काळ्या ठिपक्यांचे निरीक्षण करा. पिकात पाणी साचू न देता हवा खेळती ठेवा.',
      };
    } else {
      return {
        'en': 'Favorable Conditions: Micro-climate pathogen pressure is currently low. Continue regular cultural sanitation.',
        'hi': 'अनुकूल स्थिति: वर्तमान में मौसम के कारण रोग का खतरा कम है। नियमित स्वच्छता बनाए रखें।',
        'mr': 'अनुकूल हवामान: सध्या हवामानामुळे रोगाचा धोका कमी आहे. नियमित पिकाची काळजी घ्या.',
      };
    }
  }

  /// Determines device coordinates with runtime permission checks
  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Default to agricultural heartland of Maharashtra (Nashik: 19.9975, 73.7898)
      return Position(
        longitude: 73.7898,
        latitude: 19.9975,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 600.0,
        altitudeAccuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Position(
          longitude: 73.7898,
          latitude: 19.9975,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 600.0,
          altitudeAccuracy: 10.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Position(
        longitude: 73.7898,
        latitude: 19.9975,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 600.0,
        altitudeAccuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      return Position(
        longitude: 73.7898,
        latitude: 19.9975,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 600.0,
        altitudeAccuracy: 10.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  WeatherRiskReport _buildDefaultFallbackReport(String geoHash5) {
    return WeatherRiskReport(
      geoHash5: geoHash5,
      currentTempC: 26.5,
      currentHumidity: 78.0,
      currentPrecipitationMm: 0.0,
      aggregateOutbreakScore: 55,
      aggregateRiskLevel: WeatherRiskLevel.moderate,
      primaryThreatName: 'Foliar Blight Inoculum',
      localizedAdvisory: {
        'en': 'Offline Baseline: Monitor fields for initial blight lesions. Ensure soil moisture is regulated via drip.',
        'hi': 'ऑफ़लाइन बेसलाइन: पत्तियों पर झुलसा धब्बों की निगरानी करें और ड्रिप से सिंचाई करें।',
        'mr': 'ऑफलाईन माहिती: पानांवरील करप्याच्या लक्षणांवर लक्ष ठेवा आणि ठिबक सिंचनाचा वापर करा.',
      },
      dailyForecasts: const [],
      syncedAt: DateTime.now().toUtc(),
      isFromOfflineCache: true,
    );
  }
}

// =============================================================================
// RIVERPOD DEPENDENCY INJECTION PROVIDERS
// =============================================================================

/// Global Provider for the Predictive Weather Service
final predictiveWeatherServiceProvider = Provider<PredictiveWeatherService>((ref) {
  final fcmService = ref.watch(outbreakFcmServiceProvider);
  return PredictiveWeatherService(outbreakFcmService: fcmService);
});

/// Auto-disposing FutureProvider delivering the latest disease warning report
final weatherRiskReportFutureProvider =
    FutureProvider.autoDispose<WeatherRiskReport>((ref) async {
  final service = ref.watch(predictiveWeatherServiceProvider);
  return await service.getPredictiveDiseaseWarning();
});
