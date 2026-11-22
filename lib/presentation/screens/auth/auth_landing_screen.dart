import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../onboarding/language_selection_screen.dart';
import 'login_screen.dart';
import 'registration_screen.dart';

/// Screen: Auth Landing Screen (Req 2A)
///
/// Prominently displays "Already registered?" and presents two unambiguous
/// 56dp+ action pathways for farmers with limited digital literacy.
class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final isMr = activeLang == FarmerLanguage.marathi;
    final isHi = activeLang == FarmerLanguage.hindi;

    final String alreadyRegisteredTitle = isMr
        ? 'आधीच नोंदणी केली आहे का?'
        : (isHi ? 'क्या आप पहले से पंजीकृत हैं?' : 'Already registered?');

    final String alreadyRegisteredSubtitle = isMr
        ? 'जर आपले खाते आधीच असेल तर थेट लॉगिन करा, किंवा नवीन खाते उघडा.'
        : (isHi
            ? 'यदि आपका खाता पहले से है तो लॉगिन करें, या नया खाता बनाएं।'
            : 'Log in if you already have an account, or create a new farmer profile.');

    final String yesLoginText = isMr
        ? 'होय, लॉगिन करा (Yes, Login)'
        : (isHi ? 'हाँ, लॉगिन करें (Yes, Login)' : 'Yes, Login');

    final String noCreateAccountText = isMr
        ? 'नाही, नवीन खाते तयार करा'
        : (isHi ? 'नहीं, नया खाता बनाएं' : 'No, Create Account');

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Language Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.leaf,
                          color: FloraXTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'LeafGuard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: FloraXTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSelectionScreen(isSettingsMode: true),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.languages, size: 16, color: FloraXTheme.primaryGreen),
                    label: Text(
                      activeLang.displayName,
                      style: const TextStyle(
                        color: FloraXTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 1),

              // Main Graphic Card
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: FloraXTheme.primaryGreen.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.userCheck,
                      color: FloraXTheme.primaryGreen,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Headline Prompt
              Text(
                alreadyRegisteredTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FloraXTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  alreadyRegisteredSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: FloraXTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(flex: 2),

              // Option 1: Yes, Login (Existing Users)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(LucideIcons.logIn, size: 22),
                label: Text(
                  yesLoginText,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FloraXTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 14),

              // Option 2: No, Create Account (New Users)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                  );
                },
                icon: const Icon(LucideIcons.userPlus, size: 22, color: FloraXTheme.primaryGreen),
                label: Text(
                  noCreateAccountText,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: FloraXTheme.primaryGreen,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FloraXTheme.primaryGreen, width: 1.8),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
