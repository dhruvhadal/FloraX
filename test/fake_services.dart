import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:florax/data/repositories/farmer_profile_repository.dart';
import 'package:florax/data/repositories/scan_history_repository.dart';
import 'package:florax/data/repositories/outbreak_radar_repository.dart';
import 'package:florax/data/repositories/expert_directory_repository.dart';
import 'package:florax/data/repositories/assistance_repository.dart';
import 'package:florax/data/repositories/crop_tracker_repository.dart';
import 'package:florax/services/utility/device_utility_service.dart';
import 'package:florax/domain/models/florax_models.dart';

class FakeFarmerProfileRepository implements FarmerProfileRepository {
  final Map<String, FarmerProfile> _registered;
  FarmerProfile? _current;

  FakeFarmerProfileRepository({
    Map<String, FarmerProfile>? initialRegistered,
    FarmerProfile? initialCurrent,
  })  : _registered = initialRegistered ??
            {
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
        _current = initialCurrent ??
            FarmerProfile(
              mobileE164: '+919876543210',
              fullName: 'Ramesh Patil',
              village: 'Pimpalgaon',
              district: 'Satara',
              state: 'Maharashtra',
              createdAt: DateTime(2026, 1, 1),
              lastLoginAt: DateTime(2026, 1, 1),
              isRegistered: true,
            );

  void clear() {
    _registered.clear();
    _current = null;
  }

  @override
  Future<FarmerProfile?> getLocalProfile() async => _current;

  @override
  Future<FarmerProfile> registerFarmer({
    required String fullName,
    required String mobile10Digits,
    String? village,
    String? district,
    String? state,
    String? pincode,
    String? preferredLanguage,
    bool notificationsEnabled = true,
    bool voiceGuidanceEnabled = true,
  }) async {
    final e164 = FarmerProfileRepository.formatMobileE164(mobile10Digits);
    if (_registered.containsKey(e164)) {
      throw DuplicateFarmerException('Farmer with mobile $e164 already registered.');
    }
    final profile = FarmerProfile(
      mobileE164: e164,
      fullName: fullName.trim(),
      village: village ?? 'Pimpalgaon',
      district: district ?? 'Satara',
      state: state ?? 'Maharashtra',
      pincode: pincode ?? '415001',
      preferredLanguage: preferredLanguage ?? 'mr',
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      isRegistered: true,
    );
    _registered[e164] = profile;
    _current = profile;
    return profile;
  }

  @override
  Future<FarmerProfile> loginFarmer({
    required String fullName,
    required String mobile10Digits,
  }) async {
    final e164 = FarmerProfileRepository.formatMobileE164(mobile10Digits);
    final existing = _registered[e164];
    if (existing == null) {
      throw UnregisteredFarmerException('No registered record found for mobile $e164.');
    }
    if (FarmerProfileRepository.normalizeNameKey(existing.fullName) !=
        FarmerProfileRepository.normalizeNameKey(fullName)) {
      throw CredentialMismatchException('Provided name does not match registered farmer account.');
    }
    _current = existing;
    return existing;
  }

  @override
  Future<FarmerProfile> loginOrRegisterPasswordless({
    required String rawMobile,
    String? fullName,
    String? village,
    String? district,
    String? state,
    String? pincode,
    String? preferredLanguage,
    bool notificationsEnabled = true,
    bool voiceGuidanceEnabled = true,
  }) async {
    final e164 = FarmerProfileRepository.formatMobileE164(rawMobile);
    _current = FarmerProfile(
      mobileE164: e164,
      fullName: fullName ?? 'Ramesh Patil',
      village: village ?? 'Pimpalgaon',
      district: district ?? 'Satara',
      state: state ?? 'Maharashtra',
      createdAt: DateTime(2026, 1, 1),
      lastLoginAt: DateTime.now(),
      isRegistered: true,
    );
    _registered[e164] = _current!;
    return _current!;
  }

  @override
  Future<void> saveProfile(FarmerProfile profile) async {
    _current = profile;
  }

  @override
  Future<FarmerProfile?> getProfile(String rawMobile) async => _current;

  @override
  Stream<FarmerProfile?> watchProfile(String rawMobile) => Stream.value(_current);

  @override
  Future<void> updatePreferences({
    required String rawMobile,
    String? language,
    bool? notificationsEnabled,
    bool? voiceGuidanceEnabled,
  }) async {}

  @override
  Future<void> logout() async {
    _current = null;
  }
}

class FakeScanHistoryRepository implements ScanHistoryRepository {
  final List<ScanLogEntry> _logs = [
    ScanLogEntry(
      flxScanId: 'TEST-SCAN-001',
      farmerMobile: '+919876543210',
      canonicalId: 'tomato_early_blight',
      crop: 'Tomato',
      confidence: 0.94,
      normalizedEntropy: 0.22,
      latitude: 19.9975,
      longitude: 73.7898,
      geoHash: 'te7u8k',
      safetyState: ClinicalSafetyState.confirmedBiotic,
      verificationStatus: VerificationStatus.aiVerified,
      lesionAreaPercentage: 12.5,
      severityGrade: SeverityGrade.mild,
      timestamp: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<void> saveScanLog(ScanLogEntry entry) async {
    _logs.insert(0, entry);
  }

  @override
  Future<List<ScanLogEntry>> getLocalScanLogs({String? farmerMobile, int limit = 20}) async => _logs;

  @override
  Stream<List<ScanLogEntry>> watchRecentScans({String? farmerMobile, int limit = 20}) => Stream.value(_logs);

  @override
  Future<ScanLogEntry?> getScanById(String flxScanId) async => _logs.first;

  @override
  Future<List<ScanLogEntry>> getScansByCrop(String crop, {int limit = 10}) async => _logs;
}

class FakeOutbreakRadarRepository implements OutbreakRadarRepository {
  @override
  Stream<List<RegionalOutbreakAlert>> watchRegionalOutbreaks({String? state, String? district}) =>
      Stream.value([]);

  @override
  Future<List<RegionalOutbreakAlert>> getOutbreaksNearLocation({
    required double latitude,
    required double longitude,
    double radiusKm = 50.0,
    String? crop,
  }) async => [];

  @override
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) => 10.0;
}

class FakeExpertDirectoryRepository implements ExpertDirectoryRepository {
  @override
  Stream<List<VerifiedExpert>> watchExperts({String? discipline, String? district}) =>
      Stream.value([]);

