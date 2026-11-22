import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../domain/models/florax_models.dart';
import '../../../repositories/ecosystem_directory_repository.dart';
import '../../../services/auth/auth_role_service.dart';
import '../../../services/voice/vernacular_voice_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../../services/weather/disaster_tracking_service.dart';
import '../../../services/weather/predictive_weather_service.dart';
import '../../widgets/florax_design_primitives.dart';

/// Available GIS Layer Modes for the Unified Agricultural Map (PRD Reqs 9, 11)
enum MapLayerMode {
  outbreaks,
  soilFertility,
  weatherRadar;

  String get label {
    switch (this) {
      case MapLayerMode.outbreaks:
        return 'Disease Outbreaks';
      case MapLayerMode.soilFertility:
        return 'Soil & Fertilizer';
      case MapLayerMode.weatherRadar:
        return 'Weather Radar';
    }
  }
}

/// Predictive Micro-Climate, Verified Institutional Disease Alerts & Regional Heatmap (Feature #14)
class PredictiveRadarAndHeatmapScreen extends ConsumerStatefulWidget {
  const PredictiveRadarAndHeatmapScreen({super.key});

  @override
  ConsumerState<PredictiveRadarAndHeatmapScreen> createState() =>
      _PredictiveRadarAndHeatmapScreenState();
}

