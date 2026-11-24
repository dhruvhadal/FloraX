import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/farmer_localization.dart';

class NpkCalculatorScreen extends ConsumerStatefulWidget {
  const NpkCalculatorScreen({super.key});

  @override
  ConsumerState<NpkCalculatorScreen> createState() => _NpkCalculatorScreenState();
}

class _NpkCalculatorScreenState extends ConsumerState<NpkCalculatorScreen> {
  final TextEditingController _areaController = TextEditingController(text: '1.0');
  String _selectedUnit = 'Acre'; // 'Acre' or 'Guntha' (1 Acre = 40 Gunthas)
  String _selectedCrop = 'Tomato';
  String _soilFertility = 'Medium'; // 'Low', 'Medium', 'High'

  // Standard ICAR recommended N-P-K (kg/acre) baseline ratios for major Indian crops
  static const Map<String, Map<String, double>> _cropNutrientNeeds = {
    'Tomato': {'N': 60.0, 'P': 40.0, 'K': 40.0},
    'Cotton': {'N': 48.0, 'P': 24.0, 'K': 24.0},
    'Sugarcane': {'N': 100.0, 'P': 40.0, 'K': 40.0},
    'Rice / Paddy': {'N': 40.0, 'P': 20.0, 'K': 20.0},
    'Wheat': {'N': 48.0, 'P': 24.0, 'K': 16.0},
    'Maize': {'N': 48.0, 'P': 24.0, 'K': 20.0},
    'Soybean': {'N': 12.0, 'P': 32.0, 'K': 16.0}, // Legume fixates nitrogen
    'Chilli': {'N': 50.0, 'P': 25.0, 'K': 25.0},
    'Potato': {'N': 60.0, 'P': 40.0, 'K': 50.0},
    'Onion': {'N': 40.0, 'P': 20.0, 'K': 30.0},
  };

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  double get _areaInAcres {
    final val = double.tryParse(_areaController.text) ?? 1.0;
    if (_selectedUnit == 'Guntha') {
      return val / 40.0;
    }
    return val;
  }