  @override
  Future<VerifiedExpert?> getExpertById(String expertId) async => null;

  @override
  Future<void> submitConsultation(ConsultationRequest request) async {}

  @override
  Future<List<ConsultationRequest>> getLocalConsultations({String? farmerMobile}) async => [];

  @override
  Stream<List<ConsultationRequest>> watchFarmerConsultations(String farmerMobile) =>
      Stream.value([]);
}

class FakeAssistanceRepository implements AssistanceRepository {
  final List<AssistanceApplication> _applications = [];

  @override
  Future<void> submitApplication(AssistanceApplication app) async {
    if (app.category != AssistanceCategory.ngo) {
      throw UnsupportedError(
        'Government schemes and subsidies (${app.category.name}) are strictly informational records. Only NGO Support applications can be submitted.',
      );
    }
    _applications.add(app);
  }

  @override
  Future<List<AssistanceApplication>> getLocalApplications({String? farmerMobile}) async =>
      List.from(_applications);

  @override
  Stream<List<AssistanceApplication>> watchFarmerApplications(String farmerMobile) =>
      Stream.value(List.from(_applications));

  @override
  Future<List<AidProgram>> getAvailablePrograms({
    AssistanceCategory? category,
    String? state,
  }) async {
    final progs = AssistanceRepository.seededPrograms;
    if (category == null) return progs;
    return progs.where((p) => p.category == category).toList();
  }

  @override
  Future<List<NgoPartner>> searchNgoDirectory({
    String? query,
    String? district,
    String? pinCode,
  }) async => AssistanceRepository.seededNgos;
}

class FakeDeviceUtilityService implements DeviceUtilityService {
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  void setSpeaking(bool val) => _speaking = val;

  @override
  Future<bool> isCameraGranted() async => true;

  @override
  Future<bool> isLocationGranted() async => true;

  @override
  Future<bool> isMicrophoneGranted() async => true;

  @override
  Future<Map<Permission, PermissionStatus>> requestFieldScanningPermissions() async => {
    Permission.camera: PermissionStatus.granted,
    Permission.location: PermissionStatus.granted,
    Permission.microphone: PermissionStatus.granted,
  };

  @override
  Future<Position?> getCurrentLocation() async => null;

  @override
  Future<void> speakVernacular(String text, {String langCode = 'mr'}) async {
    _speaking = true;
  }

  @override
  Future<void> stopSpeaking() async {
    _speaking = false;
  }

  @override
  Future<void> stopAllAudio() async {
    _speaking = false;
  }

  @override
  Future<bool> initializeSpeech() async => true;

