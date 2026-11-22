import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/florax_theme.dart';
import '../../../domain/models/florax_models.dart';
import '../../../repositories/ecosystem_directory_repository.dart';
import '../../../services/voice/voice_guide_service.dart';
import '../../widgets/florax_design_primitives.dart';

/// Screen 7 — NGO & FPO Support Network (Inside Partner / KVK Portal)
class LeafGuardConnectScreen extends ConsumerStatefulWidget {
  const LeafGuardConnectScreen({super.key});

  @override
  ConsumerState<LeafGuardConnectScreen> createState() => _LeafGuardConnectScreenState();
}

class _LeafGuardConnectScreenState extends ConsumerState<LeafGuardConnectScreen> {
  String _selectedDistrict = 'ALL';

  final List<String> _districts = [
    'ALL',
    'Pune',
    'Nashik',
    'Ahmednagar',
    'Jalgaon',
    'Aurangabad',
    'Raigad',
    'Ratnagiri',
    'Dhule',
  ];

  @override
  Widget build(BuildContext context) {
    final ngosAsync = ref.watch(
      ngoPartnersStreamProvider(_selectedDistrict == 'ALL' ? null : _selectedDistrict),
    );
    final voiceGuide = ref.watch(voiceGuideServiceProvider);
    final strings = voiceGuide.strings;

    return Scaffold(
      backgroundColor: FloraXTheme.background,
      appBar: AppBar(
        title: Text(strings.ngoPortalTitle),
        backgroundColor: FloraXTheme.cardSurface,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: FloraXTheme.textPrimary, size: 24),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: FloraXTheme.primaryGreen,
          backgroundColor: FloraXTheme.cardSurface,
          onRefresh: () async {
            ref.invalidate(ngoPartnersStreamProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Reassuring Trust Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF15803D), width: 1.2),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.shieldCheck, color: Color(0xFF15803D), size: 26),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Verified NGO & FPO Partners provide 100% free on-field assistance, soil test kits, and subsidized seeds under government grants.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF14532D), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // District Filter Selector Strip
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _districts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final d = _districts[index];
                      final bool isSelected = _selectedDistrict == d;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDistrict = d),
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
                              d == 'ALL' ? 'All Districts' : d,
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
              ),

              // NGO Partners Stream List
              ngosAsync.when(
                data: (ngos) {
                  if (ngos.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No partner NGOs registered for this district.',
                            style: TextStyle(color: FloraXTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ngo = ngos[index];
                        return _buildNgoCard(ngo, strings);
                      },
                      childCount: ngos.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: FloraXTheme.primaryGreen),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $err', style: const TextStyle(color: FloraXTheme.crimsonAlert)),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNgoCard(NgoPartner ngo, FarmerLocalization strings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FloraXGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Partner Avatar, Name, Darpan Verification Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(LucideIcons.heartHandshake, color: Color(0xFF15803D), size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ngo.name,
                              style: const TextStyle(
                                fontSize: 16,
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
                            child: const Text(
                              'Darpan Verified',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Coverage: ${ngo.districtsServed.join(", ")}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: FloraXTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Free Support Tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildSupportTag('Free Soil Testing', LucideIcons.testTube),
                _buildSupportTag('Bio-Fertilizer Kits', LucideIcons.sprout),
                _buildSupportTag('Seed Grants', LucideIcons.award),
              ],
            ),
            const SizedBox(height: 14),

            // Clean Actions: [Request Support] (52dp green) & [View Program] (52dp outlined)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openAssistanceModal(ngo),
                    icon: const Icon(LucideIcons.helpingHand, size: 18, color: Colors.white),
                    label: Text(
                      strings.requestSupport,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FloraXTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showProgramDetailsModal(ngo),
                    icon: const Icon(LucideIcons.fileText, size: 18, color: FloraXTheme.primaryGreen),
                    label: Text(
                      strings.viewProgram,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: FloraXTheme.primaryGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FloraXTheme.primaryGreen,
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: FloraXTheme.borderDim, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildSupportTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FloraXTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FloraXTheme.borderDim),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: FloraXTheme.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: FloraXTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  void _openAssistanceModal(NgoPartner ngo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: FloraXTheme.cardSurface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Request Support from ${ngo.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Field Rep: ${ngo.fieldRepName} • Contact: ${ngo.fieldRepContact}',
                style: const TextStyle(fontSize: 13, color: FloraXTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Support request submitted to ${ngo.name}!'),
                      backgroundColor: FloraXTheme.primaryGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FloraXTheme.primaryGreen,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Confirm Support Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProgramDetailsModal(NgoPartner ngo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FloraXTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ngo.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registration: ${ngo.registrationNumber}', style: const TextStyle(fontSize: 13, color: FloraXTheme.textSecondary)),
            const SizedBox(height: 10),
            const Text('Focus Areas:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...ngo.focusAreas.map((f) => Text('• $f')),
            const SizedBox(height: 10),
            const Text('Eligible Schemes:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...ngo.schemesEligible.map((s) => Text('• $s')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
