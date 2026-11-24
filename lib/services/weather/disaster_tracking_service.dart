import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/utils/ist_date_time_formatter.dart';
import 'predictive_weather_service.dart';

/// Categorization of Agricultural Disasters and Extreme Weather Events (PRD Req 10)
enum DisasterType {
  none,
  flood,
  cyclone,
  heatwave,
  heavyRainfall,
  drought,
  hailstorm,
  pestOutbreak;

  String get displayName {
    switch (this) {
      case DisasterType.flood:
        return 'Flood Warning (पूर इशारा)';
      case DisasterType.cyclone:
        return 'Cyclone Alert (चक्रीवादळ इशारा)';
      case DisasterType.heatwave:
        return 'Severe Heatwave (तीव्र उष्णतेची लाट)';
      case DisasterType.heavyRainfall:
        return 'Heavy Rainfall Alert (मुसळधार पाऊस)';
      case DisasterType.drought:
        return 'Drought Watch (दुष्काळ निरीक्षण)';
      case DisasterType.hailstorm:
        return 'Hailstorm Warning (गारपीट इशारा)';
      case DisasterType.pestOutbreak:
        return 'Regional Pest Outbreak (मोठी कीड प्रादुर्भाव)';
      case DisasterType.none:
        return 'Normal Weather (हवामान सामान्य)';
    }
  }
}

/// Severity classification aligned with NDMA / IMD alert scales
enum DisasterSeverity {
  normal,
  advisory,
  watch,
  warning,
  emergency;

  String get label {
    switch (this) {
      case DisasterSeverity.emergency:
        return 'EMERGENCY (तात्काळ धोका)';
      case DisasterSeverity.warning:
        return 'WARNING (धोका इशारा)';
      case DisasterSeverity.watch:
        return 'WATCH (दक्षता सूचना)';
      case DisasterSeverity.advisory:
        return 'ADVISORY (सल्ला)';
      case DisasterSeverity.normal:
        return 'NORMAL (सुरक्षित)';
    }
  }
}

/// Structured representation of an active meteorological disaster or extreme alert
@immutable
class DisasterAlert {
  final String id;
  final DisasterType disasterType;
  final DisasterSeverity severity;
  final String headline;
  final String description;
  final List<String> emergencyPrecautions;
  final DateTime effectiveTime;
  final DateTime expiresTime;
  final List<String> affectedDistricts;
  final String source;
  final bool isActive;

  const DisasterAlert({
    required this.id,
    required this.disasterType,
    required this.severity,
    required this.headline,
    required this.description,
    required this.emergencyPrecautions,
    required this.effectiveTime,
    required this.expiresTime,
    required this.affectedDistricts,
    required this.source,
    this.isActive = true,
  });

  bool get isThreat => severity != DisasterSeverity.normal && disasterType != DisasterType.none;

  String get formattedEffectiveTimeIst => IstTimeUtils.formatDateTimeIst(effectiveTime);
  String get formattedExpiresTimeIst => IstTimeUtils.formatDateTimeIst(expiresTime);

  factory DisasterAlert.normal({String? district}) {
    final now = DateTime.now().toUtc();
    return DisasterAlert(
      id: 'DISASTER-NORMAL',
      disasterType: DisasterType.none,
      severity: DisasterSeverity.normal,
      headline: 'No Extreme Weather Warnings in ${district ?? 'Your District'}',
      description: 'Atmospheric pressure and precipitation parameters are within seasonal agricultural bounds. Normal farm operations permitted.',
      emergencyPrecautions: [
        'Regular irrigation and weeding as scheduled.',
        'Inspect foliage for early micro-spore symptoms.',
      ],
      effectiveTime: now,
      expiresTime: now.add(const Duration(hours: 24)),
      affectedDistricts: district != null ? [district] : ['Statewide'],
      source: 'IMD / Open-Meteo Severe Weather Alert Center',
      isActive: false,
    );
  }

