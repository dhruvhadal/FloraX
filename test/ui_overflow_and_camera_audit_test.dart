import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florax/domain/models/florax_models.dart';
import 'package:florax/presentation/screens/scanner/smart_camera_screen.dart';
import 'package:florax/presentation/screens/scanner/cure_guide_screen.dart';
import 'package:florax/presentation/screens/progression/disease_progression_screen.dart';
import 'package:florax/presentation/screens/radar/predictive_radar_and_heatmap_screen.dart';
import 'package:florax/presentation/screens/experts/expert_directory_screen.dart';
import 'package:florax/presentation/providers/scan_orchestrator_provider.dart';
import 'package:florax/presentation/widgets/florax_design_primitives.dart';
import 'package:florax/repositories/firestore_ipm_and_scan_repository.dart';
import 'package:florax/repositories/ecosystem_directory_repository.dart';
import 'package:florax/services/voice/voice_guide_service.dart';
import 'package:florax/services/weather/predictive_weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Overflow & Camera Retake Flow Audit (360dp width)', () {
    FlutterErrorDetails? caughtDetails;
    void Function(FlutterErrorDetails)? originalOnError;

    setUp(() {
      caughtDetails = null;
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });
    testWidgets('Retake Sheet renders without RenderFlex overflow at 360dp in English, Hindi, and Marathi',
        (tester) async {
      // Set surface size to narrow 360x640 Android device viewport
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (final lang in [FarmerLanguage.english, FarmerLanguage.hindi, FarmerLanguage.marathi]) {
        final container = ProviderContainer(
          overrides: [
            activeFarmerLanguageProvider.overrideWith((ref) => lang),
          ],
        );

        final qualityReport = ImageQualityReport(
          isAcceptable: false,
          blurScore: 42.0,
          brightnessScore: 120.0,
          leafCoveragePercent: 65.0,
          failureCode: 'blurry',
          failureReasons: [
            lang == FarmerLanguage.marathi
                ? 'फोटो अस्पष्ट/धुरकट आला — हात स्थिर ठेवा'
                : (lang == FarmerLanguage.hindi
                    ? 'फोटो धुंधला है — हाथ स्थिर रखें'
                    : 'Image blurry — hold camera steady')
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: SmartCameraScreen(),
            ),
          ),
        );

        // Put orchestrator into quality rejected state
        container.read(scanOrchestratorProvider.notifier).state = AsyncValue.data(
          ScanOrchestratorState(
            stage: ScanPipelineStage.qualityRejected,
            qualityReport: qualityReport,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Expect zero RenderFlex overflow errors
        expect(tester.takeException(), isNull,
            reason: 'RenderFlex overflow occurred in language: ${lang.name}');

        // Verify FarmerAudioPill and CTA button are safely rendered
        expect(find.byType(FarmerAudioPill), findsAtLeastNWidgets(1));
        expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('Concise plain-language trigger reason is displayed clearly for every failure code',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testCases = [
        {'code': 'tooDark', 'expectedEn': 'Too dark — move into daylight or turn on flash'},
        {'code': 'tooBright', 'expectedEn': 'Too bright — avoid harsh sunlight glare'},
        {'code': 'blurry', 'expectedEn': 'Image blurry — hold camera steady'},
        {'code': 'noLeafDetected', 'expectedEn': 'Leaf not detected clearly — frame one leaf in the center'},
        {'code': 'lowConfidenceOod', 'expectedEn': 'Object not recognized — frame a crop leaf clearly'},
      ];

      for (final tc in testCases) {
        final container = ProviderContainer(
          overrides: [
            activeFarmerLanguageProvider.overrideWith((ref) => FarmerLanguage.english),
          ],
        );

        final qualityReport = ImageQualityReport(
          isAcceptable: false,
          blurScore: 100.0,
          brightnessScore: 120.0,
          leafCoveragePercent: 50.0,
          failureCode: tc['code'] as String,
          failureReasons: [tc['expectedEn'] as String],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: SmartCameraScreen(),
            ),
          ),
        );

        container.read(scanOrchestratorProvider.notifier).state = AsyncValue.data(
          ScanOrchestratorState(
            stage: ScanPipelineStage.qualityRejected,
            qualityReport: qualityReport,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        if (caughtDetails != null) {
        debugPrint('>>> CAUGHT DETAILS EXCEPTION:\n${caughtDetails.toString()}');
      }
      expect(caughtDetails, isNull);
        // Verify concise plain-language reason is visible in the UI
        expect(find.text(tc['expectedEn'] as String), findsAtLeastNWidgets(1),
            reason: 'Expected trigger reason "${tc['expectedEn']}" not found for code ${tc['code']}');
      }
    });

    testWidgets('CureGuideScreen header renders cleanly with FarmerAudioPill at 360dp width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const dummyProtocol = IcarIpmProtocol(
        diseaseId: 'tomato_early_blight',
        diseaseName: {
          'en': 'Tomato Early Blight',
          'hi': 'टमाटर का अगेती झुलसा',
          'mr': 'टोमॅटोवरील करपा',
        },
        scientificName: 'Alternaria solani',
        category: DiseaseCategory.fungal,
        tier1Cultural: {
          'en': ['Remove infected leaves']
        },
        tier2Biological: {
          'en': ['Apply Trichoderma viride @ 5g/L']
        },
        tier3Chemical: ChemicalControlProtocol(
          formulationName: 'Mancozeb 75 WP',
          dosagePerLitre: '2g/L',
          waitingPeriodDays: 7,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeFarmerLanguageProvider.overrideWith((ref) => FarmerLanguage.marathi),
          scanVerificationStreamProvider('FLX-TEST-001').overrideWith((ref) => Stream.value(null)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CureGuideScreen(
              protocol: dummyProtocol,
              scanId: 'FLX-TEST-001',
              initialVerificationStatus: VerificationStatus.aiVerified,
              requiresKvkReview: false,
              topConfidence: 0.92,
              cropName: 'टोमॅटो',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (caughtDetails != null) {
        debugPrint('>>> CAUGHT DETAILS EXCEPTION:\n${caughtDetails.toString()}');
      }
      expect(caughtDetails, isNull);
      expect(find.byType(FarmerAudioPill), findsAtLeastNWidgets(1));
    });

    testWidgets('DiseaseProgressionScreen header renders cleanly at 360dp width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          activeFarmerLanguageProvider.overrideWith((ref) => FarmerLanguage.marathi),
          userPlantPlotsStreamProvider('farmer_anonymous').overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DiseaseProgressionScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (caughtDetails != null) {
        debugPrint('>>> CAUGHT DETAILS EXCEPTION:\n${caughtDetails.toString()}');
      }
      expect(caughtDetails, isNull);
    });

    testWidgets('PredictiveRadarScreen header renders cleanly at 360dp width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyWeather = WeatherRiskReport(
        geoHash5: 'te7u1',
        currentTempC: 28.0,
        currentHumidity: 65.0,
        currentPrecipitationMm: 0.0,
        aggregateOutbreakScore: 20,
        aggregateRiskLevel: WeatherRiskLevel.low,
        primaryThreatName: 'None',
        localizedAdvisory: const {'en': 'Normal weather', 'hi': 'सामान्य मौसम'},
        dailyForecasts: const [],
        syncedAt: DateTime(2026, 11, 22),
      );

      final container = ProviderContainer(
        overrides: [
          activeFarmerLanguageProvider.overrideWith((ref) => FarmerLanguage.hindi),
          verifiedOutbreakReportsStreamProvider(null).overrideWith((ref) => Stream.value([])),
          weatherRiskReportFutureProvider.overrideWith((ref) => Future.value(dummyWeather)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PredictiveRadarAndHeatmapScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (caughtDetails != null) {
        debugPrint('>>> CAUGHT DETAILS EXCEPTION:\n${caughtDetails.toString()}');
      }
      expect(caughtDetails, isNull);
    });

    testWidgets('ExpertDirectoryScreen header renders cleanly at 360dp width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          activeFarmerLanguageProvider.overrideWith((ref) => FarmerLanguage.marathi),
          farmerSecondOpinionRequestsStreamProvider('farmer_anonymous')
              .overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExpertDirectoryScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      if (caughtDetails != null) {
        debugPrint('>>> CAUGHT DETAILS EXCEPTION:\n${caughtDetails.toString()}');
      }
      expect(caughtDetails, isNull);
      expect(find.byType(FarmerAudioPill), findsAtLeastNWidgets(1));
    });
  });
}
