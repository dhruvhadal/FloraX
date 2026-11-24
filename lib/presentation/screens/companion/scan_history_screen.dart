import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/scan_history_repository.dart';
import '../../../domain/models/florax_models.dart';

/// Screen — Scan History & Diagnostics Telemetry (`scan_history_screen`)
/// Chronological list of recorded scans from local SQLite cache and Cloud Firestore.
/// Tapping any scan opens DiagnosisDetailsScreen.
class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(farmerLocalizationProvider);
    final historyRepo = ref.watch(scanHistoryRepositoryProvider);
    final historyFuture = historyRepo.getLocalScanLogs();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppTheme.forestGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.tr('past_scans'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.forestGreen),
        ),
      ),
      body: FutureBuilder<List<ScanLogEntry>>(
        future: historyFuture,
        builder: (context, snapshot) {
          final scans = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.forestGreen));
          }

          if (scans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.history, size: 54, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      loc.tr('past_scans'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.tr('first_scan_desc'),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.forestGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: Text(loc.tr('start_first_scan'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.scanner),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: scans.length,
            itemBuilder: (context, idx) {
              final scan = scans[idx];
              final percent = (scan.confidence * 100).toStringAsFixed(1);
              final isBiotic = scan.safetyState == ClinicalSafetyState.confirmedBiotic;
              final isAbiotic = scan.safetyState == ClinicalSafetyState.abioticStress;

              return InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.diagnosis,
                    arguments: scan,
                  );
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: AppTheme.softCardShadow,
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Container(
                          width: 58,
                          height: 58,
                          color: AppTheme.surfaceContainerLow,
                          child: scan.thumbnailBase64 != null && scan.thumbnailBase64!.isNotEmpty
                              ? Image.memory(
                                  base64Decode(scan.thumbnailBase64!.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(LucideIcons.leaf, color: AppTheme.forestGreen),
                                )
                              : const Icon(LucideIcons.leaf, color: AppTheme.forestGreen),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  scan.crop,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isBiotic
                                        ? AppTheme.errorContainer
                                        : (isAbiotic ? AppTheme.abioticContainer : AppTheme.pistachioContainer),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                  ),
                                  child: Text(
                                    '$percent%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isBiotic
                                          ? AppTheme.alertRed
                                          : (isAbiotic ? AppTheme.onAbioticContainer : AppTheme.forestGreen),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              scan.canonicalId.replaceAll('_', ' '),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${scan.flxScanId} • ${_formatDate(scan.timestamp)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.outline),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
