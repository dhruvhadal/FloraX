import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../domain/models/florax_models.dart';
import '../../../services/vision/hybrid_gradcam_client.dart';
import '../../../services/vision/tflite_isolate_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../providers/scan_orchestrator_provider.dart';
import '../../widgets/florax_design_primitives.dart';
import '../../widgets/gradcam_overlay_painter.dart';
import '../experts/expert_directory_screen.dart';
import 'cure_guide_screen.dart';

/// Screen 1 (Smart Leaf Scanner) & Screen 2 (Crop Diagnosis Result)
class SmartCameraScreen extends ConsumerStatefulWidget {
  final String? initialPlantTag;
  const SmartCameraScreen({super.key, this.initialPlantTag});

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;
  bool _isTorchOn = false;
  late String _selectedPlantTag;

  // Screen 2 State: 1-Tap Pill Toggle (Leaf Photo vs Damage Spot AI)
  bool _showHeatmapOverlay = true;

  @override
  void initState() {
    super.initState();
    _selectedPlantTag = widget.initialPlantTag ?? 'PLANT-TOM-01';
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        debugPrint('[FloraX Camera] No physical camera hardware detected.');
        return;
      }

      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
      });
    } catch (e) {
      debugPrint('[FloraX Camera ERROR] Camera initialization failed: $e');
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final newMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      debugPrint('[FloraX Camera] Torch toggle failed: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    final orchestratorState = ref.read(scanOrchestratorProvider).value;
    final activeLang = ref.read(activeFarmerLanguageProvider);
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        (orchestratorState?.isProcessing ?? false)) {
      return;
    }

    try {
      final XFile photoFile = await _cameraController!.takePicture();
      final Uint8List rawBytes = await photoFile.readAsBytes();

      await ref.read(scanOrchestratorProvider.notifier).executeScanPipeline(
            rawBytes: rawBytes,
            plantTagId: _selectedPlantTag,
            cropType: 'Tomato',
            languageOverride: activeLang.code,
          );
    } catch (e, stackTrace) {
      debugPrint('[FloraX Pipeline ERROR] Capture or inference failed: $e\n$stackTrace');
    }
  }

  void _dismissDiagnosticResult() {
    ref.read(scanOrchestratorProvider.notifier).reset();
    _cameraController?.resumePreview();
  }

  @override
  Widget build(BuildContext context) {
    final orchestratorState =
        ref.watch(scanOrchestratorProvider).value ?? const ScanOrchestratorState();
    final bool hasResult = orchestratorState.hasResult;
    final bool isProcessing = orchestratorState.isProcessing;
    final bool isQualityRejected = orchestratorState.isQualityRejected;

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Screen 1: Full-Bleed Viewfinder OR Screen 2: Crop Diagnosis Result
            if (!hasResult)
              _buildScreen1ScannerViewfinder(isProcessing)
            else
              _buildScreen2DiagnosisResultView(orchestratorState),

            // Non-blocking Parallel Pipeline Status Pill
            if (isProcessing)
              _buildPipelineStatusPill(orchestratorState.statusMessage),

            // Screen 1 Retake Sheet (OOD / Blur rejection)
            if (isQualityRejected)
              _buildVisualRetakeSheet(orchestratorState),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 1: SMART LEAF SCANNER (ULTRA-SIMPLE CAMERA)
  // ===========================================================================
  Widget _buildScreen1ScannerViewfinder(bool isBusy) {
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;

    return Column(
      children: [
        // Full-bleed live camera viewfinder stage
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FloraXTheme.borderDim, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Live Camera Stream
                  if (_isCameraReady && _cameraController != null)
                    CameraPreview(_cameraController!)
                  else
                    const Center(
                      child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
                    ),

                  // Center Rounded Leaf Alignment Frame (Bold High-Contrast Target)
                  CustomPaint(
                    painter: LeafFramingReticlePainter(),
                  ),

                  // Single 3-Word Visual Hint at Center-Top
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.leaf, color: Color(0xFF4EDEA3), size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                strings.holdLeafSteady,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Action Dock: Exactly 3 Clean Controls
        // Gallery (left, 56dp), Huge CAPTURE green shutter (76dp center), Flash (right, 56dp)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 76), // leave room above docked voice bar
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Gallery Button (56dp)
              SizedBox(
                width: 56,
                height: 56,
                child: Material(
                  color: FloraXTheme.cardSurface,
                  shape: const CircleBorder(
                    side: BorderSide(color: FloraXTheme.borderDim, width: 1.5),
                  ),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Field photo archive ready for zero-network analysis.'),
                          backgroundColor: FloraXTheme.primaryGreen,
                        ),
                      );
                    },
                    customBorder: const CircleBorder(),
                    child: const Icon(LucideIcons.image, color: FloraXTheme.textPrimary, size: 26),
                  ),
                ),
              ),

              // 2. Huge CAPTURE Green Shutter Button (76dp center)
              GestureDetector(
                onTap: isBusy ? null : _captureAndAnalyze,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FloraXTheme.primaryGreen,
                    boxShadow: [
                      BoxShadow(
                        color: FloraXTheme.primaryGreen.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isBusy ? LucideIcons.loader2 : LucideIcons.camera,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),

              // 3. Flash Toggle (56dp)
              SizedBox(
                width: 56,
                height: 56,
                child: Material(
                  color: _isTorchOn ? const Color(0xFFFEF3C7) : FloraXTheme.cardSurface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: _isTorchOn ? FloraXTheme.amberCaution : FloraXTheme.borderDim,
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: _toggleTorch,
                    customBorder: const CircleBorder(),
                    child: Icon(
                      _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                      color: _isTorchOn ? FloraXTheme.amberCaution : FloraXTheme.textSecondary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 1 RETAKE SHEET (FRIENDLY VISUAL RETAKE GUIDE)
  // ===========================================================================
  Widget _buildVisualRetakeSheet(ScanOrchestratorState orchestratorState) {
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;
    final report = orchestratorState.qualityReport;
    final activeFarmerLang = ref.watch(activeFarmerLanguageProvider);
    final activeLang = activeFarmerLang.code;

    // Concise plain-language trigger reason matching user and developer diagnostic expectations
    String conciseReason;
    if (report?.isTooDark == true || report?.failureCode == 'tooDark') {
      conciseReason = activeLang == 'mr'
          ? 'खूप अंधार आहे — उजेडात जा किंवा फ्लॅश चालू करा'
          : (activeLang == 'hi'
              ? 'बहुत अंधेरा है — उजाले में जाएं या फ्लैश जलाएं'
              : 'Too dark — move into daylight or turn on flash');
    } else if (report?.isTooBright == true || report?.failureCode == 'tooBright') {
      conciseReason = activeLang == 'mr'
          ? 'खूप प्रखर प्रकाश आहे — पानावर सावली करा'
          : (activeLang == 'hi'
              ? 'बहुत तेज रोशनी है — सीधी धूप से बचें'
              : 'Too bright — avoid harsh sunlight glare');
    } else if (report?.isBlurry == true || report?.failureCode == 'blurry') {
      conciseReason = activeLang == 'mr'
          ? 'फोटो अस्पष्ट/धुरकट आला — हात स्थिर ठेवा'
          : (activeLang == 'hi'
              ? 'फोटो धुंधला है — हाथ स्थिर रखें'
              : 'Image blurry — hold camera steady');
    } else if (report?.isNoLeafDetected == true || report?.failureCode == 'noLeafDetected') {
      conciseReason = activeLang == 'mr'
          ? 'पिकाचे पान आढळले नाही — एक पान चौकटीत मध्यभागी आणा'
          : (activeLang == 'hi'
              ? 'पत्ती नहीं दिखी — एक पत्ती को फ्रेम के बीच लाएं'
              : 'Leaf not detected clearly — frame one leaf in the center');
    } else if (report?.isLowConfidenceOod == true || report?.failureCode == 'lowConfidenceOod') {
      conciseReason = activeLang == 'mr'
          ? 'वस्तू ओळखली नाही — कृपया पिकाचे पान कॅमेऱ्यासमोर धरा'
          : (activeLang == 'hi'
              ? 'वस्तु पहचानी नहीं गई — कृपया पौधे की पत्ती दिखाएं'
              : 'Object not recognized — frame a crop leaf clearly');
    } else if (report != null && report.failureReasons.isNotEmpty) {
      conciseReason = report.failureReasons.first;
    } else {
      conciseReason = strings.retakeSubtitle;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          decoration: const BoxDecoration(
            color: FloraXTheme.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      report?.isTooDark == true
                          ? LucideIcons.moon
                          : (report?.isTooBright == true
                              ? LucideIcons.sun
                              : (report?.isBlurry == true
                                  ? LucideIcons.focus
                                  : (report?.isNoLeafDetected == true
                                      ? LucideIcons.leaf
                                      : LucideIcons.cameraOff))),
                      color: const Color(0xFFB45309),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.retakeTitle,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: FloraXTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          conciseReason,
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: FloraXTheme.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FarmerAudioPill(
                    textToSpeak: conciseReason,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Concise Plain-Language Trigger Reason Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conciseReason,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Simple "Bad photo vs. Good leaf photo" visual guide
              Row(
                children: [
                  // Bad Photo Example Tile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFB91C1C), width: 1.5),
                      ),
                      child: Column(
                        children: const [
                          Icon(LucideIcons.xCircle, color: Color(0xFFB91C1C), size: 32),
                          SizedBox(height: 6),
                          Text(
                            '❌ Bad Photo',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Blurry / Far / No Leaf',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Good Leaf Photo Example Tile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF15803D), width: 1.5),
                      ),
                      child: Column(
                        children: const [
                          Icon(LucideIcons.checkCircle2, color: Color(0xFF15803D), size: 32),
                          SizedBox(height: 6),
                          Text(
                            '✅ Good Photo',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Close / Clear Leaf',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF14532D), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Huge Try Again CTA Button (64dp) with Camera Resume
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(scanOrchestratorProvider.notifier).reset();
                  _cameraController?.resumePreview();
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 24, color: Colors.white),
                label: Text(
                  strings.tryAgain,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FloraXTheme.primaryGreen,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 2: CROP DIAGNOSIS RESULT (DAYLIGHT KISAN EDITION)
  // ===========================================================================
  Widget _buildScreen2DiagnosisResultView(ScanOrchestratorState orchestratorState) {
    final result = orchestratorState.diagnosticResult!;
    final protocol = orchestratorState.ipmProtocol;
    final scanRecord = orchestratorState.scanRecord;
    final scanId = scanRecord?.scanId ?? 'FLX-ACTIVE';

    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;
    final activeLang = ref.watch(activeFarmerLanguageProvider);

    final topPrediction = result.topCandidates.isNotEmpty ? result.topCandidates.first : null;
    final double confidence = topPrediction?.confidence ?? 0.0;
    final bool isConfidenceLow = confidence < 0.75;
    final bool isHealthy = topPrediction?.labelId.toLowerCase().contains('healthy') ?? false;
    final bool isAbiotic = (topPrediction?.category == DiseaseCategory.abiotic) ||
        (protocol?.isAbioticNutrientDeficiency ?? false);

    final String conditionTitle = _formatConditionTitle(topPrediction?.labelId, activeLang.code);

    // Dynamically resolve crop name based on detected condition label
    String cropName = 'Crop';
    final String labelLower = (topPrediction?.labelId ?? '').toLowerCase();
    if (labelLower.startsWith('tomato_') || labelLower.contains('tomato')) {
      cropName = 'Tomato';
    } else if (labelLower.startsWith('grape_') || labelLower.contains('grape')) {
      cropName = 'Grape';
    } else if (labelLower.startsWith('apple_') || labelLower.contains('apple')) {
      cropName = 'Apple';
    } else if (labelLower.startsWith('paddy_') || labelLower.startsWith('rice_') || labelLower.contains('paddy')) {
      cropName = 'Paddy / Rice';
    } else if (labelLower.startsWith('cotton_') || labelLower.contains('cotton')) {
      cropName = 'Cotton';
    } else if (labelLower.startsWith('banana_') || labelLower.contains('banana')) {
      cropName = 'Banana';
    } else if (labelLower.startsWith('potato_') || labelLower.contains('potato')) {
      cropName = 'Potato';
    } else if (labelLower.startsWith('corn_') || labelLower.contains('corn')) {
      cropName = 'Corn / Maize';
    } else if (labelLower.startsWith('wheat_') || labelLower.contains('wheat')) {
      cropName = 'Wheat';
    } else if (labelLower.startsWith('pepper_') || labelLower.contains('pepper')) {
      cropName = 'Bell Pepper';
    } else if (labelLower.startsWith('sugarcane_') || labelLower.contains('sugarcane')) {
      cropName = 'Sugarcane';
    } else if (labelLower.startsWith('abiotic_')) {
      cropName = 'Crop Foliage';
    }

    // Decode Cloud Grad-CAM heatmap if available
    Uint8List? decodedHeatmap;
    if (result.heatmapBase64 != null && result.heatmapBase64!.isNotEmpty) {
      try {
        final cleanBase64 = result.heatmapBase64!.split(',').last;
        decodedHeatmap = base64Decode(cleanBase64);
      } catch (_) {}
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Navigation / Dismiss Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: FloraXTheme.textPrimary, size: 24),
                onPressed: _dismissDiagnosticResult,
                tooltip: 'Back to Scanner',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    strings.diagnosisResult,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FloraXTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _captureAndAnalyze,
                icon: const Icon(LucideIcons.refreshCw, color: FloraXTheme.primaryGreen, size: 18),
                label: const Text('Rescan', style: TextStyle(color: FloraXTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. TOP HERO CARD: Captured Leaf Photo with 1-Tap Pill Toggle
          FloraXGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Leaf Image with Smooth Grad-CAM Heatmap Overlay
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(FloraXTheme.radiusXl)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Raw Leaf Photo
                        if (result.sanitizedImageBytes.isNotEmpty)
                          Image.memory(result.sanitizedImageBytes, fit: BoxFit.cover)
                        else
                          Container(color: FloraXTheme.surfaceContainerHigh),

                        // Grad-CAM Heatmap Overlay (when Damage Spot is active)
                        if (_showHeatmapOverlay && decodedHeatmap != null)
                          Opacity(
                            opacity: 0.75,
                            child: Image.memory(decodedHeatmap, fit: BoxFit.cover),
                          ),

                        // Thermal Hotspots / Bounding Layer
                        if (_showHeatmapOverlay && result.gradCamHotspots.isNotEmpty)
                          Opacity(
                            opacity: 0.8,
                            child: CustomPaint(
                              painter: ThermalAttentionPainter(
                                hotspots: result.gradCamHotspots,
                                selectedHotspot: result.gradCamHotspots.firstOrNull,
                              ),
                            ),
                          ),

                        // Feature #1: Multi-Region Numbered Bounding Boxes (when Damage Spot is active)
                        if (_showHeatmapOverlay && result.lesionRegions.isNotEmpty)
                          CustomPaint(
                            painter: NumberedLesionRegionsPainter(
                              regions: result.lesionRegions,
                            ),
                          ),

                        // Feature #1: Summary Chip: "X infected zones detected"
                        if (_showHeatmapOverlay && result.lesionRegions.isNotEmpty)
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.target, size: 14, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${result.lesionRegions.length} ${result.lesionRegions.length == 1 ? 'infected zone' : 'infected zones'} detected',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Feature #10: Offline status vs. Cloud Grad-CAM indicator
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!result.isCloudInference) ...[
                                  const Icon(LucideIcons.wifiOff, color: Color(0xFF34D399), size: 12),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Offline Mode — Local AI Active',
                                    style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ] else ...[
                                  const Icon(LucideIcons.cloud, color: Color(0xFF60A5FA), size: 12),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Cloud PyTorch Grad-CAM',
                                    style: TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 1-Tap Pill Toggle: [Leaf Photo] | [Damage Spot (AI)]
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: FloraXTheme.cardSurface,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: FloraXTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                      border: Border.all(color: FloraXTheme.borderDim, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        // Leaf Photo Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showHeatmapOverlay = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_showHeatmapOverlay ? FloraXTheme.cardSurface : Colors.transparent,
                                borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                                boxShadow: !_showHeatmapOverlay
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  strings.leafPhotoTab,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: !_showHeatmapOverlay ? FontWeight.w800 : FontWeight.w600,
                                    color: !_showHeatmapOverlay ? FloraXTheme.textPrimary : FloraXTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Damage Spot (AI) Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showHeatmapOverlay = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _showHeatmapOverlay ? FloraXTheme.primaryGreen : Colors.transparent,
                                borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                                boxShadow: _showHeatmapOverlay
                                    ? [
                                        BoxShadow(
                                          color: FloraXTheme.primaryGreen.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  strings.damageSpotTab,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _showHeatmapOverlay ? FontWeight.w800 : FontWeight.w600,
                                    color: _showHeatmapOverlay ? Colors.white : FloraXTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Feature #2: Biotic vs. Abiotic Differentiation Visual Pill
          _buildEtiologyPill(
            isHealthy: isHealthy,
            isAbiotic: isAbiotic,
            activeLang: activeLang.code,
          ),
          const SizedBox(height: 12),

          // Feature #3: Early-Stage Disease Recognition Banner
          if (orchestratorState.isEarlyStageAlert || scanRecord?.isEarlyStageAlert == true) ...[
            _buildEarlyStageBanner(activeLang.code),
            const SizedBox(height: 12),
          ],

          // Feature #4: Explainable AI (XAI) Plain-Language Caption
          _buildXaiCaptionCard(
            conditionTitle: conditionTitle,
            regionCount: result.lesionRegions.length,
            distinguishingSymptom: topPrediction?.distinguishingSymptom ?? '',
            activeLang: activeLang.code,
          ),
          const SizedBox(height: 12),

          // 2. TRAFFIC-LIGHT VERDICT BANNER
          _buildTrafficLightVerdictBanner(
            cropName: cropName,
            conditionTitle: isHealthy ? strings.healthyVerdict : conditionTitle,
            confidence: confidence,
            isHealthy: isHealthy,
            isAbiotic: isAbiotic,
            isConfidenceLow: isConfidenceLow,
            lesionAreaPercent: result.lesionAreaPercent,
            voiceGuide: voiceGuide,
            strings: strings,
          ),
          const SizedBox(height: 16),

          // 3. PRIMARY CTA
          // Single full-width 60dp green button: See Cure Steps ->
          // If confidence < 75%: Prominent amber card: Not 100% Sure — Ask an Expert Free
          if (isConfidenceLow)
            _buildLowConfidenceAmberCard(context, strings)
          else
            ElevatedButton(
              onPressed: () {
                if (protocol != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CureGuideScreen(
                        protocol: protocol,
                        scanId: scanId,
                        initialVerificationStatus: result.verificationStatus,
                        requiresKvkReview: result.requiresKvkReview,
                        topConfidence: confidence,
                        cropName: cropName,
                        isEarlyStage: orchestratorState.isEarlyStageAlert || (scanRecord?.isEarlyStageAlert == true),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification protocol loaded.'),
                      backgroundColor: FloraXTheme.primaryGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FloraXTheme.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    strings.seeCureSteps,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, size: 22),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // 4. COLLAPSIBLE "🔬 Scientist / AI Details" ExpansionTile (Collapsed by default)
          _buildScientistExpansionTile(
            result: result,
            scanId: scanId,
            canonicalId: topPrediction?.labelId ?? 'N/A',
            confidence: confidence,
            strings: strings,
            inferenceError: ref.watch(tfliteIsolateServiceProvider).lastInferenceError,
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficLightVerdictBanner({
    required String cropName,
    required String conditionTitle,
    required double confidence,
    required bool isHealthy,
    required bool isAbiotic,
    required bool isConfidenceLow,
    required double lesionAreaPercent,
    required VoiceGuideService voiceGuide,
    required FarmerLocalization strings,
  }) {
    Color bannerBg = const Color(0xFFDCFCE7);
    Color bannerBorder = const Color(0xFF15803D);
    Color bannerFg = const Color(0xFF15803D);
    IconData icon = LucideIcons.checkCircle2;

    if (isHealthy) {
      bannerBg = const Color(0xFFDCFCE7);
      bannerBorder = const Color(0xFF15803D);
      bannerFg = const Color(0xFF15803D);
      icon = LucideIcons.leaf;
    } else if (isConfidenceLow || isAbiotic) {
      bannerBg = const Color(0xFFFEF3C7);
      bannerBorder = const Color(0xFFB45309);
      bannerFg = const Color(0xFFB45309);
      icon = LucideIcons.alertTriangle;
    } else if (lesionAreaPercent > 25.0) {
      bannerBg = const Color(0xFFFEE2E2);
      bannerBorder = const Color(0xFFB91C1C);
      bannerFg = const Color(0xFFB91C1C);
      icon = LucideIcons.shieldAlert;
    }

    final spokenText = voiceGuide.buildDiagnosisSpokenScript(
      cropName: cropName,
      conditionName: conditionTitle,
      confidence: confidence,
      isHealthy: isHealthy,
      isAbiotic: isAbiotic,
      requiresKvk: isConfidenceLow,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusXl),
        border: Border.all(color: bannerBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: bannerFg, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conditionTitle.toLowerCase().contains(cropName.toLowerCase())
                          ? conditionTitle
                          : '$cropName — $conditionTitle',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: bannerFg,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHealthy
                          ? 'Zero symptoms detected • Safe foliage'
                          : 'Confidence: ${(confidence * 100).toStringAsFixed(0)}% • Spread: ${lesionAreaPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: bannerFg.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Severity Meter (3 Simple Bars: Low / Medium / High)
          _buildVisualSeverityMeter(lesionAreaPercent, strings),
          const SizedBox(height: 14),

          // Prominent "🔊 Listen to Result" Pill Button
          FarmerAudioPill(
            textToSpeak: spokenText,
            customLabel: voiceGuide.isSpeaking ? strings.stopListening : strings.listenResult,
            height: 52,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualSeverityMeter(double lesionPct, FarmerLocalization strings) {
    // Feature #7: Standardized phytopathology severity bands: Mild <15%, Moderate 15-40%, Severe >=40%
    int activeBars = 1;
    Color barColor = const Color(0xFF15803D);
    String bandLabel = strings.severityLow;

    if (lesionPct >= 40.0) {
      activeBars = 3;
      barColor = const Color(0xFFB91C1C);
      bandLabel = strings.severityHigh;
    } else if (lesionPct >= 15.0) {
      activeBars = 2;
      barColor = const Color(0xFFB45309);
      bandLabel = strings.severityMedium;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'DAMAGE SEVERITY (${lesionPct.toStringAsFixed(1)}% leaf affected)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FloraXTheme.textMuted),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              bandLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildSeverityBarSegment(isActive: activeBars >= 1, color: barColor)),
            const SizedBox(width: 6),
            Expanded(child: _buildSeverityBarSegment(isActive: activeBars >= 2, color: barColor)),
            const SizedBox(width: 6),
            Expanded(child: _buildSeverityBarSegment(isActive: activeBars >= 3, color: barColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildSeverityBarSegment({required bool isActive, required Color color}) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? color : FloraXTheme.borderDim,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
      ),
    );
  }

  Widget _buildEtiologyPill({
    required bool isHealthy,
    required bool isAbiotic,
    required String activeLang,
  }) {
    final String label;
    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final IconData icon;
    final String spokenText;

    if (isHealthy) {
      label = activeLang == 'mr'
          ? '✅ निरोगी पान (रोग नाही)'
          : (activeLang == 'hi' ? '✅ स्वस्थ पत्ती (कोई रोग नहीं)' : '✅ Healthy Leaf (Zero Disease)');
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF15803D);
      borderColor = const Color(0xFF86EFAC);
      icon = LucideIcons.leaf;
      spokenText = activeLang == 'mr'
          ? 'पीक पूर्णपणे निरोगी आहे.'
          : (activeLang == 'hi' ? 'फसल पूरी तरह स्वस्थ है.' : 'Crop leaf is healthy.');
    } else if (isAbiotic) {
      label = activeLang == 'mr'
          ? '🌱 अन्नद्रव्य कमतरता (जिवाणू किंवा बुरशी नाही)'
          : (activeLang == 'hi' ? '🌱 पोषक तत्व की कमी (जीवाणु/फफूंद नहीं)' : '🌱 Nutrient Deficiency (Not a Germ)');
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFB45309);
      borderColor = const Color(0xFFFCD34D);
      icon = LucideIcons.sprout;
      spokenText = activeLang == 'mr'
          ? 'ही बुरशी नसून खतांची किंवा अन्नद्रव्याची कमतरता आहे. रासायनिक कीटकनाशक फवारू नका.'
          : (activeLang == 'hi'
              ? 'यह फफूंद नहीं बल्कि पोषक तत्वों की कमी है. रासायनिक कीटनाशक न छिड़कें.'
              : 'This is an abiotic nutrient deficiency, not an infectious germ. Do not spray chemical fungicides.');
    } else {
      label = activeLang == 'mr'
          ? '🦠 संसर्गजन्य रोग (बुरशी/जिवाणू)'
          : (activeLang == 'hi' ? '🦠 संक्रामक रोग (फफूंद/जीवाणु)' : '🦠 Infectious Disease (Biotic)');
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFB91C1C);
      borderColor = const Color(0xFFFCA5A5);
      icon = LucideIcons.bug;
      spokenText = activeLang == 'mr'
          ? 'हा संसर्गजन्य रोग आहे. नियंत्रणासाठी जैविक किंवा रासायनिक उपाय करा.'
          : (activeLang == 'hi'
              ? 'यह संक्रामक रोग है. नियंत्रण के लिए अनुशंसित उपाय अपनाएं.'
              : 'This is an infectious biotic disease.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FarmerAudioPill(textToSpeak: spokenText),
        ],
      ),
    );
  }

  Widget _buildEarlyStageBanner(String activeLang) {
    final String title = activeLang == 'mr'
        ? '⚡ रोगाची प्राथमिक अवस्था — पीक वाचवण्यासाठी त्वरित उपाय करा'
        : (activeLang == 'hi'
            ? '⚡ प्रारंभिक अवस्था पकड़ी गई — फसल बचाने के लिए तुरंत उपचार करें'
            : '⚡ Early Stage Caught — Treat Now to Save Crop');
    final String subtitle = activeLang == 'mr'
        ? 'संसर्ग फक्त सुरुवातीच्या टप्प्यात आहे. कमी खर्चात जैविक व मशागतीचे उपाय करून रोग आटोक्यात आणा.'
        : (activeLang == 'hi'
            ? 'संक्रमण शुरुआती स्तर पर है. जैविक और सांस्कृतिक तरीकों से कम खर्च में तुरंत रोकथाम संभव है.'
            : 'Small initial infection footprint detected. Immediate preventive bio-control will stop spread.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.zap, color: Color(0xFF059669), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FarmerAudioPill(textToSpeak: '$title. $subtitle'),
        ],
      ),
    );
  }

  Widget _buildXaiCaptionCard({
    required String conditionTitle,
    required int regionCount,
    required String distinguishingSymptom,
    required String activeLang,
  }) {
    final String countText = regionCount > 1 ? '$regionCount areas' : '1 area';
    final String symptomSuffix = distinguishingSymptom.isNotEmpty ? ' $distinguishingSymptom' : '';
    final String caption = activeLang == 'mr'
        ? 'पानावरील $countText मध्ये दिसणारे डाग $conditionTitle या रोगाशी तंतोतंत जुळतात.$symptomSuffix'
        : (activeLang == 'hi'
            ? 'पत्ती के $countText में हाइलाइट किए गए धब्बे $conditionTitle से मेल खाते हैं.$symptomSuffix'
            : 'Highlighted spots across $countText on the leaf match $conditionTitle.$symptomSuffix');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FloraXTheme.cardSurface,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
        border: Border.all(color: FloraXTheme.borderDim, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(LucideIcons.eye, color: FloraXTheme.primaryGreen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WHY AI MADE THIS CALL (XAI)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: FloraXTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(fontSize: 12.5, color: FloraXTheme.textPrimary, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FarmerAudioPill(textToSpeak: caption),
        ],
      ),
    );
  }

  Widget _buildLowConfidenceAmberCard(BuildContext context, FarmerLocalization strings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(FloraXTheme.radiusXl),
        border: Border.all(color: const Color(0xFFB45309), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.helpCircle, color: Color(0xFFB45309), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.askExpertFree,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AI confidence is below 75%. Chemical sprays are hidden to protect your crop from chemical injury. Connect directly with an ICAR agronomist.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF78350F), height: 1.35),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpertDirectoryScreen()),
              );
            },
            icon: const Icon(LucideIcons.phoneCall, size: 20, color: Colors.white),
            label: const Text('Call KVK Expert Free (डॉक्टरांना कॉल करा)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScientistExpansionTile({
    required HybridDiagnosticResult result,
    required String scanId,
    required String canonicalId,
    required double confidence,
    required FarmerLocalization strings,
    String? inferenceError,
  }) {
    return ExpansionTile(
      title: Text(
        strings.scientistDetails,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: FloraXTheme.textSecondary,
        ),
      ),
      leading: const Icon(LucideIcons.flaskConical, color: FloraXTheme.primaryGreen, size: 22),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        FloraXGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inferenceError != null && inferenceError.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB91C1C), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertOctagon, color: Color(0xFFB91C1C), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ AI Model Error: $inferenceError',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Text(
                'Top-3 Differential Diagnoses:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              ...result.topCandidates.take(3).map((candidate) {
                final pct = (candidate.confidence * 100).toStringAsFixed(1);
                final displayName = candidate.plainName.isNotEmpty ? candidate.plainName : candidate.labelId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FloraXTheme.primaryGreen),
                          ),
                        ],
                      ),
                      if (candidate.distinguishingSymptom.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '🔍 ${candidate.distinguishingSymptom}',
                          style: const TextStyle(fontSize: 11, color: FloraXTheme.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const Divider(color: FloraXTheme.borderDim, height: 16),
              _buildTechRow('Canonical ID:', canonicalId),
              _buildTechRow('Scan ID:', scanId),
              _buildTechRow('Inference Engine:', result.isCloudInference ? 'Cloud PyTorch ResNet50 Grad-CAM' : 'Local Edge TFLite (MobileNetV2 69->50)'),
              _buildTechRow('Verification Flag:', result.requiresKvkReview ? 'MANDATORY_KVK_REVIEW' : 'AI_VERIFIED'),
              _buildTechRow('Lesion Area Ratio:', '${result.lesionAreaPercent.toStringAsFixed(2)}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: FloraXTheme.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: FloraXTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStatusPill(String statusMessage) {
    return Positioned(
      bottom: 90,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FloraXTheme.cardSurface,
          borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
          border: Border.all(color: FloraXTheme.primaryGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: FloraXTheme.primaryGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusMessage.isNotEmpty ? statusMessage : 'Processing Leaf Foliage...',
                style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatConditionTitle(String? labelId, String langCode) {
    if (labelId == null) return 'Leaf Condition';
    final lower = labelId.toLowerCase();
    if (lower.contains('healthy')) {
      return langCode == 'mr' ? 'पीक निरोगी आहे' : (langCode == 'hi' ? 'फसल स्वस्थ है' : 'Healthy Leaf');
    }
    if (lower.contains('early_blight')) {
      return langCode == 'mr' ? 'लवकर येणारा करपा (Early Blight)' : (langCode == 'hi' ? 'अगेती झुलसा (Early Blight)' : 'Early Blight');
    }
    if (lower.contains('late_blight')) {
      return langCode == 'mr' ? 'उशिरा येणारा करपा (Late Blight)' : (langCode == 'hi' ? 'पछेती झुलसा (Late Blight)' : 'Late Blight');
    }
    if (lower.contains('magnesium_deficiency')) {
      return langCode == 'mr' ? 'मॅग्नेशियम कमतरता' : (langCode == 'hi' ? 'मैग्नीशियम की कमी' : 'Magnesium Deficiency');
    }
    return labelId.replaceAll('_', ' ').toUpperCase();
  }
}

/// Custom Leaf Framing Reticle with High-Contrast Brackets & Center Target
class LeafFramingReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final double rectWidth = size.width * 0.78;
    final double rectHeight = size.height * 0.52;
    final Rect frame = Rect.fromCenter(
      center: Offset(size.width / 2.0, size.height * 0.44),
      width: rectWidth,
      height: rectHeight,
    );

    const double cornerLength = 36.0;

    // Top-Left Corner
    canvas.drawLine(frame.topLeft, Offset(frame.left + cornerLength, frame.top), paint);
    canvas.drawLine(frame.topLeft, Offset(frame.left, frame.top + cornerLength), paint);

    // Top-Right Corner
    canvas.drawLine(frame.topRight, Offset(frame.right - cornerLength, frame.top), paint);
    canvas.drawLine(frame.topRight, Offset(frame.right, frame.top + cornerLength), paint);

    // Bottom-Left Corner
    canvas.drawLine(frame.bottomLeft, Offset(frame.left + cornerLength, frame.bottom), paint);
    canvas.drawLine(frame.bottomLeft, Offset(frame.left, frame.bottom - cornerLength), paint);

    // Bottom-Right Corner
    canvas.drawLine(frame.bottomRight, Offset(frame.right - cornerLength, frame.bottom), paint);
    canvas.drawLine(frame.bottomRight, Offset(frame.right, frame.bottom - cornerLength), paint);

    // Center Crosshair
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    final center = frame.center;
    canvas.drawLine(Offset(center.dx - 14, center.dy), Offset(center.dx + 14, center.dy), centerPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 14), Offset(center.dx, center.dy + 14), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
