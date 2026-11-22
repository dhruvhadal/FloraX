import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../main.dart';
import '../../../services/auth/auth_role_service.dart';
import '../../../services/voice/vernacular_voice_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import 'registration_screen.dart';

/// Screen: Existing User Login (Req 2D)
///
/// Streamlined mobile-number & password authentication preserving all historical scans.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authRoleServiceProvider);
      final credential = await authService.loginWithMobileAndPassword(
        mobileNumber: _mobileController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        // Retrieve and restore user's saved language preference if present
        final profile = await authService.fetchUserProfile(uid);
        if (profile != null && profile['language'] != null) {
          final savedLang = FarmerLanguage.fromCode(profile['language'] as String);
          ref.read(activeFarmerLanguageProvider.notifier).state = savedLang;
          ref.read(vernacularVoiceStateProvider.notifier).setLanguage(savedLang.ttsLocale);
          const storage = FlutterSecureStorage();
          await storage.write(key: 'florax_preferred_language', value: savedLang.code);
        }
      }

      if (!mounted) return;

      // Navigate to main application shell
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FloraXMainShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No registered account found with this mobile number. Please create an account.';
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _errorMessage = 'Incorrect password. Please verify and try again.';
        } else if (e.code == 'too-many-requests') {
          _errorMessage = 'Too many attempts. Please try again after a few minutes.';
        } else {
          _errorMessage = e.message ?? 'Authentication failed. Please check network connection.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _mobileController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Password Recovery',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered 10-digit mobile number to verify your account or reset credentials via KVK support.',
              style: TextStyle(fontSize: 13.5, color: FloraXTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                prefixText: '+91 ',
                labelText: 'Mobile Number',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: FloraXTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Password reset assistance requested. For immediate help, call your local KVK Center toll-free at 1800-180-1551.',
                  ),
                  backgroundColor: FloraXTheme.primaryGreen,
                  duration: Duration(seconds: 5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FloraXTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Request Assistance'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final isMr = activeLang == FarmerLanguage.marathi;
    final isHi = activeLang == FarmerLanguage.hindi;

    final String loginHeader = isMr
        ? 'शेतकरी लॉगिन (Farmer Login)'
        : (isHi ? 'किसान लॉगिन (Farmer Login)' : 'Farmer Login');

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
          loginHeader,
          style: const TextStyle(
            color: FloraXTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Icon Header
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      border: Border.all(color: FloraXTheme.primaryGreen, width: 1.5),
                    ),
                    child: const Icon(
                      LucideIcons.user,
                      color: FloraXTheme.primaryGreen,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isMr
                      ? 'आपल्या नोंदणीकृत मोबाईल नंबरने लॉगिन करा'
                      : (isHi ? 'अपने पंजीकृत मोबाइल नंबर से लॉगिन करें' : 'Login with your registered mobile number'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: FloraXTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

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
                  const SizedBox(height: 20),
                ],

                // Mobile Number Field
                const Text(
                  'Mobile Number / मोबाईल नंबर',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 18),

                // Password Field
                const Text(
                  'Password / पासवर्ड',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
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
                    hintText: 'Enter your password',
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
                      return 'Please enter your password';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      isMr
                          ? 'पासवर्ड विसरलात का?'
                          : (isHi ? 'पासवर्ड भूल गए?' : 'Forgot Password?'),
                      style: const TextStyle(
                        color: FloraXTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Login Button (56dp+)
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                          isMr ? 'लॉगिन करा' : (isHi ? 'लॉगिन करें' : 'Login'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Create Account Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMr
                          ? 'नवीन शेतकरी आहात? '
                          : (isHi ? 'नये किसान हैं? ' : "Don't have an account? "),
                      style: const TextStyle(color: FloraXTheme.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                        );
                      },
                      child: Text(
                        isMr ? 'नोंदणी करा' : (isHi ? 'रजिस्टर करें' : 'Create Account'),
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
}
