import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../main.dart';
import '../../../services/voice/vernacular_voice_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../auth/auth_landing_screen.dart';
import 'language_selection_screen.dart';

/// Startup Gate determining whether to show Language Selection, Login, or Main Shell
class AppStartupGate extends ConsumerStatefulWidget {
  const AppStartupGate({super.key});

  @override
  ConsumerState<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends ConsumerState<AppStartupGate> {
  static const _storage = FlutterSecureStorage();
  bool _isChecking = true;
  bool _hasSavedLanguage = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      final savedLangCode = await _storage.read(key: LanguageSelectionScreen.preferredLanguageKey);
      final User? user = FirebaseAuth.instance.currentUser;

      if (savedLangCode != null && savedLangCode.isNotEmpty) {
        _hasSavedLanguage = true;
        final lang = FarmerLanguage.fromCode(savedLangCode);
        ref.read(activeFarmerLanguageProvider.notifier).state = lang;
        ref.read(vernacularVoiceStateProvider.notifier).setLanguage(lang.ttsLocale);
      }

      // Check if user is authenticated (registered user or existing active session)
      if (user != null && !user.isAnonymous) {
        _isAuthenticated = true;
      }
    } catch (e) {
      debugPrint('[FloraX StartupGate] Error checking initial state: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: FloraXTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
        ),
      );
    }

    // 1. If language is not yet selected, show Language Selection Screen (Req 3)
    if (!_hasSavedLanguage) {
      return const LanguageSelectionScreen();
    }

    // 2. If authenticated, go straight to Main Shell
    if (_isAuthenticated) {
      return const FloraXMainShell();
    }

    // 3. Otherwise show Login vs Registration Split (Req 2)
    return const AuthLandingScreen();
  }
}
