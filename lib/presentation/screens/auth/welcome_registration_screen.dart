import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../domain/models/florax_models.dart';
import '../../../services/location/location_service.dart';
import '../../../services/utility/device_utility_service.dart';

/// Screen 1 — Welcome & Registration Screen (`welcome_registration`)
/// Allows farmers to sign up or log in passwordlessly with instant profile creation.
class WelcomeRegistrationScreen extends ConsumerStatefulWidget {
  const WelcomeRegistrationScreen({super.key});

  @override
  ConsumerState<WelcomeRegistrationScreen> createState() =>
      _WelcomeRegistrationScreenState();
}

class _WelcomeRegistrationScreenState
    extends ConsumerState<WelcomeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _isRegisterMode = true; // true = Register, false = Login
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedState = '';
  String _selectedDistrict = '';

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final repo = ref.read(farmerProfileRepositoryProvider);
    final profile = await repo.getLocalProfile();
    if (profile != null && profile.isRegistered && mounted) {
      // Pre-fill existing user info
      setState(() {
        _mobileController.text = profile.mobileE164.replaceAll('+91', '');
        _nameController.text = profile.fullName;
        _selectedState = profile.state;
        _selectedDistrict = profile.district;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _speakHelpAudio() {
    final utility = ref.read(deviceUtilityServiceProvider);
    final lang = ref.read(activeFarmerLanguageProvider).code;
    final message = lang == 'mr'
        ? 'शेतकरी बंधूंनो, किसानसेतू ॲपमध्ये आपले स्वागत आहे. येथे नोंदणी करण्यासाठी पासवर्ड किंवा ओटीपीची आवश्यकता नाही. फक्त आपले नाव आणि मोबाईल क्रमांक टाका.'
        : (lang == 'hi'
            ? 'किसान भाइयों, किसानसेतु ऐप में आपका स्वागत है। यहां पंजीकरण के लिए किसी पासवर्ड या ओटीपी की आवश्यकता नहीं है। बस अपना नाम और मोबाइल नंबर दर्ज करें।'
            : 'Welcome to KisanSetu. No password or OTP required. Simply enter your name and mobile number to continue.');

    utility.speakVernacular(message, langCode: lang);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawMobile = _mobileController.text.trim();
    if (rawMobile.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(farmerProfileRepositoryProvider);
      final lang = ref.read(activeFarmerLanguageProvider).code;
      final liveLoc = ref.read(farmerLocationProvider).location;
      final effectiveDistrict = _selectedDistrict.isNotEmpty
          ? _selectedDistrict
          : (liveLoc?.district ?? '');
      final effectiveState = _selectedState.isNotEmpty
          ? _selectedState
          : (liveLoc?.state ?? '');

      FarmerProfile profile;
      if (_isRegisterMode) {
        profile = await repo.registerFarmer(
          fullName: _nameController.text.trim(),
          mobile10Digits: rawMobile,
          state: effectiveState,
          district: effectiveDistrict,
          preferredLanguage: lang,
        );
      } else {
        profile = await repo.loginFarmer(
          fullName: _nameController.text.trim(),
          mobile10Digits: rawMobile,
        );
      }

      debugPrint('[WelcomeRegistration] Profile authenticated: ${profile.mobileE164}');

      final utility = ref.read(deviceUtilityServiceProvider);
      final camGranted = await utility.isCameraGranted();
      final locGranted = await utility.isLocationGranted();
      final hasPermissions = camGranted && locGranted;

      if (mounted) {
        if (!_isRegisterMode && hasPermissions) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.permissions,
            arguments: profile,
          );
        }
      }
    } on DuplicateFarmerException catch (_) {
      final lang = ref.read(activeFarmerLanguageProvider).code;
      final msg = lang == 'mr'
          ? 'या मोबाईल क्रमांकावर आधीच खाते नोंदणीकृत आहे. कृपया लॉगिन करा.'
          : (lang == 'hi'
              ? 'यह मोबाइल नंबर पहले से पंजीकृत है। कृपया लॉग इन करें।'
              : 'Account already registered for this mobile. Please log in.');
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on UnregisteredFarmerException catch (_) {
      final lang = ref.read(activeFarmerLanguageProvider).code;
      final msg = lang == 'mr'
          ? 'या मोबाईल क्रमांकावर कोणतीही नोंदणी आढळली नाही. कृपया नवीन नोंदणी करा.'
          : (lang == 'hi'
              ? 'इस मोबाइल नंबर पर कोई खाता नहीं मिला। कृपया पहले पंजीकरण करें।'
              : 'No registered account found for this mobile. Please register first.');
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on CredentialMismatchException catch (_) {
      final lang = ref.read(activeFarmerLanguageProvider).code;
      final msg = lang == 'mr'
          ? 'नोंदणीकृत नाव आणि प्रविष्ट केलेले नाव जुळत नाही. कृपया अचूक नाव टाका.'
          : (lang == 'hi'
              ? 'पंजीकृत नाम और दर्ज किया गया नाम मेल नहीं खाते। कृपया सही नाम दर्ज करें।'
              : 'Name does not match the registered profile for this mobile number.');
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _errorMessage = e.message.toString());
    } catch (e) {
      debugPrint('[WelcomeRegistration ERROR] $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please verify credentials and connection.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(farmerLocalizationProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // =========================================================
                    // 1. HERO BANNER WITH AUDIO HELP PILL
                    // =========================================================
                    _buildHeroBanner(),
                    const SizedBox(height: 16),

                    // =========================================================
                    // 2. KISANSETU LOGO & BRANDING ROW
                    // =========================================================
                    _buildBrandingHeader(),
                    const SizedBox(height: 16),

                    // =========================================================
                    // 3. SEGMENTED REGISTER VS LOGIN TOGGLE
                    // =========================================================
                    _buildSegmentedToggle(),
                    const SizedBox(height: 16),

                    // =========================================================
                    // 4. MAIN FORM CARD
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
                        boxShadow: AppTheme.softCardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // FULL FARMER NAME INPUT
                          _buildLabel(
                            _isRegisterMode ? loc.tr('enter_name') : 'Registered Full Name',
                            isRequired: true,
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: loc.tr('name_hint'),
                              prefixIcon: const Icon(
                                LucideIcons.user,
                                size: 20,
                                color: AppTheme.outline,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // MOBILE NUMBER INPUT
                          _buildLabel('Mobile Number', isRequired: true),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              hintText: '98765 43210',
                              prefixIcon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: AppTheme.outlineVariant.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '🇮🇳 +91',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDarkForest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your mobile number';
                              }
                              if (val.trim().length != 10) {
                                return 'Must be exactly 10 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // HELPER BADGE: NO OTP OR PASSWORD REQUIRED
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(color: AppTheme.pistachioPill),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  LucideIcons.checkCircle2,
                                  size: 18,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.tr('secure_passwordless'),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textDarkForest,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.alertRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // CONTINUE BUTTON
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _isRegisterMode ? 'Continue to Farm Setup' : 'Log In to KisanSetu',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(LucideIcons.arrowRight, size: 16),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // TRUST FOOTER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.shieldCheck, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            loc.tr('icar_free_farmers_badge'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Stack(
      children: [
        Container(
          height: 175,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            image: const DecorationImage(
              image: AssetImage('assets/branding/kisansetu.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: 175,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.15),
                AppTheme.deepForest.withOpacity(0.85),
              ],
            ),
          ),
        ),
        // 100% Free Badge
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.sprout, size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  ref.watch(farmerLocalizationProvider).tr('free_100_badge'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Audio Help Floating Button
        Positioned(
          bottom: 12,
          left: 12,
          child: InkWell(
            onTap: _speakHelpAudio,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                boxShadow: AppTheme.softCardShadow,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.volume2, size: 16, color: AppTheme.forestGreen),
                  SizedBox(width: 6),
                  Text(
                    'बोलकर सुनें (Audio Help)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDarkForest,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandingHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
            image: const DecorationImage(
              image: AssetImage('assets/branding/kisansetu.jpg'),
              fit: BoxFit.contain,
            ),
            boxShadow: AppTheme.softCardShadow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.watch(farmerLocalizationProvider).tr('welcome_title'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ref.watch(farmerLocalizationProvider).tr('welcome_subtitle'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedToggle() {
    final loc = ref.watch(farmerLocalizationProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isRegisterMode = true),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isRegisterMode ? AppTheme.primaryAction : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: _isRegisterMode ? AppTheme.softCardShadow : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  loc.tr('register_btn'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _isRegisterMode ? Colors.white : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isRegisterMode = false),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isRegisterMode ? AppTheme.primaryAction : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: !_isRegisterMode ? AppTheme.softCardShadow : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  loc.tr('login_btn'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: !_isRegisterMode ? Colors.white : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String title, {bool isRequired = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        if (isRequired)
          Text(
            ref.watch(farmerLocalizationProvider).tr('required_field_label'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
      ],
    );
  }
}
