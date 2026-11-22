import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'core/bootstrap/firebase_security_init.dart';
import 'core/theme/florax_theme.dart';
import 'domain/models/florax_models.dart';
import 'presentation/providers/scan_orchestrator_provider.dart';
import 'presentation/screens/experts/expert_directory_screen.dart';
import 'presentation/screens/kvk/kvk_scientist_console_sheet.dart';
import 'presentation/screens/ngo/leafguard_connect_screen.dart';
import 'presentation/screens/onboarding/app_startup_gate.dart';
import 'presentation/screens/onboarding/language_selection_screen.dart';
import 'presentation/screens/progression/disease_progression_screen.dart';
import 'presentation/screens/radar/predictive_radar_and_heatmap_screen.dart';
import 'presentation/screens/scanner/cure_guide_screen.dart';
import 'presentation/screens/scanner/smart_camera_screen.dart';
import 'presentation/widgets/florax_design_primitives.dart';
import 'presentation/widgets/state_selection_dropdown.dart';
import 'repositories/ecosystem_directory_repository.dart';
import 'repositories/firestore_ipm_and_scan_repository.dart';
import 'services/auth/auth_role_service.dart';
import 'services/notifications/outbreak_fcm_service.dart';
import 'services/sync/offline_media_sync_manager.dart';
import 'services/voice/vernacular_voice_service.dart';
import 'services/voice/voice_guide_service.dart';

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

    // 3. Bootstrap Firebase Core, Hardware Attestation (Play Integrity), and Unlimited SQLite Cache
    try {
      await FirebaseSecurityInitService().initialize();
    } catch (e) {
      debugPrint('[FloraX Init] FirebaseSecurityInitService error: $e');
    }

    // 4. Ensure Authenticated Session (Anonymous Farmer Login & User Profile Sync)
    try {
      final authRoleService = AuthRoleService();
      await authRoleService.ensureAuthenticatedSession();
    } catch (e) {
      debugPrint('[FloraX Init] AuthRoleService error: $e');
    }

    // 5. Start Persistent Offline Media Synchronization Manager
    try {
      final offlineSyncManager = OfflineMediaSyncManager();
      await offlineSyncManager.initialize();
    } catch (e) {
      debugPrint('[FloraX Init] OfflineMediaSyncManager error: $e');
    }

    // 6. Initialize Outbreak FCM Service (Permissions, Background Handlers & Topics)
    try {
      final fcmService = OutbreakFcmService();
      await fcmService.initialize();
    } catch (e) {
      debugPrint('[FloraX Init] OutbreakFcmService error: $e');
    }

    // 7. Mount Root Application with Global Riverpod Scope
    runApp(
      const ProviderScope(
        child: FloraXApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('[FloraX Uncaught Zone Error] $error\n$stackTrace');
  });
}

/// Root Application Widget Alias
typedef FloraXApp = FloraXMobileApp;

/// Root Application Widget
class FloraXMobileApp extends StatelessWidget {
  const FloraXMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeafGuard FloraX',
      debugShowCheckedModeBanner: false,
      theme: FloraXTheme.daylightTheme,
      home: const AppStartupGate(),
    );
  }
}

/// Primary Navigation Shell with Daylight Kisan 4-Tab Bottom Nav & Partner Portal Access
class FloraXMainShell extends ConsumerStatefulWidget {
  const FloraXMainShell({super.key});

  @override
  ConsumerState<FloraXMainShell> createState() => _FloraXMainShellState();
}

