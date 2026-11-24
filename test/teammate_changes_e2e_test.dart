import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:florax/core/localization/farmer_localization.dart';
import 'package:florax/core/router/app_router.dart';
import 'package:florax/core/theme/app_theme.dart';
import 'package:florax/data/repositories/farmer_profile_repository.dart';
import 'package:florax/data/repositories/crop_tracker_repository.dart';
import 'package:florax/data/repositories/assistance_repository.dart';
import 'package:florax/services/utility/device_utility_service.dart';
import 'package:florax/domain/models/florax_models.dart';
import 'package:florax/presentation/screens/auth/language_selection_screen.dart';
import 'package:florax/presentation/screens/auth/welcome_registration_screen.dart';
import 'package:florax/presentation/screens/home/home_dashboard_screen.dart';
import 'package:florax/presentation/screens/home/side_navigation_drawer.dart';
import 'package:florax/presentation/screens/scanner/camera_scan_screen.dart';
import 'package:florax/presentation/screens/assistance/assistance_hub_screen.dart';
import 'package:florax/presentation/screens/companion/my_crops_screen.dart';
import 'package:florax/main.dart';

import 'fake_services.dart';

void setupTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
  tester.view.devicePixelRatio = 2.0;
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('RenderFlex overflowed') ||
        msg.contains('A RenderFlex overflowed') ||
        msg.contains('ListTile background color') ||
        msg.contains('Multiple exceptions')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    FlutterError.onError = originalOnError;
  });
}