  factory DisasterAlert.fromFirestore(Map<String, dynamic> data, String docId) {
    final eff = data['effectiveTime'];
    final exp = data['expiresTime'];
    return DisasterAlert(
      id: docId,
      disasterType: _parseDisasterType(data['disasterType'] as String?),
      severity: _parseSeverity(data['severity'] as String?),
      headline: data['headline'] as String? ?? 'Meteorological Alert',
      description: data['description'] as String? ?? '',
      emergencyPrecautions: (data['precautions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      effectiveTime: eff is Timestamp ? eff.toDate() : DateTime.now().toUtc(),
      expiresTime: exp is Timestamp ? exp.toDate() : DateTime.now().toUtc().add(const Duration(hours: 24)),
      affectedDistricts: (data['affectedDistricts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      source: data['source'] as String? ?? 'IMD / Open-Meteo',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  static DisasterType _parseDisasterType(String? val) {
    switch (val?.toLowerCase()) {
      case 'flood':
        return DisasterType.flood;
      case 'cyclone':
        return DisasterType.cyclone;
      case 'heatwave':
        return DisasterType.heatwave;
      case 'heavyrainfall':
      case 'heavy_rainfall':
        return DisasterType.heavyRainfall;
      case 'drought':
        return DisasterType.drought;
      case 'hailstorm':
        return DisasterType.hailstorm;
      case 'pestoutbreak':
      case 'pest_outbreak':
        return DisasterType.pestOutbreak;
      default:
        return DisasterType.none;
    }
  }

  static DisasterSeverity _parseSeverity(String? val) {
    switch (val?.toLowerCase()) {
      case 'emergency':
        return DisasterSeverity.emergency;
      case 'warning':
        return DisasterSeverity.warning;
      case 'watch':
        return DisasterSeverity.watch;
      case 'advisory':
        return DisasterSeverity.advisory;
      default:
        return DisasterSeverity.normal;
    }
  }
}

/// Service managing real-time disaster alerts & extreme weather monitoring (PRD Req 10)
class DisasterTrackingService {
  final FirebaseFirestore? _firestore;

  DisasterTrackingService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore? get firestore {
    if (_firestore != null) return _firestore;
    return Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
  }

  /// Fetches the active disaster alert for the user's location or district
  /// Evaluates official broadcasts first, then evaluates physical weather telemetry
  Future<DisasterAlert> getActiveDisasterAlert({
    required double latitude,
    required double longitude,
    String? district,
    WeatherRiskReport? weatherReport,
  }) async {
    // 1. Check for official administrative disaster broadcast in Firestore
    final fs = firestore;
    if (fs != null) {
      try {
        final query = await fs
            .collection('disaster_alerts')
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));

        if (query.docs.isNotEmpty) {
          final alert = DisasterAlert.fromFirestore(
            query.docs.first.data(),
            query.docs.first.id,
          );
          if (district == null ||
              alert.affectedDistricts.isEmpty ||
              alert.affectedDistricts.any((d) => d.toLowerCase() == district.toLowerCase())) {
            return alert;
          }
        }
      } catch (e) {
        debugPrint('[DisasterTrackingService] Firestore broadcast check skipped/offline: $e');
      }
    }

    // 2. Real-Time Meteorological Threshold Evaluation
    // TODO: Add API Key for IMD / NDMA Disaster Alert Push API (https://sachet.ndma.gov.in)
    if (weatherReport != null) {
      final now = DateTime.now().toUtc();
      
      // Extreme Heavy Rainfall (> 45 mm or critical flood accumulation)
      if (weatherReport.currentPrecipitationMm > 45.0) {
        return DisasterAlert(
          id: 'ALERT-HEAVY-RAIN-${weatherReport.geoHash5}',
          disasterType: DisasterType.heavyRainfall,
          severity: DisasterSeverity.warning,
          headline: 'Heavy Rainfall Warning: ${weatherReport.currentPrecipitationMm.toStringAsFixed(1)} mm Precip',
          description: 'Sustained severe precipitation detected in your micro-climate cell. High risk of waterlogging, root asphyxiation, and fungal spore dissemination.',
          emergencyPrecautions: [
            'Create field drainage channels immediately to prevent root flooding.',
            'Cease all pesticide & fertilizer applications until soil drains.',
            'Stake tall tomato/chilli plants to prevent lodging.',
          ],
          effectiveTime: now,
          expiresTime: now.add(const Duration(hours: 12)),
          affectedDistricts: district != null ? [district] : ['Current Zone'],
          source: 'Open-Meteo Severe Weather Telemetry Engine',
          isActive: true,
        );
      }

      // Extreme Heatwave (> 41.5 °C)
      if (weatherReport.currentTempC >= 41.5) {
        return DisasterAlert(
          id: 'ALERT-HEATWAVE-${weatherReport.geoHash5}',
          disasterType: DisasterType.heatwave,
          severity: DisasterSeverity.warning,
          headline: 'Severe Heatwave Warning (${weatherReport.currentTempC.toStringAsFixed(1)}°C)',
          description: 'Critical thermal stress detected. Blossom drop, pollen desiccation, and rapid leaf scorch likely.',
          emergencyPrecautions: [
            'Provide light micro-irrigation or sprinkler misting during early morning (6 AM - 8 AM).',
            'Avoid midday field spraying or soil disturbance.',
            'Apply straw/crop residue mulch around root zones to conserve soil moisture.',
          ],
          effectiveTime: now,
          expiresTime: now.add(const Duration(hours: 18)),
          affectedDistricts: district != null ? [district] : ['Current Zone'],
          source: 'Open-Meteo Thermal Alert Feed',
          isActive: true,
        );
      }

      // High Gale / Squall (> 50 km/h)
      if (weatherReport.currentWindSpeedKmh >= 50.0) {
        return DisasterAlert(
          id: 'ALERT-SQUALL-${weatherReport.geoHash5}',
          disasterType: DisasterType.cyclone,
          severity: DisasterSeverity.watch,
          headline: 'High Wind / Squall Alert (${weatherReport.currentWindSpeedKmh.toStringAsFixed(0)} km/h)',
          description: 'Strong gusty winds capable of damaging crop trellises and tearing broad foliage.',
          emergencyPrecautions: [
            'Reinforce shade nets and polyhouse plastic covers.',
            'Anchor staking ropes for vine crops.',
            'Delay drone or mechanical high-pressure spray runs.',
          ],
          effectiveTime: now,
          expiresTime: now.add(const Duration(hours: 8)),
          affectedDistricts: district != null ? [district] : ['Current Zone'],
          source: 'Open-Meteo Anemometer Feed',
          isActive: true,
        );
      }
    }

    // 3. Normal conditions — Reassuring Safe State (Req 10)
    return DisasterAlert.normal(district: district);
  }
}

/// Riverpod provider for Disaster Tracking Service
final disasterTrackingServiceProvider = Provider<DisasterTrackingService>((ref) {
  return DisasterTrackingService();
});

/// Riverpod FutureProvider for active disaster alert
final activeDisasterAlertProvider = FutureProvider<DisasterAlert>((ref) async {
  final service = ref.watch(disasterTrackingServiceProvider);
  final weatherAsync = await ref.watch(weatherRiskReportFutureProvider.future);
  
  Position? pos;
  try {
    pos = await Geolocator.getLastKnownPosition();
  } catch (_) {}

  return service.getActiveDisasterAlert(
    latitude: pos?.latitude ?? 0.0,
    longitude: pos?.longitude ?? 0.0,
    weatherReport: weatherAsync,
  );
});
