import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../services/location/location_service.dart';

/// Screen 4 — Side Navigation Drawer (`side_navigation_menu`)
/// Slide-out left drawer with KisanSetu header, full navigation links, and field-sync status footer.
class SideNavigationDrawer extends ConsumerWidget {
  final String activeRoute;

  const SideNavigationDrawer({
    super.key,
    this.activeRoute = AppRoutes.home,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmerAsync = ref.watch(farmerProfileRepositoryProvider).getLocalProfile();
    final loc = ref.watch(farmerLocalizationProvider);

    return Drawer(
      backgroundColor: AppTheme.background,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppTheme.radiusXl),
          bottomRight: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // =================================================================
            // 1. KISANSETU BRANDING & FARMER IDENTITY HEADER
            // =================================================================
            FutureBuilder(
              future: farmerAsync,
              builder: (context, snapshot) {
                final farmer = snapshot.data;
                final liveLoc = ref.watch(farmerLocationProvider).location;
                final name = farmer?.fullName ?? 'Kisan Mitra';
                final mobile = farmer?.mobileE164 ?? '+91 98765 43210';
                final location = (farmer != null && farmer.district.isNotEmpty)
                    ? '${farmer.district}, ${farmer.state}'
                    : (liveLoc?.displayLocation ?? loc.tr('location_disabled'));

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(
                                color: AppTheme.outlineVariant.withOpacity(0.5),
                              ),
                              image: const DecorationImage(
                                image: AssetImage('assets/branding/kisansetu.jpg'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KisanSetu',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.forestGreen,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  loc.tr('welcome_subtitle'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.pistachioPill,
                              child: Icon(
                                LucideIcons.user,
                                size: 18,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$mobile • $location',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // =================================================================
            // 2. SCROLLABLE NAVIGATION LINKS
            // =================================================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_home'),
                    icon: LucideIcons.home,
                    route: AppRoutes.home,
                    isActive: activeRoute == AppRoutes.home,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.myCropsTitle,
                    icon: LucideIcons.sprout,
                    route: AppRoutes.progression,
                    isActive: activeRoute == AppRoutes.progression,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('past_scans'),
                    icon: LucideIcons.history,
                    route: AppRoutes.scanHistory,
                    isActive: activeRoute == AppRoutes.scanHistory,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_radar'),
                    icon: LucideIcons.radar,
                    route: AppRoutes.radar,
                    isActive: activeRoute == AppRoutes.radar,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_weather'),
                    icon: LucideIcons.cloudSun,
                    route: AppRoutes.weather,
                    isActive: activeRoute == AppRoutes.weather,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_experts'),
                    icon: LucideIcons.userCheck,
                    route: AppRoutes.experts,
                    isActive: activeRoute == AppRoutes.experts,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_schemes'),
                    icon: LucideIcons.heartHandshake,
                    route: AppRoutes.assistanceHub,
                    isActive: activeRoute == AppRoutes.assistanceHub,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('quick_guides'),
                    icon: LucideIcons.bookOpen,
                    route: AppRoutes.offlineGuides,
                    isActive: activeRoute == AppRoutes.offlineGuides,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_help'),
                    icon: LucideIcons.phoneCall,
                    route: AppRoutes.helpSupport,
                    isActive: activeRoute == AppRoutes.helpSupport,
                  ),
                  _buildDrawerItem(
                    context,
                    title: loc.tr('menu_profile'),
                    icon: LucideIcons.user,
                    route: AppRoutes.profile,
                    isActive: activeRoute == AppRoutes.profile,
                  ),
                ],
              ),
            ),

            // =================================================================
            // 3. BOTTOM FIELD-SYNC READY STATUS FOOTER
            // =================================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.pistachioContainer,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.checkCheck,
                    size: 16,
                    color: AppTheme.forestGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.tr('offline_status_active'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDarkForest,
                      ),
                    ),
                  ),
                  const Text(
                    'v2.1',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.forestGreen,
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

  Widget _buildDrawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.pistachioPill : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: isActive ? AppTheme.textDarkForest : AppTheme.forestGreen,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppTheme.textDarkForest : AppTheme.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          if (!isActive) {
            Navigator.of(context).pushNamed(route);
          }
        },
      ),
    );
  }
}
