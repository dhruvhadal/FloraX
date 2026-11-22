import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/florax_theme.dart';
import '../../services/auth/auth_role_service.dart';
import '../../services/voice/vernacular_voice_service.dart';
import '../../services/voice/voice_guide_service.dart';
import '../screens/kvk/kvk_scientist_console_sheet.dart';
import '../screens/ngo/leafguard_connect_screen.dart';

/// Lightweight Daylight Kisan Card with crisp white surface and outdoor-readable 1.5px border
class FloraXGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const FloraXGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FloraXTheme.spaceMd),
    this.margin,
    this.borderRadius = FloraXTheme.radiusXl,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.5,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? FloraXTheme.cardSurface;
    final effectiveBorder = borderColor ?? FloraXTheme.borderDim;

    Widget cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: borderWidth),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Accessible Status Pill for Confidence, Severity, Offline-Sync & Credentials
class FloraXStatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color? backgroundColor;
  final bool isGlowing;
  final bool isOutlined;
  final double fontSize;
  final VoidCallback? onTap;

  const FloraXStatusPill({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.backgroundColor,
    this.isGlowing = false,
    this.isOutlined = false,
    this.fontSize = 12.0,
    this.onTap,
  });

  /// Factory for Confidence Badges (≥75% Bio-Green vs <75% Amber Guardrail)
  factory FloraXStatusPill.confidence({
    required double confidence,
    String? customPrefix,
  }) {
    final isHigh = confidence >= 0.75;
    final pctStr = '${(confidence * 100).toStringAsFixed(0)}%';
    final text = customPrefix != null
        ? '$customPrefix: $pctStr'
        : (isHigh ? 'AI Verified $pctStr' : 'Ask Expert ($pctStr)');
    final color = isHigh ? const Color(0xFF15803D) : const Color(0xFFB45309);
    final bg = isHigh ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);

    return FloraXStatusPill(
      label: text,
      icon: isHigh ? LucideIcons.shieldCheck : LucideIcons.alertTriangle,
      color: color,
      backgroundColor: bg,
      isGlowing: false,
    );
  }

  /// Factory for 3-Tier Severity Badges (Mild, Moderate, Severe)
  factory FloraXStatusPill.severity({required String severityLevel}) {
    final upper = severityLevel.toUpperCase();
    Color color = const Color(0xFF15803D);
    Color bg = const Color(0xFFDCFCE7);
    IconData icon = LucideIcons.checkCircle;

    if (upper == 'MODERATE' || upper == 'MEDIUM') {
      color = const Color(0xFFB45309);
      bg = const Color(0xFFFEF3C7);
      icon = LucideIcons.alertCircle;
    } else if (upper == 'SEVERE' || upper == 'CRITICAL' || upper == 'HIGH') {
      color = const Color(0xFFB91C1C);
      bg = const Color(0xFFFEE2E2);
      icon = LucideIcons.alertOctagon;
    }

    return FloraXStatusPill(
      label: upper,
      icon: icon,
      color: color,
      backgroundColor: bg,
      isGlowing: false,
    );
  }

  /// Factory for ICAR / Institutional Verification Badges
  factory FloraXStatusPill.verifiedInstitution({required String institutionName}) {
    return FloraXStatusPill(
      label: institutionName,
      icon: LucideIcons.award,
      color: const Color(0xFF15803D),
      backgroundColor: const Color(0xFFDCFCE7),
      isOutlined: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? color.withValues(alpha: 0.12);

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
        border: Border.all(
          color: isOutlined ? color.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 3, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: pill,
      );
    }
    return pill;
  }
}

