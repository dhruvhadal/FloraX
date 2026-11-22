import 'package:flutter_test/flutter_test.dart';

import 'package:florax/core/constants/indian_regions.dart';
import 'package:florax/core/utils/ist_date_time_formatter.dart';
import 'package:florax/services/weather/disaster_tracking_service.dart';
import 'package:florax/services/weather/predictive_weather_service.dart';
import 'package:florax/presentation/screens/radar/predictive_radar_and_heatmap_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LeafGuard PRD Comprehensive Verification Suite', () {
    // -------------------------------------------------------------------------
    // 1. REQ 2C: 28 Indian States & 8 Union Territories
    // -------------------------------------------------------------------------
    test('Req 2C: IndianRegions defines exactly 28 States and 8 Union Territories', () {
      expect(IndianRegions.states.length, equals(28));
      expect(IndianRegions.unionTerritories.length, equals(8));
      expect(IndianRegions.allRegions.length, equals(36));

      // Key agricultural hubs must be present
      expect(IndianRegions.states, contains('Maharashtra'));
      expect(IndianRegions.states, contains('Punjab'));
      expect(IndianRegions.states, contains('Uttar Pradesh'));
      expect(IndianRegions.states, contains('Karnataka'));
      expect(IndianRegions.states, contains('Gujarat'));
      expect(IndianRegions.unionTerritories, contains('Jammu and Kashmir'));
      expect(IndianRegions.unionTerritories, contains('Delhi'));
    });

    // -------------------------------------------------------------------------
    // 2. REQ 1 & 6: Indian Standard Time (IST = UTC + 05:30) Formatting
    // -------------------------------------------------------------------------
    test('Req 1 & 6: IstTimeUtils converts UTC to IST accurately', () {
      final utcTime = DateTime.utc(2026, 11, 22, 12, 0, 0); // 12:00 UTC = 17:30 IST
      final istTime = IstTimeUtils.toIst(utcTime);

      expect(istTime.hour, equals(17));
      expect(istTime.minute, equals(30));

      final formattedDateTime = IstTimeUtils.formatDateTimeIst(utcTime);
      expect(formattedDateTime, contains('IST'));
      expect(formattedDateTime, contains('05:30 PM'));

      final formattedTimeOnly = IstTimeUtils.formatTimeOnlyIst(utcTime);
      expect(formattedTimeOnly, equals('05:30 PM IST'));
    });

    // -------------------------------------------------------------------------
    // 3. REQ 6: Device-Centric Weather Telemetry & Forecast Separation
    // -------------------------------------------------------------------------
    test('Req 6: WeatherRiskReport contains wind speed, rain probability, and IST timestamp', () {
      final report = WeatherRiskReport(
        geoHash5: 'te7ue',
        currentTempC: 27.5,
        currentHumidity: 65.0,
        currentPrecipitationMm: 2.5,
        currentWindSpeedKmh: 18.0,
        precipitationProbability: 40.0,
        aggregateOutbreakScore: 45,
        aggregateRiskLevel: WeatherRiskLevel.moderate,
        primaryThreatName: 'Early Blight Inoculum',
        localizedAdvisory: {'en': 'Test advisory'},
        dailyForecasts: const [],
        syncedAt: DateTime.utc(2026, 11, 22, 10, 0, 0),
      );

      // Current Conditions
      expect(report.currentTempC, equals(27.5));
      expect(report.currentHumidity, equals(65.0));
      expect(report.currentWindSpeedKmh, equals(18.0));

      // Forecast Conditions
      expect(report.currentPrecipitationMm, equals(2.5));
      expect(report.precipitationProbability, equals(40.0));

      // IST Representation
      expect(report.lastUpdatedIst, contains('IST'));
      expect(report.lastUpdatedTimeIst, contains('IST'));
    });

    // -------------------------------------------------------------------------
    // 4. REQ 10: Active Disaster Tracking & Reassuring Normal State
    // -------------------------------------------------------------------------
    test('Req 10: DisasterTrackingService returns normal status when conditions are safe', () async {
      final service = DisasterTrackingService();
      final report = WeatherRiskReport(
        geoHash5: 'te7ue',
        currentTempC: 26.0,
        currentHumidity: 70.0,
        currentPrecipitationMm: 0.0,
        currentWindSpeedKmh: 12.0,
        precipitationProbability: 10.0,
        aggregateOutbreakScore: 30,
        aggregateRiskLevel: WeatherRiskLevel.low,
        primaryThreatName: 'Low Pathogen Activity',
        localizedAdvisory: {},
        dailyForecasts: const [],
        syncedAt: DateTime.now().toUtc(),
      );

      final alert = await service.getActiveDisasterAlert(
        latitude: 19.9975,
        longitude: 73.7898,
        district: 'Nashik',
        weatherReport: report,
      );

      expect(alert.isThreat, isFalse);
      expect(alert.disasterType, equals(DisasterType.none));
      expect(alert.severity, equals(DisasterSeverity.normal));
      expect(alert.headline, contains('No Extreme Weather Warnings'));
    });

    test('Req 10: DisasterTrackingService raises Heavy Rainfall Alert on critical precipitation (>45mm)', () async {
      final service = DisasterTrackingService();
      final extremeReport = WeatherRiskReport(
        geoHash5: 'te7ue',
        currentTempC: 24.0,
        currentHumidity: 95.0,
        currentPrecipitationMm: 55.0, // Critical rain
        currentWindSpeedKmh: 20.0,
        precipitationProbability: 90.0,
        aggregateOutbreakScore: 85,
        aggregateRiskLevel: WeatherRiskLevel.critical,
        primaryThreatName: 'Severe Waterlogging',
        localizedAdvisory: {},
        dailyForecasts: const [],
        syncedAt: DateTime.now().toUtc(),
      );

      final alert = await service.getActiveDisasterAlert(
        latitude: 19.9975,
        longitude: 73.7898,
        district: 'Nashik',
        weatherReport: extremeReport,
      );

      expect(alert.isThreat, isTrue);
      expect(alert.disasterType, equals(DisasterType.heavyRainfall));
      expect(alert.severity, equals(DisasterSeverity.warning));
      expect(alert.emergencyPrecautions, isNotEmpty);
      expect(alert.emergencyPrecautions.first, contains('drainage channels'));
    });

    // -------------------------------------------------------------------------
    // 5. REQS 9 & 11: Unified GIS Map Layer Modes
    // -------------------------------------------------------------------------
    test('Req 11: MapLayerMode defines 3 unified agricultural layers', () {
      expect(MapLayerMode.values.length, equals(3));
      expect(MapLayerMode.outbreaks.label, equals('Disease Outbreaks'));
      expect(MapLayerMode.soilFertility.label, equals('Soil & Fertilizer'));
      expect(MapLayerMode.weatherRadar.label, equals('Weather Radar'));
    });
  });
}
