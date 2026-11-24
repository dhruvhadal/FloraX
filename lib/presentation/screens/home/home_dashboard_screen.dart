import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/location/location_service.dart';
import 'side_navigation_drawer.dart';

/// Screen 3 — Home Dashboard Screen (`home_dashboard`)
/// Comprehensive field dashboard with voice assistant, central scanner hero card,
/// 2x2 quick agronomic links, and zero overflow at 360dp width.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(farmerLocationProvider.notifier).refreshLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: const SideNavigationDrawer(activeRoute: AppRoutes.home),
      body: SafeArea(
        child: Column(
          children: [
            // =================================================================
            // 1. TOP APP BAR (Zero Overflow at 360dp)
            // =================================================================
            _buildTopAppBar(activeLang),

            // =================================================================
            // 2. SCROLLABLE DASHBOARD CONTENT
            // =================================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Context Telemetry Banners
                    _buildContextBanners(),
                    const SizedBox(height: 12),

                    // Large Central "SCAN YOUR CROP" Hero Card directly below GPS location + Offline-Ready row
                    _buildScannerHeroCard(),
                    const SizedBox(height: 14),

                    // 2x2 Quick Links
                    _buildQuickLinksGrid(activeLang),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // =================================================================
            // 3. FIXED BOTTOM NAVIGATION BAR
            // =================================================================
            _buildBottomNav(activeLang),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildTopAppBar(FarmerLanguage activeLang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          // Hamburger Icon
          IconButton(
            icon: const Icon(LucideIcons.menu, color: AppTheme.forestGreen, size: 22),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),

          // KisanSetu Emblem & Wordmark (Wrapped in Expanded to eliminate overflow)
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
                    image: const DecorationImage(
                      image: AssetImage('assets/branding/kisansetu.jpg'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'KisanSetu',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.forestGreen,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        activeLang == FarmerLanguage.marathi
                            ? 'एआय कृषी सल्लागार'
                            : (activeLang == FarmerLanguage.hindi ? 'एआई कृषि सलाहकार' : 'AI Agronomy'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Compact Language Switcher (EN | हिं | मरा)
          _buildCompactLanguageToggle(activeLang),
          const SizedBox(width: 6),

          // Notification Icon
          IconButton(
            icon: const Stack(
              children: [
                Icon(LucideIcons.bell, size: 20, color: AppTheme.onSurfaceVariant),
                Positioned(
                  top: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppTheme.alertRed,
                  ),
                ),
              ],
            ),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.radar),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          // Farmer Profile Avatar Icon
          InkWell(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.pistachioPill,
                child: Icon(LucideIcons.user, size: 16, color: AppTheme.forestGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLanguageToggle(FarmerLanguage activeLang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLangMiniItem(FarmerLanguage.english, 'EN', activeLang),
          const Text('·', style: TextStyle(color: AppTheme.outline, fontSize: 10)),
          _buildLangMiniItem(FarmerLanguage.hindi, 'हिं', activeLang),
          const Text('·', style: TextStyle(color: AppTheme.outline, fontSize: 10)),
          _buildLangMiniItem(FarmerLanguage.marathi, 'मरा', activeLang),
        ],
      ),
    );
  }

  Widget _buildLangMiniItem(FarmerLanguage lang, String label, FarmerLanguage active) {
    final isSelected = lang == active;
    return InkWell(
      onTap: () {
        ref.read(activeFarmerLanguageProvider.notifier).setLanguage(lang);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAction : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildContextBanners() {
    final locState = ref.watch(farmerLocationProvider);
    String locationLabel;
    VoidCallback? onLocationTap;

    if (locState.isLoading) {
      locationLabel = 'Detecting GPS...';
    } else if (locState.isServiceDisabled) {
      locationLabel = 'Enable GPS';
      onLocationTap = () => ref.read(farmerLocationProvider.notifier).openLocationSettings();
    } else if (locState.isPermissionDenied) {
      locationLabel = 'Allow GPS';
      onLocationTap = () => ref.read(farmerLocationProvider.notifier).refreshLocation();
    } else if (locState.isDeniedForever) {
      locationLabel = 'Open App Settings';
      onLocationTap = () => ref.read(farmerLocationProvider.notifier).openAppSettings();
    } else if (locState.location != null) {
      locationLabel = locState.location!.displayLocation;
      onLocationTap = () => ref.read(farmerLocationProvider.notifier).refreshLocation();
    } else {
      locationLabel = 'Tap to Detect Location';
      onLocationTap = () => ref.read(farmerLocationProvider.notifier).refreshLocation();
    }

    return Row(
      children: [
        // Location Pin Badge with Tappable Refresh
        Expanded(
          child: InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 14, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  locState.isLoading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryGreen),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 12, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Offline-Ready Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.pistachioPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wifiOff, size: 13, color: AppTheme.forestGreen),
              const SizedBox(width: 5),
              Text(
                ref.watch(farmerLocalizationProvider).tr('offline_ready_pill'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerHeroCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Column(
          children: [
            // Viewfinder Preview Box
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 145,
                  width: double.infinity,
                  color: AppTheme.deepForest,
                  child: Image.asset(
                    'assets/branding/kisansetu.jpg',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.25),
                  ),
                ),
                // Viewfinder Reticle Overlay
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.scanLine,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      ref.watch(farmerLocalizationProvider).tr('edgert_45_active'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Action Area
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Text(
                    ref.watch(farmerLocalizationProvider).tr('scan_your_crop'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.forestGreen,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ref.watch(farmerLocalizationProvider).tr('scan_crop_subtitle'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.scanner);
                          },
                          icon: const Icon(LucideIcons.camera, size: 18),
                          label: Text(ref.watch(farmerLocalizationProvider).tr('open_smart_camera')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAction,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.scanner);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(46, 46),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(LucideIcons.image, size: 20, color: AppTheme.forestGreen),
                      ),
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

  Widget _buildQuickLinksGrid(FarmerLanguage activeLang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeLang == FarmerLanguage.marathi
              ? 'त्वरित कृषी सेवा (Quick Access)'
              : (activeLang == FarmerLanguage.hindi
                  ? 'त्वरित कृषि सेवाएं (Quick Access)'
                  : 'Quick Agronomic Access'),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            _buildQuickLinkCard(
              title: activeLang == FarmerLanguage.marathi
                  ? 'पीक रोग व कीड'
                  : (activeLang == FarmerLanguage.hindi ? 'फसल रोग व कीट' : 'Crop Disease'),
              subtitle: activeLang == FarmerLanguage.marathi
                  ? '४५-प्रकार आयसीएआर नियमावली'
                  : (activeLang == FarmerLanguage.hindi ? '४५-प्रकार आईसीएआर नियमावली' : '45-Class ICAR Protocols'),
              icon: LucideIcons.bug,
              accentColor: AppTheme.alertRed,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.offlineGuides),
            ),
            _buildQuickLinkCard(
              title: activeLang == FarmerLanguage.marathi
                  ? 'कृषी तज्ञ'
                  : (activeLang == FarmerLanguage.hindi ? 'कृषि विशेषज्ञ' : 'Agri Experts'),
              subtitle: activeLang == FarmerLanguage.marathi
                  ? 'केव्हीके शास्त्रज्ञ निर्देशिका'
                  : (activeLang == FarmerLanguage.hindi ? 'केवीके वैज्ञानिक निर्देशिका' : 'KVK Agronomist Directory'),
              icon: LucideIcons.userCheck,
              accentColor: AppTheme.abioticTeal,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.experts),
            ),
            _buildQuickLinkCard(
              title: activeLang == FarmerLanguage.marathi
                  ? 'स्कॅन इतिहास'
                  : (activeLang == FarmerLanguage.hindi ? 'स्कैन इतिहास' : 'Scan History & Telemetry'),
              subtitle: activeLang == FarmerLanguage.marathi
                  ? 'नोंदी व पाने निदान अहवाल'
                  : (activeLang == FarmerLanguage.hindi ? 'रिकॉर्ड व पत्ती निदान रिपोर्ट' : 'Logs & Foliar Diagnostics'),
              icon: LucideIcons.history,
              accentColor: AppTheme.primaryGreen,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.scanHistory),
            ),
            _buildQuickLinkCard(
              title: activeLang == FarmerLanguage.marathi
                  ? 'हवामान व फवारणी'
                  : (activeLang == FarmerLanguage.hindi ? 'मौसम व छिड़काव' : 'Weather & Spray'),
              subtitle: activeLang == FarmerLanguage.marathi
                  ? 'फवारणी अनुकूलता सावधानता'
                  : (activeLang == FarmerLanguage.hindi ? 'छिड़काव अनुकूलता सावधानी' : 'Spraying Precautions'),
              icon: LucideIcons.cloudSun,
              accentColor: AppTheme.warningAmber,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.weather),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickLinkCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
          boxShadow: AppTheme.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(FarmerLanguage activeLang) {
    final loc = ref.watch(farmerLocalizationProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(
            color: AppTheme.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, LucideIcons.home, loc.tr('menu_home'), () {}),
          _buildNavItem(1, LucideIcons.sprout, loc.tr('my_crops'), () {
            Navigator.of(context).pushNamed(AppRoutes.progression);
          }),
          // Floating Center Scan AI Action Button
          InkWell(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.scanner),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryAction,
                shape: BoxShape.circle,
                boxShadow: AppTheme.floatingActionShadow,
              ),
              child: const Icon(LucideIcons.camera, color: Colors.white, size: 24),
            ),
          ),
          _buildNavItem(3, LucideIcons.heartHandshake, loc.tr('menu_schemes'), () {
            Navigator.of(context).pushNamed(AppRoutes.assistanceHub);
          }),
          _buildNavItem(4, LucideIcons.user, loc.tr('menu_profile'), () {
            Navigator.of(context).pushNamed(AppRoutes.profile);
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, VoidCallback onTap) {
    final isSelected = _currentNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _currentNavIndex = index);
        onTap();
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.outline,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
