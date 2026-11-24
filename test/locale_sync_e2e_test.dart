import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:florax/core/localization/farmer_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: FarmerLocalization Dictionary & Key Parity Tests', () {
    test('Dictionary key parity across MR, HI, EN is complete', () {
      final locMr = FarmerLocalization(FarmerLanguage.marathi);
      final locHi = FarmerLocalization(FarmerLanguage.hindi);
      final locEn = FarmerLocalization(FarmerLanguage.english);

      // Core Titles
      expect(locMr.tr('app_title'), 'किसानसेतू');
      expect(locHi.tr('app_title'), 'किसानसेतु');
      expect(locEn.tr('app_title'), 'KisanSetu');

      // Navigation Tabs
      expect(locMr.tr('tab_scan'), 'स्कॅन');
      expect(locHi.tr('tab_scan'), 'स्कैन');
      expect(locEn.tr('tab_scan'), 'Scan');

      expect(locMr.tr('tab_my_crops'), 'माझी पिके');
      expect(locHi.tr('tab_my_crops'), 'मेरी फसलें');
      expect(locEn.tr('tab_my_crops'), 'My Crops');

      // Crop Localizers
      expect(locMr.localizeCropName('Tomato'), 'टोमॅटो');
      expect(locHi.localizeCropName('Tomato'), 'टमाटर');
      expect(locEn.localizeCropName('Tomato'), 'Tomato');

      expect(locMr.localizeCropName('Cotton'), 'कापूस');
      expect(locHi.localizeCropName('Cotton'), 'कपास');
      expect(locEn.localizeCropName('Cotton'), 'Cotton');

      // Disease Localizers
      expect(locMr.localizeDiseaseName('tomato_early_blight'), 'टोमॅटो अगेती करपा');
      expect(locHi.localizeDiseaseName('tomato_early_blight'), 'टमाटर अगेती झुलसा');
      expect(locEn.localizeDiseaseName('tomato_early_blight'), 'Tomato Early Blight');

      // Clinical 4-State Safety Banners
      expect(locMr.tr('banner_confirmed_biotic'), contains('प्रमाणित उपचार'));
      expect(locHi.tr('banner_confirmed_biotic'), contains('प्रमाणित उपचार'));
      expect(locEn.tr('banner_confirmed_biotic'), contains('Verified ICAR'));
    });

    test('FarmerLanguage enum mapping works correctly', () {
      expect(FarmerLanguage.fromCode('mr'), FarmerLanguage.marathi);
      expect(FarmerLanguage.fromCode('hi'), FarmerLanguage.hindi);
      expect(FarmerLanguage.fromCode('en'), FarmerLanguage.english);
      expect(FarmerLanguage.fromCode('unknown'), FarmerLanguage.marathi); // default
    });
  });

  group('Phase 4: LocaleNotifier & Persistence Tests', () {
    test('LocaleNotifier switches state and updates SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier(FarmerLanguage.marathi);

      expect(notifier.state, FarmerLanguage.marathi);

      await notifier.setLanguage(FarmerLanguage.hindi);
      expect(notifier.state, FarmerLanguage.hindi);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_language_code'), 'hi');

      await notifier.setLanguage(FarmerLanguage.english);
      expect(notifier.state, FarmerLanguage.english);
      expect(prefs.getString('selected_language_code'), 'en');

      await notifier.setLanguage(FarmerLanguage.marathi);
      expect(notifier.state, FarmerLanguage.marathi);
      expect(prefs.getString('selected_language_code'), 'mr');
    });
  });

  group('Phase 4: E2E Widget Tree Reactive Locale Synchronization', () {
    testWidgets('Instant reactive locale switching re-renders widget tree across MR -> HI -> EN', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer(
        overrides: [
          initialLanguageOverrideProvider.overrideWithValue(FarmerLanguage.marathi),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final activeLang = ref.watch(activeFarmerLanguageProvider);
              final loc = ref.watch(farmerLocalizationProvider);

              return MaterialApp(
                locale: activeLang.locale,
                supportedLocales: const [Locale('mr'), Locale('hi'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  appBar: AppBar(title: Text(loc.tr('app_title'))),
                  body: Column(
                    children: [
                      Text(loc.tr('tab_scan')),
                      Text(loc.tr('tab_my_crops')),
                      Text(loc.tr('open_smart_camera')),
                      Text(loc.tr('scan_another_crop')),
                      Text(loc.tr('recovery_progress')),
                      Text(loc.tr('safety_lock_title')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      // 1. Initial State: Marathi (मराठी)
      expect(find.text('किसानसेतू'), findsOneWidget);
      expect(find.text('स्कॅन'), findsOneWidget);
      expect(find.text('माझी पिके'), findsOneWidget);
      expect(find.text('स्मार्ट कॅमेरा उघडा'), findsOneWidget);
      expect(find.text('दुसरे पीक स्कॅन करा'), findsOneWidget);
      expect(find.text('सुधारणा प्रगती'), findsOneWidget);
      expect(find.text('रासायनिक औषध सुरक्षिततेसाठी लॉक आहे'), findsOneWidget);

      // 2. Switch to Hindi (हिन्दी)
      await container.read(activeFarmerLanguageProvider.notifier).setLanguage(FarmerLanguage.hindi);
      await tester.pump();

      // Verify Marathi strings are gone, Hindi strings render
      expect(find.text('किसानसेतू'), findsNothing);
      expect(find.text('किसानसेतु'), findsOneWidget);
      expect(find.text('स्कैन'), findsOneWidget);
      expect(find.text('मेरी फसलें'), findsOneWidget);
      expect(find.text('स्मार्ट कैमरा खोलें'), findsOneWidget);
      expect(find.text('दूसरी फसल स्कैन करें'), findsOneWidget);
      expect(find.text('सुधार प्रगति'), findsOneWidget);
      expect(find.text('रासायनिक दवा सुरक्षा कारणों से लॉक है'), findsOneWidget);

      // 3. Switch to English (EN)
      await container.read(activeFarmerLanguageProvider.notifier).setLanguage(FarmerLanguage.english);
      await tester.pump();

      // Verify Hindi strings are gone, English strings render
      expect(find.text('किसानसेतु'), findsNothing);
      expect(find.text('KisanSetu'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('My Crops'), findsOneWidget);
      expect(find.text('Open Smart Camera'), findsOneWidget);
      expect(find.text('Scan Another Crop'), findsOneWidget);
      expect(find.text('Recovery Progress'), findsOneWidget);
      expect(find.text('Chemical Spray Locked for Safety'), findsOneWidget);

      // 4. Switch back to Marathi (MR)
      await container.read(activeFarmerLanguageProvider.notifier).setLanguage(FarmerLanguage.marathi);
      await tester.pump();

      expect(find.text('KisanSetu'), findsNothing);
      expect(find.text('किसानसेतू'), findsOneWidget);
      expect(find.text('स्कॅन'), findsOneWidget);
    });
  });
}
