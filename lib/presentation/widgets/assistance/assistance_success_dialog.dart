import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Standard Confirmation Modal for all 6 Assistance Applications.
/// Displays generated `KS-AID-...` ticket ID with immediate tracking routing.
void showAssistanceSuccessDialog({
  required BuildContext context,
  required String ticketId,
  required String categoryTitle,
  required String summaryText,
  bool isUrgent = false,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final loc = ref.watch(farmerLocalizationProvider);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(22),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isUrgent ? const Color(0xFFFEE2E2) : AppTheme.pistachioPill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUrgent ? LucideIcons.alertTriangle : LucideIcons.checkCheck,
                  color: isUrgent ? AppTheme.alertRed : AppTheme.forestGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isUrgent ? loc.tr('urgent_claim_registered') : loc.tr('application_submitted'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isUrgent ? AppTheme.alertRed : AppTheme.forestGreen,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.tr('reference_id'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      ticketId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summaryText,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.35),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context); // Return to previous screen/hub
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(loc.btnClose),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.assistanceHub,
                          (route) => route.isFirst,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUrgent ? AppTheme.alertRed : AppTheme.forestGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(loc.tr('track_status'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
