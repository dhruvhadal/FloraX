import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/farmer_localization.dart';
import '../../../domain/models/florax_models.dart';

class OfflineGuidesScreen extends ConsumerStatefulWidget {
  const OfflineGuidesScreen({super.key});

  @override
  ConsumerState<OfflineGuidesScreen> createState() => _OfflineGuidesScreenState();
}

class _OfflineGuidesScreenState extends ConsumerState<OfflineGuidesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<IcarIpmProtocol> _allProtocols = [];
  List<IcarIpmProtocol> _filteredProtocols = [];
  bool _isLoading = true;
  String _selectedCrop = 'All';
  String _selectedCategory = 'All';

  final List<String> _crops = [
    'All',
    'Tomato',
    'Cotton',
    'Potato',
    'Rice',
    'Wheat',
    'Sugarcane',
    'Chilli',
    'Maize',
    'Soybean',
    'Grapes',
  ];

  final List<String> _categories = [
    'All',
    'FUNGAL',
    'BACTERIAL',
    'VIRAL',
    'NUTRIENT',
  ];

  @override
  void initState() {
    super.initState();
    _loadProtocols();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProtocols() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/offline_icar_protocols.json');
      final dynamic decoded = json.decode(jsonStr);
      if (decoded is List) {
        final List<IcarIpmProtocol> loaded = [];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              loaded.add(IcarIpmProtocol.fromMap(item, item['id']?.toString()));
            } catch (_) {
              // Gracefully continue on any single malformed record
            }
          }
        }
        if (mounted) {
          setState(() {
            _allProtocols = loaded;
            _filteredProtocols = loaded;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredProtocols = _allProtocols.where((p) {
        // Crop filter
        if (_selectedCrop != 'All') {
          final matchesCrop = p.affectedCrops.any((c) => c.toLowerCase().contains(_selectedCrop.toLowerCase()));
          if (!matchesCrop) return false;
        }

        // Category filter
        if (_selectedCategory != 'All') {
          if (p.category.toFirestoreValue() != _selectedCategory) return false;
        }

        // Search query
        if (query.isNotEmpty) {
          final nameEn = (p.diseaseName['en'] ?? '').toLowerCase();
          final nameHi = (p.diseaseName['hi'] ?? '').toLowerCase();
          final nameMr = (p.diseaseName['mr'] ?? '').toLowerCase();
          final sci = p.scientificName.toLowerCase();
          final crops = p.affectedCrops.join(' ').toLowerCase();

          final matches = nameEn.contains(query) ||
              nameHi.contains(query) ||
              nameMr.contains(query) ||
              sci.contains(query) ||
              crops.contains(query);
          if (!matches) return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final loc = ref.watch(farmerLocalizationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        title: Text(
          activeLang.code == 'hi'
              ? 'ऑफ़लाइन कृषि संदर्भ पुस्तिका'
              : activeLang.code == 'mr'
                  ? 'ऑफलाइन पीक संरक्षण संदर्भ'
                  : 'Offline ICAR Field Guides',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Top Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: activeLang.code == 'hi'
                        ? 'रोग या फसल का नाम खोजें...'
                        : activeLang.code == 'mr'
                            ? 'रोग किंवा पिकाचे नाव शोधा...'
                            : 'Search by disease, pathogen, or crop...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.forestGreen),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF4F7F4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal Crop Chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _crops.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final crop = _crops[idx];
                      final isSelected = _selectedCrop == crop;
                      return ChoiceChip(
                        label: Text(
                          crop,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppTheme.forestGreen,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.forestGreen,
                        backgroundColor: AppTheme.pistachioPill.withOpacity(0.3),
                        onSelected: (_) {
                          setState(() => _selectedCrop = crop);
                          _applyFilters();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Horizontal Category Chips
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final isSelected = _selectedCategory == cat;
                      return FilterChip(
                        label: Text(
                          cat == 'NUTRIENT' ? 'ABIOTIC/NUTRIENT' : cat,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: _getCategoryColor(cat),
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                          _applyFilters();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Offline Status Sub-header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.pistachioPill.withOpacity(0.2),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 16, color: AppTheme.forestGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_filteredProtocols.length} ${loc.tr('icar_protocols_offline_count')}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.forestGreen),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // List of Protocols
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.forestGreen))
                : _filteredProtocols.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(ref.watch(farmerLocalizationProvider).tr('no_matching_icar_guide'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredProtocols.length,
                        itemBuilder: (context, idx) {
                          final p = _filteredProtocols[idx];
                          return _buildProtocolCard(p, activeLang.code);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'FUNGAL':
        return Colors.brown.shade600;
      case 'BACTERIAL':
        return Colors.orange.shade800;
      case 'VIRAL':
        return Colors.red.shade700;
      case 'NUTRIENT':
      case 'ABIOTIC':
        return const Color(0xFF0D9488);
      default:
        return AppTheme.forestGreen;
    }
  }

  Widget _buildProtocolCard(IcarIpmProtocol protocol, String langCode) {
    final loc = ref.watch(farmerLocalizationProvider);
    final title = protocol.diseaseName[langCode] ?? protocol.diseaseName['en'] ?? protocol.id;
    final catColor = _getCategoryColor(protocol.category.toFirestoreValue());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            protocol.isAbioticNutrientDeficiency ? Icons.science : Icons.coronavirus,
            color: catColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              protocol.scientificName,
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    protocol.category.toFirestoreValue(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: catColor),
                  ),
                ),
                ...protocol.affectedCrops.take(3).map((crop) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        crop,
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade800),
                      ),
                    )),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),

                // Causal Agent
                if ((protocol.causalAgent[langCode] ?? protocol.causalAgent['en']) != null) ...[
                  Text(ref.watch(farmerLocalizationProvider).tr('pathological_etiology'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.forestGreen)),
                  const SizedBox(height: 4),
                  Text(
                    protocol.causalAgent[langCode] ?? protocol.causalAgent['en']!,
                    style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                ],

                // Distinguishing Symptoms
                if (protocol.distinguishingSymptoms[langCode]?.isNotEmpty ?? protocol.distinguishingSymptoms['en']?.isNotEmpty ?? false) ...[
                  Text(ref.watch(farmerLocalizationProvider).tr('key_diagnostic_symptoms'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.forestGreen)),
                  const SizedBox(height: 4),
                  ...(protocol.distinguishingSymptoms[langCode] ?? protocol.distinguishingSymptoms['en'] ?? []).map(
                    (symptom) => Padding(
                      padding: const EdgeInsets.only(bottom: 3.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.forestGreen)),
                          Expanded(child: Text(symptom, style: const TextStyle(fontSize: 12, height: 1.3))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Natural Remedy Steps (AgriSage Organics)
                if (protocol.naturalRemedySteps.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.leafGreen.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.eco, color: AppTheme.leafGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              loc.tr('agrisage_icar_bio_protocol'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.forestGreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...protocol.naturalRemedySteps.asMap().entries.map((entry) {
                          final step = entry.value;
                          final idx = entry.key + 1;
                          final stepTitle = step.title[langCode] ?? step.title['en'] ?? 'Preparation Step';
                          final instr = step.instructions[langCode] ?? step.instructions['en'] ?? '';
                          final ingredients = step.ingredients.isNotEmpty ? step.ingredients.join(', ') : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$idx. $stepTitle ${ingredients.isNotEmpty ? '($ingredients)' : ''}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF155724)),
                                ),
                                if (instr.isNotEmpty)
                                  Text(instr, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.25)),
                                Text(
                                  '${loc.tr('dosage_prefix')}: ${step.dosage} | ${loc.tr('timing_prefix')}: ${step.timing}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Cultural Sanitation
                if (protocol.tier1Cultural[langCode]?.isNotEmpty ?? protocol.tier1Cultural['en']?.isNotEmpty ?? false) ...[
                  Text(ref.watch(farmerLocalizationProvider).tr('cultural_preventive_practices'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.forestGreen)),
                  const SizedBox(height: 4),
                  ...(protocol.tier1Cultural[langCode] ?? protocol.tier1Cultural['en'] ?? []).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.forestGreen),
                          const SizedBox(width: 6),
                          Expanded(child: Text(item, style: const TextStyle(fontSize: 11, height: 1.25))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
