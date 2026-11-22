import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/florax_theme.dart';
import '../../domain/models/florax_models.dart';
import '../../services/voice/vernacular_voice_service.dart';
import 'florax_design_primitives.dart';

/// Interactive Explainable AI (XAI) Grad-CAM & Multi-Region Diagnosis Visualizer
/// Strictly refactored to Google Stitch Obsidian Bio-Agritech specifications.
class GradCamOverlayWidget extends ConsumerStatefulWidget {
  final Uint8List? imageBytes;
  final String? imageSource;
  final List<DiseasePrediction> topPredictions;
  final double lesionAreaPercent;
  final List<GradCamHotspot> hotspots;
  final String? heatmapBase64;
  final bool isCloudGradCam;

  // Tier 3 (Phase 11) Feature Extensions
  final List<LeafRegionDiagnosis>? regionDiagnoses;
  final SeverityGrade severityGrade;
  final bool isEarlyStageAlert;
  final IcarIpmProtocol? protocol;
  final String activeLangCode; // 'mr', 'hi', 'en'

  const GradCamOverlayWidget({
    super.key,
    this.imageBytes,
    this.imageSource,
    required this.topPredictions,
    required this.lesionAreaPercent,
    required this.hotspots,
    this.heatmapBase64,
    required this.isCloudGradCam,
    this.regionDiagnoses,
    this.severityGrade = SeverityGrade.mild,
    this.isEarlyStageAlert = false,
    this.protocol,
    this.activeLangCode = 'mr',
  });

  @override
  ConsumerState<GradCamOverlayWidget> createState() => _GradCamOverlayWidgetState();
}

class _GradCamOverlayWidgetState extends ConsumerState<GradCamOverlayWidget> {
  double _opacity = 0.75;
  bool _showHeatmap = true;
  GradCamHotspot? _selectedHotspot;
  LeafRegionDiagnosis? _selectedRegion;
  Uint8List? _decodedHeatmapBytes;
  bool _isDifferentialDeckExpanded = false;

  // Feature #6: Farmer answers to clarifying questions { questionText : bool }
  final Map<String, bool> _clarifyingAnswers = {};

  @override
  void initState() {
    super.initState();
    _decodeHeatmap();
    if (widget.hotspots.isNotEmpty) {
      _selectedHotspot = widget.hotspots.first;
    }
    if (widget.regionDiagnoses != null && widget.regionDiagnoses!.isNotEmpty) {
      _selectedRegion = widget.regionDiagnoses!.first;
    }
  }