/// Farmer-First Traffic Light Semantic Banner (Color + Icon + Text)
class FarmerSemanticBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onAudioTap;
  final bool isAudioPlaying;

  const FarmerSemanticBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onAudioTap,
    this.isAudioPlaying = false,
  });

  factory FarmerSemanticBanner.healthy({
    required String title,
    String? subtitle,
    VoidCallback? onAudioTap,
    bool isAudioPlaying = false,
  }) {
    return FarmerSemanticBanner(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.checkCircle2,
      backgroundColor: FloraXTheme.bannerHealthyBg,
      foregroundColor: FloraXTheme.bannerHealthyText,
      onAudioTap: onAudioTap,
      isAudioPlaying: isAudioPlaying,
    );
  }

  factory FarmerSemanticBanner.caution({
    required String title,
    String? subtitle,
    VoidCallback? onAudioTap,
    bool isAudioPlaying = false,
  }) {
    return FarmerSemanticBanner(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.alertTriangle,
      backgroundColor: FloraXTheme.bannerCautionBg,
      foregroundColor: FloraXTheme.bannerCautionText,
      onAudioTap: onAudioTap,
      isAudioPlaying: isAudioPlaying,
    );
  }

  factory FarmerSemanticBanner.danger({
    required String title,
    String? subtitle,
    VoidCallback? onAudioTap,
    bool isAudioPlaying = false,
  }) {
    return FarmerSemanticBanner(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.shieldAlert,
      backgroundColor: FloraXTheme.bannerDangerBg,
      foregroundColor: FloraXTheme.bannerDangerText,
      onAudioTap: onAudioTap,
      isAudioPlaying: isAudioPlaying,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: foregroundColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: foregroundColor.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAudioTap != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isAudioPlaying ? LucideIcons.volumeX : LucideIcons.volume2,
                color: foregroundColor,
                size: 24,
              ),
              onPressed: onAudioTap,
              tooltip: 'Listen Aloud',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Large Recognizable "Listen / ऐका / सुनें" Pill Button with Active Speaking Pulse
class FarmerAudioPill extends ConsumerWidget {
  final String textToSpeak;
  final String? customLabel;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const FarmerAudioPill({
    super.key,
    required this.textToSpeak,
    this.customLabel,
    this.height = 48,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final isSpeaking = voiceGuide.isSpeaking;

    final defaultLabel = isSpeaking
        ? voiceGuide.strings.stopListening
        : (activeLang == FarmerLanguage.marathi
            ? '🔊 ऐका'
            : (activeLang == FarmerLanguage.hindi ? '🔊 सुनें' : '🔊 Listen'));

    final label = customLabel ?? defaultLabel;
    final bg = backgroundColor ?? (isSpeaking ? const Color(0xFFDCFCE7) : FloraXTheme.cardSurface);
    final fg = foregroundColor ?? (isSpeaking ? const Color(0xFF146C38) : FloraXTheme.primaryGreen);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          voiceGuide.speak(textToSpeak, lang: activeLang);
        },
        borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
            border: Border.all(
              color: isSpeaking ? const Color(0xFF146C38) : FloraXTheme.borderDim,
              width: isSpeaking ? 2.0 : 1.5,
            ),
            boxShadow: isSpeaking
                ? [
                    BoxShadow(
                      color: const Color(0xFF146C38).withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSpeaking ? LucideIcons.volumeX : LucideIcons.volume2,
                color: fg,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (isSpeaking) ...[
                const SizedBox(width: 8),
                _PulsingAudioWaves(color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingAudioWaves extends StatefulWidget {
  final Color color;
  const _PulsingAudioWaves({required this.color});

  @override
  State<_PulsingAudioWaves> createState() => _PulsingAudioWavesState();
}

class _PulsingAudioWavesState extends State<_PulsingAudioWaves> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final val = _animController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 8 + (val * 8), color: widget.color, margin: const EdgeInsets.symmetric(horizontal: 1.5)),
            Container(width: 3, height: 16 - (val * 8), color: widget.color, margin: const EdgeInsets.symmetric(horizontal: 1.5)),
            Container(width: 3, height: 10 + (val * 6), color: widget.color, margin: const EdgeInsets.symmetric(horizontal: 1.5)),
          ],
        );
      },
    );
  }
}