class _PredictiveRadarAndHeatmapScreenState
    extends ConsumerState<PredictiveRadarAndHeatmapScreen>
    with SingleTickerProviderStateMixin {
  String _selectedSeverityFilter = 'ALL';
  MapLayerMode _activeMapLayer = MapLayerMode.outbreaks; // PRD Req 11
  LatLng? _customFarmLocation; // PRD Req 7: Calibrated farm location
  late AnimationController _radarAnimController;
  late final MapController _mapController;
  bool _isOfflineRadarMode = false;
  static final bool _isTestEnvironment =
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherRiskReportFutureProvider);
    final authService = ref.watch(authRoleServiceProvider);
    final verifiedReportsAsync = ref.watch(verifiedOutbreakReportsStreamProvider(null));
    final disasterAlertAsync = ref.watch(activeDisasterAlertProvider); // PRD Req 10

    return FutureBuilder<UserRole>(
      future: authService.getCurrentUserRole(),
      builder: (context, roleSnapshot) {
        final UserRole role = roleSnapshot.data ?? UserRole.farmer;
        final bool isAuthorizedInstitution =
            role == UserRole.kvkScientist || role == UserRole.admin;

        return Scaffold(
          backgroundColor: FloraXTheme.background,
          floatingActionButton: isAuthorizedInstitution
              ? FloatingActionButton.extended(
                  onPressed: _openLogVerifiedOutbreakModal,
                  backgroundColor: FloraXTheme.crimsonAlert,
                  foregroundColor: Colors.white,
                  icon: const Icon(LucideIcons.shieldAlert, size: 18),
                  label: const Text(
                    'Log Verified Outbreak',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              : null,
          body: SafeArea(
            child: RefreshIndicator(
              color: FloraXTheme.neonGreen,
              backgroundColor: FloraXTheme.cardSurface,
              onRefresh: () async {
                ref.invalidate(weatherRiskReportFutureProvider);
                ref.invalidate(verifiedOutbreakReportsStreamProvider(null));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Top Header Strip
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Nearby Outbreak Alerts',
                                  softWrap: true,
                                  style: TextStyle(
                                    color: FloraXTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Interactive Radar & Spray Advisory',
                                  softWrap: true,
                                  style: TextStyle(
                                    color: FloraXTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: FloraXTheme.cardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: FloraXTheme.borderDim, width: 1.5),
                            ),
                            child: IconButton(
                              icon: const Icon(LucideIcons.refreshCw, color: FloraXTheme.primaryGreen, size: 20),
                              onPressed: () {
                                ref.invalidate(weatherRiskReportFutureProvider);
                                ref.invalidate(verifiedOutbreakReportsStreamProvider(null));
                                ref.invalidate(activeDisasterAlertProvider);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ACTIVE DISASTER MONITORING & EARLY WARNING (PRD Req 10)
                  SliverToBoxAdapter(
                    child: _buildDisasterAlertSection(disasterAlertAsync),
                  ),

                  // TOP 1-LINE WEATHER & SPRAY ADVICE BANNER (Daylight Kisan Accessible Banner)
                  SliverToBoxAdapter(
                    child: weatherAsync.when(
                      data: (report) {
                        final voiceGuide = ref.watch(voiceGuideServiceProvider);
                        final strings = voiceGuide.strings;
                        final bool isRainRisk = report.aggregateRiskLevel == WeatherRiskLevel.high ||
                            report.aggregateRiskLevel == WeatherRiskLevel.critical ||
                            (report.aggregateOutbreakScore >= 60);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              isRainRisk
                                  ? FarmerSemanticBanner.caution(
                                      title: strings.rainDoNotSpray,
                                      subtitle: 'High humidity / rain risk — spray will wash off.',
                                      onAudioTap: () => voiceGuide.speak(
                                        voiceGuide.buildWeatherSpokenScript(isRain: true, summary: ''),
                                      ),
                                    )
                                  : FarmerSemanticBanner.healthy(
                                      title: strings.clearSafeToSpray,
                                      subtitle: 'Sunny & calm — best window for foliar treatment.',
                                      onAudioTap: () => voiceGuide.speak(
                                        voiceGuide.buildWeatherSpokenScript(isRain: false, summary: ''),
                                      ),
                                    ),
                              const SizedBox(height: 8),
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  title: const Text(
                                    '🔬 Micro-Climate & Spore Forecast Details',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: FloraXTheme.textSecondary,
                                    ),
                                  ),
                                  tilePadding: EdgeInsets.zero,
                                  children: [
                                    _buildMicroClimateBento(report),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => _buildWeatherLoadingSkeleton(),
                      error: (err, _) => _buildWeatherErrorCard(err.toString()),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // SECTION 2: 5km Cluster Radar (Interactive Daylight Map Viewport)
                  SliverToBoxAdapter(
                    child: _buildRadarViewportSection(),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // SECTION 3: TOP 3 NEARBY OUTBREAK ALERTS LIST
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(LucideIcons.shieldAlert, color: FloraXTheme.crimsonAlert, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ref.watch(activeFarmerLanguageProvider).code == 'mr'
                                        ? 'जवळपासचे रोग अलर्ट (कमाल ३ मुख्य इशारे)'
                                        : (ref.watch(activeFarmerLanguageProvider).code == 'hi'
                                            ? 'आसपास के रोग अलर्ट (शीर्ष ३ मुख्य अलर्ट)'
                                            : 'Nearby Disease Outbreaks (Top 3 Priority)'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: FloraXTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          verifiedReportsAsync.maybeWhen(
                            data: (reports) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${reports.length} ACTIVE',
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // Compact bottom list of max 3 nearby alerts
                  verifiedReportsAsync.when(
                    data: (reports) {
                      final displayReports = reports.take(3).toList();
                      if (displayReports.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: FloraXGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: const [
                                  Icon(LucideIcons.shieldCheck, color: Color(0xFF15803D), size: 26),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No dangerous outbreaks nearby. Your local farm zone is clear.',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: FloraXTheme.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final report = displayReports[index];
                            return _buildCompactFarmerAlertCard(report, index);
                          },
                          childCount: displayReports.length,
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
                        ),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Alerts Error: $err', style: const TextStyle(color: FloraXTheme.crimsonAlert)),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // SECTION 4: ANONYMOUS OUTBREAK CLUSTERS FEED
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(LucideIcons.mapPin, color: FloraXTheme.crimsonAlert, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Regional Outbreak Clusters',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: FloraXTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSeverityFilterChips(),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Live Firestore Outbreak Clusters Stream
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: (!_isTestEnvironment && Firebase.apps.isNotEmpty)
                        ? FirebaseFirestore.instance
                            .collection('outbreak_clusters')
                            .snapshots()
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(color: FloraXTheme.neonGreen),
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No active outbreak clusters reported.',
                                style: TextStyle(color: FloraXTheme.textSecondary),
                              ),
                            ),
                          ),
                        );
                      }

                      final clusters = docs.map((d) => d.data()).where((c) {
                        if (_selectedSeverityFilter == 'ALL') return true;
                        return (c['severity'] as String?)?.toUpperCase() == _selectedSeverityFilter;
                      }).toList();

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final cluster = clusters[index];
                            return _buildOutbreakClusterCard(cluster);
                          },
                          childCount: clusters.length,
                        ),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SECTION 1: MICRO-CLIMATE & SPORE RISK BENTO
  // ===========================================================================

  Widget _buildMicroClimateBento(WeatherRiskReport report) {
    final Color scoreColor = _getRiskColor(report.aggregateRiskLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FloraXGlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: scoreColor.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location & Privacy Shield Pill
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: FloraXTheme.cardSurfaceLighter,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FloraXTheme.borderDim),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.shieldCheck, color: FloraXTheme.neonGreen, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'GeoHash: ${report.geoHash5}',
                        style: const TextStyle(
                          color: FloraXTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: FloraXTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Text(
                        report.isFromOfflineCache ? 'Offline SQLite' : 'Open-Meteo',
                        style: TextStyle(
                          color: report.isFromOfflineCache ? FloraXTheme.amberCaution : FloraXTheme.neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: FloraXTheme.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FloraXTheme.borderDim),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.clock, color: FloraXTheme.primaryGreen, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Updated: ${report.lastUpdatedTimeIst}',
                        style: const TextStyle(
                          color: FloraXTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // CURRENT CONDITIONS (PRD Req 6)
            const Text(
              'Current Conditions (सध्याचे हवामान)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: FloraXTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTelemetryTile(
                  icon: LucideIcons.thermometer,
                  label: 'Temp',
                  value: '${report.currentTempC.toStringAsFixed(1)}°C',
                  accentColor: FloraXTheme.amberCaution,
                ),
                const SizedBox(width: 8),
                _buildTelemetryTile(
                  icon: LucideIcons.droplets,
                  label: 'Humidity',
                  value: '${report.currentHumidity.toStringAsFixed(0)}%',
                  accentColor: FloraXTheme.bioCyan,
                ),
                const SizedBox(width: 8),
                _buildTelemetryTile(
                  icon: LucideIcons.wind,
                  label: 'Wind',
                  value: '${report.currentWindSpeedKmh.toStringAsFixed(0)} km/h',
                  accentColor: const Color(0xFF60A5FA),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // FORECAST & SPORE RISK (PRD Req 6)
            const Text(
              'Forecast & Pathogen Risk (अंदाज व रोग जोखीम)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: FloraXTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTelemetryTile(
                  icon: LucideIcons.cloudRain,
                  label: 'Expected Rain',
                  value: '${report.currentPrecipitationMm.toStringAsFixed(1)} mm',
                  accentColor: FloraXTheme.neonGreen,
                ),
                const SizedBox(width: 8),
                _buildTelemetryTile(
                  icon: LucideIcons.umbrella,
                  label: 'Rain Prob.',
                  value: '${report.precipitationProbability.toStringAsFixed(0)}%',
                  accentColor: const Color(0xFF818CF8),
                ),
                const SizedBox(width: 8),
                _buildTelemetryTile(
                  icon: LucideIcons.alertCircle,
                  label: 'Spore Index',
                  value: '${report.aggregateOutbreakScore}/100',
                  accentColor: scoreColor,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 7-Day Spore Outbreak Risk Radial Gauge & Advisory
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FloraXTheme.cardSurfaceLighter,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FloraXTheme.borderDim),
              ),
              child: Row(
                children: [
                  // Radial Gauge
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: (report.aggregateOutbreakScore / 100.0).clamp(0.0, 1.0),
                            strokeWidth: 5,
                            backgroundColor: FloraXTheme.borderDim,
                            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${report.aggregateOutbreakScore}%',
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              report.aggregateRiskLevel.label.toUpperCase(),
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Advisory content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scoreColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '7-Day Spore Outbreak Risk',
                              style: TextStyle(
                                color: FloraXTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.localizedAdvisory['mr'] ??
                              report.localizedAdvisory['hi'] ??
                              report.localizedAdvisory['en'] ??
                              'Foliar spore germination risk elevated — apply preventive bio-agent immediately.',
                          style: const TextStyle(
                            color: FloraXTheme.textSecondary,
                            fontSize: 11,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            final voice = ref.read(vernacularVoiceServiceProvider);
                            final advisoryText = report.localizedAdvisory['mr'] ??
                                report.localizedAdvisory['hi'] ??
                                report.localizedAdvisory['en'] ??
                                'Spore risk active.';
                            voice.speak(advisoryText, langCode: 'mr');
                          },
                          child: Row(
                            children: const [
                              Icon(LucideIcons.volume2, color: FloraXTheme.amberCaution, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'ऑडिओ अलर्ट ऐका (Audio Alert)',
                                style: TextStyle(
                                  color: FloraXTheme.amberCaution,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: 5KM CLUSTER RADAR VIEWPORT
  // ===========================================================================

  /// Decode 5-character privacy-preserving GeoHash to LatLng center
  LatLng _decodeGeoHashToLatLng(
    String geoHash5, {
    LatLng fallback = const LatLng(19.9975, 73.7898),
  }) {
    try {
      final clean = geoHash5.trim();
      if (clean.isEmpty || clean.length < 4) return fallback;
      final coords = GeoHasher().decode(clean);
      if (coords.length >= 2 && coords[0].isFinite && coords[1].isFinite) {
        // coords[0] is longitude, coords[1] is latitude in dart_geohash
        return LatLng(coords[1], coords[0]);
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildRadarViewportSection() {
    final weatherAsync = ref.watch(weatherRiskReportFutureProvider);
    final verifiedReportsAsync = ref.watch(verifiedOutbreakReportsStreamProvider(null));
    final String userGeoHash = weatherAsync.valueOrNull?.geoHash5 ?? 'te7ue';
    final LatLng defaultLatLng = _decodeGeoHashToLatLng(userGeoHash);
    final LatLng userLatLng = _customFarmLocation ?? defaultLatLng;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FloraXGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOfflineRadarMode ? LucideIcons.radar : LucideIcons.mapPin,
                      color: FloraXTheme.bioCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOfflineRadarMode ? '5km Vector Radar' : 'GIS & 5km Radar',
                      style: const TextStyle(
                        color: FloraXTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Mode toggle pill
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isOfflineRadarMode = !_isOfflineRadarMode;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isOfflineRadarMode
                          ? FloraXTheme.amberCaution.withValues(alpha: 0.15)
                          : FloraXTheme.bioCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isOfflineRadarMode
                            ? FloraXTheme.amberCaution.withValues(alpha: 0.5)
                            : FloraXTheme.bioCyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOfflineRadarMode ? LucideIcons.radar : LucideIcons.map,
                          size: 11,
                          color: _isOfflineRadarMode ? FloraXTheme.amberCaution : FloraXTheme.bioCyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isOfflineRadarMode ? 'Offline Radar' : 'Interactive Map',
                          style: TextStyle(
                            color: _isOfflineRadarMode ? FloraXTheme.amberCaution : FloraXTheme.bioCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: FloraXTheme.cardSurfaceLighter,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FloraXTheme.borderDim),
                  ),
                  child: Text(
                    'Cell: $userGeoHash',
                    style: const TextStyle(
                      color: FloraXTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // UNIFIED GIS MAP LAYER CHIPS (PRD Req 11)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildLayerChip(
                    mode: MapLayerMode.outbreaks,
                    icon: LucideIcons.flame,
                    label: 'Disease Outbreaks',
                    isSelected: _activeMapLayer == MapLayerMode.outbreaks,
                  ),
                  const SizedBox(width: 8),
                  _buildLayerChip(
                    mode: MapLayerMode.soilFertility,
                    icon: LucideIcons.sprout,
                    label: 'Soil & Fertilizer',
                    isSelected: _activeMapLayer == MapLayerMode.soilFertility,
                  ),
                  const SizedBox(width: 8),
                  _buildLayerChip(
                    mode: MapLayerMode.weatherRadar,
                    icon: LucideIcons.cloudRain,
                    label: 'Weather Radar',
                    isSelected: _activeMapLayer == MapLayerMode.weatherRadar,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Live GIS / Radar Viewport Canvas
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 290,
                width: double.infinity,
                color: const Color(0xFF080D0A),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: (!_isTestEnvironment && Firebase.apps.isNotEmpty)
                      ? FirebaseFirestore.instance
                          .collection('outbreak_clusters')
                          .snapshots()
                      : const Stream.empty(),
                  builder: (context, clusterSnap) {
                    final verifiedReports = verifiedReportsAsync.valueOrNull ?? [];
                    final List<_RadarOutbreakPinItem> pins = [];

                    // 1. Populate pins directly from live Firestore outbreak_clusters stream
                    if (clusterSnap.hasData && clusterSnap.data!.docs.isNotEmpty) {
                      for (final doc in clusterSnap.data!.docs) {
                        final data = doc.data();
                        final sevStr = (data['severity'] as String?)?.toUpperCase() ?? 'MODERATE';
                        final SeverityGrade sev = sevStr == 'CRITICAL' || sevStr == 'SEVERE'
                            ? SeverityGrade.severe
                            : (sevStr == 'HIGH' || sevStr == 'MODERATE' ? SeverityGrade.moderate : SeverityGrade.mild);
                        final crop = (data['cropName'] as String?) ?? 'Crop';
                        final dis = (data['diseaseName'] ?? data['primaryDisease'] as String? ?? 'Outbreak')
                            .replaceAll('abiotic_', '')
                            .replaceAll('_', ' ');
                        final hash = (data['geoHash5'] as String?) ?? (data['geohash'] as String?) ?? userGeoHash;
                        final centerCoords = _decodeGeoHashToLatLng(hash);
                        final double angle = _computeDeterministicAngle(hash, doc.id);
                        final offsetLat = 0.003 * math.sin(angle);
                        final offsetLng = 0.003 * math.cos(angle);
                        final coordinates = LatLng(centerCoords.latitude + offsetLat, centerCoords.longitude + offsetLng);
                        final caseCount = (data['caseCount'] as num?)?.toInt() ?? (data['activeCases'] as num?)?.toInt() ?? 1;
                        final verifiedBy = (data['verifiedBy'] as String?) ?? (data['institutionName'] as String?);
                        final isVerified = (data['isVerified'] as bool?) ?? false;

                        pins.add(_RadarOutbreakPinItem(
                          id: doc.id,
                          label: '$crop $dis',
                          cropName: crop,
                          diseaseName: dis,
                          geoHash5: hash,
                          coordinates: coordinates,
                          severity: sev,
                          caseCount: caseCount,
                          verifiedBy: verifiedBy,
                          isVerified: isVerified,
                          isPulsing: sev == SeverityGrade.severe,
                        ));
                      }
                    }

                    // 2. Supplement with verified outbreak reports if not already represented
                    if (verifiedReports.isNotEmpty) {
                      for (final r in verifiedReports) {
                        final bool exists = pins.any((p) =>
                            p.id == r.reportId ||
                            (p.geoHash5 == r.geoHash5 && p.label.toLowerCase().contains(r.diseaseId.toLowerCase())));
                        if (!exists) {
                          final crop = r.cropName;
                          final dis = r.diseaseId.replaceAll('abiotic_', '').replaceAll('_', ' ');
                          final centerCoords = _decodeGeoHashToLatLng(r.geoHash5);
                          final double angle = _computeDeterministicAngle(r.geoHash5, r.reportId);
                          final offsetLat = 0.003 * math.sin(angle);
                          final offsetLng = 0.003 * math.cos(angle);
                          final coordinates = LatLng(centerCoords.latitude + offsetLat, centerCoords.longitude + offsetLng);
                          final verifiedBy = r.organizationName.isNotEmpty
                              ? r.organizationName
                              : (r.verifiedByInstitutionName.isNotEmpty ? r.verifiedByInstitutionName : 'ICAR / KVK Agronomist');

                          pins.add(_RadarOutbreakPinItem(
                            id: r.reportId,
                            label: '$crop $dis',
                            cropName: crop,
                            diseaseName: dis,
                            geoHash5: r.geoHash5,
                            coordinates: coordinates,
                            severity: r.severityGrade,
                            caseCount: r.confirmedCasesCount > 0 ? r.confirmedCasesCount : 1,
                            verifiedBy: verifiedBy,
                            isVerified: true,
                            isPulsing: r.severityGrade == SeverityGrade.severe,
                          ));
                        }
                      }
                    }

                    if (_isOfflineRadarMode) {
                      return _buildOfflineRadarCanvas(pins, userGeoHash);
                    } else {
                      return _buildInteractiveGisMap(pins, userLatLng, userGeoHash);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Dynamic Legend Strip based on Active Map Layer (PRD Reqs 9, 11)
            _buildDynamicLegendStrip(weatherAsync.valueOrNull),
          ],
        ),
      ),
    );
  }

  /// Builds the real OpenStreetMap interactive GIS viewport with Dark Bio theme
  Widget _buildInteractiveGisMap(
    List<_RadarOutbreakPinItem> pins,
    LatLng userLatLng,
    String userGeoHash,
  ) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 12.0,
            minZoom: 7.0,
            maxZoom: 17.0,
            backgroundColor: Colors.white,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.florax.crophealth',
              tileProvider: _isTestEnvironment ? _TestSafeTileProvider() : null,
              evictErrorTileStrategy: EvictErrorTileStrategy.none,
              errorTileCallback: (tile, error, stackTrace) {},
            ),
            // 1. Outbreak Circles (only in outbreaks mode)
            if (_activeMapLayer == MapLayerMode.outbreaks)
              CircleLayer(
                circles: pins.map((pin) {
                  final Color baseColor;
                  switch (pin.severity) {
                    case SeverityGrade.severe:
                      baseColor = FloraXTheme.crimsonAlert;
                      break;
                    case SeverityGrade.moderate:
                      baseColor = FloraXTheme.amberCaution;
                      break;
                    case SeverityGrade.mild:
                      baseColor = FloraXTheme.neonGreen;
                      break;
                  }
                  final double radius = pin.severity == SeverityGrade.severe
                      ? 4900
                      : (pin.severity == SeverityGrade.moderate ? 3600 : 2500);

                  return CircleMarker(
                    point: pin.coordinates,
                    radius: radius,
                    useRadiusInMeter: true,
                    color: baseColor.withValues(alpha: 0.20),
                    borderColor: baseColor.withValues(alpha: 0.70),
                    borderStrokeWidth: 1.5,
                  );
                }).toList(),
              ),

            // 2. Weather Radar Precipitation Circles (PRD Req 11)
            if (_activeMapLayer == MapLayerMode.weatherRadar)
              CircleLayer(
                circles: _buildWeatherRadarCircles(
                  userLatLng,
                  ref.watch(weatherRiskReportFutureProvider).valueOrNull,
                ),
              ),

            // 3. Soil & Fertilizer Agricultural Parcels (PRD Req 9)
            if (_activeMapLayer == MapLayerMode.soilFertility)
              PolygonLayer(
                polygons: _buildSoilFertilityPolygons(userLatLng),
              ),

            // 4. Marker Layer
            MarkerLayer(
              markers: [
                // Outbreak pin markers
                if (_activeMapLayer == MapLayerMode.outbreaks)
                  ...pins.map((pin) {
                    final Color color = _getSeverityColor(pin.severity);
                    return Marker(
                      point: pin.coordinates,
                      width: 42,
                      height: 42,
                      child: GestureDetector(
                        onTap: () => _showOutbreakDetailsBottomSheet(context, pin, userLatLng),
                        child: _buildMapOutbreakMarker(pin, color),
                      ),
                    );
                  }),

                // Soil & Fertilizer Status Markers
                if (_activeMapLayer == MapLayerMode.soilFertility)
                  ..._buildSoilFertilityMarkers(userLatLng),

                // Weather Radar Anemometer Markers
                if (_activeMapLayer == MapLayerMode.weatherRadar)
                  ..._buildWeatherRadarMarkers(
                    userLatLng,
                    ref.watch(weatherRiskReportFutureProvider).valueOrNull,
                  ),

                // Farmer current GPS marker
                Marker(
                  point: userLatLng,
                  width: 44,
                  height: 44,
                  child: _buildMapUserGpsMarker(),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),

        // Floating Empty-Radar State if 0 active outbreaks
        if (pins.isEmpty)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FloraXTheme.neonGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.shieldCheck, color: FloraXTheme.neonGreen, size: 14),
                  SizedBox(width: 6),
                  Text(
                    '5km Perimeter Clear • 0 Active Outbreaks',
                    style: TextStyle(
                      color: FloraXTheme.neonGreen,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Floating Map Overlay Controls (Top-Right)
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              _buildMapFloatingButton(
                icon: LucideIcons.crosshair,
                tooltip: 'Recenter on My Farm (GPS)',
                color: FloraXTheme.bioCyan,
                onPressed: () {
                  _mapController.move(userLatLng, 12.5);
                },
              ),
              const SizedBox(height: 6),
              _buildMapFloatingButton(
                icon: LucideIcons.refreshCw,
                tooltip: 'Refresh Weather & Risk',
                color: FloraXTheme.neonGreen,
                onPressed: () {
                  ref.invalidate(weatherRiskReportFutureProvider);
                  ref.invalidate(verifiedOutbreakReportsStreamProvider(null));
                },
              ),
              const SizedBox(height: 6),
              _buildMapFloatingButton(
                icon: LucideIcons.mapPin,
                tooltip: 'Calibrate Farm Location',
                color: FloraXTheme.amberCaution,
                onPressed: () {
                  _showLocationCorrectionDialog(context, userLatLng);
                },
              ),
              const SizedBox(height: 6),
              _buildMapFloatingButton(
                icon: LucideIcons.radar,
                tooltip: 'Switch to Offline Radar',
                color: FloraXTheme.amberCaution,
                onPressed: () {
                  setState(() {
                    _isOfflineRadarMode = true;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the lightweight vector radar viewport for 0-connectivity rural environments
  Widget _buildOfflineRadarCanvas(List<_RadarOutbreakPinItem> pins, String userGeoHash) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

        return Stack(
          children: [
            // Radar Grid & Sweeper
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _radarAnimController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarCanvasPainter(
                      sweepAngle: _radarAnimController.value * 2 * math.pi,
                    ),
                  );
                },
              ),
            ),

            // Geographic corridor markers
            const Positioned(
              top: 10,
              left: 12,
              child: Text(
                'DINDORI N.',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const Positioned(
              bottom: 10,
              left: 12,
              child: Text(
                'NASHIK METRO',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const Positioned(
              top: 10,
              right: 12,
              child: Text(
                'NIPHAD E.',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Clean Empty-Radar State when zero verified outbreaks exist nearby
            if (pins.isEmpty)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FloraXTheme.neonGreen.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.shieldCheck, color: FloraXTheme.neonGreen, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '5km Perimeter Clear • 0 Active Outbreaks',
                        style: TextStyle(
                          color: FloraXTheme.neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Dynamically Positioned Polar Outbreak Pins
            ...pins.map((pin) {
              final double angle = _computeDeterministicAngle(pin.geoHash5, pin.id);
              final double radius = _computeDeterministicRadius(pin.geoHash5, userGeoHash, pin.id);
              final double px = center.dx + radius * math.cos(angle);
              final double py = center.dy + radius * math.sin(angle);

              return Positioned(
                left: (px - 45).clamp(4.0, constraints.maxWidth - 94.0),
                top: (py - 16).clamp(8.0, constraints.maxHeight - 32.0),
                width: 90,
                child: _buildRadarPin(
                  label: pin.label,
                  color: _getSeverityColor(pin.severity),
                  isPulsing: pin.isPulsing,
                ),
              );
            }),

            // User Center GPS Marker
            Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: FloraXTheme.bioCyan.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: FloraXTheme.bioCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),

            // Floating button to switch back to GIS Map
            Positioned(
              top: 10,
              right: 10,
              child: _buildMapFloatingButton(
                icon: LucideIcons.map,
                tooltip: 'Switch to Interactive GIS Map',
                color: FloraXTheme.bioCyan,
                onPressed: () {
                  setState(() {
                    _isOfflineRadarMode = false;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Map pin marker with severity color and pulsing animation
  Widget _buildMapOutbreakMarker(_RadarOutbreakPinItem pin, Color color) {
    return AnimatedBuilder(
      animation: _radarAnimController,
      builder: (context, _) {
        final double pulse = pin.isPulsing
            ? (0.8 + 0.25 * math.sin(_radarAnimController.value * 2 * math.pi).abs())
            : 1.0;

        return Transform.scale(
          scale: pulse,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: FloraXTheme.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: pin.isPulsing ? 0.6 : 0.35),
                      blurRadius: pin.isPulsing ? 10 : 6,
                      spreadRadius: pin.isPulsing ? 2 : 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    pin.severity == SeverityGrade.severe
                        ? LucideIcons.alertTriangle
                        : (pin.severity == SeverityGrade.moderate ? LucideIcons.alertCircle : LucideIcons.shieldAlert),
                    color: color,
                    size: 16,
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: pin.isVerified
                    ? Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF15803D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.shieldCheck, size: 8, color: Colors.white),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: FloraXTheme.bioCyan,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AI',
                          style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Farmer current GPS location marker with concentric pulsing wave
  Widget _buildMapUserGpsMarker() {
    return AnimatedBuilder(
      animation: _radarAnimController,
      builder: (context, _) {
        final double wave = _radarAnimController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14 + 24 * wave,
              height: 14 + 24 * wave,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: FloraXTheme.bioCyan.withValues(alpha: (1.0 - wave).clamp(0.0, 1.0) * 0.8),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: FloraXTheme.bioCyan.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: FloraXTheme.bioCyan,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: FloraXTheme.bioCyan,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compact floating button for map viewport controls
  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1512).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FloraXTheme.borderDim),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  /// Displays detailed outbreak information bottom sheet when an outbreak pin is tapped
  void _showOutbreakDetailsBottomSheet(
    BuildContext context,
    _RadarOutbreakPinItem pin,
    LatLng userLatLng,
  ) {
    final double distanceKm = const Distance().as(
      LengthUnit.Kilometer,
      userLatLng,
      pin.coordinates,
    );

    final Color sevColor = _getSeverityColor(pin.severity);
    final String sevLabel = pin.severity == SeverityGrade.severe
        ? 'CRITICAL / SEVERE OUTBREAK'
        : (pin.severity == SeverityGrade.moderate
            ? 'MODERATE EPIDEMIC RISK'
            : 'MONITORED / MILD ALERT');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1512),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: FloraXTheme.borderDim),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Severity Tag & Institutional Verifier Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sevColor.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.alertTriangle, size: 13, color: sevColor),
                        const SizedBox(width: 6),
                        Text(
                          sevLabel,
                          style: TextStyle(
                            color: sevColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pin.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FloraXTheme.bioCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: FloraXTheme.bioCyan.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.badgeCheck, size: 13, color: FloraXTheme.bioCyan),
                          SizedBox(width: 4),
                          Text(
                            'KVK / NGO Verified',
                            style: TextStyle(
                              color: FloraXTheme.bioCyan,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Crop & Disease Name
              Text(
                '${pin.cropName} • ${pin.diseaseName}',
                style: const TextStyle(
                  color: FloraXTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),

              // 3-Metric Telemetry Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FloraXTheme.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FloraXTheme.borderDim),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModalMetricItem(
                        icon: LucideIcons.mapPin,
                        iconColor: FloraXTheme.neonGreen,
                        title: 'Distance',
                        value: distanceKm < 0.1 ? '< 0.1 km' : '${distanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                    Container(width: 1, height: 32, color: FloraXTheme.borderDim),
                    Expanded(
                      child: _buildModalMetricItem(
                        icon: LucideIcons.users,
                        iconColor: FloraXTheme.amberCaution,
                        title: 'Active Cases',
                        value: '${pin.caseCount} Field Reports',
                      ),
                    ),
                    Container(width: 1, height: 32, color: FloraXTheme.borderDim),
                    Expanded(
                      child: _buildModalMetricItem(
                        icon: LucideIcons.shield,
                        iconColor: FloraXTheme.bioCyan,
                        title: 'Cell ID',
                        value: pin.geoHash5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Privacy & Corridors Info Note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: const [
                    Icon(LucideIcons.shieldCheck, size: 14, color: Colors.white38),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Farmer Privacy Protected: Location masked to ~4.9 km GeoHash-5 bounding corridor.',
                        style: TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ),

              if (pin.verifiedBy != null && pin.verifiedBy!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(LucideIcons.landmark, size: 13, color: FloraXTheme.bioCyan),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verifying Institution: ${pin.verifiedBy}',
                        style: const TextStyle(
                          color: FloraXTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Action Button: Focus on Map
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (_isOfflineRadarMode) {
                      setState(() {
                        _isOfflineRadarMode = false;
                      });
                    }
                    _mapController.move(pin.coordinates, 13.5);
                  },
                  icon: const Icon(LucideIcons.crosshair, size: 16),
                  label: const Text('Focus Outbreak on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloraXTheme.cardSurfaceLighter,
                    foregroundColor: FloraXTheme.neonGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Metric cell for bottom sheet
  Widget _buildModalMetricItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: FloraXTheme.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  double _computeDeterministicAngle(String geoHash, String id) {
    final combined = '$geoHash-$id';
    int hash = 5381;
    for (int i = 0; i < combined.length; i++) {
      hash = ((hash << 5) + hash) + combined.codeUnitAt(i);
    }
    final deg = (hash.abs() % 360).toDouble();
    return (deg * math.pi) / 180.0;
  }

  double _computeDeterministicRadius(String pinGeoHash, String userGeoHash, String id) {
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (hash * 37 + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final double jitter = (hash % 16).toDouble();
    final bool isSameCell = pinGeoHash.isNotEmpty &&
        userGeoHash.isNotEmpty &&
        pinGeoHash.trim().toLowerCase() == userGeoHash.trim().toLowerCase();

    if (isSameCell) {
      return 28.0 + jitter;
    } else {
      return 52.0 + jitter;
    }
  }

  Color _getSeverityColor(SeverityGrade grade) {
    switch (grade) {
      case SeverityGrade.mild:
        return FloraXTheme.neonGreen;
      case SeverityGrade.moderate:
        return FloraXTheme.amberCaution;
      case SeverityGrade.severe:
        return FloraXTheme.crimsonAlert;
    }
  }

  Widget _buildRadarPin({
    required String label,
    required Color color,
    required bool isPulsing,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isPulsing)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 3: COMPACT FARMER ALERT CARD (MAX 3 NEARBY ALERTS)
  // ===========================================================================

  Widget _buildCompactFarmerAlertCard(VerifiedOutbreakReport report, int index) {
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final distanceStr = '${(index + 1) * 3} km away';
    final diseaseClean = report.diseaseId.replaceAll('abiotic_', '').replaceAll('_', ' ').toUpperCase();
    final cropName = report.cropName.isNotEmpty ? report.cropName : 'Tomato';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: FloraXTheme.cardSurface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => SafeArea(
              child: SingleChildScrollView(
                child: _buildVerifiedOutbreakReportCard(report),
              ),
            ),
          );
        },
        child: FloraXGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.leaf, color: Color(0xFF15803D), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$cropName — $diseaseClean',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: FloraXTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 13, color: FloraXTheme.crimsonAlert),
                      const SizedBox(width: 4),
                      Text(
                        '$distanceStr (${report.taluka}, ${report.district})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: FloraXTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.volume2, color: FloraXTheme.primaryGreen, size: 24),
              tooltip: 'Listen to Alert',
              style: IconButton.styleFrom(
                backgroundColor: FloraXTheme.surfaceContainerHigh,
                minimumSize: const Size(44, 44),
              ),
              onPressed: () {
                final text = 'सावधान. $cropName पिकावर $diseaseClean रोग $distanceStr परिसरात नोंदवला गेला आहे.';
                voiceGuide.speak(text);
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 3b: VERIFIED OUTBREAK REPORT CARD (DETAILS)
  // ===========================================================================

  Widget _buildVerifiedOutbreakReportCard(VerifiedOutbreakReport report) {
    Color severityColor;
    switch (report.severityGrade) {
      case SeverityGrade.mild:
        severityColor = FloraXTheme.neonGreen;
        break;
      case SeverityGrade.moderate:
        severityColor = FloraXTheme.amberCaution;
        break;
      case SeverityGrade.severe:
        severityColor = FloraXTheme.crimsonAlert;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FloraXGlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: severityColor.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Severity Pill + Distance + Verified Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    FloraXStatusPill(
                      label: report.severityGrade.toFirestoreValue().toUpperCase(),
                      color: severityColor,
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.navigation, color: FloraXTheme.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${report.taluka}, ${report.district}',
                          style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${report.verifiedAt.day}/${report.verifiedAt.month}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Crop & Disease
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: FloraXTheme.cardSurfaceLighter,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FloraXTheme.borderDim),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.leaf, color: FloraXTheme.neonGreen, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.cropName} • ${report.diseaseId.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          color: FloraXTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(LucideIcons.shieldCheck, color: FloraXTheme.neonGreen, size: 13),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Verified by ${report.organizationName}',
                              style: const TextStyle(
                                color: FloraXTheme.neonGreen,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom Recommendation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FloraXTheme.cardSurfaceLighter,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Bio-Protocol: Copper Oxychloride 50 WP / Trichoderma viride',
                      style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Protocol',
                        style: TextStyle(
                          color: FloraXTheme.neonGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: FloraXTheme.neonGreen, size: 13),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: OUTBREAK CLUSTER CARD & MODAL
  // ===========================================================================

  void _openLogVerifiedOutbreakModal() {
    final cropController = TextEditingController(text: 'Tomato');
    final diseaseController = TextEditingController(text: 'tomato_early_blight');
    final districtController = TextEditingController(text: 'Nashik');
    final talukaController = TextEditingController(text: 'Nashik');
    final hashController = TextEditingController(text: 'tes3z');
    SeverityGrade selectedSeverity = SeverityGrade.moderate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FloraXTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.shieldAlert, color: FloraXTheme.crimsonAlert, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Log Verified Outbreak (Institutional)',
                        style: TextStyle(
                          color: FloraXTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Feature #14: Only accredited KVKs and certified field NGOs may publish outbreak reports to prevent farmer panic.',
                    style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: cropController,
                    style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Host Crop',
                      labelStyle: const TextStyle(color: FloraXTheme.neonGreen),
                      filled: true,
                      fillColor: FloraXTheme.cardSurfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: diseaseController,
                    style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Pathology Taxonomy ID',
                      labelStyle: const TextStyle(color: FloraXTheme.neonGreen),
                      filled: true,
                      fillColor: FloraXTheme.cardSurfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: districtController,
                          style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'District',
                            labelStyle: const TextStyle(color: FloraXTheme.neonGreen),
                            filled: true,
                            fillColor: FloraXTheme.cardSurfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: talukaController,
                          style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Taluka',
                            labelStyle: const TextStyle(color: FloraXTheme.neonGreen),
                            filled: true,
                            fillColor: FloraXTheme.cardSurfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hashController,
                          style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'GeoHash5',
                            labelStyle: const TextStyle(color: FloraXTheme.neonGreen),
                            filled: true,
                            fillColor: FloraXTheme.cardSurfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<SeverityGrade>(
                          initialValue: selectedSeverity,
                          dropdownColor: FloraXTheme.cardSurface,
                          decoration: InputDecoration(
                            labelText: 'Severity',
                            labelStyle: const TextStyle(color: FloraXTheme.neonGreen),
                            filled: true,
                            fillColor: FloraXTheme.cardSurfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: SeverityGrade.values.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.toFirestoreValue(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedSeverity = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _submitVerifiedReport(
                        crop: cropController.text,
                        disease: diseaseController.text,
                        district: districtController.text,
                        taluka: talukaController.text,
                        geoHash: hashController.text,
                        severity: selectedSeverity,
                      );
                    },
                    icon: const Icon(LucideIcons.checkCheck, size: 18),
                    label: const Text('Publish Verified Outbreak to District'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FloraXTheme.crimsonAlert,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitVerifiedReport({
    required String crop,
    required String disease,
    required String district,
    required String taluka,
    required String geoHash,
    required SeverityGrade severity,
  }) async {
    final repo = ref.read(ecosystemDirectoryRepositoryProvider);
    final auth = ref.read(authRoleServiceProvider);
    final user = auth.currentUser;

    final report = VerifiedOutbreakReport(
      reportId: 'REP-${DateTime.now().millisecondsSinceEpoch}',
      submittedByUid: user?.uid ?? 'inst_kvk_01',
      organizationName: 'KVK Nashik (ICAR Accredited)',
      organizationType: 'kvk',
      cropName: crop,
      diseaseId: disease,
      severityGrade: severity,
      geoHash5: geoHash,
      district: district,
      taluka: taluka,
      imageUrl: '',
      verifiedAt: DateTime.now().toUtc(),
    );

    try {
      await repo.submitInstitutionalOutbreakReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verified outbreak alert published to district registry!'),
          backgroundColor: FloraXTheme.neonGreen,
        ),
      );
      ref.invalidate(verifiedOutbreakReportsStreamProvider(null));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission rejected: $e'),
          backgroundColor: FloraXTheme.crimsonAlert,
        ),
      );
    }
  }

  Widget _buildSeverityFilterChips() {
    final filters = ['ALL', 'CRITICAL', 'HIGH'];
    return Row(
      children: filters.map((f) {
        final isSelected = _selectedSeverityFilter == f;
        return GestureDetector(
          onTap: () => setState(() => _selectedSeverityFilter = f),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? FloraXTheme.neonGreen : FloraXTheme.cardSurfaceLighter,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? FloraXTheme.neonGreen : FloraXTheme.borderDim,
              ),
            ),
            child: Text(
              f,
              style: TextStyle(
                color: isSelected ? Colors.black : FloraXTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutbreakClusterCard(Map<String, dynamic> cluster) {
    final String taluka = cluster['taluka'] as String? ?? 'Maharashtra District';
    final String district = cluster['district'] as String? ?? '';
    final String crop = cluster['cropName'] as String? ?? 'Field Crops';
    final String disease = cluster['diseaseName'] as String? ?? 'Fungal Inoculum';
    final int confirmedCases = (cluster['confirmedCases'] as num?)?.toInt() ?? 0;
    final double affectedHectares = (cluster['affectedHectares'] as num?)?.toDouble() ?? 0.0;
    final String geoHash7 = cluster['geohash'] as String? ?? 'tes3z0k';
    final String severity = cluster['severity'] as String? ?? 'HIGH';

    final Color badgeColor = severity.toUpperCase() == 'CRITICAL'
        ? FloraXTheme.crimsonAlert
        : FloraXTheme.amberCaution;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FloraXGlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: badgeColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.flame, color: badgeColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$taluka Taluka, $district',
                      style: const TextStyle(
                        color: FloraXTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                FloraXStatusPill(label: severity.toUpperCase(), color: badgeColor),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              disease,
              style: const TextStyle(
                color: FloraXTheme.neonGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Primary Host: $crop',
              style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.users, color: Colors.white54, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$confirmedCases Cases',
                      style: const TextStyle(
                        color: FloraXTheme.textPrimary,
                        fontSize: 11.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(LucideIcons.trees, color: Colors.white54, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '${affectedHectares.toStringAsFixed(0)} Ha Impacted',
                      style: const TextStyle(
                        color: FloraXTheme.textPrimary,
                        fontSize: 11.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    geoHash7,
                    style: const TextStyle(
                      color: FloraXTheme.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(WeatherRiskLevel level) {
    switch (level) {
      case WeatherRiskLevel.critical:
        return FloraXTheme.crimsonAlert;
      case WeatherRiskLevel.high:
        return FloraXTheme.amberCaution;
      case WeatherRiskLevel.moderate:
        return Colors.yellowAccent;
      case WeatherRiskLevel.low:
        return FloraXTheme.neonGreen;
    }
  }

  Widget _buildTelemetryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: FloraXTheme.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FloraXTheme.borderDim),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: FloraXTheme.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: FloraXTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherLoadingSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 180,
      decoration: BoxDecoration(
        color: FloraXTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FloraXTheme.borderDim),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: FloraXTheme.neonGreen),
      ),
    );
  }

  Widget _buildWeatherErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FloraXTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FloraXTheme.crimsonAlert),
      ),
      child: Text(
        'Weather Radar Error: $error',
        style: const TextStyle(color: FloraXTheme.crimsonAlert, fontSize: 12),
      ),
    );
  }

  Widget _buildLayerChip({
    required MapLayerMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _activeMapLayer = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.cardSurfaceLighter,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: FloraXTheme.primaryGreen.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : FloraXTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : FloraXTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicLegendStrip(WeatherRiskReport? report) {
    if (_activeMapLayer == MapLayerMode.soilFertility) {
      return Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 12,
        runSpacing: 6,
        children: [
          _buildLegendItem('Balanced NPK / Organic', const Color(0xFF16A34A)),
          _buildLegendItem('Under-fertilized (Low N)', const Color(0xFFD97706)),
          _buildLegendItem('Soil Unverified', const Color(0xFF9CA3AF)),
        ],
      );
    } else if (_activeMapLayer == MapLayerMode.weatherRadar) {
      final double wind = report?.currentWindSpeedKmh ?? 12.0;
      return Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 12,
        runSpacing: 6,
        children: [
          _buildLegendItem('Rain Inflow Radius', const Color(0xFF3B82F6)),
          _buildLegendItem('Wind: ${wind.toStringAsFixed(0)} km/h', const Color(0xFF2563EB)),
          _buildLegendItem('Field Protected', FloraXTheme.neonGreen),
        ],
      );
    } else {
      return Wrap(
        alignment: WrapAlignment.spaceAround,
        spacing: 10,
        runSpacing: 6,
        children: [
          _buildLegendItem('Severe (4.9km)', FloraXTheme.crimsonAlert),
          _buildLegendItem('Moderate (3.6km)', FloraXTheme.amberCaution),
          _buildLegendItem('Mild (2.5km)', FloraXTheme.neonGreen),
          _buildLegendItem('KVK Shield', const Color(0xFF15803D)),
          _buildLegendItem('AI Scan', FloraXTheme.bioCyan),
        ],
      );
    }
  }

  Widget _buildDisasterAlertSection(AsyncValue<DisasterAlert> disasterAlertAsync) {
    return disasterAlertAsync.maybeWhen(
      data: (alert) {
        if (alert.isThreat) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FloraXTheme.crimsonAlert, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: FloraXTheme.crimsonAlert.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, color: FloraXTheme.crimsonAlert, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.severity.label,
                              style: const TextStyle(
                                color: FloraXTheme.crimsonAlert,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              alert.headline,
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.description,
                    style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13, height: 1.3),
                  ),
                  if (alert.emergencyPrecautions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Emergency Precautions (आपत्कालीन खबरदारी):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    ...alert.emergencyPrecautions.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: FloraXTheme.crimsonAlert, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                p,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Effective: ${alert.formattedEffectiveTimeIst}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Reassuring normal state (Req 10)
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.shieldCheck, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🛡️ Field Conditions Normal: No extreme weather warnings in your district',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _showLocationCorrectionDialog(BuildContext context, LatLng currentPos) {
    double tempLat = currentPos.latitude;
    double tempLng = currentPos.longitude;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: FloraXTheme.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FloraXTheme.borderDim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(LucideIcons.mapPin, color: FloraXTheme.primaryGreen, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Correct My Farm Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: FloraXTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Adjust your farm pin if device GPS is slightly displaced from your actual agricultural field.',
                style: TextStyle(fontSize: 13, color: FloraXTheme.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FloraXTheme.cardSurfaceLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FloraXTheme.borderDim),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Latitude', style: TextStyle(fontSize: 11, color: FloraXTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          tempLat.toStringAsFixed(5),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: FloraXTheme.borderDim),
                    Column(
                      children: [
                        const Text('Longitude', style: TextStyle(fontSize: 11, color: FloraXTheme.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          tempLng.toStringAsFixed(5),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nudge Farm Boundary (~100m steps):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FloraXTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowUpCircle, size: 32, color: FloraXTheme.primaryGreen),
                    onPressed: () => setModalState(() => tempLat += 0.001),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeftCircle, size: 32, color: FloraXTheme.primaryGreen),
                    onPressed: () => setModalState(() => tempLng -= 0.001),
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(LucideIcons.arrowRightCircle, size: 32, color: FloraXTheme.primaryGreen),
                    onPressed: () => setModalState(() => tempLng += 0.001),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowDownCircle, size: 32, color: FloraXTheme.primaryGreen),
                    onPressed: () => setModalState(() => tempLat -= 0.001),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloraXTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.check, size: 20),
                  label: const Text(
                    'Save Farm Coordinates',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                  setState(() {
                    _customFarmLocation = LatLng(tempLat, tempLng);
                  });
                  _mapController.move(LatLng(tempLat, tempLng), 13.0);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Farm coordinates calibrated: ${tempLat.toStringAsFixed(4)}, ${tempLng.toStringAsFixed(4)}'),
                      backgroundColor: FloraXTheme.primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildSoilFertilityMarkers(LatLng farmCenter) {
    return [
      Marker(
        point: LatLng(farmCenter.latitude - 0.0018, farmCenter.longitude + 0.0022),
        width: 140,
        height: 48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('South Plot: Balanced', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
              Text('NPK 19:19:19 • Organic OK', style: TextStyle(fontSize: 9, color: Color(0xFF15803D))),
            ],
          ),
        ),
      ),
      Marker(
        point: LatLng(farmCenter.latitude + 0.0025, farmCenter.longitude - 0.0015),
        width: 150,
        height: 48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD97706), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('North Ridge: Under-fertilized', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              Text('Low Nitrogen • Add Urea/FYM', style: TextStyle(fontSize: 9, color: Color(0xFFB45309))),
            ],
          ),
        ),
      ),
      Marker(
        point: LatLng(farmCenter.latitude + 0.0012, farmCenter.longitude + 0.0035),
        width: 140,
        height: 48,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF9CA3AF), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Canal Plot: Unverified', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
              Text('Soil Test Kit Pending', style: TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ),
    ];
  }

  List<Polygon> _buildSoilFertilityPolygons(LatLng farmCenter) {
    return [
      Polygon(
        points: [
          LatLng(farmCenter.latitude - 0.0010, farmCenter.longitude + 0.0010),
          LatLng(farmCenter.latitude - 0.0030, farmCenter.longitude + 0.0015),
          LatLng(farmCenter.latitude - 0.0028, farmCenter.longitude + 0.0035),
          LatLng(farmCenter.latitude - 0.0008, farmCenter.longitude + 0.0030),
        ],
        color: const Color(0xFF22C55E).withValues(alpha: 0.25),
        borderColor: const Color(0xFF16A34A),
        borderStrokeWidth: 2,
      ),
      Polygon(
        points: [
          LatLng(farmCenter.latitude + 0.0015, farmCenter.longitude - 0.0010),
          LatLng(farmCenter.latitude + 0.0035, farmCenter.longitude - 0.0005),
          LatLng(farmCenter.latitude + 0.0032, farmCenter.longitude - 0.0030),
          LatLng(farmCenter.latitude + 0.0012, farmCenter.longitude - 0.0025),
        ],
        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
        borderColor: const Color(0xFFD97706),
        borderStrokeWidth: 2,
      ),
    ];
  }

  List<CircleMarker> _buildWeatherRadarCircles(LatLng farmCenter, WeatherRiskReport? report) {
    final double rain = report?.currentPrecipitationMm ?? 0.0;
    final Color rainColor = rain > 10.0
        ? const Color(0xFF3B82F6)
        : (rain > 0.0 ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD));
    return [
      CircleMarker(
        point: farmCenter,
        radius: 3500,
        useRadiusInMeter: true,
        color: rainColor.withValues(alpha: 0.25),
        borderColor: rainColor.withValues(alpha: 0.70),
        borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: farmCenter,
        radius: 6000,
        useRadiusInMeter: true,
        color: rainColor.withValues(alpha: 0.12),
        borderColor: rainColor.withValues(alpha: 0.40),
        borderStrokeWidth: 1.5,
      ),
    ];
  }

  List<Marker> _buildWeatherRadarMarkers(LatLng farmCenter, WeatherRiskReport? report) {
    final double windSpeed = report?.currentWindSpeedKmh ?? 12.0;
    return [
      Marker(
        point: LatLng(farmCenter.latitude + 0.002, farmCenter.longitude + 0.002),
        width: 140,
        height: 38,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wind, color: Color(0xFF2563EB), size: 14),
              const SizedBox(width: 4),
              Text(
                'Wind: ${windSpeed.toStringAsFixed(0)} km/h',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Custom painter for synthetic radar concentric circles and rotating sweep line
class _RadarCanvasPainter extends CustomPainter {
  final double sweepAngle;

  _RadarCanvasPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Grid pattern
    final gridPaint = Paint()
      ..color = const Color(0xFF3C4A42).withValues(alpha: 0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Rings
    final ringPaint = Paint()
      ..color = const Color(0xFF3C4A42).withValues(alpha: 0.4)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 40, ringPaint);
    canvas.drawCircle(center, 75, ringPaint);

    // Crosshairs
    final crossPaint = Paint()
      ..color = const Color(0xFF3C4A42).withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossPaint);

    // Rotating Sweep line
    final sweepPaint = Paint()
      ..color = FloraXTheme.neonGreen.withValues(alpha: 0.4)
      ..strokeWidth = 1.2;

    final sweepEnd = Offset(
      center.dx + 85 * math.cos(sweepAngle),
      center.dy + 85 * math.sin(sweepAngle),
    );
    canvas.drawLine(center, sweepEnd, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarCanvasPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}

/// Outbreak pin representation on both the OpenStreetMap GIS layer and polar radar fallback
class _RadarOutbreakPinItem {
  final String id;
  final String label;
  final String cropName;
  final String diseaseName;
  final String geoHash5;
  final LatLng coordinates;
  final SeverityGrade severity;
  final int caseCount;
  final String? verifiedBy;
  final bool isVerified;
  final bool isPulsing;

  const _RadarOutbreakPinItem({
    required this.id,
    required this.label,
    required this.cropName,
    required this.diseaseName,
    required this.geoHash5,
    required this.coordinates,
    required this.severity,
    this.caseCount = 1,
    this.verifiedBy,
    this.isVerified = false,
    this.isPulsing = false,
  });
}

/// Safe in-memory tile provider that eliminates unmocked network HTTP requests during headless widget tests
class _TestSafeTileProvider extends TileProvider {
  _TestSafeTileProvider();

  static final Uint8List _transparentPng = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPng);
  }
}
