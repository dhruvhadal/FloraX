import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

/// Reusable full-width submit button with loading state & optional emergency styling
class AssistanceSubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isSubmitting;
  final bool isEmergency;
  final IconData icon;

  const AssistanceSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isSubmitting = false,
    this.isEmergency = false,
    this.icon = LucideIcons.send,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isEmergency ? AppTheme.alertRed : AppTheme.forestGreen;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.6),
          elevation: isEmergency ? 2 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
