import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/localization/farmer_localization.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/utility/device_utility_service.dart';

/// Screen 0 — First-Launch Language Selection Screen (`language_selection`)
/// Displayed immediately on cold startup when hasSelectedLanguage == false.
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  FarmerLanguage _selectedLang = FarmerLanguage.marathi;

  @override
  void initState() {
    super.initState();
    _selectedLang = ref.read(activeFarmerLanguageProvider);
  }

  Future<void> _handleContinue() async {
    await ref.read(activeFarmerLanguageProvider.notifier).setLocale(_selectedLang.code);
    await ref.read(hasSelectedLanguageProvider.notifier).setHasSelected(true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
    }
  }

  void _speakHelpAudio() {
    final utility = ref.read(deviceUtilityServiceProvider);
    final lang = _selectedLang.code;
    final message = lang == 'mr'
        ? 'शेतकरी बंधूंनो, आपली पसंतीची भाषा निवडा. किसानसेतू मराठी, हिंदी व इंग्रजी भाषेत उपलब्ध आहे.'
        : (lang == 'hi'
            ? 'किसान भाइयों, अपनी पसंदीदा भाषा चुनें। किसानसेतु मराठी, हिंदी और अंग्रेजी में उपलब्ध है।'
            : 'Dear farmers, please select your preferred language to continue in KisanSetu.');

    utility.speakVernacular(message, langCode: lang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // KisanSetu Logo Emblem
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/branding/kisansetu.jpg'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'KisanSetu • किसानसेतू',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.forestGreen,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Welcoming prompt in all 3 languages
              const Text(
                'Choose Your Preferred Language / अपनी पसंदीदा भाषा चुनें / तुमची पसंतीची भाषा निवडा',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDarkForest,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),

              // 3 Large Accessible Cards: English, हिन्दी (Hindi), मराठी (Marathi)
              _buildLargeLanguageCard(
                lang: FarmerLanguage.english,
                title: 'English',
                subtitle: 'National Agronomic Advisory',
                nativeTitle: 'English',
                isSelected: _selectedLang == FarmerLanguage.english,
              ),
              const SizedBox(height: 14),
              _buildLargeLanguageCard(
                lang: FarmerLanguage.hindi,
                title: 'हिन्दी (Hindi)',
                subtitle: 'उत्तर व मध्य भारत क्षेत्रीय भाषा',
                nativeTitle: 'हिंदी',
                isSelected: _selectedLang == FarmerLanguage.hindi,
              ),
              const SizedBox(height: 14),
              _buildLargeLanguageCard(
                lang: FarmerLanguage.marathi,
                title: 'मराठी (Marathi)',
                subtitle: 'महाराष्ट्र व कोकण विभाग प्रादेशिक भाषा',
                nativeTitle: 'मराठी',
                isSelected: _selectedLang == FarmerLanguage.marathi,
              ),

              const Spacer(),

              // Audio Help Readout
              OutlinedButton.icon(
                onPressed: _speakHelpAudio,
                icon: const Icon(LucideIcons.volume2, size: 18),
                label: const Text(
                  'ऑडिओ मदत • ऑडियो सहायता • Audio Help',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.forestGreen,
                  side: const BorderSide(color: AppTheme.forestGreen),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
              const SizedBox(height: 12),

              // Continue Button
              ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forestGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue • पुढे सुरू ठेवा • आगे बढ़ें',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeLanguageCard({
    required FarmerLanguage lang,
    required String title,
    required String subtitle,
    required String nativeTitle,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _selectedLang = lang);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.pistachioContainer : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected ? AppTheme.forestGreen : AppTheme.outlineVariant,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected ? AppTheme.softCardShadow : [],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  isSelected ? AppTheme.forestGreen : AppTheme.surfaceContainerHigh,
              child: Icon(
                isSelected ? LucideIcons.check : LucideIcons.globe,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      color: isSelected ? AppTheme.forestGreen : AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
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
}
