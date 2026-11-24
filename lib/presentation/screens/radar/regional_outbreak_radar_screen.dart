import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/outbreak_radar_repository.dart';
import '../../../services/location/location_service.dart';

/// Screen 7 — Regional Outbreak Radar Screen (`regional_outbreak_radar`)
/// Interactive OpenStreetMap radar supporting Heatmap & Pin views, risk badge,
/// radius & crop filter chips, active alert cards, and regional disease distribution stats.
class RegionalOutbreakRadarScreen extends ConsumerStatefulWidget {
  const RegionalOutbreakRadarScreen({super.key});

  @override
  ConsumerState<RegionalOutbreakRadarScreen> createState() => _RegionalOutbreakRadarScreenState();
}

class _RegionalOutbreakRadarScreenState extends ConsumerState<RegionalOutbreakRadarScreen> {
  final MapController _mapController = MapController();

  bool _isHeatmapView = true;
  double _selectedRadiusKm = 50.0;
  String _selectedCrop = 'All';
  String _selectedDisease = 'All';

  final List<double> _radiusOptions = [10.0, 25.0, 50.0, 100.0];
  final List<String> _cropOptions = ['All', 'Tomato', 'Cotton', 'Sugarcane', 'Paddy', 'Wheat'];
  final List<String> _diseaseOptions = ['All', 'Late Blight', 'Leaf Curl', 'Rust', 'Blight'];

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final locDictionary = ref.watch(farmerLocalizationProvider);
    final radarRepo = ref.watch(outbreakRadarRepositoryProvider);
    final locState = ref.watch(farmerLocationProvider);
    final loc = locState.location;
    final LatLng farmerLocation = (loc != null && (loc.latitude != 0.0 || loc.longitude != 0.0))
        ? LatLng(loc.latitude, loc.longitude)
        : const LatLng(18.5204, 73.8567);
    final stateQuery = (loc != null && loc.state.isNotEmpty) ? loc.state : 'Maharashtra';
    final alertsStream = radarRepo.watchRegionalOutbreaks(state: stateQuery);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.forestGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          activeLang == FarmerLanguage.marathi
              ? 'रोग उद्रेक रडार व सतर्कता'
              : (activeLang == FarmerLanguage.hindi
                  ? 'रोग प्रकोप रडार व चेतावनी'
                  : 'Outbreak Radar & Heatmap'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.forestGreen,
          ),
        ),
        actions: [
          // Heatmap vs Pin Toggle Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                _isHeatmapView ? LucideIcons.flame : LucideIcons.mapPin,
                size: 16,
                color: AppTheme.forestGreen,
              ),
              label: Text(
                _isHeatmapView ? 'Heatmap' : 'Pins',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestGreen,
                ),
              ),
              backgroundColor: AppTheme.pistachioPill,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              onPressed: () {
                setState(() => _isHeatmapView = !_isHeatmapView);
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<RegionalOutbreakAlert>>(
        stream: alertsStream,
        builder: (context, snapshot) {
          final allAlerts = snapshot.data ?? OutbreakRadarRepository.seededIcarAlerts;

          // Apply Radius & Filter Chips
          final filteredAlerts = allAlerts.where((alert) {
            final dist = LocationService.calculateDistanceKm(
              farmerLocation.latitude,
              farmerLocation.longitude,
              alert.latitude,
              alert.longitude,
            );
            if (dist > _selectedRadiusKm) return false;
            if (_selectedCrop != 'All' && !alert.crop.toLowerCase().contains(_selectedCrop.toLowerCase())) {
              return false;
            }
            if (_selectedDisease != 'All' && !alert.diseaseName.toLowerCase().contains(_selectedDisease.toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          final highCount = filteredAlerts.where((a) => a.severity == 'HIGH').length;
          final riskLevel = highCount >= 2 ? 'HIGH RISK ZONE' : (highCount == 1 ? 'MODERATE SURVEILLANCE' : 'LOW RISK AREA');
          final riskColor = highCount >= 2 ? AppTheme.alertRed : (highCount == 1 ? AppTheme.warningAmber : AppTheme.forestGreen);
          final riskBg = highCount >= 2 ? AppTheme.errorContainer : (highCount == 1 ? AppTheme.warningContainer : AppTheme.pistachioContainer);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // =============================================================
                // 1. TOP-LEVEL REGIONAL RISK BANNER
                // =============================================================
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: riskBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.shieldAlert, color: riskColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              riskLevel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: riskColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              activeLang == FarmerLanguage.marathi
                                  ? '${filteredAlerts.length} सक्रिय रोग प्रादुर्भाव ${_selectedRadiusKm.toInt()} किमी परिसरात.'
                                  : (activeLang == FarmerLanguage.hindi
                                      ? '${filteredAlerts.length} सक्रिय प्रकोप ${_selectedRadiusKm.toInt()} किमी दायरे में।'
                                      : '${filteredAlerts.length} Active outbreaks within ${_selectedRadiusKm.toInt()} km radius.'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // 2. INTERACTIVE OPENSTREETMAP (Heatmap & Pin Views)
                // =============================================================
                Container(
                  height: 280,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                    boxShadow: AppTheme.softCardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: farmerLocation,
                      initialZoom: 9.0,
                    ),
                    children: [
                      // OpenStreetMap Offline-Friendly Tile Layer
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.florax.kisansetu',
                      ),

                      // Heatmap Radial Threat Zones (CircleLayer)
                      if (_isHeatmapView)
                        CircleLayer(
                          circles: [
                            // Farmer Home Radius Circle
                            CircleMarker(
                              point: farmerLocation,
                              radius: _selectedRadiusKm * 100, // scaled radius representation
                              useRadiusInMeter: false,
                              color: AppTheme.forestGreen.withValues(alpha: 0.12),
                              borderColor: AppTheme.forestGreen,
                              borderStrokeWidth: 2,
                            ),
                            // Threat Hotspots
                            ...filteredAlerts.map((alert) {
                              final isHigh = alert.severity == 'HIGH';
                              return CircleMarker(
                                point: LatLng(alert.latitude, alert.longitude),
                                radius: isHigh ? 38 : 26,
                                color: (isHigh ? Colors.red : Colors.amber).withValues(alpha: 0.35),
                                borderColor: (isHigh ? Colors.red : Colors.amber),
                                borderStrokeWidth: 1.5,
                              );
                            }),
                          ],
                        ),

                      // Pin View Markers (MarkerLayer)
                      MarkerLayer(
                        markers: [
                          // Farmer Current Location Pin
                          Marker(
                            point: farmerLocation,
                            width: 44,
                            height: 44,
                            child: const Column(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.forestGreen,
                                  child: Icon(LucideIcons.home, color: Colors.white, size: 14),
                                ),
                                Icon(LucideIcons.mapPin, color: AppTheme.forestGreen, size: 16),
                              ],
                            ),
                          ),

                          // Outbreak Threat Pins
                          ...filteredAlerts.map((alert) {
                            final isHigh = alert.severity == 'HIGH';
                            return Marker(
                              point: LatLng(alert.latitude, alert.longitude),
                              width: 60,
                              height: 52,
                              child: GestureDetector(
                                onTap: () => _showAlertDetailModal(context, alert),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isHigh ? AppTheme.alertRed : AppTheme.warningAmber,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      ),
                                      child: Text(
                                        '${alert.activeCases}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      LucideIcons.alertTriangle,
                                      size: 20,
                                      color: isHigh ? AppTheme.alertRed : AppTheme.warningAmber,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // 3. HORIZONTALLY SCROLLABLE FILTER CHIPS
                // =============================================================
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Radius Selector Pills
                        ..._radiusOptions.map((r) => _buildFilterPill(
                              label: '${r.toInt()} km',
                              isSelected: _selectedRadiusKm == r,
                              onTap: () => setState(() => _selectedRadiusKm = r),
                            )),
                        const SizedBox(width: 8),

                        // Crop Filter Pills
                        ..._cropOptions.map((c) => _buildFilterPill(
                              label: c,
                              isSelected: _selectedCrop == c,
                              onTap: () => setState(() => _selectedCrop = c),
                            )),
                        const SizedBox(width: 8),

                        // Disease Filter Pills
                        ..._diseaseOptions.map((d) => _buildFilterPill(
                              label: d,
                              isSelected: _selectedDisease == d,
                              onTap: () => setState(() => _selectedDisease = d),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // =============================================================
                // 4. REGIONAL EPIDEMIOLOGY STATS CARD
                // =============================================================
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.softCardShadow,
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.activity, size: 17, color: AppTheme.forestGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locDictionary.tr('maharashtra_regional_pathogen_dist'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDistributionBar('Fungal Blight & Rust', 0.56, AppTheme.forestGreen, '56% (Active)'),
                      const SizedBox(height: 8),
                      _buildDistributionBar('Bacterial Leaf Spot', 0.28, AppTheme.harvestGold, '28% (Rising)'),
                      const SizedBox(height: 8),
                      _buildDistributionBar('Viral Begomovirus', 0.16, AppTheme.alertRed, '16% (Severe)'),
                    ],
                  ),
                ),

                // =============================================================
                // 5. VERTICAL LIST OF ACTIVE ALERT CARDS
                // =============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${locDictionary.tr('active_alerts_title')} (${filteredAlerts.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        locDictionary.tr('auto_refreshed_icar'),
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),

                ...filteredAlerts.map((alert) {
                  final dist = LocationService.calculateDistanceKm(
                    farmerLocation.latitude,
                    farmerLocation.longitude,
                    alert.latitude,
                    alert.longitude,
                  );
                  final isHigh = alert.severity == 'HIGH';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.softCardShadow,
                      border: Border.all(
                        color: isHigh
                            ? AppTheme.alertRed.withValues(alpha: 0.4)
                            : AppTheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isHigh ? AppTheme.errorContainer : AppTheme.warningContainer,
                                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              ),
                              child: Text(
                                '${alert.severity} ${locDictionary.tr('risk_suffix')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isHigh ? AppTheme.alertRed : AppTheme.warningAmber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppTheme.pistachioContainer,
                                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              ),
                              child: Text(
                                locDictionary.tr('verified_by_icar'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.forestGreen,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${dist.toStringAsFixed(1)} ${locDictionary.tr('km_away')}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${alert.crop} • ${alert.diseaseName}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          alert.precautionaryAdvice[activeLang.code] ??
                              alert.precautionaryAdvice['en'] ??
                              'Monitor lower canopy leaves closely.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(LucideIcons.shieldCheck, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              alert.verifiedSource,
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const Spacer(),
                            Text(
                              '${alert.activeCases} ${locDictionary.tr('active_cases_suffix')}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.forestGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPill({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.forestGreen : AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: isSelected ? AppTheme.forestGreen : AppTheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionBar(String title, double fraction, Color color, String percentLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
            Text(percentLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: AppTheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showAlertDetailModal(BuildContext context, RegionalOutbreakAlert alert) {
    final loc = ref.read(farmerLocalizationProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: AppTheme.alertRed, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${loc.tr('pathogen_label')} ${alert.diseaseName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${loc.tr('location_label')}: ${alert.district}, ${alert.state}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              Text('${loc.tr('active_cases_label')} ${alert.activeCases}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.forestGreen)),
              const SizedBox(height: 14),
              Text(loc.tr('icar_advisory_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                alert.precautionaryAdvice[loc.lang.code] ?? alert.precautionaryAdvice['en'] ?? 'Immediate foliar spray recommended.',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forestGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.tr('acknowledge_advisory'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}
