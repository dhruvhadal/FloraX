import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../services/location/location_service.dart';

/// Pre-filled Read-Only Farmer Header Card with KYC Verification Status Indicator.
/// Privacy-Safe: Stores only document type & verification boolean.
/// Never stores unencrypted raw government ID numbers in plain text.
class AssistanceFarmerHeaderCard extends ConsumerStatefulWidget {
  final bool initialKycVerified;
  final String initialDocType;
  final ValueChanged<bool>? onKycStatusChanged;

  const AssistanceFarmerHeaderCard({
    super.key,
    this.initialKycVerified = true,
    this.initialDocType = '7/12 Land Record (Satbara)',
    this.onKycStatusChanged,
  });

  @override
  ConsumerState<AssistanceFarmerHeaderCard> createState() => _AssistanceFarmerHeaderCardState();
}

class _AssistanceFarmerHeaderCardState extends ConsumerState<AssistanceFarmerHeaderCard> {
  late bool _isKycVerified;
  late String _docType;

  @override
  void initState() {
    super.initState();
    _isKycVerified = widget.initialKycVerified;
    _docType = widget.initialDocType;
  }

  void _showKycDetailsModal() {
    final loc = ref.read(farmerLocalizationProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.pistachioPill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.shieldCheck, color: AppTheme.forestGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.tr('verified_farmer_badge'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        loc.tr('verified_on_record'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.tr('doc_type'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(_docType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.tr('compliance_status'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      Row(
                        children: [
                          Icon(
                            _isKycVerified ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                            size: 16,
                            color: _isKycVerified ? AppTheme.forestGreen : AppTheme.warningAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isKycVerified ? loc.tr('verified_on_record') : loc.tr('pending_verification'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isKycVerified ? AppTheme.forestGreen : AppTheme.warningAmber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.tr('security_policy'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      Text(loc.tr('zero_raw_id_storage'), style: const TextStyle(fontSize: 12, color: AppTheme.forestGreen, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isKycVerified = !_isKycVerified;
                        widget.onKycStatusChanged?.call(_isKycVerified);
                      });
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.forestGreen,
                      side: const BorderSide(color: AppTheme.forestGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_isKycVerified ? loc.tr('mark_as_pending') : loc.tr('mark_as_verified')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(loc.btnClose),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmerAsync = ref.watch(farmerProfileRepositoryProvider).getLocalProfile();
    final liveLoc = ref.watch(farmerLocationProvider).location;

    return FutureBuilder(
      future: farmerAsync,
      builder: (context, snapshot) {
        final farmer = snapshot.data;
        final name = farmer?.fullName ?? 'Kisan Mitra';
        final mobile = farmer?.mobileE164 ?? '+91 98765 43210';
        final location = (farmer != null && farmer.district.isNotEmpty)
            ? '${farmer.district}, ${farmer.state}'
            : (liveLoc?.displayLocation ?? 'Location Not Set');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.pistachioPill,
                    child: const Icon(LucideIcons.user, size: 20, color: AppTheme.forestGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$mobile • $location',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // KYC Status Badge
                  InkWell(
                    onTap: _showKycDetailsModal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isKycVerified ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isKycVerified
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isKycVerified ? LucideIcons.badgeCheck : LucideIcons.fileText,
                            size: 13,
                            color: _isKycVerified ? const Color(0xFF047857) : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isKycVerified ? 'KYC Verified' : 'Upload Doc',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: _isKycVerified ? const Color(0xFF047857) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.fileCheck, size: 14, color: AppTheme.forestGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${ref.watch(farmerLocalizationProvider).tr('verified_attachment')}: $_docType',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      ref.watch(farmerLocalizationProvider).tr('icar_nabard_linked'),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
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
}
