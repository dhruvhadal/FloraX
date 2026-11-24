import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/farmer_localization.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String _selectedCategory = 'Scan Accuracy Query';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Scan Accuracy Query',
    'Offline AI Model Issue',
    'Consultation / Agronomist Request',
    'Report Crop Disease Outbreak',
    'New Crop Request',
    'General App Feedback',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    final loc = ref.read(farmerLocalizationProvider);
    final statusMsg = loc.tr('copied_to_clipboard');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: $text ($statusMsg)'),
        backgroundColor: AppTheme.forestGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final ticketRef = FirebaseFirestore.instance.collection('support_tickets').doc();
      final ticketId = 'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      await ticketRef.set({
        'ticketId': ticketId,
        'category': _selectedCategory,
        'message': _feedbackController.text.trim(),
        'contact': _contactController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'OPEN',
      }).timeout(const Duration(seconds: 4), onTimeout: () {
        // Offline graceful fallback
        return;
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _feedbackController.clear();
      _contactController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.forestGreen),
              const SizedBox(width: 8),
              Text(ref.read(farmerLocalizationProvider).tr('ticket_registered'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '${ref.read(farmerLocalizationProvider).tr('ticket_registered_desc')} (#$ticketId)',
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(farmerLocalizationProvider).tr('ticket_saved_offline')),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(farmerLocalizationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        title: Text(
          loc.tr('menu_help'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Emergency Helplines Card
            Text(
              loc.tr('national_state_helplines'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),

            _buildHelplineCard(
              title: 'Kisan Call Center (KCC) Toll-Free',
              phone: '1800-180-1551',
              subtitle: 'Free advisory in 22 languages • 6:00 AM - 10:00 PM',
              icon: Icons.headset_mic,
              badgeColor: AppTheme.forestGreen,
            ),
            const SizedBox(height: 10),

            _buildHelplineCard(
              title: 'PM-Kisan & Crop Insurance Helpline',
              phone: '155261',
              subtitle: 'Financial aid, DBT grants, and crop damage insurance',
              icon: Icons.account_balance,
              badgeColor: AppTheme.harvestGold,
            ),
            const SizedBox(height: 10),

            _buildHelplineCard(
              title: 'Maharashtra Agri Department Helpline',
              phone: '1800-233-4000',
              subtitle: 'Kisan desk for subsidized seeds, sprayers, and fertilizer',
              icon: Icons.phone_in_talk,
              badgeColor: const Color(0xFF0D9488),
            ),
            const SizedBox(height: 24),

            // FAQs Accordion
            Text(
              loc.tr('faq_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),

            _buildFaqItem(
              q: 'Does KisanSetu leaf scanner work without internet?',
              a: 'Yes! The 45-class EfficientNetV2 vision engine runs entirely on-device using quantized LiteRT. It performs full offline diagnosis even in remote fields without mobile data.',
            ),
            _buildFaqItem(
              q: 'Why are chemical fungicides locked when confidence is low?',
              a: 'To prevent hazardous misapplication, ICAR and Central Insecticide Board (CIB&RC) safety rules lock chemical sprays if AI confidence is under 75% or abiotic stress is diagnosed. You can request a 2nd opinion from a KVK agronomist with one tap.',
            ),
            _buildFaqItem(
              q: 'Are the biological remedies organic and certified?',
              a: 'All natural preparations (Neem kernel extract, Dashaparni ark, Trichoderma viride) strictly follow ICAR-NBAIR and State Agriculture University organic crop protection protocols.',
            ),
            _buildFaqItem(
              q: 'How does Regional Outbreak Radar predict risk zones?',
              a: 'Radar aggregates anonymized geolocated scans from nearby farms. If high-virulence pathogens (like Late Blight or Fall Armyworm) spike within 25 km, an automated alert is triggered.',
            ),
            const SizedBox(height: 24),

            // Submit Ticket / Grievance Form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: AppTheme.forestGreen),
                        const SizedBox(width: 8),
                        Text(
                          loc.tr('raise_grievance_query'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Topic dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: loc.tr('issue_category'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Message text area
                    TextFormField(
                      controller: _feedbackController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: loc.tr('describe_question'),
                        hintText: loc.tr('describe_question_hint'),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        alignLabelWithHint: true,
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please write your message' : null,
                    ),
                    const SizedBox(height: 14),

                    // Contact phone (optional)
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: loc.tr('contact_phone_optional'),
                        hintText: '+91 98765 43210',
                        prefixIcon: const Icon(Icons.phone, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.forestGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(loc.tr('submit_ticket_kvk'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineCard({
    required String title,
    required String phone,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: badgeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(phone, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: badgeColor)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AppTheme.forestGreen, size: 20),
            tooltip: 'Copy Number',
            onPressed: () => _copyToClipboard(phone, title),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required String q, required String a}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Text(a, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35)),
        ],
      ),
    );
  }
}