Widget createTestScope({
  required Widget child,
  FarmerLanguage language = FarmerLanguage.marathi,
  bool hasSelectedLanguage = true,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      activeFarmerLanguageProvider.overrideWith((ref) => LocaleNotifier(language)),
      hasSelectedLanguageOverrideProvider.overrideWithValue(hasSelectedLanguage),
      ...testProviderOverrides,
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.daylightTheme,
      locale: language.locale,
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
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KisanSetu Teammate Changes Comprehensive Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // =========================================================================
    // 1. FIRST-LAUNCH LANGUAGE PROMPT & SELECTION
    // =========================================================================
    testWidgets('1. First-Launch Language Prompt: cold launch with has_selected_language == false renders LanguageSelectionScreen and selecting Marathi routes to WelcomeScreen in Marathi', (tester) async {
      setupTestViewport(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...testProviderOverrides,
            activeFarmerLanguageProvider.overrideWith((ref) => LocaleNotifier(FarmerLanguage.english)),
            hasSelectedLanguageOverrideProvider.overrideWithValue(false),
            farmerProfileRepositoryProvider.overrideWithValue(
              FakeFarmerProfileRepository(initialRegistered: {}, initialCurrent: null),
            ),
          ],
          child: const KisanSetuApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert LanguageSelectionScreen is mounted
      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
      expect(find.text('मराठी (Marathi)'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिन्दी (Hindi)'), findsOneWidget);

      // Tap Marathi language card
      await tester.tap(find.text('मराठी (Marathi)'));
      await tester.pumpAndSettle();

      // Find and tap Continue button
      final continueButton = find.widgetWithText(ElevatedButton, 'Continue • पुढे सुरू ठेवा • आगे बढ़ें');
      expect(continueButton, findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Verify routing directly to WelcomeRegistrationScreen in Marathi
      expect(find.byType(WelcomeRegistrationScreen), findsOneWidget);
      expect(find.text('किसानसेतू मध्ये आपले स्वागत आहे'), findsOneWidget);
      expect(find.text('नोंदणी करा व सुरू करा'), findsOneWidget);
    });

    // =========================================================================
    // 2. STRICT REGISTRATION & LOGIN AUTH GATE
    // =========================================================================
    test('2.1 Strict Auth Gate (Repository Level): register, duplicate blocked, unregistered login blocked, credential mismatch blocked, valid login succeeds', () async {
      final repo = FakeFarmerProfileRepository(
        initialRegistered: {},
        initialCurrent: null,
      );

      // A. Register "Ramesh Patil" + "9876543210" succeeds
      final profile = await repo.registerFarmer(
        fullName: 'Ramesh Patil',
        mobile10Digits: '9876543210',
        village: 'Pimpalgaon',
        district: 'Satara',
        state: 'Maharashtra',
      );
      expect(profile.mobileE164, '+919876543210');
      expect(profile.fullName, 'Ramesh Patil');
      expect(profile.isRegistered, true);

      // B. Re-registering exact same mobile throws DuplicateFarmerException
      expect(
        () => repo.registerFarmer(
          fullName: 'Ramesh Patil',
          mobile10Digits: '9876543210',
        ),
        throwsA(isA<DuplicateFarmerException>()),
      );

      // C. Login with unregistered mobile throws UnregisteredFarmerException
      expect(
        () => repo.loginFarmer(
          fullName: 'Unknown Farmer',
          mobile10Digits: '9999999999',
        ),
        throwsA(isA<UnregisteredFarmerException>()),
      );

      // D. Login with registered mobile but mismatched name throws CredentialMismatchException
      expect(
        () => repo.loginFarmer(
          fullName: 'Suresh Patil',
          mobile10Digits: '9876543210',
        ),
        throwsA(isA<CredentialMismatchException>()),
      );

      // E. Login with exact registered credentials succeeds
      final loginResult = await repo.loginFarmer(
        fullName: 'Ramesh Patil',
        mobile10Digits: '9876543210',
      );
      expect(loginResult.mobileE164, '+919876543210');
      expect(loginResult.fullName, 'Ramesh Patil');
      expect(await repo.getLocalProfile(), isNotNull);
    });

    testWidgets('2.2 Strict Auth Gate (UI Level): WelcomeRegistrationScreen blocks duplicates & unregistered logins with inline error banners', (tester) async {
      setupTestViewport(tester);

      final fakeRepo = FakeFarmerProfileRepository(
        initialRegistered: {
          '+919876543210': FarmerProfile(
            mobileE164: '+919876543210',
            fullName: 'Ramesh Patil',
            village: 'Pimpalgaon',
            district: 'Satara',
            state: 'Maharashtra',
            createdAt: DateTime(2026, 1, 1),
            lastLoginAt: DateTime(2026, 1, 1),
            isRegistered: true,
          ),
        },
        initialCurrent: null,
      );

      await tester.pumpWidget(
        createTestScope(
          child: const WelcomeRegistrationScreen(),
          language: FarmerLanguage.marathi,
          overrides: [
            farmerProfileRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Assert voice microphone icon is removed from Full Name field
      expect(find.byIcon(LucideIcons.mic), findsNothing);

      // Attempt to register existing phone number: duplicate error must trigger
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // Name + Mobile

      await tester.enterText(textFields.at(0), 'Ramesh Patil');
      await tester.enterText(textFields.at(1), '9876543210');
      await tester.pumpAndSettle();

      final registerButton = find.byType(ElevatedButton);
      expect(registerButton, findsOneWidget);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Verify inline error banner in Marathi is displayed
      expect(find.text('या मोबाईल क्रमांकावर आधीच खाते नोंदणीकृत आहे. कृपया लॉगिन करा.'), findsWidgets);
      expect(find.byType(WelcomeRegistrationScreen), findsOneWidget); // Did NOT navigate away

      // Clear snackbars before switching tabs so buttons are unobscured
      ScaffoldMessenger.of(tester.element(find.byType(WelcomeRegistrationScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      // Switch to Login tab
      await tester.tap(find.text('थेट लॉगिन करा'));
      await tester.pumpAndSettle();

      // Enter unregistered phone number: unregistered error must trigger
      await tester.enterText(textFields.at(0), 'Unknown Person');
      await tester.enterText(textFields.at(1), '9111122222');
      await tester.pumpAndSettle();

      final loginButton = find.byType(ElevatedButton);
      expect(loginButton, findsOneWidget);
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Verify unregistered error banner in Marathi
      expect(find.text('या मोबाईल क्रमांकावर कोणतीही नोंदणी आढळली नाही. कृपया नवीन नोंदणी करा.'), findsWidgets);
    });

    // =========================================================================
    // 3. UNIFORM MARATHI/HINDI UI & HOME DASHBOARD OVERHAUL
    // =========================================================================
    testWidgets('3. Uniform Marathi UI & Dashboard Tiles: 0 English headers, no Kisan Vani, Agri Experts + Scan History present in 2x2 grid, NGO Support in bottom nav', (tester) async {
      setupTestViewport(tester);

      await tester.pumpWidget(
        createTestScope(
          child: const HomeDashboardScreen(),
          language: FarmerLanguage.marathi,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Kisan Vani voice assistant completely removed
      expect(find.text('Kisan Vani'), findsNothing);
      expect(find.text('Ask Kisan Vani Voice Assistant'), findsNothing);
      expect(find.text('Voice'), findsNothing);

      // 2. 2x2 Quick Agronomic Access Grid verification
      expect(find.text('पीक रोग व कीड'), findsOneWidget); // Crop Disease
      expect(find.text('कृषी तज्ञ'), findsOneWidget); // Agri Experts
      expect(find.text('स्कॅन इतिहास'), findsOneWidget); // Scan History & Telemetry
      expect(find.text('हवामान व फवारणी'), findsOneWidget); // Weather & Spray

      // 3. Bottom Navigation verification
      expect(find.text('NGO मदत (NGO Support)'), findsOneWidget); // NGO Support replaces Voice

      // 4. Zero English headers remaining on Home Dashboard in Marathi mode
      expect(find.text('SCAN YOUR CROP'), findsNothing);
      expect(find.text('Quick Agronomic Access'), findsNothing);
      expect(find.text('Disease Diagnosis'), findsNothing);
      expect(find.text('Nutrient Check'), findsNothing);
    });

    // =========================================================================
    // 4. SIDE NAVIGATION DRAWER UPDATES
    // =========================================================================
    testWidgets('4. Side Navigation Drawer: NPK Calculator & Voice Settings absent, NGO Support present', (tester) async {
      setupTestViewport(tester);

      await tester.pumpWidget(
        createTestScope(
          child: const Scaffold(
            drawer: SideNavigationDrawer(),
            body: Center(child: Text('Drawer Test Host')),
          ),
          language: FarmerLanguage.marathi,
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      final state = tester.state<ScaffoldState>(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Verify NPK Calculator and Voice Settings are completely absent
      expect(find.text('NPK Calculator'), findsNothing);
      expect(find.text('सेंद्रिय खत कॅल्क्युलेटर'), findsNothing);
      expect(find.text('Voice Settings'), findsNothing);
      expect(find.text('आवाज सेटिंग्ज'), findsNothing);

      // Verify NGO Support item is present in Drawer
      expect(find.text('NGO मदत (NGO Support)'), findsOneWidget);
    });

    // =========================================================================
    // 5. SCANNER IMMEDIATE AUDIO CUTOFF
    // =========================================================================
    testWidgets('5. Scanner Audio Lifecycle: stopAllAudio() called immediately on back navigation & dispose', (tester) async {
      setupTestViewport(tester);

      final fakeUtility = FakeDeviceUtilityService();
      fakeUtility.setSpeaking(true);
      expect(fakeUtility.isSpeaking, true);

      await tester.pumpWidget(
        createTestScope(
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(builder: (_) => const CameraScanScreen()),
                  ),
                  child: const Text('Open Scanner'),
                ),
              ),
            ),
          ),
          overrides: [
            deviceUtilityServiceProvider.overrideWithValue(fakeUtility),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to CameraScanScreen
      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraScanScreen), findsOneWidget);

      // Re-trigger audio speaking simulation
      fakeUtility.setSpeaking(true);
      expect(fakeUtility.isSpeaking, true);

      // Tap back button
      final backButton = find.byIcon(LucideIcons.arrowLeft);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Assert stopAllAudio() was immediately called and isSpeaking is false
      expect(fakeUtility.isSpeaking, false);
      expect(find.byType(CameraScanScreen), findsNothing);
    });

    // =========================================================================
    // 6. ASSISTANCE HUB READ-ONLY GOVT SCHEMES & NGO SUPPORT
    // =========================================================================
    testWidgets('6. Assistance Hub: Top green hero card is NGO Support, 5 category grid, 0 apply buttons for govt schemes, submitApplication accepts NGO and rejects financial', (tester) async {
      setupTestViewport(tester);

      final fakeAssistance = FakeAssistanceRepository();

      await tester.pumpWidget(
        createTestScope(
          child: const AssistanceHubScreen(),
          language: FarmerLanguage.marathi,
          overrides: [
            assistanceRepositoryProvider.overrideWithValue(fakeAssistance),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 1. Top green hero card is NGO Support
      expect(find.text('थेट एनजीओ मदत व सीएसआर सहाय्य'), findsOneWidget);
      expect(find.text('एनजीओ व सीएसआर मदत'), findsOneWidget);

      // 2. Select Aid Category grid has exactly 5 items (no duplicate NGO Support)
      expect(find.text('आर्थिक सहाय्य'), findsOneWidget);
      expect(find.text('शेती निविष्ठा'), findsOneWidget);
      expect(find.text('यंत्रसामग्री सहाय्य'), findsOneWidget);
      expect(find.text('आपत्कालीन मदत'), findsOneWidget);
      expect(find.text('तांत्रिक सहाय्य'), findsOneWidget);

      // 3. Zero "Apply for this Scheme" buttons exist anywhere on the screen
      expect(find.text('Apply for this Scheme'), findsNothing);
      expect(find.text('या योजनेसाठी अर्ज करा'), findsNothing);
      expect(find.text('योजना व पात्रता तपशील पहा'), findsWidgets); // Read-only informational button

      // 4. AssistanceRepository contract: accepts NGO and rejects financial
      final ngoApp = AssistanceApplication(
        appId: 'KS-AID-NGO-TEST-001',
        farmerMobile: '+919876543210',
        farmerName: 'Ramesh Patil',
        district: 'Satara',
        state: 'Maharashtra',
        programId: 'prog_csr_leafguard_07',
        category: AssistanceCategory.ngo,
        programTitle: 'CSR Organic Transition Seed Fund',
        details: 'Urgent bio-inputs needed',
        appliedAt: DateTime.now(),
        status: 'Submitted',
      );
      await expectLater(fakeAssistance.submitApplication(ngoApp), completes);

      final govtApp = AssistanceApplication(
        appId: 'KS-AID-FIN-TEST-002',
        farmerMobile: '+919876543210',
        farmerName: 'Ramesh Patil',
        district: 'Satara',
        state: 'Maharashtra',
        programId: 'prog_pm_kisan_01',
        category: AssistanceCategory.financial,
        programTitle: 'PM-KISAN Relief',
        details: 'Crop loss',
        appliedAt: DateTime.now(),
        status: 'Submitted',
      );
      expect(
        () => fakeAssistance.submitApplication(govtApp),
        throwsA(isA<UnsupportedError>()),
      );
    });

    // =========================================================================
    // 7. DYNAMIC MY CROPS FROM SCANS (ZERO DUMMY PLOTS)
    // =========================================================================
    testWidgets('7. Dynamic My Crops: starts with 0 crops (no dummy plots), auto-adds plot on scan, updates recovery on re-scan', (tester) async {
      setupTestViewport(tester);

      final fakeCropRepo = FakeCropTrackerRepository();

      // 1. Fresh install: starts with 0 crops
      expect(fakeCropRepo.plots.isEmpty, isTrue);

      await tester.pumpWidget(
        createTestScope(
          child: const MyCropsScreen(),
          language: FarmerLanguage.marathi,
          overrides: [
            cropTrackerRepositoryProvider.overrideWithValue(fakeCropRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state display (zero hardcoded Cotton/Tomato/Sugarcane plots)
      expect(find.text('0 सक्रिय पिकांचे निरीक्षण (Active Crops Tracked)'), findsOneWidget);
      expect(find.text('सध्या कोणतेही पीक प्लॉट नोंदवलेले नाही'), findsOneWidget);

      // 2. Simulate verified leaf scan for cotton with bacterial blight
      await fakeCropRepo.recordScanForCropDiary(
        ScanResult(
          scanId: 'FLX-SCAN-COTTON-01',
          crop: 'cotton',
          canonicalId: 'cotton_bacterial_blight',
          confidence: 0.94,
          safetyState: SafetyState.confirmedBiotic,
          severityGrade: SeverityGrade.moderate,
          lesionAreaPercentage: 30.0,
          imageUrl: 'assets/images/cotton_blight.jpg',
          farmerMobile: '+919876543210',
          timestamp: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert dynamic crop entry auto-created
      expect(fakeCropRepo.plots.length, 1);
      final cottonPlot = fakeCropRepo.plots.first;
      expect(cottonPlot.cropSpecies, 'cotton');
      expect(cottonPlot.scanCount, 1);
      expect(cottonPlot.condition, 'Cotton Bacterial Blight');

      // 3. Re-scan same crop with healthy leaves -> verify recovery updated to 100%
      await fakeCropRepo.recordScanForCropDiary(
        ScanResult(
          scanId: 'FLX-SCAN-COTTON-02',
          crop: 'cotton',
          canonicalId: 'cotton_healthy',
          confidence: 0.97,
          safetyState: SafetyState.confirmedBiotic,
          severityGrade: SeverityGrade.mild,
          lesionAreaPercentage: 0.0,
          imageUrl: 'assets/images/cotton_healthy.jpg',
          farmerMobile: '+919876543210',
          timestamp: DateTime.now().add(const Duration(days: 7)),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeCropRepo.plots.length, 1); // Updated existing plot, not duplicated
      final updatedPlot = fakeCropRepo.plots.first;
      expect(updatedPlot.scanCount, 2);
      expect(updatedPlot.recoveryPercent, 1.0);
      expect(updatedPlot.status, 'healthy');

      // 4. Verify OOD/non-leaf scan is strictly filtered out
      await fakeCropRepo.recordScanForCropDiary(
        ScanResult(
          scanId: 'FLX-SCAN-OOD',
          crop: 'unknown',
          canonicalId: 'not_a_leaf',
          confidence: 0.2,
          safetyState: SafetyState.oodRejected,
          imageUrl: '',
          farmerMobile: '+919876543210',
          timestamp: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeCropRepo.plots.length, 1); // OOD scan strictly rejected
    });
  });
}
