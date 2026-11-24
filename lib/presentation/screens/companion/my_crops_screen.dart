import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/crop_tracker_repository.dart';
import '../../../data/repositories/farmer_profile_repository.dart';

/// Screen — My Crops & Field Recovery Tracker (`my_crops_screen`)
/// Visual timeline and recovery progress for crops under treatment.
/// Backed 100% by dynamic scans from CropTrackerRepository (zero dummy data).
class MyCropsScreen extends ConsumerWidget {
  const MyCropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(farmerLocalizationProvider);
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final farmerAsync = ref.watch(farmerProfileRepositoryProvider).getLocalProfile();

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
          loc.myCropsTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.forestGreen),
        ),
      ),
      body: FutureBuilder(
        future: farmerAsync,
        builder: (context, farmerSnap) {
          final mobile = farmerSnap.data?.mobileE164;
          final cropRepo = ref.watch(cropTrackerRepositoryProvider);

          return StreamBuilder<List<CropPlotEntry>>(
            stream: cropRepo.watchCropPlots(farmerMobile: mobile),
            builder: (context, snapshot) {
              final plots = snapshot.data ?? [];
              final plotCount = plots.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.pistachioContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.forestGreen,
                            child: Icon(LucideIcons.sprout, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeLang == FarmerLanguage.marathi
                                      ? '$plotCount सक्रिय पिकांचे निरीक्षण (Active Crops Tracked)'
                                      : (activeLang == FarmerLanguage.hindi
                                          ? '$plotCount सक्रिय फसलों की निगरानी (Active Crops Tracked)'
                                          : '$plotCount Active Crops Tracked'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.deepForest),
                                ),
                                Text(
                                  plotCount == 0
                                      ? (activeLang == FarmerLanguage.marathi
                                          ? 'पुनर्प्राप्ती ट्रॅकिंग सुरू करण्यासाठी पिकाच्या पानाचे स्कॅन करा'
                                          : (activeLang == FarmerLanguage.hindi
                                              ? 'रिकवरी ट्रैकिंग शुरू करने के लिए फसल की पत्ती स्कैन करें'
                                              : 'Scan a crop leaf to automatically start recovery tracking'))
                                      : (activeLang == FarmerLanguage.marathi
                                          ? '१४ दिवसांच्या कालावधीत पानावरील सुधारणेचे निरीक्षण'
                                          : (activeLang == FarmerLanguage.hindi
                                              ? '१४ दिनों के अंतराल में पत्ती सुधार की निगरानी'
                                              : 'Foliar recovery monitored dynamically over 14-day intervals')),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.onSecondaryContainer),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Empty State or Real Dynamic Crops
                    if (plotCount == 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                          boxShadow: AppTheme.softCardShadow,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: AppTheme.pistachioPill,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.sprout, size: 32, color: AppTheme.forestGreen),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              activeLang == FarmerLanguage.marathi
                                  ? 'सध्या कोणतेही पीक प्लॉट नोंदवलेले नाही'
                                  : (activeLang == FarmerLanguage.hindi
                                      ? 'अभी तक कोई फसल प्लॉट दर्ज नहीं है'
                                      : 'No Crop Plots Tracked Yet'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activeLang == FarmerLanguage.marathi
                                  ? 'जेव्हा तुम्ही पिकाच्या पानाचे स्कॅन करता (भात, टोमॅटो, कापूस, ऊस इ.), तेव्हा किसानसेतू आपोआप त्याची पुनर्प्राप्ती टाइमलाइन येथे तयार करेल.'
                                  : (activeLang == FarmerLanguage.hindi
                                      ? 'जब आप फसल की पत्ती को स्कैन करते हैं (धान, टमाटर, कपास, गन्ना आदि), तो किसानसेतु स्वचालित रूप से यहां उसकी रिकवरी टाइमलाइन तैयार करेगा।'
                                      : 'Whenever you scan a crop leaf (paddy, tomato, cotton, sugarcane, etc.), KisanSetu will automatically create and track its recovery timeline here.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.scanner),
                              icon: const Icon(LucideIcons.camera, size: 18),
                              label: Text(loc.tr('open_smart_camera')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.forestGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...plots.map((plot) => _buildDynamicCropCard(context, plot)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.camera, size: 18),
        label: Text(loc.tr('scan_another_crop'), style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.scanner),
      ),
    );
  }

  Widget _buildDynamicCropCard(BuildContext context, CropPlotEntry plot) {
    final loc = ProviderScope.containerOf(context, listen: false).read(farmerLocalizationProvider);
    final isImproving = plot.isImproving;
    final recoveryPercent = plot.recoveryPercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plot.cropName,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isImproving ? AppTheme.pistachioContainer : AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  isImproving ? loc.tr('improving_status') : loc.tr('needs_check'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isImproving ? AppTheme.forestGreen : AppTheme.warningAmber,
                  ),
                ),
              ),
            ],
          ),
          Text(plot.variety, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Text('${loc.tr('condition_label')}: ${plot.condition}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
          const SizedBox(height: 10),

          // Recovery Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.tr('recovery_progress'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
              Text('${(recoveryPercent * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.forestGreen)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              value: recoveryPercent,
              minHeight: 7,
              backgroundColor: AppTheme.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.forestGreen),
            ),
          ),
          const SizedBox(height: 10),
          Text('${loc.tr('day_label')} ${plot.daysElapsed} • ${plot.lastAction}', style: const TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.forestGreen,
              side: const BorderSide(color: AppTheme.forestGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              minimumSize: const Size.fromHeight(38),
            ),
            icon: const Icon(LucideIcons.camera, size: 15),
            label: Text(loc.tr('recheck_crop'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.scanner,
              arguments: {'targetCropId': plot.cropId},
            ),
          ),
        ],
      ),
    );
  }
}