class _FloraXMainShellState extends ConsumerState<FloraXMainShell> {
  int _currentTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(outbreakFcmServiceProvider);
      // Pre-warm Firestore offline SQLite cache for rural zero-network resilience
      await ref.read(ecosystemDirectoryRepositoryProvider).warmOfflineCache();
    });
  }

  // The 4 Primary Farmer Navigation Screens (Accessible Bottom Navigation)
  // Tab 0: Scan (Camera Scanner & Diagnosis)
  // Tab 1: My Crops (Visual Recovery Tracker)
  // Tab 2: Alerts (Nearby Outbreak Map & Radar)
  // Tab 3: Experts (One-Tap Call & KVK Directory)
  final List<Widget> _screens = const [
    SmartCameraScreen(),
    DiseaseProgressionScreen(),
    PredictiveRadarAndHeatmapScreen(),
    ExpertDirectoryScreen(),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentTabIndex = index;
    });
  }

  void _handleVoiceIntentNavigation(FarmerVoiceIntentType intentType) {
    switch (intentType) {
      case FarmerVoiceIntentType.diagnoseSymptom:
        setState(() => _currentTabIndex = 0);
        break;
      case FarmerVoiceIntentType.inquireTreatment:
        setState(() => _currentTabIndex = 1);
        break;
      case FarmerVoiceIntentType.checkWeather:
        setState(() => _currentTabIndex = 2);
        break;
      case FarmerVoiceIntentType.contactKvkExpert:
        setState(() => _currentTabIndex = 3);
        break;
      case FarmerVoiceIntentType.ngoConnect:
        // Open Partner / NGO portal screen
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LeafGuardConnectScreen()),
        );
        break;
      case FarmerVoiceIntentType.unknown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(vernacularVoiceStateProvider);
    final auth = ref.watch(authRoleServiceProvider);
    final activeFarmerLang = ref.watch(activeFarmerLanguageProvider);
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;

    // Dynamic hands-free vernacular voice navigation trigger
    ref.listen<VernacularVoiceState>(vernacularVoiceStateProvider, (previous, next) {
      if (next.lastIntent != null && previous?.lastIntent != next.lastIntent) {
        _handleVoiceIntentNavigation(next.lastIntent!.intentType);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FloraXTheme.background,
      drawer: _buildAppDrawer(context, auth),
      appBar: FloraXTopUtilityBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        activeLang: activeFarmerLang.code,
        onLangChanged: (code) {
          final newLang = FarmerLanguage.fromCode(code);
          ref.read(activeFarmerLanguageProvider.notifier).state = newLang;
          ref.read(vernacularVoiceStateProvider.notifier).setLanguage(newLang.ttsLocale);
        },
      ),
      body: Stack(
        children: [
          // Active Screen
          IndexedStack(
            index: _currentTabIndex,
            children: _screens,
          ),

          // Docked Vernacular Voice Assistant Bar (Kisan Vani)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: FloraXDockedVoiceBar(voiceState: voiceState),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(strings),
    );
  }

  Widget _buildAppDrawer(BuildContext context, AuthRoleService auth) {
    final userRole = auth.currentRole;
    final user = auth.currentUser;
    final isAuthorizedInstitution = userRole == UserRole.kvkScientist || userRole == UserRole.admin;

    return Drawer(
      backgroundColor: FloraXTheme.cardSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              border: Border(bottom: BorderSide(color: FloraXTheme.borderDim, width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: FloraXTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.leaf, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'LeafGuard • FloraX',
                          style: TextStyle(
                            color: FloraXTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Daylight Kisan Edition • ICAR',
                          style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: userRole == UserRole.kvkScientist
                            ? const Color(0xFFFEF3C7)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: userRole == UserRole.kvkScientist
                              ? FloraXTheme.amberCaution
                              : FloraXTheme.primaryGreen,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        userRole.value.toUpperCase(),
                        style: TextStyle(
                          color: userRole == UserRole.kvkScientist
                              ? FloraXTheme.amberCaution
                              : FloraXTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user?.uid != null ? 'UID: ${user!.uid.substring(0, 8)}...' : 'Kisan Active',
                        style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'KISAN FIELD DIAGNOSTICS (पिकांचे निदान व उपचार)',
              style: TextStyle(color: FloraXTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          // Screen 1: Smart Leaf Scanner
          ListTile(
            leading: const Icon(LucideIcons.camera, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('1. Smart Leaf Scanner', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            selected: _currentTabIndex == 0,
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 0);
            },
          ),
          // Screen 2: Crop Diagnosis Result (Restored - Req 4)
          ListTile(
            leading: const Icon(LucideIcons.fileCheck, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('2. Crop Diagnosis Result', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('View AI pathology scan & hotspots', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 0);
            },
          ),
          // Screen 3: Step-by-Step Cure Guide (Restored - Req 4)
          ListTile(
            leading: const Icon(LucideIcons.clipboardList, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('3. Step-by-Step Cure Guide', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('Organic, cultural & chemical protocols', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12)),
            onTap: () async {
              Navigator.pop(context);
              final orchestrator = ref.read(scanOrchestratorProvider).valueOrNull;
              if (orchestrator != null && orchestrator.hasResult && orchestrator.ipmProtocol != null) {
                final topCandidate = orchestrator.diagnosticResult?.topCandidates.firstOrNull;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CureGuideScreen(
                      protocol: orchestrator.ipmProtocol!,
                      scanId: orchestrator.scanRecord?.scanId ?? 'FLX-ACTIVE',
                      initialVerificationStatus: orchestrator.scanRecord?.verificationStatus ?? VerificationStatus.aiVerified,
                      requiresKvkReview: orchestrator.scanRecord?.requiresKvkReview ?? false,
                      topConfidence: (topCandidate?.confidence ?? 0.9) * 100.0,
                      cropName: topCandidate != null ? topCandidate.labelId.split('_').first : 'Tomato',
                    ),
                  ),
                );
              } else {
                final protocols = await FirestoreIpmAndScanRepository.getOrLoadOfflineProtocols();
                final fallbackProtocol = protocols.values.isNotEmpty
                    ? protocols.values.first
                    : FirestoreIpmAndScanRepository.buildGenericSafeIpmProtocol('tomato_early_blight');
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CureGuideScreen(
                      protocol: fallbackProtocol,
                      scanId: 'SAMPLE-DEMO-GUIDE',
                      initialVerificationStatus: VerificationStatus.aiVerified,
                      requiresKvkReview: false,
                      topConfidence: 0.95,
                      cropName: 'Tomato',
                    ),
                  ),
                );
              }
            },
          ),
          // Screen 4: My Crops & Recovery Tracker
          ListTile(
            leading: const Icon(LucideIcons.sprout, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('4. My Crops & Recovery Tracker', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            selected: _currentTabIndex == 1,
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 1);
            },
          ),
          // Screen 5: Outbreak Alerts & Radar Map
          ListTile(
            leading: const Icon(LucideIcons.radar, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('5. Outbreak Alerts & Radar Map', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            selected: _currentTabIndex == 2,
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 2);
            },
          ),
          // Screen 6: Call an Agri Expert
          ListTile(
            leading: const Icon(LucideIcons.phoneCall, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('6. Call an Agri Expert (KVK)', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            selected: _currentTabIndex == 3,
            onTap: () {
              Navigator.pop(context);
              setState(() => _currentTabIndex = 3);
            },
          ),

          // Institutional Portals: Strictly hidden from ordinary farmer accounts (Req 4)
          if (isAuthorizedInstitution) ...[
            const Divider(color: FloraXTheme.borderDim, height: 28),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                'INSTITUTIONAL SPECIALIST PORTAL (अधिकृत संस्था)',
                style: TextStyle(color: FloraXTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.heartHandshake, color: Color(0xFF0369A1), size: 24),
              title: const Text('7. NGO & FPO Support Hub', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Grants, free soil tests & seed inputs', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeafGuardConnectScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.clipboardCheck, color: FloraXTheme.amberCaution, size: 24),
              title: const Text('8. KVK Scientist Console', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Clinical verification & advisory override', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KvkScientistConsoleSheet()),
                );
              },
            ),
          ],

          // Settings & Farmer Profile Section
          const Divider(color: FloraXTheme.borderDim, height: 28),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              'SETTINGS & PREFERENCES (सेटिंग्ज व पसंती)',
              style: TextStyle(color: FloraXTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.languages, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('Change Language / भाषा बदला', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('मराठी • हिन्दी • English', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(isSettingsMode: true)),
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.mapPin, color: FloraXTheme.primaryGreen, size: 24),
            title: const Text('Update State / राज्य बदला', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('Select from 28 States & 8 UTs', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _showStateUpdateDialog(context, auth);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: FloraXTheme.crimsonAlert, size: 24),
            title: const Text('Sign Out / बाहेर पडा', style: TextStyle(color: FloraXTheme.crimsonAlert, fontSize: 15, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AppStartupGate()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showStateUpdateDialog(BuildContext context, AuthRoleService auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.70,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: FloraXTheme.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Farm State / राज्य बदला',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select your agricultural region for location-relevant disease alerts:',
              style: TextStyle(fontSize: 13, color: FloraXTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            StateSelectionDropdown(
              selectedState: null,
              onStateSelected: (newState) async {
                final user = auth.currentUser;
                if (user != null) {
                  await auth.updateUserProfile(user.uid, {'state': newState});
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Farm State updated to $newState'),
                      backgroundColor: FloraXTheme.primaryGreen,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(FarmerLocalization strings) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: FloraXTheme.cardSurface,
        border: Border(top: BorderSide(color: FloraXTheme.borderDim, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavTab(
            index: 0,
            icon: LucideIcons.camera,
            label: strings.tabScan,
            isSelected: _currentTabIndex == 0,
          ),
          _buildNavTab(
            index: 1,
            icon: LucideIcons.sprout,
            label: strings.tabMyCrops,
            isSelected: _currentTabIndex == 1,
          ),
          _buildNavTab(
            index: 2,
            icon: LucideIcons.radar,
            label: strings.tabAlerts,
            isSelected: _currentTabIndex == 2,
          ),
          _buildNavTab(
            index: 3,
            icon: LucideIcons.phoneCall,
            label: strings.tabExperts,
            isSelected: _currentTabIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabSelected(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFDCFCE7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
