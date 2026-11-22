import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../domain/models/florax_models.dart';
import '../../../repositories/firestore_ipm_and_scan_repository.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../widgets/florax_design_primitives.dart';
import '../experts/expert_directory_screen.dart';

/// Screen 3 — Step-by-Step Cure Guide (Daylight Kisan Accessible Edition)
class CureGuideScreen extends ConsumerStatefulWidget {
  final IcarIpmProtocol protocol;
  final String scanId;
  final VerificationStatus initialVerificationStatus;
  final bool requiresKvkReview;
  final double topConfidence;
  final String cropName;

  final bool isEarlyStage;

  const CureGuideScreen({
    super.key,
    required this.protocol,
    required this.scanId,
    required this.initialVerificationStatus,
    required this.requiresKvkReview,
    required this.topConfidence,
    this.cropName = 'Tomato',
    this.isEarlyStage = false,
  });

  @override
  ConsumerState<CureGuideScreen> createState() => _CureGuideScreenState();
}

class _CureGuideScreenState extends ConsumerState<CureGuideScreen> {
  @override
  Widget build(BuildContext context) {
    final activeFarmerLang = ref.watch(activeFarmerLanguageProvider);
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;
    final langCode = activeFarmerLang.code;

    // Listen to real-time Firestore verification updates
    final scanAsync = ref.watch(scanVerificationStreamProvider(widget.scanId));
    final LeafScanRecord? liveScan = scanAsync.value;
    final VerificationStatus currentStatus = liveScan?.verificationStatus ?? widget.initialVerificationStatus;
    final bool isKvkConfirmed = currentStatus == VerificationStatus.kvkConfirmed;
    final bool isChemicalLocked = widget.requiresKvkReview && !isKvkConfirmed;
    final bool isAbiotic = widget.protocol.isAbioticNutrientDeficiency;

    final String localizedDiseaseName = widget.protocol.diseaseName[langCode] ??
        widget.protocol.diseaseName['en'] ??
        widget.protocol.scientificName;

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      appBar: AppBar(
        title: Text(strings.cureGuideTitle),
        backgroundColor: FloraXTheme.cardSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: FloraXTheme.textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Condition Summary Card with Full-Length Audio Read-Aloud
              FloraXGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.cropName} • $localizedDiseaseName',
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: FloraXTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAbiotic
                                    ? 'Nutrient Deficiency (Non-Infectious)'
                                    : 'Scientific: ${widget.protocol.scientificName}',
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: FloraXTheme.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FarmerAudioPill(
                          textToSpeak: voiceGuide.buildCureSpokenScript(
                            protocol: widget.protocol,
                            isChemicalLocked: isChemicalLocked || isAbiotic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Feature #3: Early Stage Recognition Banner
              if (widget.isEarlyStage || (liveScan?.isEarlyStageAlert == true)) ...[
                _buildEarlyStageBanner(langCode),
                const SizedBox(height: 16),
              ],

              // Visual Dosage Pictogram Strip
              _buildDosagePictogramStrip(strings, isChemicalLocked || isAbiotic),
              const SizedBox(height: 16),

              // STEP 1: Field Care & Soil Sanitation
              _buildStepCard(
                stepNumber: 1,
                title: strings.step1Title,
                icon: LucideIcons.sprout,
                accentColor: const Color(0xFF15803D),
                accentBg: const Color(0xFFDCFCE7),
                lines: widget.protocol.tier1Cultural[langCode] ??
                    widget.protocol.tier1Cultural['en'] ??
                    ['Ensure good field drainage', 'Remove infected fallen leaves'],
                voiceGuide: voiceGuide,
              ),
              const SizedBox(height: 14),

              // STEP 2: Natural / Bio Spray
              _buildStepCard(
                stepNumber: 2,
                title: strings.step2Title,
                icon: LucideIcons.flaskConical,
                accentColor: const Color(0xFF0369A1),
                accentBg: const Color(0xFFE0F2FE),
                lines: widget.protocol.tier2Biological[langCode] ??
                    widget.protocol.tier2Biological['en'] ??
                    ['Spray 5% Neem Seed Kernel Extract (NSKE)', 'Apply Trichoderma viride @ 5g/L'],
                voiceGuide: voiceGuide,
              ),
              const SizedBox(height: 14),

              // STEP 3: Safe Medicine OR Safety Lock Card
              if (isChemicalLocked || isAbiotic)
                _buildSafetyLockCard(context, strings, isAbiotic)
              else
                _buildStepCard(
                  stepNumber: 3,
                  title: strings.step3Title,
                  icon: LucideIcons.shieldCheck,
                  accentColor: const Color(0xFF15803D),
                  accentBg: const Color(0xFFDCFCE7),
                  lines: [
                    'Medicine: ${widget.protocol.tier3Chemical.formulationName}',
                    'Dose: ${widget.protocol.tier3Chemical.dosagePerLitre} • Pre-harvest: ${widget.protocol.tier3Chemical.waitingPeriodDays} days',
                  ],
                  voiceGuide: voiceGuide,
                ),
              const SizedBox(height: 16),

              // Compact ICAR Reference & Molecule Details (Collapsible)
              _buildIcarReferenceTile(strings),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDosagePictogramStrip(FarmerLocalization strings, bool isChemicalLocked) {
    return FloraXGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPRAY GUIDELINES (फवारणी नियम)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: FloraXTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPictogramItem(icon: LucideIcons.droplets, label: strings.dosageTank),
              Container(width: 1, height: 36, color: FloraXTheme.borderDim),
              _buildPictogramItem(icon: LucideIcons.utensils, label: strings.dosageDose),
              Container(width: 1, height: 36, color: FloraXTheme.borderDim),
              _buildPictogramItem(icon: LucideIcons.sun, label: strings.dosageTime),
              Container(width: 1, height: 36, color: FloraXTheme.borderDim),
              _buildPictogramItem(icon: LucideIcons.shield, label: strings.dosagePpe),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPictogramItem({required IconData icon, required String label}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FloraXTheme.primaryGreen, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: FloraXTheme.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color accentBg,
    required List<String> lines,
    required VoiceGuideService voiceGuide,
  }) {
    final previewText = lines.take(2).join('. ');

    return FloraXGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(icon, color: accentColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: FloraXTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.volume2, color: FloraXTheme.primaryGreen, size: 22),
                tooltip: 'Listen to Step $stepNumber',
                onPressed: () => voiceGuide.speak(previewText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines.take(2).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: FloraXTheme.textPrimary,
                            height: 1.4,
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
  }

  Widget _buildSafetyLockCard(BuildContext context, FarmerLocalization strings, bool isAbiotic) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.lock, color: Color(0xFFB45309), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.safetyLockTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAbiotic
                ? 'अन्नद्रव्य कमतरतेवर रासायनिक बुरशीनाशके चालत नाहीत. आधी माती परीक्षण व सेंद्रिय खतांचा वापर करा.'
                : strings.safetyLockDesc,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF78350F),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpertDirectoryScreen()),
              );
            },
            icon: const Icon(LucideIcons.phoneCall, size: 20, color: Colors.white),
            label: Text(strings.verifyWithKvk),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FloraXTheme.radiusLg),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcarReferenceTile(FarmerLocalization strings) {
    return ExpansionTile(
      title: Text(
        strings.icarAttribution,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: FloraXTheme.textSecondary,
        ),
      ),
      leading: const Icon(LucideIcons.award, color: FloraXTheme.primaryGreen, size: 20),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FloraXTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(FloraXTheme.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Molecule: ${widget.protocol.tier3Chemical.activeIngredient}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary)),
              const SizedBox(height: 4),
              Text('CIBRC Registration: ${widget.protocol.tier3Chemical.cibrcRegistrationNumber}',
                  style: const TextStyle(fontSize: 12, color: FloraXTheme.textSecondary)),
              const SizedBox(height: 4),
              Text('Economic Threshold (ETL): ${widget.protocol.tier3Chemical.economicThreshold}',
                  style: const TextStyle(fontSize: 12, color: FloraXTheme.textSecondary)),
              const SizedBox(height: 4),
              Text('Antidote Statement: ${widget.protocol.tier3Chemical.antidoteStatement}',
                  style: const TextStyle(fontSize: 12, color: FloraXTheme.textSecondary)),
              const SizedBox(height: 6),
              const Text(
                'Source: ICAR - All India Coordinated Research Project on Crop Pathology & CIBRC 2026 guidelines.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: FloraXTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarlyStageBanner(String langCode) {
    final String title = langCode == 'mr'
        ? '⚡ रोगाची प्राथमिक अवस्था — पीक वाचवण्यासाठी त्वरित उपाय करा'
        : (langCode == 'hi'
            ? '⚡ प्रारंभिक अवस्था पकड़ी गई — फसल बचाने के लिए तुरंत उपचार करें'
            : '⚡ Early Stage Caught — Treat Now to Save Crop');
    final String subtitle = langCode == 'mr'
        ? 'संसर्ग सुरुवातीच्या टप्प्यात आहे. जैविक कीटकनाशक (स्टेप २) व स्वच्छता (स्टेप १) याद्वारे रोग १००% आटोक्यात आणा.'
        : (langCode == 'hi'
            ? 'संक्रमण शुरुआती स्तर पर है. जैविक उपचार (स्टेप २) और स्वच्छता द्वारा फसल बचाएं.'
            : 'Early stage caught. Prioritize cultural sanitation and bio-sprays to prevent spread.');

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
}