  @override
  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    String langCode = 'mr',
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<LocationWeatherSnapshot> fetchWeatherForLocation({
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async =>
      LocationWeatherSnapshot(
        temperatureC: 28.0,
        relativeHumidity: 65.0,
        precipitationMm: 0.0,
        windSpeedKmh: 8.0,
        shouldDelayChemicalSpray: false,
        sprayAdvisoryReason: 'Good conditions for organic spray',
        fetchedAt: DateTime.now(),
      );
}

class FakeCropTrackerRepository implements CropTrackerRepository {
  final List<CropPlotEntry> _plots = [];
  final StreamController<List<CropPlotEntry>> _controller =
      StreamController<List<CropPlotEntry>>.broadcast();

  List<CropPlotEntry> get plots => List.unmodifiable(_plots);

  void addPlot(CropPlotEntry plot) {
    _plots.add(plot);
    _controller.add(List.from(_plots));
  }

  void clearPlots() {
    _plots.clear();
    _controller.add([]);
  }

  @override
  Future<List<CropPlotEntry>> getCropPlots({String? farmerMobile}) async =>
      List.from(_plots);

  @override
  Stream<List<CropPlotEntry>> watchCropPlots({String? farmerMobile}) async* {
    yield List.from(_plots);
    yield* _controller.stream;
  }

  @override
  Future<CropPlotEntry?> getCropPlotById(String cropId, {String? farmerMobile}) async {
    for (final p in _plots) {
      if (p.cropId == cropId) return p;
    }
    return null;
  }

  @override
  Future<void> recordScanForCropDiary(ScanResult result, {String? targetCropId}) async {
    if (result.safetyState == SafetyState.oodRejected ||
        result.canonicalId.toLowerCase().contains('not_a_leaf') ||
        result.normalizedEntropy > 0.85) {
      return;
    }

    final species = CropTrackerRepository.detectCropSpecies(result.crop, result.canonicalId);
    final isHealthy = result.canonicalId.toLowerCase().endsWith('_healthy');
    final now = result.timestamp;

    int targetIndex = -1;
    if (targetCropId != null && targetCropId.isNotEmpty) {
      targetIndex = _plots.indexWhere((p) => p.cropId == targetCropId);
    }
    if (targetIndex < 0) {
      targetIndex = _plots.indexWhere((p) => p.cropSpecies == species);
    }

    if (targetIndex >= 0) {
      final targetPlot = _plots[targetIndex];
      final baseline = targetPlot.baselineLesionPercent > 0
          ? targetPlot.baselineLesionPercent
          : (targetPlot.latestLesionPercent > 0 ? targetPlot.latestLesionPercent : 25.0);

      double newRecovery;
      bool improving;
      String status;

      if (isHealthy) {
        newRecovery = 1.0;
        improving = true;
        status = 'healthy';
      } else {
        final currentLesion = result.lesionAreaPercentage > 0
            ? result.lesionAreaPercentage
            : (result.confidence * 20.0);

        if (currentLesion <= baseline) {
          final reductionRatio = (baseline - currentLesion) / (baseline == 0 ? 1 : baseline);
          newRecovery = (0.5 + 0.5 * reductionRatio).clamp(0.0, 1.0);
          improving = true;
          status = 'improving';
        } else {
          final increaseRatio = (currentLesion - baseline) / 100.0;
          newRecovery = (0.5 - 0.5 * increaseRatio).clamp(0.0, 1.0);
          improving = false;
          status = 'needsAttention';
        }
      }

      final updatedPlot = targetPlot.copyWith(
        condition: CropTrackerRepository.formatCondition(result.canonicalId),
        canonicalId: result.canonicalId,
        recoveryPercent: newRecovery,
        lastScannedAt: now,
        scanCount: targetPlot.scanCount + 1,
        isImproving: improving,
        status: status,
        lastAction: isHealthy
            ? 'Canopy verified healthy & clear of foliar lesions'
            : (improving
                ? 'Follow-up foliar inspection: Symptoms subsiding'
                : 'Foliar inspection alert: Increased lesion activity detected'),
        imagePath: result.imageUrl,
        latestLesionPercent: result.lesionAreaPercentage,
      );

      _plots[targetIndex] = updatedPlot;
      _controller.add(List.from(_plots));
    } else {
      final cropId = 'crop_${species}_${now.millisecondsSinceEpoch}';
      final initialRecovery = isHealthy
          ? 1.0
          : (1.0 - (result.lesionAreaPercentage / 100.0)).clamp(0.2, 0.85);
      final improving = isHealthy || initialRecovery >= 0.5;

      final newPlot = CropPlotEntry(
        cropId: cropId,
        cropSpecies: species,
        cropName: CropTrackerRepository.formatCropName(species),
        variety: 'ICAR Protocol Tracked Plot',
        condition: CropTrackerRepository.formatCondition(result.canonicalId),
        canonicalId: result.canonicalId,
        recoveryPercent: initialRecovery,
        firstScannedAt: now,
        lastScannedAt: now,
        scanCount: 1,
        isImproving: improving,
        status: isHealthy ? 'healthy' : (improving ? 'improving' : 'needsAttention'),
        lastAction: isHealthy
            ? 'Initial baseline: Clean canopy verified'
            : 'Initial baseline scan recorded • Diagnostic treatment initiated',
        imagePath: result.imageUrl,
        baselineLesionPercent: result.lesionAreaPercentage,
        latestLesionPercent: result.lesionAreaPercentage,
        baselineConfidence: result.confidence,
        farmerMobile: result.farmerMobile,
      );

      _plots.insert(0, newPlot);
      _controller.add(List.from(_plots));
    }
  }
}

final testProviderOverrides = [
  farmerProfileRepositoryProvider.overrideWithValue(FakeFarmerProfileRepository()),
  scanHistoryRepositoryProvider.overrideWithValue(FakeScanHistoryRepository()),
  outbreakRadarRepositoryProvider.overrideWithValue(FakeOutbreakRadarRepository()),
  expertDirectoryRepositoryProvider.overrideWithValue(FakeExpertDirectoryRepository()),
  assistanceRepositoryProvider.overrideWithValue(FakeAssistanceRepository()),
  deviceUtilityServiceProvider.overrideWithValue(FakeDeviceUtilityService()),
  cropTrackerRepositoryProvider.overrideWithValue(FakeCropTrackerRepository()),
];
