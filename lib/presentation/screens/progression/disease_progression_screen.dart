import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../domain/models/florax_models.dart';
import '../../../repositories/firestore_ipm_and_scan_repository.dart';
import '../../../services/auth/auth_role_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../widgets/florax_design_primitives.dart';
import '../scanner/smart_camera_screen.dart';

/// Screen 4 — My Crops & Recovery Tracker (Daylight Kisan Accessible Edition)
class DiseaseProgressionScreen extends ConsumerStatefulWidget {
  const DiseaseProgressionScreen({super.key});

  @override
  ConsumerState<DiseaseProgressionScreen> createState() =>
      _DiseaseProgressionScreenState();
}

class _DiseaseProgressionScreenState
    extends ConsumerState<DiseaseProgressionScreen> {
  String? _activePlantTag;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRoleServiceProvider);
    final String currentUserId = auth.currentUser?.uid ?? 'farmer_anonymous';
    final userPlotsAsync = ref.watch(userPlantPlotsStreamProvider(currentUserId));
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;

    final List<PlantPlotInfo> availablePlots = userPlotsAsync.maybeWhen(
      data: (plots) {
        if (_activePlantTag != null && !plots.any((p) => p.id == _activePlantTag)) {
          return [
            PlantPlotInfo(
              id: _activePlantTag!,
              name: _activePlantTag!,
              vernacular: 'नवीन पीक',
              cropType: 'Field Crop',
            ),
            ...plots,
          ];
        }
        return plots;
      },
      orElse: () => const [],
    );

    final String effectivePlantTag = _activePlantTag ?? (availablePlots.isNotEmpty ? availablePlots.first.id : 'PLANT-TOM-01');

    final progressionAsync = ref.watch(
      plantProgressionStreamProvider(
        PlantProgressionParams(
          userId: currentUserId,
          plantTagId: effectivePlantTag,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Screen Header Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.myCropsTitle,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: FloraXTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Visual Recovery History & Photo Checkpoints',
                            softWrap: true,
                            style: TextStyle(fontSize: 13, color: FloraXTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.plusCircle, color: FloraXTheme.primaryGreen, size: 28),
                      tooltip: 'Track New Crop',
                      onPressed: () => _openTrackNewPlantDialog(context),
                    ),
                  ],
                ),
              ),
            ),

            // Plant Selector Horizontal Carousel
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...availablePlots.map((plot) {
                        final bool isSelected = effectivePlantTag == plot.id;
                        return GestureDetector(
                          onTap: () => setState(() => _activePlantTag = plot.id),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFDCFCE7) : FloraXTheme.cardSurface,
                              borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                              border: Border.all(
                                color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
                                width: isSelected ? 2.0 : 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  plot.name,
                                  style: TextStyle(
                                    color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // Track New Crop Button
                      GestureDetector(
                        onTap: () => _openTrackNewPlantDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: FloraXTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                            border: Border.all(color: FloraXTheme.borderDim, width: 1.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.plus, size: 16, color: FloraXTheme.primaryGreen),
                              SizedBox(width: 6),
                              Text(
                                '+ Add Crop',
                                style: TextStyle(
                                  color: FloraXTheme.primaryGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Prominent "+ Scan Same Crop Again" 56dp CTA Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SmartCameraScreen(initialPlantTag: effectivePlantTag),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.camera, size: 22, color: Colors.white),
                  label: Text(
                    strings.scanSameCropAgain,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloraXTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56), // Required 56dp
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),

            // Main Content: Progression Stream
            progressionAsync.when(
              data: (report) => _buildProgressionContentSlivers(report, effectivePlantTag, strings),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: FloraXTheme.primaryGreen)),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $err', style: const TextStyle(color: FloraXTheme.crimsonAlert)),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionContentSlivers(
    PlantProgressionReport report,
    String plantTag,
    FarmerLocalization strings,
  ) {
    if (report.scans.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FloraXGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(LucideIcons.camera, color: FloraXTheme.primaryGreen, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'No Scans Yet for this Crop',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Capture your first leaf photo to establish a baseline and monitor recovery over time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: FloraXTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SmartCameraScreen(initialPlantTag: plantTag),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.camera, size: 20, color: Colors.white),
                  label: const Text('Scan First Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloraXTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 52),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final LeafScanRecord latestScan = report.scans.last;
    final LeafScanRecord baselineScan = report.scans.first;
    final double delta = double.parse(
      (latestScan.lesionAreaPercent - baselineScan.lesionAreaPercent).toStringAsFixed(1),
    );
    final bool isRecovering = delta <= 0.0;

    return SliverMainAxisGroup(
      slivers: [
        // 1. SIDE-BY-SIDE BEFORE VS AFTER PHOTO COMPARISON CARD
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildBeforeAfterComparisonCard(
              baselineScan: baselineScan,
              latestScan: latestScan,
              delta: delta,
              isRecovering: isRecovering,
              strings: strings,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // 2. COLLAPSIBLE "VIEW PROGRESS GRAPH" SECTION
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCollapsibleProgressGraph(report.scans, strings),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // 3. VISUAL PHOTO TIMELINE GRID/CARDS OF PAST SCANS
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.history, color: FloraXTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      strings.pastScans,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '${report.scans.length} Checkpoints',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FloraXTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // Timeline Grid / Cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final scan = report.scans[report.scans.length - 1 - index];
                final scanNum = report.scans.length - index;
                return _buildTimelineGridCard(scan, scanNum);
              },
              childCount: report.scans.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeforeAfterComparisonCard({
    required LeafScanRecord baselineScan,
    required LeafScanRecord latestScan,
    required double delta,
    required bool isRecovering,
    required FarmerLocalization strings,
  }) {
    return FloraXGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Smiling / Improving Visual Trend Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Recovery Comparison',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              // Trend Pill (Getting Better / Needs Check)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isRecovering ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                  border: Border.all(
                    color: isRecovering ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRecovering ? LucideIcons.smile : LucideIcons.alertCircle,
                      size: 16,
                      color: isRecovering ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRecovering ? strings.gettingBetter : strings.needsCheck,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isRecovering ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Side-by-side Before vs. After Photos
          Row(
            children: [
              // Before Photo (Day 1)
              Expanded(
                child: _buildComparisonPhotoTile(
                  title: 'Day 1 (Before)',
                  date: '${baselineScan.timestamp.day}/${baselineScan.timestamp.month}',
                  lesionPercent: baselineScan.lesionAreaPercent,
                  imageSource: baselineScan.thumbnailBase64?.isNotEmpty == true
                      ? baselineScan.thumbnailBase64!
                      : baselineScan.imageUrl,
                ),
              ),
              const SizedBox(width: 10),

              // After Photo (Current)
              Expanded(
                child: _buildComparisonPhotoTile(
                  title: 'Today (Latest)',
                  date: '${latestScan.timestamp.day}/${latestScan.timestamp.month}',
                  lesionPercent: latestScan.lesionAreaPercent,
                  imageSource: latestScan.thumbnailBase64?.isNotEmpty == true
                      ? latestScan.thumbnailBase64!
                      : latestScan.imageUrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delta Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRecovering ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRecovering
                      ? '✓ Leaf health improved by ${delta.abs()}%'
                      : '⚠ Damage spread by +$delta%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isRecovering ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
                Text(
                  isRecovering ? '🟢 Safe' : '🔴 Check',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonPhotoTile({
    required String title,
    required String date,
    required double lesionPercent,
    required String imageSource,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FloraXTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FloraXTheme.borderDim, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: FloraXAdaptiveImage(
                imageSource: imageSource,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary)),
                Text(date, style: const TextStyle(fontSize: 10, color: FloraXTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleProgressGraph(List<LeafScanRecord> scans, FarmerLocalization strings) {
    return ExpansionTile(
      title: Text(
        strings.viewProgressGraph,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: FloraXTheme.textSecondary,
        ),
      ),
      leading: const Icon(LucideIcons.lineChart, color: FloraXTheme.primaryGreen, size: 20),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        FloraXGlassCard(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 40,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: scans.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.lesionAreaPercent)).toList(),
                    isCurved: true,
                    color: FloraXTheme.primaryGreen,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: FloraXTheme.primaryGreen.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineGridCard(LeafScanRecord scan, int scanNum) {
    final double pct = scan.lesionAreaPercent;
    final dotColor = pct < 15.0
        ? const Color(0xFF15803D)
        : (pct < 40.0 ? const Color(0xFFB45309) : const Color(0xFFB91C1C));

    return FloraXGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(FloraXTheme.radiusXl)),
                  child: FloraXAdaptiveImage(
                    imageSource: scan.thumbnailBase64?.isNotEmpty == true
                        ? scan.thumbnailBase64!
                        : scan.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                // Date Badge + Traffic-Light Dot
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
                        const SizedBox(width: 5),
                        Text(
                          '${scan.timestamp.day}/${scan.timestamp.month}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scan #$scanNum', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary)),
                Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dotColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openTrackNewPlantDialog(BuildContext context) {
    final tagController = TextEditingController(
      text: 'PLANT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FloraXTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Crop Plot', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tagController,
              decoration: const InputDecoration(labelText: 'Plot ID Tag'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final tag = tagController.text.trim();
              if (tag.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _activePlantTag = tag);
              }
            },
            child: const Text('Save & Track'),
          ),
        ],
      ),
    );
  }
}
