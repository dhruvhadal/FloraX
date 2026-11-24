import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/assistance_repository.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../services/location/location_service.dart';
import '../../../domain/models/florax_models.dart';
import '../../widgets/assistance/assistance_widgets.dart';

/// Screen 14 — Emergency Aid Application Screen (`emergency_aid_application`)
/// Red-tinted "Priority Claim (24-Hour Review)" urgency banner, emergency types,
/// estimated crop damage brackets, photo evidence uploader, and urgent claim routing.
class EmergencyAidApplicationScreen extends ConsumerStatefulWidget {
  const EmergencyAidApplicationScreen({super.key});

  @override
  ConsumerState<EmergencyAidApplicationScreen> createState() => _EmergencyAidApplicationScreenState();
}

class _EmergencyAidApplicationScreenState extends ConsumerState<EmergencyAidApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cropController = TextEditingController(text: 'Tomato');
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedEmergencyType = 'Hail';
  String _selectedDamageBracket = '50%–75%';
  File? _evidencePhoto;
  bool _isSubmitting = false;

  final List<String> _emergencyTypes = ['Flood', 'Drought', 'Pest', 'Hail'];
  final List<String> _damageBrackets = ['<25%', '25%–50%', '50%–75%', '>75%'];

  @override
  void dispose() {
    _cropController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _evidencePhoto = File(picked.path));
      }
    } catch (e) {
      final loc = ref.read(farmerLocalizationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.tr('could_not_access_image')}: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    final loc = ref.read(farmerLocalizationProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.tr('attach_crop_damage_photo'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(LucideIcons.camera, color: AppTheme.alertRed),
                title: Text(loc.tr('capture_with_camera')),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppTheme.alertRed),
                title: Text(loc.tr('select_from_gallery')),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEmergencyClaim() async {
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

      final ticketId = 'KS-AID-EMG-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final crop = _cropController.text.trim();

      double estimatedClaimAmount;
      switch (_selectedDamageBracket) {
        case '<25%':
          estimatedClaimAmount = 10000.0;
          break;
        case '25%–50%':
          estimatedClaimAmount = 25000.0;
          break;
        case '50%–75%':
          estimatedClaimAmount = 45000.0;
          break;
        case '>75%':
          estimatedClaimAmount = 75000.0;
          break;
        default:
          estimatedClaimAmount = 30000.0;
      }

      final app = AssistanceApplication(
        appId: ticketId,
        farmerMobile: mobile,
        farmerName: name,
        district: district,
        state: state,
        pinCode: pinCode,
        category: AssistanceCategory.emergency,
        programId: 'prog_pmfby_relief_02',
        programTitle: 'Emergency $_selectedEmergencyType Relief for $crop ($_selectedDamageBracket Damage)',
        details: 'Urgent Disaster Claim: $_selectedEmergencyType inflicted $_selectedDamageBracket loss on $crop. Notes: ${_notesController.text.trim()}',
        requestedAmount: estimatedClaimAmount,
        status: 'PENDING',
        appliedAt: DateTime.now(),
        metadata: {
          'priority': 'urgent_24h',
          'emergencyType': _selectedEmergencyType,
          'targetCrop': crop,
          'damageBracket': _selectedDamageBracket,
          'hasPhotoEvidence': _evidencePhoto != null,
          'photoLocalPath': _evidencePhoto?.path,
          'routedTo': 'District Disaster Management Authority (DDMA) & PMFBY Nodal Cell',
        },
      );

      await ref.read(assistanceRepositoryProvider).submitApplication(app);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showAssistanceSuccessDialog(
        context: context,
        ticketId: ticketId,
        categoryTitle: 'Priority Disaster Relief Claim (24H)',
        summaryText:
            'Your urgent claim for $crop damage ($_selectedDamageBracket due to $_selectedEmergencyType) has been escalated to the Taluka Disaster Control Cell.',
        isUrgent: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final loc = ref.read(farmerLocalizationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.tr('submission_queued_offline')} ($e)'),
          backgroundColor: AppTheme.alertRed,
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
        backgroundColor: AppTheme.alertRed,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          activeLang.code == 'hi'
              ? 'आपातकालीन आपदा सहायता'
              : activeLang.code == 'mr'
                  ? 'आपत्कालीन नुकसान भरपाई अर्ज'
                  : 'Emergency Aid Application',
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
              // 1. Priority Claim (24-Hour Review) Urgency Top Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.alertRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.alarmClock, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.watch(farmerLocalizationProvider).tr('priority_claim_24h'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeLang.code == 'hi'
                                ? 'प्राकृतिक आपदा या कीट प्रकोप हेतु 24 घंटे में क्षेत्रीय सर्वेक्षण दल रवाना होगा।'
                                : activeLang.code == 'mr'
                                    ? 'नैसर्गिक आपत्ती किंवा कीड नुकसानीसाठी २४ तासांत पंचनामा प्रक्रिया सुरू होईल.'
                                    : 'Emergency claims are expedited for PMFBY & District Nodal inspection within 24 hours.',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Farmer Header Card
              const AssistanceFarmerHeaderCard(),
              const SizedBox(height: 18),

              // 3. Emergency Details Card
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
                    // Type of Emergency
                    AssistanceChipGroup(
                      label: 'Type of Emergency Calamity',
                      icon: LucideIcons.flame,
                      options: _emergencyTypes,
                      selectedValue: _selectedEmergencyType,
                      onSelected: (val) => setState(() => _selectedEmergencyType = val),
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // Affected Crop text field
                    Text(
                      ref.watch(farmerLocalizationProvider).tr('affected_crop_required'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cropController,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('affected_crops_hint'),
                        prefixIcon: const Icon(LucideIcons.leaf, color: AppTheme.alertRed, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter affected crop' : null,
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // Estimated Crop Damage Chips
                    AssistanceChipGroup(
                      label: 'Estimated Crop Damage Percentage',
                      icon: LucideIcons.pieChart,
                      options: _damageBrackets,
                      selectedValue: _selectedDamageBracket,
                      onSelected: (val) => setState(() => _selectedDamageBracket = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Dedicated Damaged Crop Photo Evidence Uploader
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
                        const Icon(LucideIcons.camera, color: AppTheme.alertRed, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          ref.watch(farmerLocalizationProvider).tr('damaged_photo_evidence'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ref.watch(farmerLocalizationProvider).tr('photo_evidence_tip'),
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    if (_evidencePhoto != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _evidencePhoto!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                              child: IconButton(
                                icon: const Icon(LucideIcons.trash2, color: Colors.white, size: 16),
                                onPressed: () => setState(() => _evidencePhoto = null),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: _showImageSourceDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.alertRed.withValues(alpha: 0.4),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.uploadCloud, color: AppTheme.alertRed, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                ref.watch(farmerLocalizationProvider).tr('tap_upload_damage_photo'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.alertRed),
                              ),
                              Text(
                                ref.watch(farmerLocalizationProvider).tr('camera_or_gallery'),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Additional notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: ref.watch(farmerLocalizationProvider).tr('calamity_desc_hint'),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Urgent Submit CTA
              AssistanceSubmitButton(
                label: 'REQUEST URGENT RELIEF (24H)',
                icon: LucideIcons.send,
                isEmergency: true,
                isSubmitting: _isSubmitting,
                onPressed: _submitEmergencyClaim,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
