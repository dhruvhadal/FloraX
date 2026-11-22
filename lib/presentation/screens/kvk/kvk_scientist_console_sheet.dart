import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../services/auth/auth_role_service.dart';
import '../../../services/voice/vernacular_voice_service.dart';
import '../../widgets/florax_design_primitives.dart';

/// Screen 8 — Institutional / KVK Scientist Console (Partner / KVK Portal)
///
/// Executive-clean, high-contrast operational dashboard for KVK scientists,
/// agronomists, and agricultural extension officers reviewing escalated (<75% confidence)
/// farmer cases and second-opinion requests.
class KvkScientistConsoleSheet extends ConsumerStatefulWidget {
  const KvkScientistConsoleSheet({super.key});

  @override
  ConsumerState<KvkScientistConsoleSheet> createState() =>
      _KvkScientistConsoleSheetState();
}

class _KvkScientistConsoleSheetState extends ConsumerState<KvkScientistConsoleSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _secondOpinionFeedbackController = TextEditingController();

  bool _isCommitting = false;
  bool _audioPlaying = false;
  bool _unlockTier3Chemical = true;
  String _selectedDiagnosis = 'Confirm: Alternaria solani (Early Blight) ✓';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _secondOpinionFeedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRoleServiceProvider);

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      appBar: AppBar(
        backgroundColor: FloraXTheme.cardSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: FloraXTheme.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'KVK Scientist Console',
              style: TextStyle(
                color: FloraXTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'ICAR • MPKV Rahuri Verified Clinical Workspace',
              style: TextStyle(
                color: FloraXTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userCog, color: FloraXTheme.primaryGreen, size: 22),
            tooltip: 'Toggle Demo Evaluator Role (Farmer <-> KVK)',
            onPressed: () async {
              final newRole = await auth.toggleDemoKvkRole();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched active role to: ${newRole.value}'),
                  backgroundColor: FloraXTheme.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(color: FloraXTheme.borderDim, height: 1.5),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scientist Identity Strip & Station Badge
            _buildScientistProfileHeader(),

            // Compact 3-Metric Top Strip (Screen 8 Specification)
            _buildThreeMetricTopStrip(),

            // High-Contrast Daylight Segmented Tabs Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF1E8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FloraXTheme.borderDim),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: FloraXTheme.primaryGreen,
                  unselectedLabelColor: FloraXTheme.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Escalations (<75%)'),
                    Tab(text: 'Second Opinions'),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: KVK Escalations Stream
                  _buildKvkEscalationsTab(),

                  // TAB 2: Second Opinion Requests Stream
                  _buildSecondOpinionRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SCIENTIST PROFILE HEADER
  // ===========================================================================

  Widget _buildScientistProfileHeader() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(ref.watch(authRoleServiceProvider).currentUser?.uid ?? 'unknown_uid')
          .snapshots(),
      builder: (context, userSnap) {
        final authUser = ref.watch(authRoleServiceProvider).currentUser;
        final userData = userSnap.data?.data();

        final String scientistName = userData?['name'] as String? ??
            userData?['displayName'] as String? ??
            authUser?.displayName ??
            (authUser?.email != null ? 'Dr. ${authUser!.email!.split("@").first}' : 'Dr. R. K. Shinde');

        final String stationInfo = userData?['station'] as String? ??
            userData?['organization'] as String? ??
            'KVK Nashik • ICAR Station #402';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FloraXTheme.borderDim, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Center(
                        child: Icon(LucideIcons.userCheck, color: FloraXTheme.primaryGreen, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scientistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FloraXTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF15803D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  stationInfo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FloraXTheme.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.shieldCheck, color: Color(0xFF0284C7), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Tier-3 Auth',
                      style: TextStyle(
                        color: Color(0xFF0369A1),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // COMPACT 3-METRIC TOP STRIP (Screen 8 Specification)
  // ===========================================================================

  Widget _buildThreeMetricTopStrip() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('kvk_escalations')
          .where('status', isEqualTo: 'PENDING_REVIEW')
          .snapshots(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.docs.length ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              // Metric 1: Pending Reviews
              Expanded(
                child: _buildMetricTile(
                  icon: LucideIcons.alertCircle,
                  iconColor: FloraXTheme.amberCaution,
                  bgColor: const Color(0xFFFEF3C7),
                  count: '$pendingCount',
                  label: 'Pending Reviews',
                  isHighlighted: pendingCount > 0,
                ),
              ),
              const SizedBox(width: 8),

              // Metric 2: Active Outbreaks
              Expanded(
                child: _buildMetricTile(
                  icon: LucideIcons.flame,
                  iconColor: FloraXTheme.crimsonAlert,
                  bgColor: const Color(0xFFFEE2E2),
                  count: '3 High',
                  label: 'Active Outbreaks',
                  isHighlighted: false,
                ),
              ),
              const SizedBox(width: 8),

              // Metric 3: Verified Today
              Expanded(
                child: _buildMetricTile(
                  icon: LucideIcons.badgeCheck,
                  iconColor: const Color(0xFF15803D),
                  bgColor: const Color(0xFFDCFCE7),
                  count: '28 Cases',
                  label: 'Verified Today',
                  isHighlighted: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String count,
    required String label,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? iconColor.withValues(alpha: 0.6) : FloraXTheme.borderDim,
          width: isHighlighted ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(
                  color: FloraXTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: FloraXTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: KVK LOW-CONFIDENCE ESCALATIONS
  // ===========================================================================

  Widget _buildKvkEscalationsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('kvk_escalations')
          .where('status', isEqualTo: 'PENDING_REVIEW')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(LucideIcons.checkCheck, color: Color(0xFF15803D), size: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Escalations Reviewed!',
                    style: TextStyle(
                      color: FloraXTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No pending cases under the 75% confidence guardrail right now. All farmer fields in your jurisdiction are clinically cleared.',
                    style: TextStyle(
                      color: FloraXTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final String scanId = data['scanId'] as String? ?? docs[index].id;
            return _buildEscalationItem(data, scanId);
          },
        );
      },
    );
  }

  Widget _buildEscalationItem(Map<String, dynamic> data, String scanId) {
    final String plantTagId = data['plantTagId'] as String? ?? 'PLANT-001';
    final double confidence = ((data['topConfidence'] as num?)?.toDouble() ?? 0.0) * 100.0;
    final double lesionPct = (data['lesionAreaPercent'] as num?)?.toDouble() ?? 0.0;
    final String priority = data['priority'] as String? ?? 'STANDARD';
    final String geoHash = data['geoHash5'] as String? ?? 'wh0r7';

    final bool isUrgent = priority == 'URGENT' || confidence < 50.0;
    final Color priorityColor = isUrgent ? FloraXTheme.crimsonAlert : FloraXTheme.amberCaution;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? const Color(0xFFFCA5A5) : FloraXTheme.borderDim,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isUrgent ? LucideIcons.shieldAlert : LucideIcons.alertTriangle,
                        color: priorityColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isUrgent ? 'URGENT ESCALATION (<50% CONF)' : 'AI FLAGGED: LOW CONFIDENCE (<75%)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Case #$scanId',
                    style: const TextStyle(
                      color: FloraXTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Side-by-Side Dual Telemetry Vision Feed (Raw Capture + Grad-CAM)
                Row(
                  children: [
                    // Raw Capture Leaf Image
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: FloraXTheme.borderDim),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: FloraXAdaptiveImage(
                                    imageSource: (data['thumbnailBase64'] as String?) ??
                                        (data['imageUrl'] as String?),
                                    fit: BoxFit.cover,
                                    errorWidget: Center(
                                      child: Icon(
                                        LucideIcons.leaf,
                                        color: FloraXTheme.primaryGreen.withValues(alpha: 0.4),
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(LucideIcons.camera, color: Colors.white, size: 10),
                                        SizedBox(width: 4),
                                        Text(
                                          'Original Leaf',
                                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Grad-CAM Saliency Overlay
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: FloraXTheme.amberCaution.withValues(alpha: 0.5)),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Icon(
                                    LucideIcons.activity,
                                    color: FloraXTheme.amberCaution.withValues(alpha: 0.5),
                                    size: 40,
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFCD34D)),
                                    ),
                                    child: Text(
                                      '${confidence.toStringAsFixed(1)}% Conf',
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(LucideIcons.eye, color: Color(0xFF4ADE80), size: 10),
                                        SizedBox(width: 4),
                                        Text(
                                          'Grad-CAM Heatmap',
                                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Case Context Summary Strip
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.mapPin, color: FloraXTheme.textSecondary, size: 13),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Plot: $plantTagId • Geo: $geoHash',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: FloraXTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'AI Primary Detection: Tomato — Early Blight',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Text(
                          '${lesionPct.toStringAsFixed(1)}% Canopy',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Top-3 AI Differential Diagnosis Bars (Screen 8 Specification)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FloraXTheme.borderDim),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Top-3 AI Differential Diagnosis',
                            style: TextStyle(
                              color: FloraXTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Entropy: 0.82 (High Uncertainty)',
                            style: TextStyle(
                              color: FloraXTheme.amberCaution,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildDifferentialBar(
                        '1. Early Blight (Alternaria solani)',
                        confidence / 100,
                        FloraXTheme.amberCaution,
                        'Dark brown rings like a bullseye target on older leaves',
                      ),
                      const SizedBox(height: 6),
                      _buildDifferentialBar(
                        '2. Septoria Leaf Spot',
                        0.22,
                        const Color(0xFF64748B),
                        'Many tiny circular spots with dark brown margins and pale grey centers',
                      ),
                      const SizedBox(height: 6),
                      _buildDifferentialBar(
                        '3. Late Blight (Phytophthora)',
                        0.10,
                        const Color(0xFF94A3B8),
                        'Water-soaked dark lesions with white mold on underside in humid air',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Farmer Voice Symptom & Audio Transcript Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(LucideIcons.mic, color: FloraXTheme.primaryGreen, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Farmer Field Audio Transcript',
                                style: TextStyle(
                                  color: Color(0xFF14532D),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'मराठी (Nashik Rural)',
                              style: TextStyle(color: FloraXTheme.primaryGreen, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '"पानावर काळे ठिपके दिसत आहेत आणि खालील पाने पिवळी पडून गळत आहेत. औषध सुचवा."',
                        style: TextStyle(
                          color: FloraXTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'English: "Black spots appear on lower leaves and yellowing leaf drop observed. Advise medicine."',
                        style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 10),

                      // Vernacular Audio playback bar
                      GestureDetector(
                        onTap: () {
                          final voice = ref.read(vernacularVoiceServiceProvider);
                          if (_audioPlaying) {
                            setState(() => _audioPlaying = false);
                          } else {
                            setState(() => _audioPlaying = true);
                            voice.speak(
                              'पानावर काळे ठिपके दिसत आहेत आणि खालील पाने पिवळी पडून गळत आहेत. औषध सुचवा.',
                              langCode: 'mr',
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _audioPlaying ? LucideIcons.pause : LucideIcons.play,
                                color: FloraXTheme.primaryGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: List.generate(
                                    22,
                                    (i) => Expanded(
                                      child: Container(
                                        height: (i % 4 + 1) * 3.5 + 4,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: i < 9 ? FloraXTheme.primaryGreen : const Color(0xFFD1D5DB),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '0:14',
                                style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Official Pathological Confirmation Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedDiagnosis,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Official Pathological Classification',
                    labelStyle: const TextStyle(color: FloraXTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    isDense: true,
                  ),
                  items: [
                    'Confirm: Alternaria solani (Early Blight) ✓',
                    'Re-classify: Septoria Leaf Spot',
                    'Re-classify: Late Blight (Phytophthora infestans)',
                    'Re-classify: Abiotic Nitrogen Deficiency',
                    'Inconclusive: Order Physical Sample Collection',
                  ].map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(
                        d,
                        style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDiagnosis = val);
                  },
                ),
                const SizedBox(height: 12),

                // 6. Safety Override Switch (Tier-3 Chemical Unlock)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _unlockTier3Chemical ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _unlockTier3Chemical ? const Color(0xFFFCD34D) : FloraXTheme.borderDim,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _unlockTier3Chemical ? LucideIcons.unlock : LucideIcons.lock,
                                color: _unlockTier3Chemical ? const Color(0xFFB45309) : FloraXTheme.textSecondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Unlock Tier-3 Chemical Control',
                                style: TextStyle(
                                  color: FloraXTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _unlockTier3Chemical,
                            activeThumbColor: FloraXTheme.primaryGreen,
                            onChanged: (val) => setState(() => _unlockTier3Chemical = val),
                          ),
                        ],
                      ),
                      if (_unlockTier3Chemical) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: const [
                              Icon(LucideIcons.shieldAlert, color: Color(0xFFB45309), size: 14),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'CIB&RC Registered Prescription: Mancozeb 75% WP @ 2.5g/L (Approved for moderate outbreak, 7-day safety interval).',
                                  style: TextStyle(color: Color(0xFF92400E), fontSize: 11, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 7. Scientist Field Advisory Input
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Scientist Advisory Note (Auto-Translated to Marathi)',
                    labelStyle: const TextStyle(color: FloraXTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                    hintText: 'Enter clinical observations, spray precautions, or dosage changes...',
                    hintStyle: const TextStyle(color: FloraXTheme.textMuted, fontSize: 11.5),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: FloraXTheme.borderDim),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // 8. Crisp Actions: "Override Diagnosis" & "Approve Advisory"
                Row(
                  children: [
                    // Override Diagnosis Button (Screen 8 Specification)
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: _isCommitting ? null : () => _overrideDiagnosis(scanId),
                        icon: const Icon(LucideIcons.refreshCw, size: 15),
                        label: const Text('Override'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB45309),
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Approve Advisory Button (Screen 8 Specification)
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: _isCommitting ? null : () => _approvePrescription(scanId),
                        icon: const Icon(LucideIcons.checkCircle2, size: 16),
                        label: const Text('Approve Advisory'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FloraXTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferentialBar(String label, double pct, Color color, [String? distinguishingSymptom]) {
    final int displayPct = (pct * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: FloraXTheme.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$displayPct%',
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (distinguishingSymptom != null && distinguishingSymptom.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '🔍 $distinguishingSymptom',
            style: const TextStyle(fontSize: 10.5, color: FloraXTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Future<void> _approvePrescription(String scanId) async {
    setState(() => _isCommitting = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final authUser = ref.read(authRoleServiceProvider).currentUser;
      final String scientistUid = authUser?.uid ?? 'KVK_NASHIK_EXPERT_01';
      final String finalNote = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : 'Diagnosis verified by institutional specialist: $_selectedDiagnosis';

      final scanRef = firestore.collection('scans').doc(scanId);
      batch.update(scanRef, {
        'verificationStatus': 'KVK_CONFIRMED',
        'chemicalUnlocked': _unlockTier3Chemical,
        'kvkScientistId': scientistUid,
        'kvkScientistNote': finalNote,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      final escalationRef = firestore.collection('kvk_escalations').doc(scanId);
      batch.update(escalationRef, {
        'status': 'RESOLVED',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionNote': finalNote,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prescription #$scanId Approved! Advisory synced to farmer in real-time.'),
          backgroundColor: FloraXTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[FloraX KVK ERROR] Approval failed: $e');
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  Future<void> _overrideDiagnosis(String scanId) async {
    setState(() => _isCommitting = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final authUser = ref.read(authRoleServiceProvider).currentUser;
      final String scientistUid = authUser?.uid ?? 'KVK_NASHIK_EXPERT_01';
      final String finalNote = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : 'Pathology diagnosis overridden by specialist: $_selectedDiagnosis';

      final scanRef = firestore.collection('scans').doc(scanId);
      batch.update(scanRef, {
        'verificationStatus': 'KVK_OVERRIDDEN',
        'overriddenPathology': _selectedDiagnosis,
        'chemicalUnlocked': _unlockTier3Chemical,
        'kvkScientistId': scientistUid,
        'kvkScientistNote': finalNote,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      final escalationRef = firestore.collection('kvk_escalations').doc(scanId);
      batch.update(escalationRef, {
        'status': 'RESOLVED',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolutionNote': 'Overridden: $finalNote',
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Case #$scanId Diagnosis Overridden and Synced to Farmer App!'),
          backgroundColor: const Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[FloraX KVK ERROR] Override failed: $e');
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  // ===========================================================================
  // TAB 2: SECOND OPINION REQUESTS REVIEW (Feature #12)
  // ===========================================================================

  Widget _buildSecondOpinionRequestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('second_opinion_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.inbox, color: FloraXTheme.textMuted, size: 48),
                  SizedBox(height: 14),
                  Text(
                    'No Second Opinion Requests',
                    style: TextStyle(
                      color: FloraXTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Farmer second opinion submissions will appear here for specialist review.',
                    style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final String reqId = docs[index].id;
            return _buildSecondOpinionReviewCard(data, reqId);
          },
        );
      },
    );
  }

  Widget _buildSecondOpinionReviewCard(Map<String, dynamic> data, String reqId) {
    final String farmerUid = data['farmerUid'] as String? ?? 'Farmer';
    final String crop = data['cropType'] as String? ?? 'Crop';
    final String aiLabel = data['aiPredictionLabel'] as String? ?? 'Pathology';
    final double confidence = ((data['aiConfidence'] as num?)?.toDouble() ?? 0.0) * 100.0;
    final String severity = data['severityGrade'] as String? ?? 'MILD';
    final String farmerQuery = data['farmerQuery'] as String? ?? '';
    final String status = data['status'] as String? ?? 'PENDING';
    final String? feedback = data['expertFeedback'] as String?;
    final bool isCompleted = status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted ? const Color(0xFF86EFAC) : FloraXTheme.borderDim,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Request: #$reqId',
                  style: const TextStyle(
                    color: FloraXTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Text(
                    isCompleted ? 'RESOLVED' : 'PENDING REVIEW',
                    style: TextStyle(
                      color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF92400E),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (data['thumbnailBase64'] != null || data['imageUrl'] != null) ...[
              Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: FloraXTheme.borderDim),
                ),
                clipBehavior: Clip.antiAlias,
                child: FloraXAdaptiveImage(
                  imageSource: (data['thumbnailBase64'] as String?) ?? (data['imageUrl'] as String?),
                  fit: BoxFit.cover,
                ),
              ),
            ],
            Text(
              'Host Crop: $crop • AI: ${aiLabel.replaceAll("_", " ")} (${confidence.toStringAsFixed(1)}%)',
              style: const TextStyle(
                color: FloraXTheme.primaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Farmer UID: $farmerUid • Severity: $severity',
              style: const TextStyle(color: FloraXTheme.textSecondary, fontSize: 11.5),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Farmer Query: "$farmerQuery"',
                style: const TextStyle(
                  color: FloraXTheme.textPrimary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (isCompleted && feedback != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.checkCheck, color: Color(0xFF15803D), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Specialist Advisory: $feedback',
                        style: const TextStyle(
                          color: Color(0xFF14532D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _secondOpinionFeedbackController,
                maxLines: 2,
                style: const TextStyle(color: FloraXTheme.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Specialist Clinical Verdict & Prescription',
                  labelStyle: const TextStyle(color: FloraXTheme.primaryGreen, fontSize: 11.5, fontWeight: FontWeight.bold),
                  hintText: 'Enter clinical diagnosis, verified pathogen, and recommended dosage...',
                  hintStyle: const TextStyle(color: FloraXTheme.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCommitting ? null : () => _resolveSecondOpinion(reqId),
                  icon: const Icon(LucideIcons.send, size: 15),
                  label: const Text('Sign & Send Second Opinion Verdict'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloraXTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resolveSecondOpinion(String reqId) async {
    setState(() => _isCommitting = true);
    try {
      final authUser = ref.read(authRoleServiceProvider).currentUser;
      final String expertUid = authUser?.uid ?? 'KVK_NASHIK_EXPERT_01';
      final String finalFeedback = _secondOpinionFeedbackController.text.trim().isNotEmpty
          ? _secondOpinionFeedbackController.text.trim()
          : 'Diagnosis verified by institutional specialist: Approved standard ICAR IPM treatment protocol.';

      final docRef = FirebaseFirestore.instance.collection('second_opinion_requests').doc(reqId);
      await docRef.update({
        'status': 'COMPLETED',
        'assignedExpertId': expertUid,
        'expertFeedback': finalFeedback,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Second opinion #$reqId resolved and dispatched to farmer!'),
          backgroundColor: FloraXTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[FloraX SecondOpinion ERROR] Resolve failed: $e');
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }
}
