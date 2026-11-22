import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../main.dart';
import '../../../services/auth/auth_role_service.dart';
import '../../../services/voice/vernacular_voice_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../widgets/state_selection_dropdown.dart';
import 'login_screen.dart';

/// Screen: New User Registration (Req 2B, 2C, 2E, 2F)
///
/// Collects farmer profile, state selection, password, and requests native device permissions.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedState;
  String? _stateError;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Device permissions state tracking
  bool _locationGranted = false;
  bool _cameraGranted = false;
  bool _storageGranted = true; // default true for scoped storage on modern Android

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialPermissions() async {
    try {
      final locStatus = await Geolocator.checkPermission();
      if (locStatus == LocationPermission.always || locStatus == LocationPermission.whileInUse) {
        if (mounted) setState(() => _locationGranted = true);
      }
    } catch (_) {}
  }

  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        if (mounted) setState(() => _locationGranted = true);
      }
    } catch (_) {}
  }

  Future<void> _requestCameraPermission() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty && mounted) {
        setState(() => _cameraGranted = true);
      }
    } catch (_) {}
  }

  Future<void> _handleRegister() async {
    setState(() {
      _stateError = _selectedState == null ? 'Please select your State / Union Territory' : null;
    });

    if (!_formKey.currentState!.validate() || _selectedState == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authRoleServiceProvider);
      final activeLang = ref.read(activeFarmerLanguageProvider);

      await authService.registerWithMobileAndPassword(
        fullName: _nameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        password: _passwordController.text.trim(),
        state: _selectedState!,
        language: activeLang.code,
      );

      // Persist language choice
      const storage = FlutterSecureStorage();
      await storage.write(key: 'florax_preferred_language', value: activeLang.code);

      if (!mounted) return;

      // Navigate to main application shell
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FloraXMainShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists with this mobile number. Please log in.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'Password is too weak. Please use at least 6 characters.';
        } else {
          _errorMessage = e.message ?? 'Registration failed. Please check network connection.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final isMr = activeLang == FarmerLanguage.marathi;
    final isHi = activeLang == FarmerLanguage.hindi;

    final String registerTitle = isMr
        ? 'नवीन शेतकरी नोंदणी (New Farmer Registration)'
        : (isHi ? 'नया किसान पंजीकरण (New Farmer Registration)' : 'New Farmer Registration');

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: FloraXTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          registerTitle,
          style: const TextStyle(
            color: FloraXTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.alertCircle, color: Color(0xFFB91C1C), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Section 1: Personal Details
                const Text(
                  '1. Full Name / पूर्ण नाव / पूरा नाम',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: FloraXTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.user, color: FloraXTheme.primaryGreen, size: 20),
                    hintText: isMr ? 'उदा. ज्ञानेश्वर पाटील' : (isHi ? 'उदा. रामेश्वर सिंह' : 'e.g. Ramesh Patel'),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.primaryGreen, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Section 2: Mobile Number
                const Text(
                  '2. Mobile Number / मोबाईल नंबर',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: FloraXTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.phone, color: FloraXTheme.primaryGreen, size: 20),
                    prefixText: '+91 ',
                    hintText: '9876543210',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.primaryGreen, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your 10-digit mobile number';
                    }
                    if (val.trim().length != 10 || !RegExp(r'^[0-9]+$').hasMatch(val.trim())) {
                      return 'Please enter a valid 10-digit Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Section 3: State Selection Dropdown (Req 2C)
                const Text(
                  '3. State / राज्य / प्रदेश',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: FloraXTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                StateSelectionDropdown(
                  selectedState: _selectedState,
                  errorText: _stateError,
                  onStateSelected: (state) {
                    setState(() {
                      _selectedState = state;
                      _stateError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Section 4: Preferred Language
                const Text(
                  '4. Preferred Language / पसंतीची भाषा',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: FloraXTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildLanguageChip(FarmerLanguage.marathi, 'मराठी'),
                    const SizedBox(width: 8),
                    _buildLanguageChip(FarmerLanguage.hindi, 'हिन्दी'),
                    const SizedBox(width: 8),
                    _buildLanguageChip(FarmerLanguage.english, 'English'),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 5: Password Fields
                const Text(
                  '5. Create Password / पासवर्ड तयार करा',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: FloraXTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.lock, color: FloraXTheme.primaryGreen, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: FloraXTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: 'Minimum 6 characters',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.primaryGreen, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a password';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.check, color: FloraXTheme.primaryGreen, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: FloraXTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    hintText: 'Confirm password',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FloraXTheme.primaryGreen, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                // Section 6: Device Permissions (Req 2F)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FloraXTheme.borderDim, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.shieldCheck, color: FloraXTheme.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Device Permissions (उपकरण परवानग्या)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'LeafGuard needs permissions to provide farm weather, camera diagnosis, and save crop records.',
                        style: TextStyle(fontSize: 12.5, color: FloraXTheme.textSecondary),
                      ),
                      const Divider(height: 18),
                      _buildPermissionRow(
                        title: '1. GPS Location',
                        reason: 'For accurate 5km weather forecast and nearby disease alerts',
                        isGranted: _locationGranted,
                        onTap: _requestLocationPermission,
                      ),
                      const SizedBox(height: 10),
                      _buildPermissionRow(
                        title: '2. Camera',
                        reason: 'To photograph leaf symptoms and detect diseases with AI',
                        isGranted: _cameraGranted,
                        onTap: _requestCameraPermission,
                      ),
                      const SizedBox(height: 10),
                      _buildPermissionRow(
                        title: '3. Storage / Gallery',
                        reason: 'To save offline diagnosis records and export prescriptions',
                        isGranted: _storageGranted,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloraXTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isMr ? 'नोंदणी पूर्ण करा' : (isHi ? 'पंजीकरण पूरा करें' : 'Complete Registration'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 18),

                // Back to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMr ? 'आधीच खाते आहे? ' : (isHi ? 'पहले से खाता है? ' : 'Already have an account? '),
                      style: const TextStyle(color: FloraXTheme.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Text(
                        isMr ? 'लॉगिन करा' : (isHi ? 'लॉगिन करें' : 'Login here'),
                        style: const TextStyle(
                          color: FloraXTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip(FarmerLanguage lang, String label) {
    final active = ref.watch(activeFarmerLanguageProvider);
    final isSelected = active == lang;

    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(activeFarmerLanguageProvider.notifier).state = lang;
          ref.read(vernacularVoiceStateProvider.notifier).setLanguage(lang.ttsLocale);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
              width: isSelected ? 1.8 : 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textPrimary,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRow({
    required String title,
    required String reason,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isGranted ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
          size: 18,
          color: isGranted ? FloraXTheme.primaryGreen : FloraXTheme.amberCaution,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                reason,
                style: const TextStyle(fontSize: 11.5, color: FloraXTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (!isGranted)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(50, 32),
            ),
            child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Allowed',
              style: TextStyle(color: FloraXTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
