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

/// Screen 13 — Farm Inputs Application Screen (`farm_inputs_application`)
/// Features selectable input types (Seeds, Fertilisers, Pesticides, Tools),
/// validated crop name text field, quantity numeric input, and bio/organic option.
class FarmInputsApplicationScreen extends ConsumerStatefulWidget {
  const FarmInputsApplicationScreen({super.key});

  @override
  ConsumerState<FarmInputsApplicationScreen> createState() => _FarmInputsApplicationScreenState();
}

class _FarmInputsApplicationScreenState extends ConsumerState<FarmInputsApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cropController = TextEditingController(text: 'Tomato');
  final TextEditingController _quantityController = TextEditingController(text: '2');
  final TextEditingController _notesController = TextEditingController();

  String _selectedInputType = 'Fertilisers';
  String _selectedUnit = 'Bags';
  bool _preferBioOrganic = true;
  bool _isSubmitting = false;

  final List<String> _inputTypes = ['Seeds', 'Fertilisers', 'Pesticides', 'Tools'];
  final List<String> _units = ['Bags', 'Kg', 'Litres', 'Packets'];

  @override
  void dispose() {
    _cropController.dispose();
    _quantityController.dispose();
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

      final ticketId = 'KS-AID-INP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final crop = _cropController.text.trim();
      final qty = _quantityController.text.trim();

      final app = AssistanceApplication(
        appId: ticketId,
        farmerMobile: mobile,
        farmerName: name,
        district: district,
        state: state,
        pinCode: pinCode,
        category: AssistanceCategory.inputs,
        programId: 'prog_nfsm_inputs_scheme',
        programTitle: '$_selectedInputType for $crop ($qty $_selectedUnit)',
        details: 'Requested $qty $_selectedUnit of $_selectedInputType for $crop. Bio/Organic preferred: $_preferBioOrganic. ${_notesController.text.trim()}',
        requestedAmount: 4500.0,
        status: 'PENDING',
        appliedAt: DateTime.now(),
        metadata: {
          'inputType': _selectedInputType,
          'targetCrop': crop,
          'quantity': qty,
          'unit': _selectedUnit,
          'preferBioOrganic': _preferBioOrganic,
          'agency': 'National Food Security Mission (NFSM) / ICAR',
        },
      );

      await ref.read(assistanceRepositoryProvider).submitApplication(app);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showAssistanceSuccessDialog(
        context: context,
        ticketId: ticketId,
        categoryTitle: 'Farm Inputs & Seed Subsidies',
        summaryText:
            'Your requisition for $qty $_selectedUnit of $_selectedInputType for $crop has been forwarded to the Tehsil Agriculture Input Center.',
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
              ? 'कृषि इनपुट सहायता आवेदन'
              : activeLang.code == 'mr'
                  ? 'बियाणे व खते अनुदान अर्ज'
                  : 'Farm Inputs Application',
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

              // 2. Selectable Input Type Chips
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
                      label: 'Type of Input Required',
                      icon: LucideIcons.sprout,
                      options: _inputTypes,
                      selectedValue: _selectedInputType,
                      onSelected: (val) => setState(() => _selectedInputType = val),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // Organic Preference Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        ref.watch(farmerLocalizationProvider).tr('prefer_icar_bio'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      subtitle: Text(
                        ref.watch(farmerLocalizationProvider).tr('bio_fertiliser_examples'),
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                      value: _preferBioOrganic,
                      activeColor: AppTheme.forestGreen,
                      onChanged: (val) => setState(() => _preferBioOrganic = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Crop Name & Quantity Details
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
                    Text(
                      ref.watch(farmerLocalizationProvider).tr('crop_name_required'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cropController,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('crops_hint'),
                        prefixIcon: const Icon(LucideIcons.leaf, color: AppTheme.forestGreen, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter target crop' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.watch(farmerLocalizationProvider).tr('quantity_required'),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _quantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: ref.watch(farmerLocalizationProvider).tr('acreage_num_hint'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter quantity' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.watch(farmerLocalizationProvider).tr('unit'),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                ),
                                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedUnit = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      ref.watch(farmerLocalizationProvider).tr('specific_variety_optional'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('inputs_desc_hint'),
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
                label: 'SUBMIT FARM INPUTS REQUEST',
                icon: LucideIcons.packagePlus,
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