  double get _fertilityMultiplier {
    switch (_soilFertility) {
      case 'Low':
        return 1.25; // Apply 25% extra for nutrient-deficient soils
      case 'High':
        return 0.75; // Reduce 25% for rich soils to avoid vegetative burn
      default:
        return 1.00;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(farmerLocalizationProvider);
    final activeLang = ref.watch(activeFarmerLanguageProvider);
    final needs = _cropNutrientNeeds[_selectedCrop] ?? {'N': 50.0, 'P': 25.0, 'K': 25.0};
    final acres = _areaInAcres;
    final mult = _fertilityMultiplier;

    // Required pure nutrient (kg)
    final totalN = needs['N']! * acres * mult;
    final totalP = needs['P']! * acres * mult;
    final totalK = needs['K']! * acres * mult;

    // Standard fertilizer grades:
    // Urea: 46% N (50kg bag contains 23kg pure N) -> 45kg bag has 20.7kg N (Neem Coated Urea)
    // SSP (Single Super Phosphate): 16% P2O5 (50kg bag has 8kg pure P)
    // MOP (Muriate of Potash): 60% K2O (50kg bag has 30kg pure K)
    final ureaKg = totalN / 0.46;
    final sspKg = totalP / 0.16;
    final mopKg = totalK / 0.60;

    final ureaBags = (ureaKg / 45.0); // 45kg standard Indian Neem coated urea bag
    final sspBags = (sspKg / 50.0);
    final mopBags = (mopKg / 50.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        backgroundColor: AppTheme.forestGreen,
        foregroundColor: Colors.white,
        title: Text(
          activeLang.code == 'hi'
              ? 'NPK उर्वरक कैलकुलेटर'
              : activeLang.code == 'mr'
                  ? 'NPK खत गणक'
                  : 'ICAR N-P-K Dosage Calculator',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informational Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.pistachioPill.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.forestGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: AppTheme.forestGreen, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      activeLang.code == 'hi'
                          ? 'भारतीय कृषि अनुसंधान परिषद (ICAR) के मानकों के अनुसार सटीक उर्वरक गणना।'
                          : activeLang.code == 'mr'
                              ? 'भारतीय कृषी संशोधन परिषद (ICAR) च्या मानकांनुसार अचूक खत प्रमाण.'
                              : 'Scientific dosage estimation based on ICAR field-trial agronomic benchmarks.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.forestGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Card 1: Crop & Field Input
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.tr('crop_land_specs'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 14),

                    // Crop dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCrop,
                      decoration: InputDecoration(
                        labelText: loc.tr('select_crop'),
                        labelStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.eco, color: AppTheme.forestGreen),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _cropNutrientNeeds.keys.map((crop) {
                        return DropdownMenuItem(value: crop, child: Text(crop));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCrop = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Area & Unit input row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _areaController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            decoration: InputDecoration(
                              labelText: loc.tr('land_area'),
                              prefixIcon: const Icon(Icons.landscape, color: AppTheme.forestGreen),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            decoration: InputDecoration(
                              labelText: loc.tr('unit'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: [
                              DropdownMenuItem(value: 'Acre', child: Text(loc.tr('unit_acre'))),
                              DropdownMenuItem(value: 'Guntha', child: Text(loc.tr('unit_guntha'))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedUnit = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Soil Fertility Segment
                    Text(loc.tr('soil_fertility_status'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Low', 'Medium', 'High'].map((status) {
                        final isSelected = _soilFertility == status;
                        final displayLabel = status == 'Low'
                            ? loc.tr('fertility_low')
                            : (status == 'Medium' ? loc.tr('fertility_medium') : loc.tr('fertility_high'));
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  displayLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.forestGreen,
                              backgroundColor: Colors.grey.shade100,
                              onSelected: (_) => setState(() => _soilFertility = status),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Card 2: Pure Nutrients Breakdown
            Text(
              loc.tr('net_nutrient_req'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildNutrientTile('N (Nitrogen)', '${totalN.toStringAsFixed(1)} kg', Colors.blue.shade700, Icons.grass),
                const SizedBox(width: 8),
                _buildNutrientTile('P (Phosphorus)', '${totalP.toStringAsFixed(1)} kg', Colors.orange.shade800, Icons.grain),
                const SizedBox(width: 8),
                _buildNutrientTile('K (Potash)', '${totalK.toStringAsFixed(1)} kg', Colors.purple.shade700, Icons.spa),
              ],
            ),
            const SizedBox(height: 20),

            // Card 3: Fertilizer Bag Recommendation
            Text(
              loc.tr('commercial_bag_req'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),

            _buildFertilizerCard(
              name: 'Neem-Coated Urea (46% N)',
              bagWeight: '45 kg bag',
              exactBags: ureaBags,
              pureKg: ureaKg,
              color: Colors.blue.shade800,
              badge: 'Primary Nitrogen',
            ),
            const SizedBox(height: 10),
            _buildFertilizerCard(
              name: 'Single Super Phosphate (16% P)',
              bagWeight: '50 kg bag',
              exactBags: sspBags,
              pureKg: sspKg,
              color: Colors.orange.shade900,
              badge: 'Phosphorus + Sulfur (11%)',
            ),
            const SizedBox(height: 10),
            _buildFertilizerCard(
              name: 'Muriate of Potash (60% K)',
              bagWeight: '50 kg bag',
              exactBags: mopBags,
              pureKg: mopKg,
              color: Colors.purple.shade900,
              badge: 'Potassium / Fruit Rigidity',
            ),
            const SizedBox(height: 18),

            // Application Schedule Card
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
                      const Icon(Icons.calendar_month, color: AppTheme.harvestGold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        loc.tr('icar_split_schedule'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildScheduleItem(
                    phase: 'Basal Dose (At Sowing / Transplanting):',
                    desc: '100% of SSP + 50% of MOP + 25% of Urea incorporated into root zone.',
                  ),
                  const Divider(height: 16),
                  _buildScheduleItem(
                    phase: '1st Top Dressing (30 Days After Sowing):',
                    desc: '50% of remaining Urea applied near root line after light weeding.',
                  ),
                  const Divider(height: 16),
                  _buildScheduleItem(
                    phase: '2nd Top Dressing (Flowering / Boot Stage):',
                    desc: 'Remaining 25% Urea + 50% MOP to boost grain/fruit filling.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientTile(String title, String val, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFertilizerCard({
    required String name,
    required String bagWeight,
    required double exactBags,
    required double pureKg,
    required Color color,
    required String badge,
  }) {
    final roundedBags = exactBags.ceil();

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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shopping_bag, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${pureKg.toStringAsFixed(1)} kg ($bagWeight)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$roundedBags ${ref.watch(farmerLocalizationProvider).tr('bags_unit')}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                '(${exactBags.toStringAsFixed(1)})',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem({required String phase, required String desc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(phase, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.forestGreen)),
        const SizedBox(height: 3),
        Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
      ],
    );
  }
}