/// Universal Top Utility Bar conforming strictly to Daylight Kisan specifications
class FloraXTopUtilityBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final String activeLang;
  final ValueChanged<String>? onLangChanged;

  const FloraXTopUtilityBar({
    super.key,
    this.onMenuPressed,
    this.activeLang = 'mr',
    this.onLangChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFarmerLang = ref.watch(activeFarmerLanguageProvider);
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final auth = ref.watch(authRoleServiceProvider);
    final isKvk = auth.currentRole == UserRole.kvkScientist;

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 10,
        right: 10,
      ),
      decoration: const BoxDecoration(
        color: FloraXTheme.cardSurface,
        border: Border(
          bottom: BorderSide(color: FloraXTheme.borderDim, width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Menu & Brand Identity (wrapped in Expanded + Flexible to prevent RenderFlex overflow)
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMenuPressed != null) ...[
                  IconButton(
                    icon: const Icon(LucideIcons.menu, color: FloraXTheme.textPrimary, size: 22),
                    onPressed: onMenuPressed,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  const SizedBox(width: 2),
                ],
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: FloraXTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'FloraX',
                          style: TextStyle(
                            color: FloraXTheme.primaryGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: ' • ',
                          style: TextStyle(
                            color: FloraXTheme.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'LeafGuard',
                          style: TextStyle(
                            color: FloraXTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Right: Language Switcher Pill + Partner Portal Chip (guaranteed to fit at 320dp - 360dp)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clean 3-Language Switcher (EN | हिं | मरा)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: FloraXTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                  border: Border.all(color: FloraXTheme.borderDim, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLangOption(
                      code: 'en',
                      label: 'EN',
                      isSelected: activeFarmerLang == FarmerLanguage.english,
                      onTap: () {
                        ref.read(activeFarmerLanguageProvider.notifier).state = FarmerLanguage.english;
                        voiceGuide.setLanguage(FarmerLanguage.english);
                        onLangChanged?.call('en');
                      },
                    ),
                    const Text('·', style: TextStyle(color: FloraXTheme.textMuted, fontSize: 10)),
                    _buildLangOption(
                      code: 'hi',
                      label: 'हिं',
                      isSelected: activeFarmerLang == FarmerLanguage.hindi,
                      onTap: () {
                        ref.read(activeFarmerLanguageProvider.notifier).state = FarmerLanguage.hindi;
                        voiceGuide.setLanguage(FarmerLanguage.hindi);
                        onLangChanged?.call('hi');
                      },
                    ),
                    const Text('·', style: TextStyle(color: FloraXTheme.textMuted, fontSize: 10)),
                    _buildLangOption(
                      code: 'mr',
                      label: 'मरा',
                      isSelected: activeFarmerLang == FarmerLanguage.marathi,
                      onTap: () {
                        ref.read(activeFarmerLanguageProvider.notifier).state = FarmerLanguage.marathi;
                        voiceGuide.setLanguage(FarmerLanguage.marathi);
                        onLangChanged?.call('mr');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Partner / KVK Portal Icon Chip
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showPartnerPortalSheet(context, isKvk),
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isKvk ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                      border: Border.all(
                        color: isKvk ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      isKvk ? LucideIcons.clipboardCheck : LucideIcons.building,
                      size: 15,
                      color: isKvk ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangOption({
    required String code,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? FloraXTheme.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : FloraXTheme.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static void _showPartnerPortalSheet(BuildContext context, bool isKvk) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FloraXTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Partner & Institutional Portal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: FloraXTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: FloraXTheme.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.heartHandshake, color: Color(0xFF15803D)),
                  ),
                  title: const Text('Screen 7 — NGO & FPO Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Verified grassroots field partners & grants directory'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: FloraXTheme.borderDim),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LeafGuardConnectScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.clipboardCheck, color: Color(0xFFB45309)),
                  ),
                  title: const Text('Screen 8 — KVK Scientist Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Clinical case verification (<75%) & advisory overrides'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: FloraXTheme.borderDim),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KvkScientistConsoleSheet()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Docked Vernacular Voice Assistant Bar (Kisan Vani)
class FloraXDockedVoiceBar extends ConsumerWidget {
  final VernacularVoiceState voiceState;

  const FloraXDockedVoiceBar({
    super.key,
    required this.voiceState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isListening = voiceState.isListening;
    final recognizedText = voiceState.currentTranscription;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FloraXTheme.cardSurface,
        borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
        border: Border.all(
          color: isListening ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
          width: isListening ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          ref.read(vernacularVoiceStateProvider.notifier).listen();
        },
        borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening ? FloraXTheme.primaryGreen : const Color(0xFFDCFCE7),
              ),
              child: Icon(
                LucideIcons.mic,
                size: 20,
                color: isListening ? Colors.white : const Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isListening
                    ? (recognizedText.isNotEmpty ? recognizedText : 'ऐकत आहे... (Listening)')
                    : 'बोला: पान स्कॅन करा / Speak command',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isListening ? FloraXTheme.primaryGreen : FloraXTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: isListening ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            Icon(
              LucideIcons.activity,
              size: 20,
              color: isListening ? FloraXTheme.primaryGreen : FloraXTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an image adaptively across local disk storage, Base64 strings, or Network URLs
class FloraXAdaptiveImage extends StatelessWidget {
  final String? imageSource;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FloraXAdaptiveImage({
    super.key,
    this.imageSource,
    this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildRawImage(context);
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  Widget _buildRawImage(BuildContext context) {
    if (bytes != null && bytes!.isNotEmpty) {
      return Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _buildError(context),
      );
    }

    final src = imageSource?.trim();
    if (src == null || src.isEmpty) {
      return _buildError(context);
    }

    // 1. Data URI / Base64 string
    if (src.startsWith('data:image/') || (!src.startsWith('http') && src.length > 200 && !src.contains('/') && !src.contains(r'\'))) {
      try {
        final rawBase64 = src.contains(',') ? src.split(',').last : src;
        final cleanBase64 = rawBase64.replaceAll(RegExp(r'\s+'), '');
        final decoded = base64Decode(cleanBase64);
        return Image.memory(
          decoded,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, stack) => _buildError(context),
        );
      } catch (e) {
        return _buildError(context);
      }
    }

    // 2. HTTP/HTTPS Network URL
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: FloraXTheme.surfaceContainerHigh,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: FloraXTheme.primaryGreen,
                    ),
                  ),
                ),
              );
        },
        errorBuilder: (ctx, err, stack) => _buildError(context),
      );
    }

    // 3. Local filesystem path or file:// URI
    try {
      String filePath = src;
      if (filePath.startsWith('file://')) {
        filePath = Uri.parse(filePath).toFilePath();
      }
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, stack) => _buildError(context),
        );
      }
    } catch (_) {}

    return _buildError(context);
  }

  Widget _buildError(BuildContext context) {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: FloraXTheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: const Icon(
            LucideIcons.imageOff,
            color: FloraXTheme.textMuted,
            size: 28,
          ),
        );
  }
}
