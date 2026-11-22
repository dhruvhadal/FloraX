import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../domain/models/florax_models.dart';
import '../../../repositories/ecosystem_directory_repository.dart';
import '../../../services/auth/auth_role_service.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../providers/scan_orchestrator_provider.dart';
import '../../widgets/florax_design_primitives.dart';

/// Screen 6 — Call an Agri Expert (KVK Directory & Second Opinion)
class ExpertDirectoryScreen extends ConsumerStatefulWidget {
  const ExpertDirectoryScreen({super.key});

  @override
  ConsumerState<ExpertDirectoryScreen> createState() => _ExpertDirectoryScreenState();
}

class _ExpertDirectoryScreenState extends ConsumerState<ExpertDirectoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;
  String _selectedCropFilter = 'ALL';

  final List<Map<String, String>> _cropFilters = [
    {'id': 'ALL', 'label': 'All'},
    {'id': 'Paddy', 'label': 'Paddy (भात)'},
    {'id': 'Tomato', 'label': 'Tomato (टोमॅटो)'},
    {'id': 'Sugarcane', 'label': 'Sugarcane (ऊस)'},
    {'id': 'Wheat', 'label': 'Wheat (गहू)'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRoleServiceProvider);
    final String currentUserId = auth.currentUser?.uid ?? 'farmer_anonymous';
    final reviewsAsync = ref.watch(farmerSecondOpinionRequestsStreamProvider(currentUserId));
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;

    final int pendingCount = reviewsAsync.maybeWhen(
      data: (reqs) => reqs.where((r) => r.status != 'COMPLETED').length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Reassuring Farmer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.needHelpDoctor,
                          softWrap: true,
                          style: const TextStyle(
                            color: FloraXTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'ICAR & KVK Accredited Agricultural Scientists',
                          softWrap: true,
                          style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FarmerAudioPill(
                    textToSpeak: 'तुम्हाला पिकाच्या रोगाबाबत काही अडचण असल्यास जवळच्या कृषी विज्ञान केंद्राच्या डॉक्टरांशी थेट फोनवर किंवा फोटो पाठवून मोफत बोला.',
                  ),
                ],
              ),
            ),

            // Tab Switcher (Find Experts vs My Inquiries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: FloraXTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                  border: Border.all(color: FloraXTheme.borderDim, width: 1.2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _tabController.animateTo(0);
                          setState(() => _activeTabIndex = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTabIndex == 0 ? FloraXTheme.cardSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                            boxShadow: _activeTabIndex == 0
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.userCheck,
                                size: 16,
                                color: _activeTabIndex == 0 ? FloraXTheme.primaryGreen : FloraXTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Call Crop Doctors',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _activeTabIndex == 0 ? FloraXTheme.textPrimary : FloraXTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _tabController.animateTo(1);
                          setState(() => _activeTabIndex = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _activeTabIndex == 1 ? FloraXTheme.cardSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                            boxShadow: _activeTabIndex == 1
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.fileText,
                                size: 16,
                                color: _activeTabIndex == 1 ? FloraXTheme.primaryGreen : FloraXTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Sent Photos & Advice',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _activeTabIndex == 1 ? FloraXTheme.textPrimary : FloraXTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (pendingCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: FloraXTheme.primaryGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExpertsDirectoryTab(strings),
                  _buildMyReviewsTab(currentUserId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: VERIFIED EXPERTS DIRECTORY (WITH 1-TAP CROP FILTER CHIPS)
  // ===========================================================================
  Widget _buildExpertsDirectoryTab(FarmerLocalization strings) {
    const filter = VerifiedExpertsFilter(category: 'ALL', district: 'ALL');
    final expertsAsync = ref.watch(verifiedExpertsStreamProvider(filter));

    return Column(
      children: [
        // 1-Tap Crop Filter Chips: [All, Paddy, Tomato, Sugarcane, Wheat]
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: _cropFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final crop = _cropFilters[index];
              final bool isSelected = _selectedCropFilter == crop['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedCropFilter = crop['id']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.cardSurface,
                    borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                    border: Border.all(
                      color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.borderDim,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      crop['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : FloraXTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Experts List
        Expanded(
          child: expertsAsync.when(
            data: (experts) {
              if (experts.isEmpty) {
                return const Center(
                  child: Text('No experts found.', style: TextStyle(color: FloraXTheme.textSecondary)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                itemCount: experts.length,
                itemBuilder: (context, index) {
                  final expert = experts[index];
                  return _buildExpertCard(expert, strings);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: const TextStyle(color: FloraXTheme.crimsonAlert)),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // CLEAN EXPERT CARD WITH 2 HUGE 56DP BUTTONS: [📞 CALL] & [💬 SEND LEAF PHOTO]
  // ===========================================================================
  Widget _buildExpertCard(VerifiedExpert expert, FarmerLocalization strings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: FloraXGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Avatar, Name, KVK Region, Spoken Languages
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.stethoscope, color: Color(0xFF15803D), size: 26),
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
                          Expanded(
                            child: Text(
                              expert.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: FloraXTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(FloraXTheme.radiusFull),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.award, size: 12, color: Color(0xFF15803D)),
                                SizedBox(width: 4),
                                Text(
                                  'ICAR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${expert.institution} • ${expert.district} District',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FloraXTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(LucideIcons.languages, size: 14, color: FloraXTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Languages: ${expert.languages.join(", ")}',
                            style: const TextStyle(fontSize: 12, color: FloraXTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TWO HUGE UNMISTAKABLE 56DP ACTION BUTTONS: [📞 CALL] & [💬 SEND LEAF PHOTO]
            Row(
              children: [
                // 1. CALL BUTTON (56dp green)
                Expanded(
                  flex: 5,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling ${expert.name}: ${expert.phone}'),
                          backgroundColor: FloraXTheme.primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.phoneCall, size: 20, color: Colors.white),
                    label: Text(
                      strings.callButton,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FloraXTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56), // Required 56dp
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. SEND LEAF PHOTO BUTTON (56dp outlined)
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    onPressed: () => _openSendLeafPhotoDialog(expert),
                    icon: const Icon(LucideIcons.messageSquare, size: 20, color: FloraXTheme.primaryGreen),
                    label: Text(
                      strings.sendLeafPhoto,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: FloraXTheme.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FloraXTheme.primaryGreen,
                      minimumSize: const Size(double.infinity, 56), // Required 56dp
                      side: const BorderSide(color: FloraXTheme.primaryGreen, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSendLeafPhotoDialog(VerifiedExpert expert) {
    final orchestratorState = ref.read(scanOrchestratorProvider).value;
    final latestScan = orchestratorState?.scanRecord;
    final symptomController = TextEditingController(
      text: latestScan != null
          ? 'Tomato foliage showing symptoms. AI scan ref: ${latestScan.scanId}. Need second opinion.'
          : 'Tomato crop showing spots. Please verify advisory.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FloraXTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Send Photo to ${expert.name}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: FloraXTheme.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: FloraXTheme.textSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.camera, color: Color(0xFF15803D), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        latestScan != null
                            ? 'Attached Scan: ${latestScan.scanId} (${latestScan.plantTagId})'
                            : 'Attached latest camera scan summary',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: symptomController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Farmer Note / लक्षण वर्णन',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  final auth = ref.read(authRoleServiceProvider);
                  final farmerUid = auth.currentUser?.uid ?? 'farmer_anonymous';
                  final scanToSubmit = latestScan ??
                      LeafScanRecord(
                        scanId: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
                        userId: farmerUid,
                        plantTagId: 'Tomato',
                        timestamp: DateTime.now().toUtc(),
                        imageUrl: '',
                        topPredictions: const [],
                        verificationStatus: VerificationStatus.pendingKvkReview,
                        requiresKvkReview: true,
                        lesionAreaPercent: 10.0,
                        geoHash5: 'wh0r7',
                      );

                  await ref.read(ecosystemDirectoryRepositoryProvider).submitSecondOpinionRequest(
                        scan: scanToSubmit,
                        targetId: expert.expertId,
                        targetType: 'expert',
                        farmerNotes: symptomController.text.trim(),
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Photo sent to ${expert.name}! Response within 2 hours.'),
                        backgroundColor: FloraXTheme.primaryGreen,
                      ),
                    );
                  }
                },
                icon: const Icon(LucideIcons.send, size: 20, color: Colors.white),
                label: const Text('Confirm & Send Photo (पाठवा)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FloraXTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SENT PHOTOS & REVIEWS
  // ===========================================================================
  Widget _buildMyReviewsTab(String farmerUid) {
    final reviewsAsync = ref.watch(farmerSecondOpinionRequestsStreamProvider(farmerUid));

    return reviewsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No expert requests yet. Send a leaf photo from Tab 1.',
              style: TextStyle(color: FloraXTheme.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final bool isDone = req.status == 'COMPLETED';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: FloraXGlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Request: ${req.requestId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            req.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDone ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(req.symptomDescription, style: const TextStyle(fontSize: 13, color: FloraXTheme.textPrimary)),
                    if (req.expertDiagnosis != null) ...[
                      const Divider(color: FloraXTheme.borderDim, height: 16),
                      Text('Dr Diagnosis: ${req.expertDiagnosis}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FloraXTheme.primaryGreen)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: FloraXTheme.primaryGreen)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
