import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/localization/farmer_localization.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/assistance_repository.dart';
import '../../../data/repositories/farmer_profile_repository.dart';
import '../../../domain/models/florax_models.dart';

/// Screen 10 — KisanSetu Assistance Hub (`assistance_hub_screen`)
/// Rebranded visible title: "KisanSetu Assistance Hub"
/// Features 6-category navigation grid, verified available programs directory,
/// and sticky "My Applications" live tracker footer.
class AssistanceHubScreen extends ConsumerStatefulWidget {
  const AssistanceHubScreen({super.key});

  @override
  ConsumerState<AssistanceHubScreen> createState() => _AssistanceHubScreenState();
}

class _AssistanceHubScreenState extends ConsumerState<AssistanceHubScreen> {
  AssistanceCategory? _selectedCategory;
  List<AidProgram> _availablePrograms = [];
  bool _isLoadingPrograms = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    final repo = ref.read(assistanceRepositoryProvider);
    final progs = await repo.getAvailablePrograms(category: _selectedCategory);
    if (mounted) {
      setState(() {
        _availablePrograms = progs;
        _isLoadingPrograms = false;
      });
    }
  }

  void _onCategoryFilterChanged(AssistanceCategory? cat) {
    setState(() {
      _selectedCategory = cat;
      _isLoadingPrograms = true;
    });
    _loadPrograms();
  }

  void _showMyApplicationsSheet(BuildContext context, String farmerMobile) {
    final repo = ref.read(assistanceRepositoryProvider);
    final activeLang = ref.read(activeFarmerLanguageProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return StreamBuilder<List<AssistanceApplication>>(
            stream: repo.watchFarmerApplications(farmerMobile),
            builder: (context, snapshot) {
              final apps = snapshot.data ?? [];

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.fileClock, color: AppTheme.forestGreen, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              activeLang.code == 'hi'
                                  ? 'मेरे एनजीओ अनुरोध (NGO Requests)'
                                  : (activeLang.code == 'mr'
                                      ? 'माझे एनजीओ अर्ज (NGO Requests)'
                                      : 'My NGO Support Applications'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.pistachioPill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${apps.length} ${activeLang.code == 'hi' ? 'दर्ज' : (activeLang.code == 'mr' ? 'नोंदवले' : 'Filed')}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: apps.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.inbox, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                Text(
                                  activeLang.code == 'hi'
                                      ? 'कोई एनजीओ अनुरोध दर्ज नहीं है'
                                      : (activeLang.code == 'mr'
                                          ? 'कोणताही एनजीओ अर्ज नोंदवलेला नाही'
                                          : 'No NGO requests submitted yet'),
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  activeLang.code == 'hi'
                                      ? 'गैर-सरकारी राहत के लिए ऊपर दिए गए कार्ड पर टैप करें।'
                                      : (activeLang.code == 'mr'
                                          ? 'बिगर-शासकीय मदतीसाठी वरील कार्डवर टॅप करा.'
                                          : 'Select the NGO Support card above to apply for direct relief.'),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: apps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final app = apps[idx];
                              return _buildApplicationItem(app);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showSchemeDetailsSheet(BuildContext context, AidProgram prog, String langCode) {
    final title = prog.title[langCode] ?? prog.title['en'] ?? prog.programId;
    final desc = prog.description[langCode] ?? prog.description['en'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.pistachioPill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        prog.category.name.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        langCode == 'hi'
                            ? 'सरकारी योजना • केवल सूचनात्मक'
                            : (langCode == 'mr'
                                ? 'शासकीय योजना • केवळ माहितीपर'
                                : 'Government Scheme • Informational'),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  '${langCode == 'hi' ? 'संबद्ध प्राधिकारी' : (langCode == 'mr' ? 'संबंधित प्राधिकरण' : 'Issuing Authority')}: ${prog.sponsoringAgency}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.forestGreen),
                ),
                const SizedBox(height: 14),
                if (prog.maxBenefitAmount > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.award, color: AppTheme.forestGreen, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              langCode == 'hi' ? 'अधिकतम लाभ राशि' : (langCode == 'mr' ? 'कमाल लाभ रक्कम' : 'Maximum Direct Benefit'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                            ),
                            Text(
                              '₹${prog.maxBenefitAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  langCode == 'hi' ? 'योजना विवरण व पात्रता' : (langCode == 'mr' ? 'योजना तपशील व पात्रता' : 'Scheme Description & Guidelines'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 16),
                if (prog.requiredDocuments.isNotEmpty) ...[
                  Text(
                    langCode == 'hi' ? 'आवश्यक दस्तावेज सूची' : (langCode == 'mr' ? 'आवश्यक कागदपत्रे सूची' : 'Required Verification Documents'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  ...prog.requiredDocuments.map((doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.checkCircle2, color: AppTheme.forestGreen, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                doc,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                // Informational Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.info, color: Color(0xFF92400E), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          langCode == 'hi'
                              ? 'यह केवल सूचनात्मक सरकारी योजना है। आवेदन आधिकारिक सरकारी पोर्टल (pmkisan.gov.in) अथवा स्थानीय कृषि विज्ञान केंद्र (KVK) के माध्यम से ही किया जा सकता है।'
                              : langCode == 'mr'
                                  ? 'ही केवळ माहितीपर शासकीय योजना आहे. अर्ज अधिकृत शासकीय पोर्टल अथवा स्थानिक कृषी विज्ञान केंद्र (KVK) द्वारेच सादर करावेत.'
                                  : 'This is a read-only government scheme. Please submit applications through official state portals or your nearest Krishi Vigyan Kendra (KVK).',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      langCode == 'hi' ? 'बंद करें' : (langCode == 'mr' ? 'बंद करा' : 'Close'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildApplicationItem(AssistanceApplication app) {
    Color statusColor;
    Color statusBg;
    switch (app.status.toUpperCase()) {
      case 'APPROVED':
      case 'DISBURSED':
        statusColor = const Color(0xFF047857);
        statusBg = const Color(0xFFECFDF5);
        break;
      case 'REJECTED':
        statusColor = AppTheme.alertRed;
        statusBg = const Color(0xFFFEE2E2);
        break;
      default:
        statusColor = const Color(0xFFB45309);
        statusBg = const Color(0xFFFFFBEB);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                app.appId,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  app.status,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            app.programTitle.isNotEmpty ? app.programTitle : '${app.category.name.toUpperCase()} AID',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.forestGreen),
          ),
          const SizedBox(height: 4),
          Text(
            app.details,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ref.watch(farmerLocalizationProvider).tr('applied_on_prefix')}: ${app.appliedAt.day}/${app.appliedAt.month}/${app.appliedAt.year}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (app.requestedAmount > 0)
                Text(
                  '₹${app.requestedAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final farmerAsync = ref.watch(farmerProfileRepositoryProvider).getLocalProfile();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        title: Text(
          activeLang.code == 'hi'
              ? 'किसानसेतु सहायता केंद्र'
              : activeLang.code == 'mr'
                  ? 'किसानसेतू मदत व अनुदान केंद्र'
                  : 'KisanSetu Assistance Hub',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top NGO Support Hero Card
                InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.assistanceNgo),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F5132), Color(0xFF198754)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.forestGreen.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  activeLang.code == 'hi'
                                      ? 'एनजीओ व सीएसआर सहायता'
                                      : (activeLang.code == 'mr'
                                          ? 'एनजीओ व सीएसआर मदत'
                                          : 'NGO SUPPORT & CSR RELIEF'),
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                activeLang.code == 'hi'
                                    ? 'प्रत्यक्ष एनजीओ सहायता व सीएसआर अनुदान'
                                    : (activeLang.code == 'mr'
                                        ? 'थेट एनजीओ मदत व सीएसआर सहाय्य'
                                        : 'Direct NGO Support & CSR Relief'),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeLang.code == 'hi'
                                    ? 'गैर-सरकारी राहत, सीएसआर इनपुट किट और आपातकालीन सहायता के लिए आवेदन करें।'
                                    : (activeLang.code == 'mr'
                                        ? 'बिगर-शासकीय मदत, सीएसआर इनपुट किट्स व तातडीचे शेती सहाय्यासाठी अर्ज करा.'
                                        : 'Direct non-governmental relief, CSR input kits, and urgent grassroots farm support.'),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.heartHandshake, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 5-Category Informational Navigation Grid
                Text(
                  activeLang.code == 'hi'
                      ? 'सहायता श्रेणी चुनें (Select Category)'
                      : (activeLang.code == 'mr'
                          ? 'मदत श्रेणी निवडा (Select Category)'
                          : 'Select Aid Category'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _buildCategoryTile(
                      title: activeLang.code == 'hi'
                          ? 'वित्तीय सहायता'
                          : (activeLang.code == 'mr' ? 'आर्थिक सहाय्य' : 'Financial Aid'),
                      desc: activeLang.code == 'hi'
                          ? 'सब्सिडी व पीएम-किसान'
                          : (activeLang.code == 'mr' ? 'अनुदान व पीएम-किसान' : 'Subsidies, Loans & PM-KISAN'),
                      icon: LucideIcons.indianRupee,
                      color: const Color(0xFF0D9488),
                      onTap: () => _onCategoryFilterChanged(AssistanceCategory.financial),
                    ),
                    _buildCategoryTile(
                      title: activeLang.code == 'hi'
                          ? 'कृषि इनपुट किट'
                          : (activeLang.code == 'mr' ? 'शेती निविष्ठा' : 'Farm Inputs'),
                      desc: activeLang.code == 'hi'
                          ? 'बीज, जैव उर्वरक व उपकरणे'
                          : (activeLang.code == 'mr' ? 'बियाणे, सेंद्रिय खते व अवजारे' : 'Seeds, Bio-Fertiliser & Tools'),
                      icon: LucideIcons.sprout,
                      color: AppTheme.leafGreen,
                      onTap: () => _onCategoryFilterChanged(AssistanceCategory.inputs),
                    ),
                    _buildCategoryTile(
                      title: activeLang.code == 'hi'
                          ? 'यंत्रसामग्री सहाय्यता'
                          : (activeLang.code == 'mr' ? 'यंत्रसामग्री सहाय्य' : 'Equipment Support'),
                      desc: activeLang.code == 'hi'
                          ? 'ट्रैक्टर, स्प्रेयर व पंप'
                          : (activeLang.code == 'mr' ? 'ट्रॅक्टर, फवारणी यंत्र व पंप' : 'Tractors, Sprayers & Pumps'),
                      icon: LucideIcons.wrench,
                      color: Colors.blue.shade700,
                      onTap: () => _onCategoryFilterChanged(AssistanceCategory.equipment),
                    ),
                    _buildCategoryTile(
                      title: activeLang.code == 'hi'
                          ? 'आपत्कालीन सहाय्यता'
                          : (activeLang.code == 'mr' ? 'आपत्कालीन मदत' : 'Emergency Aid'),
                      desc: activeLang.code == 'hi'
                          ? 'बाढ़, सूखा व कीट (24h)'
                          : (activeLang.code == 'mr' ? 'पूर, दुष्काळ व कीड (24h)' : 'Flood, Drought & Pest (24h)'),
                      icon: LucideIcons.alertTriangle,
                      color: AppTheme.alertRed,
                      onTap: () => _onCategoryFilterChanged(AssistanceCategory.emergency),
                      isUrgent: true,
                    ),
                    _buildCategoryTile(
                      title: activeLang.code == 'hi'
                          ? 'तकनीकी मार्गदर्शन'
                          : (activeLang.code == 'mr' ? 'तांत्रिक सहाय्य' : 'Technical Assistance'),
                      desc: activeLang.code == 'hi'
                          ? 'मृदा परीक्षण व सलाह'
                          : (activeLang.code == 'mr' ? 'माती परीक्षण व कृषी सल्ला' : 'Soil Testing & Advisory'),
                      icon: LucideIcons.microscope,
                      color: Colors.purple.shade700,
                      onTap: () => _onCategoryFilterChanged(AssistanceCategory.technical),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Verified Programs Directory Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.watch(farmerLocalizationProvider).tr('available_verified_programs'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '${_availablePrograms.length} ${ref.watch(farmerLocalizationProvider).tr('schemes_suffix')}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.forestGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', _selectedCategory == null, () => _onCategoryFilterChanged(null)),
                      ...AssistanceCategory.values.where((cat) => cat != AssistanceCategory.ngo).map((cat) {
                        return _buildFilterChip(
                          cat.name.toUpperCase(),
                          _selectedCategory == cat,
                          () => _onCategoryFilterChanged(cat),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Programs List
                if (_isLoadingPrograms)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.forestGreen)),
                  )
                else if (_availablePrograms.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Text(ref.watch(farmerLocalizationProvider).tr('no_schemes_found'), style: const TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _availablePrograms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final prog = _availablePrograms[idx];
                      return _buildProgramCard(prog, activeLang.code);
                    },
                  ),
              ],
            ),
          ),

          // Sticky Bottom "Track My NGO Requests" Banner
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FutureBuilder(
              future: farmerAsync,
              builder: (context, snapshot) {
                final mobile = snapshot.data?.mobileE164 ?? '+91 98765 43210';
                final repo = ref.watch(assistanceRepositoryProvider);

                return StreamBuilder<List<AssistanceApplication>>(
                  stream: repo.watchFarmerApplications(mobile),
                  builder: (context, appSnap) {
                    final count = appSnap.data?.length ?? 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.pistachioPill,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.heartHandshake, color: AppTheme.forestGreen, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    activeLang.code == 'hi'
                                        ? 'मेरे एनजीओ अनुरोध (NGO Requests)'
                                        : (activeLang.code == 'mr'
                                            ? 'माझे एनजीओ अर्ज (NGO Requests)'
                                            : 'Track My NGO Requests'),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  Text(
                                    activeLang.code == 'hi'
                                        ? '$count सक्रिय अनुरोध दर्ज'
                                        : (activeLang.code == 'mr'
                                            ? '$count सक्रिय अर्ज नोंदीवर'
                                            : '$count active submissions on record'),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _showMyApplicationsSheet(context, mobile),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.forestGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(ref.watch(farmerLocalizationProvider).tr('view_all'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.forestGreen,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppTheme.forestGreen : Colors.grey.shade300),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildCategoryTile({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isUrgent = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isUrgent ? AppTheme.alertRed.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: isUrgent ? 1.5 : 1.0,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('24H', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    )
                  else
                    const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramCard(AidProgram prog, String langCode) {
    final title = prog.title[langCode] ?? prog.title['en'] ?? prog.programId;
    final desc = prog.description[langCode] ?? prog.description['en'] ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _showSchemeDetailsSheet(context, prog, langCode),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.pistachioPill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      prog.category.name.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
                    ),
                  ),
                  const Spacer(),
                  if (prog.maxBenefitAmount > 0)
                    Text(
                      '${langCode == 'hi' ? 'लाभ' : (langCode == 'mr' ? 'लाभ' : 'Benefit')}: ₹${prog.maxBenefitAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                '${langCode == 'hi' ? 'प्राधिकरण' : (langCode == 'mr' ? 'प्राधिकरण' : 'Provider')}: ${prog.sponsoringAgency}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              if (prog.requiredDocuments.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: prog.requiredDocuments.map((doc) => Chip(
                        label: Text(doc, style: const TextStyle(fontSize: 10)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(0),
                      )).toList(),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () => _showSchemeDetailsSheet(context, prog, langCode),
                  icon: const Icon(LucideIcons.info, size: 16),
                  label: Text(
                    langCode == 'hi'
                        ? 'योजना व पात्रता विवरण देखें'
                        : (langCode == 'mr'
                            ? 'योजना व पात्रता तपशील पहा'
                            : 'View Scheme & Eligibility'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.forestGreen,
                    side: const BorderSide(color: AppTheme.forestGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
