import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../services/voice/vernacular_voice_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../auth/auth_landing_screen.dart';

/// Screen 0: Initial Language Selection Screen (Req 3)
///
/// Prominently presented on first launch so farmers choose their preferred dialect
/// before any authentication or dashboard interaction.
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  final bool isSettingsMode;
  static const String preferredLanguageKey = 'florax_preferred_language';

  const LanguageSelectionScreen({
    super.key,
    this.isSettingsMode = false,
  });

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  late FarmerLanguage _selectedLang;
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _selectedLang = ref.read(activeFarmerLanguageProvider);
  }

  Future<void> _persistAndProceed() async {
    // 1. Update Riverpod Language Providers
    ref.read(activeFarmerLanguageProvider.notifier).state = _selectedLang;
    ref.read(vernacularVoiceStateProvider.notifier).setLanguage(_selectedLang.ttsLocale);

    // 2. Persist in secure storage for future sessions
    try {
      await _storage.write(key: LanguageSelectionScreen.preferredLanguageKey, value: _selectedLang.code);
    } catch (_) {}

    if (!mounted) return;

    if (widget.isSettingsMode) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language updated to ${_selectedLang.displayName}'),
          backgroundColor: FloraXTheme.primaryGreen,
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthLandingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FloraXTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LeafGuard Logo & Title
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: FloraXTheme.primaryGreen, width: 2),
                  ),
                  child: const Icon(
                    LucideIcons.leaf,
                    color: FloraXTheme.primaryGreen,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'LeafGuard • FloraX',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: FloraXTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Select your preferred language\nतुमची भाषा निवडा • अपनी भाषा चुनें',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: FloraXTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Language Cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildLanguageOptionCard(
                      lang: FarmerLanguage.marathi,
                      nativeTitle: 'मराठी',
                      subtitle: 'महाराष्ट्र आणि कोकण भागातील शेतकऱ्यांसाठी',
                      badge: 'मरा',
                    ),
                    const SizedBox(height: 16),
                    _buildLanguageOptionCard(
                      lang: FarmerLanguage.hindi,
                      nativeTitle: 'हिन्दी',
                      subtitle: 'मध्य व उत्तर भारत के किसान भाइयों के लिए',
                      badge: 'हिं',
                    ),
                    const SizedBox(height: 16),
                    _buildLanguageOptionCard(
                      lang: FarmerLanguage.english,
                      nativeTitle: 'English',
                      subtitle: 'Agricultural guidance in clear English',
                      badge: 'EN',
                    ),
                  ],
                ),
              ),

              // Confirm / Proceed Button
              ElevatedButton(
                onPressed: _persistAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FloraXTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedLang == FarmerLanguage.marathi
                          ? 'पुढे जा (Continue)'
                          : (_selectedLang == FarmerLanguage.hindi
                              ? 'आगे बढ़ें (Continue)'
                              : 'Continue'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.arrowRight, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOptionCard({
    required FarmerLanguage lang,
    required String nativeTitle,
    required String subtitle,
    required String badge,
  }) {
    final bool isSelected = _selectedLang == lang;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLang = lang;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FloraXTheme.primaryGreen.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? FloraXTheme.primaryGreen : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    color: isSelected ? Colors.white : FloraXTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeTitle,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: FloraXTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