  @override
  void didUpdateWidget(covariant GradCamOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heatmapBase64 != widget.heatmapBase64) {
      _decodeHeatmap();
    }
    if (widget.regionDiagnoses != null && widget.regionDiagnoses!.isNotEmpty) {
      if (_selectedRegion == null || !widget.regionDiagnoses!.contains(_selectedRegion)) {
        _selectedRegion = widget.regionDiagnoses!.first;
      }
    }
  }

  void _decodeHeatmap() {
    if (widget.heatmapBase64 != null && widget.heatmapBase64!.isNotEmpty) {
      try {
        final cleanBase64 = widget.heatmapBase64!.split(',').last;
        _decodedHeatmapBytes = base64Decode(cleanBase64);
      } catch (e) {
        debugPrint('[FloraX XAI] Failed to decode heatmap base64: $e');
        _decodedHeatmapBytes = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.activeLangCode;
    final regions = widget.regionDiagnoses ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // STITCH HEADER: Report Metadata & Audio Trigger Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStitchReportHeader(lang),
        ),
        const SizedBox(height: 12),

        // STITCH HERO: Multi-Region Grad-CAM Explainable AI Hero Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: FloraXTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(FloraXTheme.radiusXl),
              border: Border.all(color: FloraXTheme.borderDim, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FloraXTheme.radiusXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Visual Heatmap Container
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapUp: (details) {
                            _handleCanvasTap(details.localPosition, constraints.biggest);
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Leaf Base Image
                              (widget.imageBytes != null && widget.imageBytes!.isNotEmpty)
                                  ? Image.memory(
                                      widget.imageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : FloraXAdaptiveImage(
                                      imageSource: widget.imageSource,
                                      fit: BoxFit.cover,
                                    ),

                              // 2. PyTorch Cloud Grad-CAM Superimposed Image Layer
                              if (_decodedHeatmapBytes != null && _showHeatmap)
                                Opacity(
                                  opacity: _opacity,
                                  child: Image.memory(
                                    _decodedHeatmapBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                              // 3. Thermal Radial Heatmap Layer & Hotspots
                              if (_showHeatmap)
                                Opacity(
                                  opacity: _opacity,
                                  child: CustomPaint(
                                    painter: ThermalAttentionPainter(
                                      hotspots: widget.hotspots,
                                      selectedHotspot: _selectedHotspot,
                                    ),
                                  ),
                                ),

                              // 4. Multi-Region Bounding Boxes Layer
                              CustomPaint(
                                painter: MultiRegionBoxPainter(
                                  regions: regions,
                                  selectedRegion: _selectedRegion,
                                ),
                              ),

                              // 5. Canvas Header Badges
                              _buildCanvasHeaderBadges(),

                              // 6. Selected Region or Hotspot Callout
                              if (_selectedRegion != null)
                                _buildSelectedRegionCallout(lang)
                              else if (_selectedHotspot != null && _showHeatmap)
                                _buildSelectedHotspotPill(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Heatmap Controls & Interaction Suite (Segmented Mode & Opacity Slider)
                  _buildHeatmapControlsSuite(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // STITCH KPI ROW: Severity & Early-Stage KPI Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSeverityAndEarlyStageRow(lang),
        ),
        const SizedBox(height: 14),

        // STITCH REGION CHIPS: Region Selector Switcher Chips
        if (regions.length > 1) ...[
          _buildRegionSelectorChips(regions),
          const SizedBox(height: 14),
        ],

        // 3. Top-3 Diagnoses Card Deck
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildTopDiagnosesDeck(),
        ),
        const SizedBox(height: 14),

        // 4. Differential Diagnosis Comparison Deck (Feature #6)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildDifferentialDiagnosisDeck(lang),
        ),
      ],
    );
  }

  /// STITCH HEADER: Report Metadata & Audio Trigger Header Row
  Widget _buildStitchReportHeader(String lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FloraXTheme.neonGreen,
                    boxShadow: [
                      BoxShadow(
                        color: FloraXTheme.neonGreen.withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Diagnosis Report',
                  style: TextStyle(
                    color: FloraXTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  widget.isCloudGradCam ? LucideIcons.cloud : LucideIcons.cpu,
                  color: FloraXTheme.neonGreen,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isCloudGradCam ? 'Cloud PyTorch XAI • Today' : 'Offline TFLite • Today',
                  style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),

        // Audio Guidance Pill Button
        FloraXGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          borderRadius: FloraXTheme.radiusFull,
          backgroundColor: FloraXTheme.surfaceContainerHigh,
          onTap: () {
            final voiceService = ref.read(vernacularVoiceServiceProvider);
            final top = widget.topPredictions.isNotEmpty ? widget.topPredictions.first : null;
            if (top != null) {
              final text = 'निदान: ${_formatDiseaseLabel(top.labelId)}. बाधित क्षेत्र: ${widget.lesionAreaPercent.toStringAsFixed(1)} टक्के.';
              voiceService.speak(text, langCode: lang);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.volume2, color: FloraXTheme.neonGreen, size: 16),
              SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Listen', style: TextStyle(color: FloraXTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('मराठी ऑडिओ', style: TextStyle(color: FloraXTheme.neonGreen, fontSize: 9.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Heatmap Controls Suite: Segmented Toggle Buttons & Opacity Slider
  Widget _buildHeatmapControlsSuite() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: FloraXTheme.surfaceContainer,
      ),
      child: Column(
        children: [
          // Segmented View Toggle Buttons
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: FloraXTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(FloraXTheme.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHeatmap = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showHeatmap ? FloraXTheme.surfaceContainerHigh : Colors.transparent,
                        borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.image, size: 14, color: !_showHeatmap ? FloraXTheme.textPrimary : FloraXTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Original Leaf',
                            style: TextStyle(
                              color: !_showHeatmap ? FloraXTheme.textPrimary : FloraXTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: !_showHeatmap ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHeatmap = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showHeatmap ? FloraXTheme.neonGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.flame, size: 14, color: _showHeatmap ? const Color(0xFF003824) : FloraXTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Grad-CAM Map',
                            style: TextStyle(
                              color: _showHeatmap ? const Color(0xFF003824) : FloraXTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: _showHeatmap ? FontWeight.w700 : FontWeight.w400,
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
          const SizedBox(height: 10),

          // Opacity Smooth Range Slider
          Row(
            children: [
              const Icon(LucideIcons.sunMedium, color: FloraXTheme.textSecondary, size: 15),
              const SizedBox(width: 8),
              const Text(
                'Heatmap Opacity',
                style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: FloraXTheme.neonGreen,
                    inactiveTrackColor: FloraXTheme.surfaceContainerHighest,
                    thumbColor: FloraXTheme.neonGreen,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 1.0,
                    onChanged: _showHeatmap
                        ? (val) {
                            setState(() => _opacity = val);
                          }
                        : null,
                  ),
                ),
              ),
              Text(
                '${(_opacity * 100).toInt()}%',
                style: FloraXTheme.tabularMetric(fontSize: 12, color: FloraXTheme.neonGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// STITCH KPI ROW: Severity & Early-Stage KPI Row
  Widget _buildSeverityAndEarlyStageRow(String lang) {
    final double pct = widget.lesionAreaPercent;
    final isSevere = widget.severityGrade == SeverityGrade.severe;
    final isModerate = widget.severityGrade == SeverityGrade.moderate;
    final Color severityColor = isSevere
        ? FloraXTheme.crimsonAlert
        : (isModerate ? FloraXTheme.amberCaution : FloraXTheme.neonGreen);
    final String severityLabel = widget.severityGrade.toFirestoreValue();

    return Row(
      children: [
        // Left KPI Card: Spread Severity & Tabular Metric
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FloraXTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
              border: Border.all(color: FloraXTheme.borderDim),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spread Severity', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                      ),
                      child: Text(
                        severityLabel,
                        style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      pct.toStringAsFixed(1),
                      style: FloraXTheme.tabularMetric(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '%',
                      style: TextStyle(color: severityColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Text('Affected Leaf Surface', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100.0).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: FloraXTheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(severityColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Right KPI Card: Early-Stage Alert Trigger
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FloraXTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
              border: Border.all(
                color: widget.isEarlyStageAlert ? FloraXTheme.neonGreen : FloraXTheme.borderDim,
                width: widget.isEarlyStageAlert ? 1.2 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FloraXTheme.neonGreen.withValues(alpha: 0.18),
                      ),
                      child: const Icon(LucideIcons.leaf, color: FloraXTheme.neonGreen, size: 14),
                    ),
                    const SizedBox(width: 6),
                    const Text('Triage Alert', style: TextStyle(color: FloraXTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isEarlyStageAlert
                      ? 'Early-Stage Subtle Spots Detected — Act Preventively Now'
                      : 'Standard Diagnosis Flow Active',
                  style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 11, height: 1.3, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(LucideIcons.checkCircle2, color: FloraXTheme.neonGreen, size: 12),
                    SizedBox(width: 4),
                    Text('ICAR Protocol Verified', style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 9.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleCanvasTap(Offset tapPosition, Size canvasSize) {
    final regions = widget.regionDiagnoses ?? [];

    for (final region in regions) {
      final rect = region.boundingBoxNormalized;
      final double rx = rect.left * canvasSize.width;
      final double ry = rect.top * canvasSize.height;
      final double rw = rect.width * canvasSize.width;
      final double rh = rect.height * canvasSize.height;

      final pixelRect = Rect.fromLTWH(rx, ry, rw, rh);
      if (pixelRect.contains(tapPosition)) {
        setState(() {
          _selectedRegion = region;
        });
        return;
      }
    }

    for (final hotspot in widget.hotspots) {
      final double hotspotPxX = (hotspot.x / 100.0) * canvasSize.width;
      final double hotspotPxY = (hotspot.y / 100.0) * canvasSize.height;
      final double dist = (tapPosition - Offset(hotspotPxX, hotspotPxY)).distance;

      if (dist <= 40.0) {
        setState(() {
          _selectedHotspot = hotspot;
        });
        return;
      }
    }
  }

  Widget _buildCanvasHeaderBadges() {
    final SeverityGrade severity = widget.severityGrade;
    final double pct = widget.lesionAreaPercent;

    Color severityColor;
    String severityText;

    switch (severity) {
      case SeverityGrade.mild:
        severityColor = FloraXTheme.neonGreen;
        severityText = 'MILD (${pct.toStringAsFixed(1)}%)';
        break;
      case SeverityGrade.moderate:
        severityColor = FloraXTheme.amberCaution;
        severityText = 'MODERATE (${pct.toStringAsFixed(1)}%)';
        break;
      case SeverityGrade.severe:
        severityColor = FloraXTheme.crimsonAlert;
        severityText = 'SEVERE (${pct.toStringAsFixed(1)}%)';
        break;
    }

    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
              border: Border.all(color: severityColor, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.activity, color: severityColor, size: 13),
                const SizedBox(width: 5),
                Text(
                  severityText,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
              border: Border.all(color: FloraXTheme.borderDim),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isCloudGradCam ? LucideIcons.cloud : LucideIcons.cpu,
                  color: widget.isCloudGradCam ? FloraXTheme.bioCyan : FloraXTheme.neonGreen,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isCloudGradCam ? 'PyTorch Grad-CAM' : 'Edge Multi-Isolate',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionSelectorChips(List<LeafRegionDiagnosis> regions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: regions.map((region) {
            final bool isSelected = _selectedRegion?.regionId == region.regionId;
            final String label = region.regionId == 'region_full'
                ? 'Whole Leaf'
                : 'Region ${region.regionId.replaceAll("roi_", "#")}';

            return GestureDetector(
              onTap: () {
                setState(() => _selectedRegion = region);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? FloraXTheme.neonGreen : FloraXTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                  border: Border.all(
                    color: isSelected ? FloraXTheme.neonGreen : FloraXTheme.borderDim,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.scan,
                      size: 12,
                      color: isSelected ? const Color(0xFF003824) : FloraXTheme.neonGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF003824) : FloraXTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSelectedRegionCallout(String lang) {
    final region = _selectedRegion!;
    final explanation = region.visualSymptomExplanation[lang] ??
        region.visualSymptomExplanation['en'] ??
        'Region exhibiting diagnostic foliar symptoms.';

    final topCandidate = region.primaryPrediction;

    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(FloraXTheme.radiusMd),
          border: Border.all(color: FloraXTheme.neonGreen, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.focus, color: FloraXTheme.neonGreen, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${region.regionId.toUpperCase()}: ${_formatDiseaseLabel(topCandidate.labelId)}',
                    style: const TextStyle(
                      color: FloraXTheme.neonGreen,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(topCandidate.confidence * 100).toStringAsFixed(1)}%',
                  style: FloraXTheme.tabularMetric(fontSize: 11, color: FloraXTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              explanation,
              style: const TextStyle(
                color: FloraXTheme.textPrimary,
                fontSize: 11,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedHotspotPill() {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
          border: Border.all(color: FloraXTheme.neonGreen),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.target, color: FloraXTheme.neonGreen, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _selectedHotspot!.label,
                style: const TextStyle(
                  color: FloraXTheme.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'Weight: ${(_selectedHotspot!.intensity * 100).toInt()}%',
              style: FloraXTheme.tabularMetric(fontSize: 11, color: FloraXTheme.neonGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDiagnosesDeck() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FloraXTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusXl),
        border: Border.all(color: FloraXTheme.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Pathology Predictions',
                style: TextStyle(
                  color: FloraXTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FloraXTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
                  border: Border.all(color: FloraXTheme.borderDim),
                ),
                child: Text(
                  '${widget.topPredictions.length} Candidates',
                  style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...widget.topPredictions.asMap().entries.map((entry) {
            final int index = entry.key;
            final DiseasePrediction prediction = entry.value;
            final bool isTop = index == 0;
            final double confPercent = prediction.confidence > 1.0
                ? prediction.confidence
                : prediction.confidence * 100.0;

            final Color barColor = isTop
                ? (confPercent >= 75.0 ? FloraXTheme.neonGreen : FloraXTheme.amberCaution)
                : FloraXTheme.surfaceContainerHighest;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '#${index + 1} ',
                              style: TextStyle(
                                color: isTop ? FloraXTheme.neonGreen : FloraXTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatDiseaseLabel(prediction.labelId),
                                style: TextStyle(
                                  color: FloraXTheme.textPrimary,
                                  fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                                  fontSize: isTop ? 14 : 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${confPercent.toStringAsFixed(1)}%',
                        style: FloraXTheme.tabularMetric(
                          fontSize: 13,
                          color: isTop ? FloraXTheme.textPrimary : FloraXTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prediction.scientificName,
                        style: const TextStyle(
                          color: FloraXTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          prediction.category.toFirestoreValue(),
                          style: TextStyle(
                            color: _categoryColor(prediction.category),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (confPercent / 100.0).clamp(0.0, 1.0),
                      minHeight: isTop ? 6 : 4,
                      backgroundColor: FloraXTheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDifferentialDiagnosisDeck(String lang) {
    String panelTitle;
    String panelSubtitle;

    if (lang == 'mr') {
      panelTitle = 'तौलनिक निदान (३ संभाव्य रोगांची तुलना)';
      panelSubtitle = 'रोग निश्चित करण्यासाठी खालील प्रश्नांची उत्तरे द्या';
    } else if (lang == 'hi') {
      panelTitle = 'तुलनात्मक निदान (शीर्ष ३ संभावित रोगों की तुलना)';
      panelSubtitle = 'सटीक पहचान के लिए लक्षणों और प्रश्नों की जांच करें';
    } else {
      panelTitle = 'Compare Top-3 Possibilities (Differential Diagnosis)';
      panelSubtitle = 'Resolve uncertainty via distinguishing field symptoms & questions';
    }

    final top3 = widget.topPredictions.take(3).toList();
    final protocol = widget.protocol;

    return Container(
      decoration: BoxDecoration(
        color: FloraXTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusXl),
        border: Border.all(color: FloraXTheme.borderDim),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isDifferentialDeckExpanded,
          onExpansionChanged: (val) => setState(() => _isDifferentialDeckExpanded = val),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(LucideIcons.gitCompare, color: FloraXTheme.neonGreen, size: 22),
          title: Text(
            panelTitle,
            style: const TextStyle(
              color: FloraXTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            panelSubtitle,
            style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: FloraXTheme.borderDim, height: 1),
                  const SizedBox(height: 12),

                  ...top3.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final DiseasePrediction pred = entry.value;

                    final List<String> symptoms = protocol?.distinguishingSymptoms[lang] ??
                        protocol?.distinguishingSymptoms['en'] ??
                        _fallbackSymptoms(pred.labelId, lang);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FloraXTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(FloraXTheme.radiusMd),
                        border: Border.all(color: FloraXTheme.borderDim),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${idx + 1}. ${_formatDiseaseLabel(pred.labelId)}',
                                style: const TextStyle(
                                  color: FloraXTheme.neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${(pred.confidence * 100).toStringAsFixed(1)}%',
                                style: FloraXTheme.tabularMetric(fontSize: 12, color: FloraXTheme.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Distinguishing Key Signs:',
                            style: TextStyle(
                              color: FloraXTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...symptoms.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: FloraXTheme.neonGreen)),
                                  Expanded(
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        color: FloraXTheme.textPrimary,
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  const Text(
                    'Interactive Field Clarification (Tap to Confirm):',
                    style: TextStyle(
                      color: FloraXTheme.amberCaution,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ..._getClarifyingQuestions(lang).map((q) {
                    final bool? ans = _clarifyingAnswers[q];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FloraXTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(FloraXTheme.radiusSm),
                        border: Border.all(
                          color: ans == true ? FloraXTheme.neonGreen : FloraXTheme.borderDim,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q,
                              style: const TextStyle(
                                color: FloraXTheme.textPrimary,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('YES', style: TextStyle(fontSize: 10)),
                            selected: ans == true,
                            selectedColor: FloraXTheme.neonGreen,
                            labelStyle: TextStyle(
                              color: ans == true ? Colors.black : FloraXTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) {
                              setState(() {
                                _clarifyingAnswers[q] = true;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('NO', style: TextStyle(fontSize: 10)),
                            selected: ans == false,
                            selectedColor: FloraXTheme.crimsonAlert,
                            labelStyle: TextStyle(
                              color: ans == false ? Colors.white : FloraXTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) {
                              setState(() {
                                _clarifyingAnswers[q] = false;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getClarifyingQuestions(String lang) {
    if (widget.protocol != null &&
        widget.protocol!.clarifyingFollowUpQuestions.isNotEmpty) {
      final list = widget.protocol!.clarifyingFollowUpQuestions[lang] ??
          widget.protocol!.clarifyingFollowUpQuestions['en'];
      if (list != null && list.isNotEmpty) return list;
    }

    if (lang == 'mr') {
      return [
        'डागांमध्ये एकाग्र वर्तुळाकार चकती (Target Spot) दिसत आहेत का?',
        'पिवळेपणा आधी झाडाच्या खालच्या जुन्या पानांवर सुरू झाला का?',
        'पानाच्या मागच्या बाजूला काळी/राखाडी बुरशीची भुकटी दिसत आहे का?',
      ];
    } else if (lang == 'hi') {
      return [
        'क्या पत्ती के घावों में संकेंद्रित छल्ले (Target Rings) दिखाई दे रहे हैं?',
        'क्या पीलापन सबसे पहले पौधे की निचली पुरानी पत्तियों पर शुरू हुआ?',
        'क्या पत्ती की निचली सतह पर काले/भूरे फफूंद के बीजाणु मौजूद हैं?',
      ];
    } else {
      return [
        'Are concentric target-like rings visible inside necrotic spots?',
        'Did leaf yellowing begin on older lower canopy foliage first?',
        'Is dark velvety fungal sporulation visible on the leaf underside?',
      ];
    }
  }

  List<String> _fallbackSymptoms(String labelId, String lang) {
    if (labelId.contains('early_blight')) {
      return lang == 'mr'
          ? ['तपकिरी रंगाचे गोल डाग, पिवळे वलय, जुन्या पानांवर प्रादुर्भाव']
          : ['Concentric dark brown rings with distinct yellow chlorotic halos'];
    }
    if (labelId.contains('blast')) {
      return lang == 'mr'
          ? ['दोन्ही टोकांना टोकदार असलेले लंबगोलाकार (Spindle) आकाराचे डाग']
          : ['Spindle-shaped diamond lesions with gray-white necrotic center'];
    }
    if (labelId.contains('curl')) {
      return lang == 'mr'
          ? ['पाने वरच्या बाजूला चुरमुरणे, शिरा जाड होणे']
          : ['Upward leaf curling, vein thickening, and foliar enations'];
    }
    if (labelId.contains('magnesium')) {
      return lang == 'mr'
          ? ['शिरांमधील पिवळेपणा, शिरा हिरव्या राहणे (Interveinal chlorosis)']
          : ['Symmetrical interveinal chlorosis while main veins remain dark green'];
    }
    return ['Typical foliar pathognomonic lesions with localized tissue necrosis'];
  }

  String _formatDiseaseLabel(String rawId) {
    return rawId
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Color _categoryColor(DiseaseCategory cat) {
    switch (cat) {
      case DiseaseCategory.fungal:
        return Colors.orangeAccent;
      case DiseaseCategory.viral:
        return Colors.purpleAccent;
      case DiseaseCategory.bacterial:
        return Colors.redAccent;
      case DiseaseCategory.nutrient:
      case DiseaseCategory.abiotic:
        return FloraXTheme.bioCyan;
      case DiseaseCategory.pest:
        return Colors.amberAccent;
      case DiseaseCategory.healthy:
        return FloraXTheme.neonGreen;
    }
  }
}

/// CustomPainter rendering multi-region interactive bounding boxes onto the leaf canvas
class MultiRegionBoxPainter extends CustomPainter {
  final List<LeafRegionDiagnosis> regions;
  final LeafRegionDiagnosis? selectedRegion;

  MultiRegionBoxPainter({
    required this.regions,
    this.selectedRegion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < regions.length; i++) {
      final region = regions[i];
      final rect = region.boundingBoxNormalized;

      final double rx = rect.left * size.width;
      final double ry = rect.top * size.height;
      final double rw = rect.width * size.width;
      final double rh = rect.height * size.height;

      final bool isSelected = selectedRegion?.regionId == region.regionId;
      final Color boxColor = isSelected ? FloraXTheme.neonGreen : FloraXTheme.bioCyan.withValues(alpha: 0.70);

      final boxPaint = Paint()
        ..color = boxColor
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;

      final pixelRect = Rect.fromLTWH(rx, ry, rw, rh);
      canvas.drawRRect(RRect.fromRectAndRadius(pixelRect, const Radius.circular(8)), boxPaint);

      final tagPaint = Paint()..color = boxColor.withValues(alpha: 0.20);
      canvas.drawRRect(RRect.fromRectAndRadius(pixelRect, const Radius.circular(8)), tagPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MultiRegionBoxPainter oldDelegate) {
    return oldDelegate.regions != regions || oldDelegate.selectedRegion != selectedRegion;
  }
}

/// CustomPainter rendering thermal attention radial gradients onto the leaf canvas
class ThermalAttentionPainter extends CustomPainter {
  final List<GradCamHotspot> hotspots;
  final GradCamHotspot? selectedHotspot;

  ThermalAttentionPainter({
    required this.hotspots,
    this.selectedHotspot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final hotspot in hotspots) {
      final double cx = (hotspot.x / 100.0) * size.width;
      final double cy = (hotspot.y / 100.0) * size.height;
      final double r = (hotspot.radius / 100.0) * size.width;
      final bool isSelected = selectedHotspot == hotspot;

      final gradient = RadialGradient(
        colors: [
          FloraXTheme.crimsonAlert.withValues(alpha: 0.65 * hotspot.intensity),
          FloraXTheme.amberCaution.withValues(alpha: 0.40 * hotspot.intensity),
          FloraXTheme.neonGreen.withValues(alpha: 0.18 * hotspot.intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
        );

      canvas.drawCircle(Offset(cx, cy), r, paint);

      final ringPaint = Paint()
        ..color = isSelected ? FloraXTheme.neonGreen : Colors.white70
        ..strokeWidth = isSelected ? 2.5 : 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(cx, cy), isSelected ? r * 0.45 : r * 0.35, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ThermalAttentionPainter oldDelegate) {
    return oldDelegate.hotspots != hotspots || oldDelegate.selectedHotspot != selectedHotspot;
  }
}

/// Feature #1: CustomPainter rendering multi-region numbered bounding boxes for detected lesions
class NumberedLesionRegionsPainter extends CustomPainter {
  final List<LesionRegion> regions;

  const NumberedLesionRegionsPainter({required this.regions});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < regions.length; i++) {
      final region = regions[i];
      final rect = region.boundingBoxNormalized;

      final double rx = rect.left * size.width;
      final double ry = rect.top * size.height;
      final double rw = (rect.width * size.width).clamp(24.0, size.width);
      final double rh = (rect.height * size.height).clamp(24.0, size.height);

      final bool isNecrotic = region.lesionType == 'necrotic';
      final Color strokeColor = isNecrotic ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

      final boxPaint = Paint()
        ..color = strokeColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final pixelRect = Rect.fromLTWH(rx, ry, rw, rh);
      canvas.drawRRect(RRect.fromRectAndRadius(pixelRect, const Radius.circular(6)), boxPaint);

      final fillPaint = Paint()..color = strokeColor.withValues(alpha: 0.15);
      canvas.drawRRect(RRect.fromRectAndRadius(pixelRect, const Radius.circular(6)), fillPaint);

      // Number badge in top-left corner
      final badgeCenter = Offset(rx + 10, ry + 10);
      final badgePaint = Paint()..color = strokeColor;
      canvas.drawCircle(badgeCenter, 8.5, badgePaint);

      final textSpan = TextSpan(
        text: '${region.id}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(badgeCenter.dx - (textPainter.width / 2), badgeCenter.dy - (textPainter.height / 2)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NumberedLesionRegionsPainter oldDelegate) {
    return oldDelegate.regions != regions;
  }
}
