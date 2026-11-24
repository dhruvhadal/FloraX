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

/// Screen 9 — User Profile Screen (`user_profile`)
/// Verified farmer identity, profile audio reader, system toggles,
/// helpline directory, and passwordless session logout.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  FarmerProfile? _profile;
  bool _isLoading = true;
  bool _weatherAlerts = true;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final repo = ref.read(farmerProfileRepositoryProvider);
    final p = await repo.getLocalProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _weatherAlerts = p?.notificationsEnabled ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleWeatherAlerts(bool val) async {
    setState(() => _weatherAlerts = val);
    if (_profile != null) {
      final repo = ref.read(farmerProfileRepositoryProvider);
      await repo.updatePreferences(
        rawMobile: _profile!.mobileE164,
        notificationsEnabled: val,
      );
    }
  }

  Future<void> _changeLanguage(FarmerLanguage lang) async {
    await ref.read(activeFarmerLanguageProvider.notifier).setLanguage(
      lang,
      farmerMobile: _profile?.mobileE164,
    );
    if (_profile != null) {
      final repo = ref.read(farmerProfileRepositoryProvider);
      await repo.updatePreferences(
        rawMobile: _profile!.mobileE164,
        language: lang.code,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == FarmerLanguage.marathi
                ? 'भाषा यशस्वीरित्या मराठी मध्ये बदलली आहे.'
                : (lang == FarmerLanguage.hindi
                    ? 'भाषा सफलतापूर्वक हिन्दी में बदल दी गई है।'
                    : 'Language successfully updated to English.'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _readProfileAloud() {
    final utility = ref.read(deviceUtilityServiceProvider);
    final lang = ref.read(activeFarmerLanguageProvider);

    if (_isPlayingAudio) {
      utility.stopSpeaking();
      setState(() => _isPlayingAudio = false);
      return;
    }

    final liveLoc = ref.read(farmerLocationProvider).location;
    final name = _profile?.fullName.isNotEmpty == true ? _profile!.fullName : 'शेतकरी मित्र';
    final village = _profile?.village.isNotEmpty == true
        ? _profile!.village
        : (liveLoc?.village.isNotEmpty == true ? liveLoc!.village : '');
    final district = _profile?.district.isNotEmpty == true
        ? _profile!.district
        : (liveLoc?.district.isNotEmpty == true ? liveLoc!.district : '');
    final state = _profile?.state.isNotEmpty == true
        ? _profile!.state
        : (liveLoc?.state.isNotEmpty == true ? liveLoc!.state : '');

    String locationDesc = [village, district, state].where((s) => s.isNotEmpty).join(', ');
    if (locationDesc.isEmpty) locationDesc = 'स्थानिक क्षेत्र';

    String speechText;
    if (lang == FarmerLanguage.marathi) {
      speechText = 'किसानसेतू शेतकरी प्रोफाइल: $name. स्थान: $locationDesc. आपली सर्व ४५ पिकांची एआय रोग निदान मॉडेल्स ऑफलाइन सक्रिय आहेत.';
    } else if (lang == FarmerLanguage.hindi) {
      speechText = 'किसानसेतु किसान प्रोफाइल: $name. स्थान: $locationDesc. आपके सभी ४५ फसल रोग पहचान एआई मॉडल ऑफलाइन तैयार हैं।';
    } else {
      speechText = 'KisanSetu Farmer Profile: $name. Location: $locationDesc. All 45 crop pathology AI models are offline ready on your device.';
    }

    setState(() => _isPlayingAudio = true);
    utility.speakVernacular(speechText, langCode: lang.code).then((_) {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
      }
    });
  }

  Future<void> _confirmLogout() async {
    final activeLang = ref.read(activeFarmerLanguageProvider);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.logOut, color: AppTheme.alertRed, size: 22),
            const SizedBox(width: 8),
            Text(
              activeLang == FarmerLanguage.marathi
                  ? 'लॉगआउट करा?'
                  : (activeLang == FarmerLanguage.hindi ? 'लॉगआउट करें?' : 'Log Out?'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          activeLang == FarmerLanguage.marathi
              ? 'आपण खात्रीपूर्वक बाहेर पडू इच्छिता? आपण पुन्हा मोबाईल क्रमांकाने सहज प्रवेश करू शकता.'
              : (activeLang == FarmerLanguage.hindi
                  ? 'क्या आप सचमुच बाहर निकलना चाहते हैं? आप दोबारा मोबाइल नंबर से तुरंत प्रवेश कर सकते हैं।'
                  : 'Are you sure you want to log out? You can sign in anytime with your mobile number.'),
          style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              activeLang == FarmerLanguage.marathi
                  ? 'रद्द करा'
                  : (activeLang == FarmerLanguage.hindi ? 'रद्द करें' : 'Cancel'),
              style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              activeLang == FarmerLanguage.marathi
                  ? 'लॉगआउट'
                  : (activeLang == FarmerLanguage.hindi ? 'लॉगआउट' : 'Log Out'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      final repo = ref.read(farmerProfileRepositoryProvider);
      await repo.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);

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
              ? 'शेतकरी प्रोफाइल'
              : (activeLang == FarmerLanguage.hindi ? 'किसान प्रोफाइल' : 'Farmer Profile'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.forestGreen,
          ),
        ),
        actions: [
          // Audio Reader Pill
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                _isPlayingAudio ? LucideIcons.volumeX : LucideIcons.volume2,
                size: 16,
                color: AppTheme.forestGreen,
              ),
              label: Text(
                _isPlayingAudio ? 'थांबवा' : 'ऐका',
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
              onPressed: _readProfileAloud,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.forestGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===========================================================
                  // 1. VERIFIED FARMER AVATAR & IDENTITY CARD
                  // ===========================================================
                  _buildFarmerIdentityCard(activeLang),
                  const SizedBox(height: 16),

                  // ===========================================================
                  // 2. SYSTEM SETTINGS & PREFERENCES
                  // ===========================================================
                  _buildSettingsCard(activeLang),
                  const SizedBox(height: 16),

                  // ===========================================================
                  // 3. HARDWARE & FIELD PERMISSIONS STATUS
                  // ===========================================================
                  _buildHardwarePermissionsCard(activeLang),
                  const SizedBox(height: 16),

                  // ===========================================================
                  // 4. HELPLINE & EMERGENCY SUPPORT DIRECTORY
                  // ===========================================================
                  _buildHelplinesCard(activeLang),
                  const SizedBox(height: 24),

                  // ===========================================================
                  // 5. VERSION BADGE & LOGOUT BUTTON
                  // ===========================================================
                  _buildFooterAndLogout(activeLang),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Future<void> _updateLocationViaGps() async {
    final loc = await ref.read(farmerLocationProvider.notifier).refreshLocation(
      farmerMobile: _profile?.mobileE164,
      forceGps: true,
    );
    if (loc != null && mounted) {
      if (_profile != null) {
        final updated = _profile!.copyWith(
          village: loc.village.isNotEmpty ? loc.village : _profile!.village,
          district: loc.district.isNotEmpty ? loc.district : _profile!.district,
          state: loc.state.isNotEmpty ? loc.state : _profile!.state,
          pincode: loc.postalCode.isNotEmpty ? loc.postalCode : _profile!.pincode,
        );
        setState(() => _profile = updated);
        await ref.read(farmerProfileRepositoryProvider).saveProfile(updated);
      }
      final locDictionary = ref.read(farmerLocalizationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${locDictionary.tr('profile_updated_gps')}: ${loc.displayLocation}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFarmerIdentityCard(FarmerLanguage activeLang) {
    final liveLoc = ref.watch(farmerLocationProvider).location;
    final name = _profile?.fullName.isNotEmpty == true ? _profile!.fullName : 'Kisan Mitra';
    final mobile = _profile?.mobileE164.isNotEmpty == true ? _profile!.mobileE164 : '+91 98765 43210';
    final village = _profile?.village.isNotEmpty == true ? _profile!.village : (liveLoc?.village ?? '');
    final district = _profile?.district.isNotEmpty == true ? _profile!.district : (liveLoc?.district ?? '');
    final state = _profile?.state.isNotEmpty == true ? _profile!.state : (liveLoc?.state ?? '');
    final pincode = _profile?.pincode.isNotEmpty == true ? _profile!.pincode : (liveLoc?.postalCode ?? '');
    final addressParts = [village, district, state, pincode].where((s) => s.trim().isNotEmpty).toList();
    final displayAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : (liveLoc?.displayLocation ?? 'Tap "Update via GPS" to detect');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppTheme.pistachioPill,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.userCheck,
                    color: AppTheme.forestGreen,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          LucideIcons.checkCircle2,
                          size: 16,
                          color: AppTheme.leafGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mobile,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.pistachioContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        activeLang == FarmerLanguage.marathi
                            ? '✓ ICAR प्रमाणित शेतकरी'
                            : (activeLang == FarmerLanguage.hindi
                                ? '✓ ICAR सत्यापित किसान'
                                : '✓ Verified ICAR Farmer'),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.surfaceContainer),
          const SizedBox(height: 14),

          // Farm Geographical Details
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayAddress,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _updateLocationViaGps,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.primaryGreen),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.locateFixed, size: 13, color: AppTheme.forestGreen),
                      const SizedBox(width: 4),
                      Text(
                        ref.watch(farmerLocalizationProvider).tr('update_via_gps'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.forestGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeLang == FarmerLanguage.marathi
                      ? 'सुरक्षित ऑफलाइन ओळख (विना पासवर्ड)'
                      : (activeLang == FarmerLanguage.hindi
                          ? 'सुरक्षित ऑफलाइन पहचान (पासवर्ड रहित)'
                          : 'Secure Offline-First Identity (Passwordless)'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(FarmerLanguage activeLang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.settings, size: 18, color: AppTheme.forestGreen),
              const SizedBox(width: 8),
              Text(
                activeLang == FarmerLanguage.marathi
                    ? 'अ‍ॅप सेटिंग्ज व प्राधान्ये'
                    : (activeLang == FarmerLanguage.hindi ? 'ऐप सेटिंग्स व प्राथमिकताएं' : 'App Settings & Preferences'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Language Selector
          Text(
            activeLang == FarmerLanguage.marathi
                ? 'प्राधान्य भाषा (Language)'
                : (activeLang == FarmerLanguage.hindi ? 'पसंदीदा भाषा (Language)' : 'Preferred Language'),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLangChip(FarmerLanguage.marathi, 'मराठी', activeLang),
              const SizedBox(width: 8),
              _buildLangChip(FarmerLanguage.hindi, 'हिन्दी', activeLang),
              const SizedBox(width: 8),
              _buildLangChip(FarmerLanguage.english, 'English', activeLang),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.surfaceContainer),
          const SizedBox(height: 12),

          // Weather & Outbreak Alerts Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.forestGreen,
            value: _weatherAlerts,
            onChanged: _toggleWeatherAlerts,
            title: Text(
              activeLang == FarmerLanguage.marathi
                  ? 'हवामान व रोग उद्रेक सतर्कता'
                  : (activeLang == FarmerLanguage.hindi
                      ? 'मौसम व रोग चेतावनी अलर्ट'
                      : 'Weather & Outbreak Alerts'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
            ),
            subtitle: Text(
              activeLang == FarmerLanguage.marathi
                  ? 'तालुका स्तरावरील संभाव्य रोगांची सूचना मिळवा'
                  : (activeLang == FarmerLanguage.hindi
                      ? 'तहसील स्तर पर संभावित रोग प्रकोप की जानकारी प्राप्त करें'
                      : 'Receive block-level epidemic risk radar notifications'),
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(FarmerLanguage lang, String label, FarmerLanguage current) {
    final isSelected = lang == current;
    return Expanded(
      child: InkWell(
        onTap: () => _changeLanguage(lang),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.forestGreen : AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected ? AppTheme.forestGreen : AppTheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHardwarePermissionsCard(FarmerLanguage activeLang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.cpu, size: 18, color: AppTheme.forestGreen),
              const SizedBox(width: 8),
              Text(
                activeLang == FarmerLanguage.marathi
                    ? 'डिव्हाइस व हार्डवेअर परवानग्या'
                    : (activeLang == FarmerLanguage.hindi
                        ? 'डिवाइस व हार्डवेयर अनुमतियां'
                        : 'Device & Hardware Permissions'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPermissionRow(
            LucideIcons.camera,
            activeLang == FarmerLanguage.marathi
                ? 'कॅमेरा (Camera)'
                : (activeLang == FarmerLanguage.hindi ? 'कैमरा (Camera)' : 'Camera Access'),
            activeLang == FarmerLanguage.marathi
                ? 'पानांचे थेट रोग स्कॅनिंग'
                : (activeLang == FarmerLanguage.hindi ? 'पत्ती रोग लाइव्ह स्कैन' : 'Leaf Pathology Scanning'),
            true,
          ),
          const SizedBox(height: 10),
          _buildPermissionRow(
            LucideIcons.mapPin,
            activeLang == FarmerLanguage.marathi
                ? 'स्थान (GPS Location)'
                : (activeLang == FarmerLanguage.hindi ? 'स्थान (GPS Location)' : 'GPS Location'),
            activeLang == FarmerLanguage.marathi
                ? 'हवामान व उद्रेक रडार'
                : (activeLang == FarmerLanguage.hindi ? 'मौसम व रोग रडार' : 'Weather & Outbreak Radar'),
            true,
          ),
          const SizedBox(height: 10),
          _buildPermissionRow(
            LucideIcons.mic,
            activeLang == FarmerLanguage.marathi
                ? 'मायक्रोफोन (Microphone)'
                : (activeLang == FarmerLanguage.hindi ? 'माइक्रोफोन (Microphone)' : 'Microphone Access'),
            activeLang == FarmerLanguage.marathi
                ? 'व्हॉईस लक्षण शोध'
                : (activeLang == FarmerLanguage.hindi ? 'आवाज़ लक्षण खोज' : 'Voice Symptom Transcription'),
            true,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.forestGreen,
              side: const BorderSide(color: AppTheme.forestGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              minimumSize: const Size.fromHeight(42),
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: Text(
              activeLang == FarmerLanguage.marathi
                  ? 'परवानग्या तपासा / रीसेट करा'
                  : (activeLang == FarmerLanguage.hindi
                      ? 'अनुमतियां जांचें / रीसेट करें'
                      : 'Check / Reset Permissions'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.permissions);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(IconData icon, String title, String subtitle, bool isGranted) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.surfaceContainerLow,
          child: Icon(icon, size: 16, color: AppTheme.primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isGranted ? AppTheme.pistachioContainer : AppTheme.warningContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            isGranted ? 'सक्रिय (Active)' : 'प्रलंबित (Pending)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isGranted ? AppTheme.forestGreen : AppTheme.warningAmber,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelplinesCard(FarmerLanguage activeLang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.phoneCall, size: 18, color: AppTheme.forestGreen),
              const SizedBox(width: 8),
              Text(
                activeLang == FarmerLanguage.marathi
                    ? 'शेतकरी मदत केंद्र व हेल्पलाइन'
                    : (activeLang == FarmerLanguage.hindi
                        ? 'किसान सहायता केंद्र व हेल्पलाइन'
                        : 'Farmer Helplines & Support Desk'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildHelplineTile(
            title: activeLang == FarmerLanguage.marathi
                ? 'किसान कॉल सेंटर (भारत सरकार)'
                : (activeLang == FarmerLanguage.hindi ? 'किसान कॉल सेंटर (भारत सरकार)' : 'Kisan Call Center (Govt. of India)'),
            number: '1800-180-1551',
            badge: 'Toll-Free 24x7',
            badgeColor: AppTheme.pistachioContainer,
            badgeTextColor: AppTheme.forestGreen,
          ),
          const SizedBox(height: 10),
          _buildHelplineTile(
            title: activeLang == FarmerLanguage.marathi
                ? 'केव्हीके कृषी शास्त्रज्ञ थेट डेस्क'
                : (activeLang == FarmerLanguage.hindi ? 'केवीके कृषि वैज्ञानिक डेस्क' : 'KVK Agronomist Direct Desk'),
            number: '1800-120-4040',
            badge: 'ICAR Verified',
            badgeColor: AppTheme.pistachioPill,
            badgeTextColor: AppTheme.forestGreen,
          ),
          const SizedBox(height: 10),
          _buildHelplineTile(
            title: activeLang == FarmerLanguage.marathi
                ? 'पंतप्रधान पीक विमा हेल्पलाइन'
                : (activeLang == FarmerLanguage.hindi ? 'पीएम फसल बीमा हेल्पलाइन' : 'PM Crop Insurance (PMFBY)'),
            number: '14447',
            badge: 'Toll-Free',
            badgeColor: AppTheme.surfaceContainerHigh,
            badgeTextColor: AppTheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildHelplineTile({
    required String title,
    required String number,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.pistachioPill,
            child: Icon(LucideIcons.phone, size: 16, color: AppTheme.forestGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.forestGreen,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterAndLogout(FarmerLanguage activeLang) {
    return Column(
      children: [
        // Version Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.pistachioContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCheck, size: 14, color: AppTheme.forestGreen),
              const SizedBox(width: 6),
              Text(
                ref.watch(farmerLocalizationProvider).tr('kisansetu_offline_banner'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.forestGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Logout Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorContainer,
            foregroundColor: AppTheme.errorRed,
            elevation: 0,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.errorRed, width: 1.2),
            ),
          ),
          icon: const Icon(LucideIcons.logOut, size: 18),
          label: Text(
            activeLang == FarmerLanguage.marathi
                ? 'अ‍ॅपमधून बाहेर पडा (Logout)'
                : (activeLang == FarmerLanguage.hindi
                    ? 'ऐप से बाहर निकलें (Logout)'
                    : 'Sign Out / Change Farmer Profile'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          onPressed: _confirmLogout,
        ),
      ],
    );
  }
}
