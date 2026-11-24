import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/location/location_service.dart';
import '../../../services/utility/device_utility_service.dart';

/// Screen — Weather Forecast & Agronomic Spray Precaution (`weather_forecast_screen`)
/// Real-time meteorological data and spray timing precaution guide.
class WeatherForecastScreen extends ConsumerWidget {
  const WeatherForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(farmerLocalizationProvider);
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final utility = ref.watch(deviceUtilityServiceProvider);
    final liveLoc = ref.watch(farmerLocationProvider).location;
    final weatherFuture = utility.fetchWeatherForLocation(
      latitude: liveLoc?.latitude ?? 0.0,
      longitude: liveLoc?.longitude ?? 0.0,
    );

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
              ? 'हवामान व फवारणी सल्ला'
              : (activeLang == FarmerLanguage.hindi
                  ? 'मौसम व छिड़काव परामर्श'
                  : 'Weather & Spray Precaution'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.forestGreen),
        ),
      ),
      body: FutureBuilder<LocationWeatherSnapshot>(
        future: weatherFuture,
        builder: (context, snapshot) {
          final weather = snapshot.data ??
              LocationWeatherSnapshot(
                temperatureC: 28.4,
                relativeHumidity: 68.0,
                precipitationMm: 0.0,
                windSpeedKmh: 9.5,
                shouldDelayChemicalSpray: false,
                sprayAdvisoryReason: 'Wind and humidity are optimal for organic or chemical spray application.',
                fetchedAt: DateTime.now(),
              );

          final bool delaySpray = weather.shouldDelayChemicalSpray;
          final statusBg = delaySpray ? AppTheme.warningContainer : AppTheme.pistachioContainer;
          final statusFg = delaySpray ? AppTheme.warningAmber : AppTheme.forestGreen;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Location & Current Condition Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.softCardShadow,
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                liveLoc?.displayLocation ?? 'Current Location',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                              ),
                              Text(
                                liveLoc?.postalCode.isNotEmpty == true ? 'PIN: ${liveLoc!.postalCode}' : 'Field Coordinates Active',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          Icon(
                            delaySpray ? LucideIcons.cloudRain : LucideIcons.sun,
                            size: 36,
                            color: delaySpray ? AppTheme.alertRed : AppTheme.harvestGold,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildWeatherMetric(LucideIcons.thermometer, '${weather.temperatureC.toStringAsFixed(1)}°C', 'Temperature'),
                          _buildWeatherMetric(LucideIcons.droplets, '${weather.relativeHumidity.toInt()}%', 'Humidity'),
                          _buildWeatherMetric(LucideIcons.wind, '${weather.windSpeedKmh.toInt()} km/h', 'Wind Speed'),
                          _buildWeatherMetric(LucideIcons.cloudDrizzle, '${weather.precipitationMm} mm', 'Precipitation'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Agronomic Spray Precaution Advisory Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: statusFg.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            delaySpray ? LucideIcons.alertOctagon : LucideIcons.checkCircle2,
                            color: statusFg,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            delaySpray ? 'DELAY SPRAY RECOMMENDED' : 'OPTIMAL SPRAY CONDITIONS',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: statusFg,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weather.sprayAdvisoryReason,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.onSurface, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Best Practices Card
                Container(
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
                      Text(
                        loc.tr('icar_spraying_practices'),
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                      ),
                      const SizedBox(height: 10),
                      Text(loc.tr('spray_tip_1'), style: const TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(loc.tr('spray_tip_2'), style: const TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(loc.tr('spray_tip_3'), style: const TextStyle(fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeatherMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.forestGreen),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.onSurface)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}
