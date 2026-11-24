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

/// Screen 11 — Financial Aid Application Screen (`financial_aid_application`)
/// Features pre-filled farmer header card, KYC status indicator (storing only doc type & boolean),
/// selectable assistance types & amount brackets, context notes, and paperless submission.
class FinancialAidApplicationScreen extends ConsumerStatefulWidget {
  const FinancialAidApplicationScreen({super.key});

  @override
  ConsumerState<FinancialAidApplicationScreen> createState() => _FinancialAidApplicationScreenState();
}

class _FinancialAidApplicationScreenState extends ConsumerState<FinancialAidApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  String _selectedAssistanceType = 'Subsidy';
  String _selectedAmountBracket = '₹10k–₹50k';
  bool _isKycVerified = true;
  String _kycDocType = '7/12 Land Record (Satbara)';
  bool _isSubmitting = false;

  final List<String> _assistanceTypes = ['Subsidy', 'Loan', 'Investment'];
  final List<String> _amountBrackets = ['Below ₹10k', '₹10k–₹50k', '₹50k–₹1L', 'Above ₹1L'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double _getNumericAmountFromBracket(String bracket) {
    switch (bracket) {
      case 'Below ₹10k':
        return 8000.0;
      case '₹10k–₹50k':
        return 35000.0;
      case '₹50k–₹1L':
        return 75000.0;
      case 'Above ₹1L':
        return 150000.0;
      default:
        return 25000.0;
    }
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

      final ticketId = 'KS-AID-FIN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final amount = _getNumericAmountFromBracket(_selectedAmountBracket);

      final app = AssistanceApplication(
        appId: ticketId,
        farmerMobile: mobile,
        farmerName: name,
        district: district,
        state: state,
        pinCode: pinCode,
        category: AssistanceCategory.financial,
        programId: 'prog_financial_aid_direct',
        programTitle: '$_selectedAssistanceType Support ($_selectedAmountBracket)',
        details: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'Applied for $_selectedAssistanceType under amount bracket $_selectedAmountBracket.',
        requestedAmount: amount,
        status: 'PENDING',
        appliedAt: DateTime.now(),
        metadata: {
          'assistanceType': _selectedAssistanceType,
          'amountBracket': _selectedAmountBracket,
          'kycVerified': _isKycVerified,
          'kycDocType': _kycDocType,
          'compliance': 'Zero raw ID numbers stored. Only statutory verification boolean.',
        },
      );

      await ref.read(assistanceRepositoryProvider).submitApplication(app);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showAssistanceSuccessDialog(
        context: context,
        ticketId: ticketId,
        categoryTitle: 'Financial Aid & Grant Application',
        summaryText:
            'Your claim for $_selectedAssistanceType of $_selectedAmountBracket has been registered with PM-KISAN / NABARD state nodal desk.',
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
              ? 'वित्तीय सहायता आवेदन'
              : activeLang.code == 'mr'
                  ? 'आर्थिक मदत व कर्ज अनुदान अर्ज'
                  : 'Financial Aid Application',
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
              // 1. Farmer Details Header Card with KYC status
              AssistanceFarmerHeaderCard(
                initialKycVerified: _isKycVerified,
                initialDocType: _kycDocType,
                onKycStatusChanged: (val) => setState(() => _isKycVerified = val),
              ),
              const SizedBox(height: 20),

              // 2. Selectable Chip Group: Type of Assistance
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
                      label: 'Type of Financial Assistance',
                      icon: LucideIcons.indianRupee,
                      options: _assistanceTypes,
                      selectedValue: _selectedAssistanceType,
                      onSelected: (val) => setState(() => _selectedAssistanceType = val),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // 3. Selectable Chip Group: Amount Required
                    AssistanceChipGroup(
                      label: 'Amount Required',
                      icon: LucideIcons.coins,
                      options: _amountBrackets,
                      selectedValue: _selectedAmountBracket,
                      onSelected: (val) => setState(() => _selectedAmountBracket = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Context & Usage Notes
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
                        const Icon(LucideIcons.fileText, color: AppTheme.forestGreen, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          ref.watch(farmerLocalizationProvider).tr('context_purpose_optional'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('financial_desc_hint'),
                        hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Submit CTA
              AssistanceSubmitButton(
                label: 'SUBMIT FINANCIAL AID APPLICATION',
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
