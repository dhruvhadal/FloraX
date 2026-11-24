import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/expert_directory_repository.dart';
import '../../../domain/models/florax_models.dart';

/// Screen 8 — Agricultural Experts & 2nd-Opinion Hub (`agricultural_experts`)
/// Features live consultations tracker banner, multi-discipline filters,
/// verified expert cards, and integrated 2nd-opinion submission with pre-attached scan support.
class AgriculturalExpertsScreen extends ConsumerStatefulWidget {
  final String? attachedScanId;
  final String? canonicalId;

  const AgriculturalExpertsScreen({
    super.key,
    this.attachedScanId,
    this.canonicalId,
  });

  @override
  ConsumerState<AgriculturalExpertsScreen> createState() => _AgriculturalExpertsScreenState();
}

class _AgriculturalExpertsScreenState extends ConsumerState<AgriculturalExpertsScreen> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'plant_pathologist',
    'agronomist',
    'botanist',
    'entomologist',
    'horticulturist',
  ];

  final Map<String, String> _categoryDisplayNames = {
    'ALL': 'All Specialists (सर्व तज्ज्ञ)',
    'plant_pathologist': 'Pathologists (रोग शास्त्रज्ञ)',
    'agronomist': 'Agronomists (कृषी शास्त्रज्ञ)',
    'botanist': 'Botanists (वनस्पतीशास्त्र)',
    'entomologist': 'Entomologists (कीटकशास्त्र)',
    'horticulturist': 'Horticulturists (फलोत्पादन)',
  };

  @override
  void initState() {
    super.initState();
    // If opened with pre-attached scan, trigger 2nd-opinion modal automatically
    if (widget.attachedScanId != null && widget.attachedScanId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptSecondOpinionModal(
          context,
          ExpertDirectoryRepository.seededExperts.first,
          widget.attachedScanId,
          widget.canonicalId,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final loc = ref.watch(farmerLocalizationProvider);
    final expertRepo = ref.watch(expertDirectoryRepositoryProvider);

    // Watch active farmer mobile for consultation tracking
    final farmerMobile = '+919876543210'; // Default E.164 fallback
    final consultationsStream = expertRepo.watchFarmerConsultations(farmerMobile);
    final expertsStream = expertRepo.watchExperts(discipline: _selectedCategory);

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
          activeLang == FarmerLanguage.marathi
              ? 'कृषी तज्ज्ञ व सल्लागार'
              : (activeLang == FarmerLanguage.hindi
                  ? 'कृषि विशेषज्ञ व परामर्श'
                  : 'Agricultural Experts Desk'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.forestGreen,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =================================================================
            // 1. TOP "MY CONSULTATIONS" LIVE TRACKER BANNER
            // =================================================================
            StreamBuilder<List<ConsultationRequest>>(
              stream: consultationsStream,
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                final pending = list.where((c) => c.status == 'REQUESTED' || c.status == 'PENDING').length;
                final completed = list.where((c) => c.status == 'CONFIRMED' || c.status == 'RESOLVED').length;

                return InkWell(
                  onTap: () => _showMyConsultationsModal(context, list, activeLang),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      boxShadow: AppTheme.softCardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppTheme.pistachioPill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.clipboardCheck, color: AppTheme.forestGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.tr('my_icar_consultations'),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                              ),
                              Text(
                                loc.tr('live_opinion_tracker'),
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        _buildTrackerPill('$pending Pending', AppTheme.warningContainer, AppTheme.warningAmber),
                        const SizedBox(width: 6),
                        _buildTrackerPill('$completed Done', AppTheme.pistachioContainer, AppTheme.forestGreen),
                      ],
                    ),
                  ),
                );
              },
            ),

            // =================================================================
            // 2. SEARCH BAR
            // =================================================================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: ref.watch(farmerLocalizationProvider).tr('search_expert_hint'),
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.forestGreen),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // =================================================================
            // 3. HORIZONTALLY SCROLLABLE DISCIPLINE CATEGORY PILLS
            // =================================================================
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final displayName = _categoryDisplayNames[cat] ?? cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.forestGreen : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(
                              color: isSelected ? AppTheme.forestGreen : AppTheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // =================================================================
            // 4. VERIFIED EXPERT PROFILE CARDS
            // =================================================================
            StreamBuilder<List<VerifiedExpert>>(
              stream: expertsStream,
              builder: (context, snapshot) {
                final allExperts = snapshot.data ?? ExpertDirectoryRepository.seededExperts;

                final filtered = allExperts.where((exp) {
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    return exp.name.toLowerCase().contains(query) ||
                        exp.institution.toLowerCase().contains(query) ||
                        exp.district.toLowerCase().contains(query) ||
                        exp.category.toLowerCase().contains(query);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.userX, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            loc.tr('no_matching_experts_found'),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final expert = filtered[idx];
                    return _buildExpertCard(context, expert, activeLang);
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackerPill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildExpertCard(BuildContext context, VerifiedExpert expert, FarmerLanguage activeLang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softCardShadow,
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with online status
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.pistachioPill,
                child: Text(
                  expert.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.forestGreen, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expert.name,
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.checkCircle2, size: 15, color: AppTheme.harvestGold),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expert.qualification,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                    ),
                    Text(
                      '${expert.institution} • ${expert.district}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.surfaceContainer),
          const SizedBox(height: 10),

          // Languages & Verified Attribution
          Row(
            children: [
              const Icon(LucideIcons.languages, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                expert.languages.join(' • '),
                style: const TextStyle(fontSize: 11.5, color: AppTheme.onSurfaceVariant),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.pistachioContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  expert.verifiedBy,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.forestGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Actions: Phone Call & Request 2nd Opinion
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 38),
                  foregroundColor: AppTheme.forestGreen,
                  side: const BorderSide(color: AppTheme.forestGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
                icon: const Icon(LucideIcons.phone, size: 14),
                label: Text(ref.watch(farmerLocalizationProvider).tr('call_desk'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () {
                  final loc = ref.read(farmerLocalizationProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${loc.tr('calling_expert')} ${expert.name} (${expert.phone})...'),
                      backgroundColor: AppTheme.forestGreen,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.forestGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                  icon: const Icon(LucideIcons.send, size: 14),
                  label: Text(ref.watch(farmerLocalizationProvider).tr('request_second_opinion'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _promptSecondOpinionModal(
                    context,
                    expert,
                    widget.attachedScanId,
                    widget.canonicalId,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2ND OPINION SUBMISSION MODAL
  // ===========================================================================

  void _promptSecondOpinionModal(
    BuildContext context,
    VerifiedExpert expert,
    String? preAttachedScanId,
    String? preAttachedCanonical,
  ) {
    final loc = ref.read(farmerLocalizationProvider);
    final notesController = TextEditingController();
    final scanId = preAttachedScanId ?? 'FLX-ACTIVE-DIAGNOSIS';
    final cropName = preAttachedCanonical != null ? preAttachedCanonical.replaceAll('_', ' ') : 'Field Crop Foliage';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.fileQuestion, color: AppTheme.forestGreen, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    loc.tr('request_second_opinion'),
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${loc.tr('assigned_expert')}: ${expert.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${loc.tr('expert_institution')}: ${expert.institution}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text('${loc.tr('attached_scan_id')}: $scanId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                    Text('${loc.tr('preliminary_diagnosis')}: $cropName', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(loc.tr('add_expert_notes'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: loc.tr('expert_notes_hint'),
                  hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.forestGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
                icon: const Icon(LucideIcons.checkCheck, size: 16),
                label: Text(loc.tr('submit_second_opinion'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                onPressed: () async {
                  final consultReq = ConsultationRequest(
                    consultId: 'CONSULT-${DateTime.now().millisecondsSinceEpoch}',
                    farmerMobile: '+919876543210',
                    farmerName: 'Kisan Mitra',
                    expertId: expert.expertId,
                    expertName: expert.name,
                    crop: cropName,
                    canonicalId: preAttachedCanonical ?? 'unspecified',
                    scanId: scanId,
                    farmerQuery: notesController.text.isNotEmpty ? notesController.text : 'Second opinion requested for low-confidence AI inference.',
                    status: 'REQUESTED',
                    submittedAt: DateTime.now(),
                  );

                  final repo = ref.read(expertDirectoryRepositoryProvider);
                  await repo.submitConsultation(consultReq);

                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${loc.tr('second_opinion_submitted')}: ${expert.name}'),
                        backgroundColor: AppTheme.forestGreen,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // MY CONSULTATIONS SHEET
  // ===========================================================================

  void _showMyConsultationsModal(BuildContext context, List<ConsultationRequest> list, FarmerLanguage activeLang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) {
        final loc = ref.read(farmerLocalizationProvider);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.clipboardList, color: AppTheme.forestGreen, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${loc.tr('tab_experts')} (${list.length})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      loc.tr('no_consultations_submitted'),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      final isDone = c.status == 'CONFIRMED' || c.status == 'RESOLVED';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c.crop, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDone ? AppTheme.pistachioContainer : AppTheme.warningContainer,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                  ),
                                  child: Text(
                                    c.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isDone ? AppTheme.forestGreen : AppTheme.warningAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${loc.tr('expert_label')}: ${c.expertName}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
                            Text('${loc.tr('query_label')}: ${c.farmerQuery}', style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                            if (c.expertResponse != null) ...[
                              const SizedBox(height: 4),
                              Text('${loc.tr('response_label')}: ${c.expertResponse}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.forestGreen)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
