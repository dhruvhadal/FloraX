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

/// Screen 16 — NGO Support Application Screen (`ngo_support_application`)
/// Features top header "NGO Support Form", selectable support types (Grants, Labor, Relief),
/// live NGO search bar filtering local verified NGOs by name or 6-digit pin code,
/// selectable NGO recommendation card, situation context text area, and submission CTA.
class NgoSupportApplicationScreen extends ConsumerStatefulWidget {
  const NgoSupportApplicationScreen({super.key});

  @override
  ConsumerState<NgoSupportApplicationScreen> createState() => _NgoSupportApplicationScreenState();
}

class _NgoSupportApplicationScreenState extends ConsumerState<NgoSupportApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();

  String _selectedSupportType = 'Grants';
  List<NgoPartner> _allNgos = [];
  List<NgoPartner> _filteredNgos = [];
  NgoPartner? _selectedNgo;
  bool _isLoadingNgos = true;
  bool _isSubmitting = false;

  final List<String> _supportTypes = ['Grants', 'Labor', 'Relief'];

  @override
  void initState() {
    super.initState();
    _loadNgos();
    _searchController.addListener(_filterNgos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _loadNgos() async {
    final repo = ref.read(assistanceRepositoryProvider);
    final ngos = await repo.searchNgoDirectory();
    if (mounted) {
      setState(() {
        _allNgos = ngos;
        _filteredNgos = ngos;
        if (ngos.isNotEmpty) {
          _selectedNgo = ngos.first; // Pre-select first verified partner
        }
        _isLoadingNgos = false;
      });
    }
  }

  void _filterNgos() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNgos = _allNgos;
      } else {
        _filteredNgos = _allNgos.where((n) {
          final inName = n.name.toLowerCase().contains(query);
          final inDist = n.districtsServed.any((d) => d.toLowerCase().contains(query));
          final inFocus = n.focusAreas.any((f) => f.toLowerCase().contains(query));
          final inRep = n.fieldRepName.toLowerCase().contains(query);
          return inName || inDist || inFocus || inRep;
        }).toList();
      }
    });
  }

  Future<void> _submitNgoSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedNgo == null) {
      final loc = ref.read(farmerLocalizationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.tr('select_ngo_validation'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final farmer = await ref.read(farmerProfileRepositoryProvider).getLocalProfile();
      final liveLoc = ref.read(farmerLocationProvider).location;
      final mobile = farmer?.mobileE164 ?? '+919876543210';
      final name = farmer?.fullName ?? 'Kisan Mitra';
      final district = (farmer?.district.isNotEmpty == true ? farmer!.district : liveLoc?.district) ?? '';
      final state = (farmer?.state.isNotEmpty == true ? farmer!.state : liveLoc?.state) ?? '';
      final pinCode = (farmer?.pincode.isNotEmpty == true ? farmer!.pincode : liveLoc?.postalCode) ?? '';

      final ticketId = 'KS-AID-NGO-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      final app = AssistanceApplication(
        appId: ticketId,
        farmerMobile: mobile,
        farmerName: name,
        district: district,
        state: state,
        pinCode: pinCode,
        category: AssistanceCategory.ngo,
        programId: _selectedNgo!.ngoId,
        programTitle: 'NGO Support: ${_selectedNgo!.name} ($_selectedSupportType)',
        details: 'Assistance in form of $_selectedSupportType requested from ${_selectedNgo!.name}. Situation: ${_contextController.text.trim()}',
        requestedAmount: _selectedSupportType == 'Grants' ? 15000.0 : 0.0,
        status: 'PENDING',
        appliedAt: DateTime.now(),
        metadata: {
          'supportType': _selectedSupportType,
          'ngoId': _selectedNgo!.ngoId,
          'ngoName': _selectedNgo!.name,
          'fieldRepName': _selectedNgo!.fieldRepName,
          'fieldRepContact': _selectedNgo!.fieldRepContact,
        },
      );

      await ref.read(assistanceRepositoryProvider).submitApplication(app);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showAssistanceSuccessDialog(
        context: context,
        ticketId: ticketId,
        categoryTitle: 'NGO Field Relief Request Forwarded',
        summaryText:
            'Your requisition for $_selectedSupportType has been linked to ${_selectedNgo!.name}. Field representative ${_selectedNgo!.fieldRepName} will connect shortly.',
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
              ? 'एनजीओ सहायता आवेदन'
              : activeLang.code == 'mr'
                  ? 'स्वयंसेवी संस्था (NGO) मदत अर्ज'
                  : 'NGO Support Form',
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

              // 2. Type of Support Needed Chips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: AssistanceChipGroup(
                  label: 'Type of Support Needed',
                  icon: LucideIcons.heartHandshake,
                  options: _supportTypes,
                  selectedValue: _selectedSupportType,
                  onSelected: (val) => setState(() => _selectedSupportType = val),
                ),
              ),
              const SizedBox(height: 18),

              // 3. Live NGO Search Bar & Selectable Directory
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
                        const Icon(LucideIcons.building2, color: AppTheme.forestGreen, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          ref.watch(farmerLocalizationProvider).tr('select_verified_ngo_partner'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search input
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('search_ngo_hint'),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.forestGreen),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingNgos)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppTheme.forestGreen)))
                    else if (_filteredNgos.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(ref.watch(farmerLocalizationProvider).tr('no_ngo_found'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredNgos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final ngo = _filteredNgos[idx];
                          final isSelected = _selectedNgo?.ngoId == ngo.ngoId;

                          return InkWell(
                            onTap: () => setState(() => _selectedNgo = ngo),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppTheme.forestGreen : Colors.grey.shade300,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Radio<String>(
                                    value: ngo.ngoId,
                                    groupValue: _selectedNgo?.ngoId,
                                    activeColor: AppTheme.forestGreen,
                                    onChanged: (_) => setState(() => _selectedNgo = ngo),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ngo.name,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '#${ngo.registrationNumber} • ${ngo.fieldRepName}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: ngo.focusAreas
                                              .map((f) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(f, style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569))),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Situation Context Text Area
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
                      ref.watch(farmerLocalizationProvider).tr('situation_needs_required'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contextController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('ngo_desc_hint'),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please describe your situation' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Submit CTA
              AssistanceSubmitButton(
                label: 'SUBMIT NGO RELIEF APPLICATION',
                icon: LucideIcons.send,
                isSubmitting: _isSubmitting,
                onPressed: _submitNgoSupportRequest,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
