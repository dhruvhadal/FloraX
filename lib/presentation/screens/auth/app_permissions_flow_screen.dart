import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../domain/models/florax_models.dart';
import '../../../services/location/location_service.dart';
import '../../../services/utility/device_utility_service.dart';

/// Screen 2 — App Permissions Flow Screen (`app_permissions_flow`)
/// Sequential interactive setup: Language selection, Location access, Camera/Storage, and Source preferences.
class AppPermissionsFlowScreen extends ConsumerStatefulWidget {
  final FarmerProfile? initialProfile;

  const AppPermissionsFlowScreen({super.key, this.initialProfile});

  @override
  ConsumerState<AppPermissionsFlowScreen> createState() =>
      _AppPermissionsFlowScreenState();
}

class _AppPermissionsFlowScreenState
    extends ConsumerState<AppPermissionsFlowScreen> {
  FarmerProfile? _profile;
  bool _isPlayingAudio = false;

  // Permissions state
  bool _locationGranted = false;
  bool _cameraGranted = false;
  String _preferredSource = 'camera'; // 'camera' or 'gallery'

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final utility = ref.read(deviceUtilityServiceProvider);
    final loc = await utility.isLocationGranted();
    final cam = await utility.isCameraGranted();

    if (_profile == null) {
      final repo = ref.read(farmerProfileRepositoryProvider);
      final cached = await repo.getLocalProfile();
      if (mounted) setState(() => _profile = cached);
    }

    if (mounted) {
      setState(() {
        _locationGranted = loc;
        _cameraGranted = cam;
      });
    }
  }

  Future<void> _toggleAudioGuide() async {
    final utility = ref.read(deviceUtilityServiceProvider);
    final lang = ref.read(activeFarmerLanguageProvider).code;

    if (_isPlayingAudio) {
      await utility.stopSpeaking();
      setState(() => _isPlayingAudio = false);
    } else {
      setState(() => _isPlayingAudio = true);
      final text = lang == 'mr'
          ? 'किसानसेतू वापरण्यासाठी तीन साध्या परवानग्या आवश्यक आहेत. पहिली: तुमची भाषा निवडा. दुसरी: स्थानिक हवामान आणि रोगांच्या सूचना मिळवण्यासाठी लोकेशन द्या. तिसरी: पिकाचे फोटो काढून रोगांचे निदान करण्यासाठी कॅमेऱ्याची परवानगी द्या.'
          : (lang == 'hi'
              ? 'किसानसेतु का उपयोग करने के लिए तीन बुनियादी अनुमतियों की आवश्यकता है। पहला: अपनी भाषा चुनें। दूसरा: स्थानीय मौसम और बीमारी के अलर्ट के लिए लोकेशन अनुमति दें। तीसरा: फसल की पत्तियों की जांच हेतु कैमरे की अनुमति दें।'
              : 'KisanSetu requires three simple permissions. First, select your preferred language. Second, enable location for regional outbreak alerts. Third, grant camera access to scan crop leaves.');

      await utility.speakVernacular(text, langCode: lang);
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    final loc = await ref.read(farmerLocationProvider.notifier).refreshLocation(
      farmerMobile: _profile?.mobileE164,
      forceGps: true,
    );
    if (mounted) {
      setState(() {
        _locationGranted = loc != null;
      });
      if (loc != null) {
        if (_profile != null) {
          final updated = _profile!.copyWith(
            village: loc.village.isNotEmpty ? loc.village : _profile!.village,
            district: loc.district.isNotEmpty ? loc.district : _profile!.district,
            state: loc.state.isNotEmpty ? loc.state : _profile!.state,
            pincode: loc.postalCode.isNotEmpty ? loc.postalCode : _profile!.pincode,
          );
          _profile = updated;
          await ref.read(farmerProfileRepositoryProvider).saveProfile(updated);
        }
        final langLoc = ref.read(farmerLocalizationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${langLoc.tr('location_calibrated')}: ${loc.displayLocation} (GPS)'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    final utility = ref.read(deviceUtilityServiceProvider);
    await utility.requestFieldScanningPermissions();
    final cam = await utility.isCameraGranted();
    if (mounted) {
      setState(() {
        _cameraGranted = cam;
      });
    }
  }

  Future<void> _continueToHome() async {
    final utility = ref.read(deviceUtilityServiceProvider);
    await utility.stopSpeaking();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locDictionary = ref.watch(farmerLocalizationProvider);
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final liveLoc = ref.watch(farmerLocationProvider).location;
    final farmerName = _profile?.fullName ?? 'Kisan Mitra';
    final mobile = _profile?.mobileE164 ?? '+91 98765 43210';
    final locationBadge = (liveLoc != null && liveLoc.displayLocation.isNotEmpty)
        ? liveLoc.displayLocation
        : ((_profile != null && _profile!.district.isNotEmpty)
            ? '${_profile!.district}, ${_profile!.state}'
            : 'Location Pending');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(locDictionary.tr('permissions_title')),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===========================================================
                  // 1. TOP TTS AUDIO GUIDE PLAYER WIDGET
                  // ===========================================================
                  _buildAudioGuideWidget(activeLang),
                  const SizedBox(height: 16),

                  // ===========================================================
                  // 2. READ-ONLY FARMER PROFILE SUMMARY CARD
                  // ===========================================================
                  _buildFarmerDetailsCard(farmerName, mobile, locationBadge),
                  const SizedBox(height: 18),

                  Text(
                    locDictionary.tr('permissions_title'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDarkForest,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ===========================================================
                  // 3. STEP 1: LANGUAGE SELECTION (Skipped if already chosen on first launch)
                  // ===========================================================
                  if (!ref.watch(hasSelectedLanguageProvider)) ...[
                    _buildLanguageSelectionCard(activeLang),
                    const SizedBox(height: 12),
                  ],

                  // ===========================================================
                  // 4. STEP 2: LOCATION ACCESS PERMISSION
                  // ===========================================================
                  _buildLocationPermissionCard(),
                  const SizedBox(height: 12),

                  // ===========================================================
                  // 5. STEP 3: CAMERA & STORAGE ACCESS PERMISSION
                  // ===========================================================
                  _buildCameraPermissionCard(),
                  const SizedBox(height: 12),

                  // ===========================================================
                  // 6. STEP 4: PREFERRED IMAGE SOURCE
                  // ===========================================================
                  _buildImageSourcePreferenceCard(),
                  const SizedBox(height: 24),

                  // ===========================================================
                  // 7. CONTINUE BUTTON
                  // ===========================================================
                  ElevatedButton(
                    onPressed: _continueToHome,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(locDictionary.tr('continue_to_app')),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioGuideWidget(FarmerLanguage activeLang) {
    final loc = ref.watch(farmerLocalizationProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryAction,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _toggleAudioGuide,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.pistachioPill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlayingAudio ? LucideIcons.square : LucideIcons.play,
                color: AppTheme.textDarkForest,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.tr('listen_permission_guide'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${loc.tr('vernacular_voice_guide')} (${activeLang.displayName})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFCBE2BC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerDetailsCard(String name, String mobile, String location) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, color: AppTheme.primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.badgeCheck, size: 16, color: AppTheme.primaryGreen),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  mobile,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.pistachioPill),
              ),
              child: Text(
                location,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkForest,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectionCard(FarmerLanguage activeLang) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.languages, size: 18, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text(
                '1. Select Preferred Language (भाषा)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLangChip(FarmerLanguage.marathi, 'मराठी', activeLang),
              const SizedBox(width: 8),
              _buildLangChip(FarmerLanguage.hindi, 'हिन्दी', activeLang),
              const SizedBox(width: 8),
              _buildLangChip(FarmerLanguage.english, 'English', activeLang),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(FarmerLanguage lang, String label, FarmerLanguage active) {
    final isSelected = lang == active;
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(activeFarmerLanguageProvider.notifier).setLanguage(lang);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryAction : AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected ? AppTheme.primaryAction : AppTheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPermissionCard() {
    final loc = ref.watch(farmerLocalizationProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _locationGranted ? AppTheme.surfaceContainerLow : AppTheme.warningContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.mapPin,
              size: 20,
              color: _locationGranted ? AppTheme.primaryGreen : AppTheme.warningAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.tr('step_location'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  loc.tr('location_desc'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _requestLocationPermission,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _locationGranted ? AppTheme.surfaceContainerLow : AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: _locationGranted ? AppTheme.primaryGreen : AppTheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      _locationGranted
                          ? '✓ Location Enabled: ${(ref.watch(farmerLocationProvider).location?.displayLocation ?? "GPS Active")}'
                          : loc.tr('grant_location'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _locationGranted ? AppTheme.primaryGreen : AppTheme.forestGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _locationGranted,
            onChanged: (val) => _requestLocationPermission(),
            activeThumbColor: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPermissionCard() {
    final loc = ref.watch(farmerLocalizationProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cameraGranted ? AppTheme.surfaceContainerLow : AppTheme.warningContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.camera,
              size: 20,
              color: _cameraGranted ? AppTheme.primaryGreen : AppTheme.warningAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.tr('step_camera'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  loc.tr('camera_desc'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _requestCameraPermission,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _cameraGranted ? AppTheme.surfaceContainerLow : AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: _cameraGranted ? AppTheme.primaryGreen : AppTheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      _cameraGranted ? '✓ Camera Enabled' : loc.tr('grant_camera'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _cameraGranted ? AppTheme.primaryGreen : AppTheme.forestGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _cameraGranted,
            onChanged: (val) => _requestCameraPermission(),
            activeThumbColor: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSourcePreferenceCard() {
    final loc = ref.watch(farmerLocalizationProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tr('step_diagnostic_source'),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSourceOption(
                  id: 'camera',
                  title: 'Live Camera',
                  icon: LucideIcons.camera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSourceOption(
                  id: 'gallery',
                  title: 'Gallery Upload',
                  icon: LucideIcons.image,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required String id,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _preferredSource == id;
    return InkWell(
      onTap: () => setState(() => _preferredSource = id),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceContainerLow : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.outlineVariant.withOpacity(0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.textDarkForest : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
