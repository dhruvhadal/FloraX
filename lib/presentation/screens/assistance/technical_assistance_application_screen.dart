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

/// Screen 15 — Technical Assistance Application Screen (`technical_assistance_application`)
/// Features selectable assistance types (Soil Testing, Disease Advice, Irrigation Planning, Organic Transition),
/// preferred support method (Phone Call, Voice Message, Expert Visit), time slots, and KVK scientist routing.
class TechnicalAssistanceApplicationScreen extends ConsumerStatefulWidget {
  const TechnicalAssistanceApplicationScreen({super.key});

  @override
  ConsumerState<TechnicalAssistanceApplicationScreen> createState() => _TechnicalAssistanceApplicationScreenState();
}

class _TechnicalAssistanceApplicationScreenState extends ConsumerState<TechnicalAssistanceApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  String _selectedAssistanceType = 'Soil Testing';
  String _selectedSupportMethod = 'Phone Call';
  String _selectedPreferredTime = 'Morning (8:00 AM – 11:00 AM)';
  bool _isSubmitting = false;

  final List<String> _assistanceTypes = [
    'Soil Testing',
    'Disease Advice',
    'Irrigation Planning',
    'Organic Transition',
  ];

  final List<String> _supportMethods = [
    'Phone Call',
    'Voice Message',
    'Expert Visit',
  ];

  final List<String> _timeSlots = [
    'Morning (8:00 AM – 11:00 AM)',
    'Afternoon (1:00 PM – 4:00 PM)',
    'Evening (5:00 PM – 8:00 PM)',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitTechnicalRequest() async {
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

      final ticketId = 'KS-AID-TEC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      final app = AssistanceApplication(
        appId: ticketId,
        farmerMobile: mobile,
        farmerName: name,
        district: district,
        state: state,
        pinCode: pinCode,
        category: AssistanceCategory.technical,
        programId: 'prog_kvk_extension_advisory',
        programTitle: 'Technical Advisory: $_selectedAssistanceType ($_selectedSupportMethod)',
        details: 'Requested $_selectedAssistanceType via $_selectedSupportMethod during $_selectedPreferredTime. Query: ${_notesController.text.trim()}',
        requestedAmount: 0.0, // Free agronomic service under ICAR KVK
        status: 'PENDING',
        appliedAt: DateTime.now(),
        metadata: {
          'assistanceType': _selectedAssistanceType,
          'supportMethod': _selectedSupportMethod,
          'preferredTimeSlot': _selectedPreferredTime,
          'assignedCenter': 'Krishi Vigyan Kendra (KVK) $district',
        },
      );

      await ref.read(assistanceRepositoryProvider).submitApplication(app);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showAssistanceSuccessDialog(
        context: context,
        ticketId: ticketId,
        categoryTitle: 'Technical Advisory Request Registered',
        summaryText:
            'A KVK Agronomist will contact you via $_selectedSupportMethod during your preferred slot ($_selectedPreferredTime).',
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
              ? 'तकनीकी कृषि परामर्श'
              : activeLang.code == 'mr'
                  ? 'तांत्रिक कृषी सल्ला व मार्गदर्शन'
                  : 'Technical Assistance',
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

              // 2. Selectable Assistance Type & Method Card
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
                      label: 'Type of Technical Assistance',
                      icon: LucideIcons.microscope,
                      options: _assistanceTypes,
                      selectedValue: _selectedAssistanceType,
                      onSelected: (val) => setState(() => _selectedAssistanceType = val),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    AssistanceChipGroup(
                      label: 'Preferred Support Method',
                      icon: LucideIcons.phoneCall,
                      options: _supportMethods,
                      selectedValue: _selectedSupportMethod,
                      onSelected: (val) => setState(() => _selectedSupportMethod = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Timing & Notes Card
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
                      ref.watch(farmerLocalizationProvider).tr('best_time_to_contact'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPreferredTime,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _timeSlots.map((slot) => DropdownMenuItem(value: slot, child: Text(slot, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPreferredTime = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      ref.watch(farmerLocalizationProvider).tr('observations_questions'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('tech_desc_hint'),
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
                label: 'SUBMIT TECHNICAL REQUEST',
                icon: LucideIcons.headphones,
                isSubmitting: _isSubmitting,
                onPressed: _submitTechnicalRequest,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
