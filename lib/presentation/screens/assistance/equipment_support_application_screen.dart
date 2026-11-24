import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/assistance_repository.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../services/location/location_service.dart';
import '../../../domain/models/florax_models.dart';
import '../../widgets/assistance/assistance_widgets.dart';

/// Screen 12 — Equipment Support Application Screen (`equipment_support_application`)
/// Features selectable equipment required, type of support (Purchase, Subsidy, Rental),
/// acreage details, and seamless paperless submission to SMAM / State Farm Mechanization.
class EquipmentSupportApplicationScreen extends ConsumerStatefulWidget {
  const EquipmentSupportApplicationScreen({super.key});

  @override
  ConsumerState<EquipmentSupportApplicationScreen> createState() => _EquipmentSupportApplicationScreenState();
}

class _EquipmentSupportApplicationScreenState extends ConsumerState<EquipmentSupportApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _acreageController = TextEditingController(text: '2.5');
  final TextEditingController _notesController = TextEditingController();

  String _selectedEquipment = 'Sprayer';
  String _selectedSupportType = 'Subsidy';
  bool _isSubmitting = false;

  final List<String> _equipmentOptions = ['Tractor', 'Pump', 'Sprayer', 'Drip'];
  final List<String> _supportTypeOptions = ['Purchase', 'Subsidy', 'Rental'];

  @override
  void dispose() {
    _acreageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final farmer = await ref.read(farmerProfileRepositoryProvider).getLocalProfile();
      final liveLoc = ref.read(farmerLocationProvider).location;
      final mobile = farmer?.mobileE164 ?? '+919876543210';
      final name = farmer?.fullName ?? 'Kisan Mitra';
      final district = (farmer?.district.isNotEmpty == true ? farmer!.district : liveLoc?.district) ?? '';
      final state = (farmer?.state.isNotEmpty == true ? farmer!.state : liveLoc?.state) ?? '';
      final pinCode = (farmer?.pincode.isNotEmpty == true ? farmer!.pincode : liveLoc?.postalCode) ?? '';

      final ticketId = 'KS-AID-EQP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final acreage = double.tryParse(_acreageController.text.trim()) ?? 2.0;

      final app = AssistanceApplication(
        appId: ticketId,
        farmerMobile: mobile,
        farmerName: name,
        district: district,
        state: state,
        pinCode: pinCode,
        category: AssistanceCategory.equipment,
        programId: 'prog_smam_equipment_scheme',
        programTitle: '$_selectedEquipment ($_selectedSupportType Scheme)',
        details: 'Requested $_selectedSupportType for $_selectedEquipment for $acreage acres. Notes: ${_notesController.text.trim()}',
        requestedAmount: _selectedSupportType == 'Rental' ? 2500.0 : 35000.0,
        status: 'PENDING',
        appliedAt: DateTime.now(),
        metadata: {
          'equipment': _selectedEquipment,
          'supportType': _selectedSupportType,
          'targetAcreage': acreage,
          'schemeAgency': 'Sub-Mission on Agricultural Mechanization (SMAM)',
        },
      );

      await ref.read(assistanceRepositoryProvider).submitApplication(app);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showAssistanceSuccessDialog(
        context: context,
        ticketId: ticketId,
        categoryTitle: 'Farm Equipment Support Application',
        summaryText:
            'Your application for $_selectedEquipment ($_selectedSupportType) has been submitted to the District Farm Mechanization Desk.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final loc = ref.read(farmerLocalizationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.tr('submission_queued_offline')} ($e)'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          activeLang.code == 'hi'
              ? 'कृषि उपकरण सहायता आवेदन'
              : activeLang.code == 'mr'
                  ? 'शेती अवजारे व यंत्रसामग्री अनुदान'
                  : 'Equipment Support Application',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Farmer Header Card
              const AssistanceFarmerHeaderCard(),
              const SizedBox(height: 20),

              // 2. Equipment & Support Type Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AssistanceChipGroup(
                      label: 'Equipment Required',
                      icon: LucideIcons.truck,
                      options: _equipmentOptions,
                      selectedValue: _selectedEquipment,
                      onSelected: (val) => setState(() => _selectedEquipment = val),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    AssistanceChipGroup(
                      label: 'Type of Support',
                      icon: LucideIcons.badgePercent,
                      options: _supportTypeOptions,
                      selectedValue: _selectedSupportType,
                      onSelected: (val) => setState(() => _selectedSupportType = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Farm Area & Specifications
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, color: AppTheme.forestGreen, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          ref.watch(farmerLocalizationProvider).tr('land_area_acres'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _acreageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('acreage_hint'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixText: 'Acres',
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter land area' : null,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      ref.watch(farmerLocalizationProvider).tr('specific_brand_optional'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('equipment_desc_hint'),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Submit CTA
              AssistanceSubmitButton(
                label: 'SUBMIT EQUIPMENT APPLICATION',
                icon: LucideIcons.wrench,
                isSubmitting: _isSubmitting,
                onPressed: _submitApplication,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
