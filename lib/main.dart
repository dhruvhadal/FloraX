import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/bootstrap/firebase_security_init.dart';
import 'core/localization/farmer_localization.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/farmer_profile_repository.dart';
import 'presentation/screens/auth/language_selection_screen.dart';
import 'presentation/screens/auth/welcome_registration_screen.dart';
import 'presentation/screens/home/home_dashboard_screen.dart';
import 'services/auth/auth_role_service.dart';
import 'services/notifications/outbreak_fcm_service.dart';
import 'services/sync/offline_media_sync_manager.dart';

/// Application Entrypoint with Guarded Zone & Production Service Bootstrapping
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Enforce portrait mode orientation for rugged field stability
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // 2. High-contrast system navigation colors for bright outdoor sunlight (Daylight Kisan)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // 3. Bootstrap Firebase Core, Hardware Attestation (Play Integrity), and SQLite Cache
    try {
      await FirebaseSecurityInitService().initialize();
    } catch (e) {
      debugPrint('[KisanSetu Init] FirebaseSecurityInitService error: $e');
    }

    // 4. Ensure Authenticated Session (Anonymous Farmer Login & User Profile Sync)
    try {
      final authRoleService = AuthRoleService();
      await authRoleService.ensureAuthenticatedSession();
    } catch (e) {
      debugPrint('[KisanSetu Init] AuthRoleService error: $e');
    }

    // 5. Start Persistent Offline Media Synchronization Manager
    try {
      final offlineSyncManager = OfflineMediaSyncManager();
      await offlineSyncManager.initialize();
    } catch (e) {
      debugPrint('[KisanSetu Init] OfflineMediaSyncManager error: $e');
    }

    // 6. Initialize Outbreak FCM Service (Permissions, Background Handlers & Topics)
    try {
      final fcmService = OutbreakFcmService();
      await fcmService.initialize();
    } catch (e) {
      debugPrint('[KisanSetu Init] OutbreakFcmService error: $e');
    }

    // 7. Load persistent language preference & first-launch state from SharedPreferences
    FarmerLanguage initialLanguage = FarmerLanguage.marathi;
    bool hasSelectedLanguage = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSelectedLanguage = prefs.getBool('has_selected_language') ?? false;
      final savedCode = prefs.getString('selected_language_code');
      if (savedCode != null && savedCode.isNotEmpty) {
        initialLanguage = FarmerLanguage.fromCode(savedCode);
      }
    } catch (e) {
      debugPrint('[KisanSetu Init] Language pre-load error: $e');
    }

    // 8. Mount Root Application with Global Riverpod Scope & Language Override
    runApp(
      ProviderScope(
        overrides: [
          initialLanguageOverrideProvider.overrideWithValue(initialLanguage),
          hasSelectedLanguageOverrideProvider.overrideWithValue(hasSelectedLanguage),
        ],
        child: const KisanSetuApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('[KisanSetu Uncaught Zone Error] $error\n$stackTrace');
  });
}

/// Root Application Widget Alias for backwards compatibility
typedef FloraXApp = KisanSetuApp;
typedef FloraXMobileApp = KisanSetuApp;

/// Primary Application Widget
class KisanSetuApp extends ConsumerWidget {
  const KisanSetuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(activeFarmerLanguageProvider);

    return MaterialApp(
      title: 'KisanSetu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.daylightTheme,
      locale: currentLang.locale,
      supportedLocales: const [
        Locale('mr'),
        Locale('hi'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: AppRouter.generateRoute,
      home: const KisanStartupGate(),
    );
  }
}

/// App Startup Gate that seamlessly routes registered farmers to HomeDashboardScreen
/// or new farmers to WelcomeRegistrationScreen.
class KisanStartupGate extends ConsumerWidget {
  const KisanStartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelectedLang = ref.watch(hasSelectedLanguageProvider);
    if (!hasSelectedLang) {
      return const LanguageSelectionScreen();
    }

    final profileAsync = ref.watch(farmerProfileRepositoryProvider).getLocalProfile();

    return FutureBuilder(
      future: profileAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.forestGreen),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile != null) {
          if (profile.preferredLanguage.isNotEmpty) {
            final profileLang = FarmerLanguage.fromCode(profile.preferredLanguage);
            if (ref.read(activeFarmerLanguageProvider) != profileLang) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(activeFarmerLanguageProvider.notifier).setLanguage(profileLang);
              });
            }
          }
          if (profile.isRegistered && profile.mobileE164.isNotEmpty) {
            return const HomeDashboardScreen();
          }
        }

        return const WelcomeRegistrationScreen();
      },
    );
  }
}
