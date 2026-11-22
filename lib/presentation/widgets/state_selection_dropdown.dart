import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/indian_regions.dart';
import '../../core/theme/florax_theme.dart';

/// Searchable State and Union Territory Selection Dropdown for Farmer Onboarding
class StateSelectionDropdown extends StatelessWidget {
  final String? selectedState;
  final ValueChanged<String> onStateSelected;
  final String? errorText;

  const StateSelectionDropdown({
    super.key,
    required this.selectedState,
    required this.onStateSelected,
    this.errorText,
  });

  void _openSearchableModal(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StateSearchBottomSheet(
        initiallySelected: selectedState,
      ),
    ).then((result) {
      if (result != null && result.isNotEmpty) {
        onStateSelected(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selectedState != null && selectedState!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _openSearchableModal(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: errorText != null
                    ? FloraXTheme.crimsonAlert
                    : (hasSelection ? FloraXTheme.primaryGreen : FloraXTheme.borderDim),
                width: hasSelection ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  color: FloraXTheme.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasSelection ? selectedState! : 'Select your State / Union Territory',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                      color: hasSelection ? FloraXTheme.textPrimary : FloraXTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  color: FloraXTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: FloraXTheme.crimsonAlert,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StateSearchBottomSheet extends StatefulWidget {
  final String? initiallySelected;

  const _StateSearchBottomSheet({this.initiallySelected});

  @override
  State<_StateSearchBottomSheet> createState() => _StateSearchBottomSheetState();
}

class _StateSearchBottomSheetState extends State<_StateSearchBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredStates = IndianRegions.states;
  List<String> _filteredUts = IndianRegions.unionTerritories;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStates = IndianRegions.states;
        _filteredUts = IndianRegions.unionTerritories;
      } else {
        _filteredStates = IndianRegions.states
            .where((s) => s.toLowerCase().contains(query))
            .toList();
        _filteredUts = IndianRegions.unionTerritories
            .where((u) => u.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: FloraXTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: FloraXTheme.borderDim,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Select State / UT (राज्य निवडा)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FloraXTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search state or union territory...',
                prefixIcon: const Icon(LucideIcons.search, size: 20, color: FloraXTheme.primaryGreen),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.xCircle, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_filteredStates.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Text(
                      'STATES (२८ राज्ये)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FloraXTheme.primaryGreen,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ..._filteredStates.map((state) => _buildItemTile(state)),
                ],
                if (_filteredUts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Text(
                      'UNION TERRITORIES (८ केंद्रशासित प्रदेश)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ..._filteredUts.map((ut) => _buildItemTile(ut)),
                ],
                if (_filteredStates.isEmpty && _filteredUts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No matching state or territory found.',
                        style: TextStyle(color: FloraXTheme.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(String name) {
    final bool isSelected = widget.initiallySelected == name;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? const Color(0xFFDCFCE7) : Colors.transparent,
        leading: Icon(
          isSelected ? LucideIcons.checkCircle2 : LucideIcons.mapPin,
          size: 18,
          color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textMuted,
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? FloraXTheme.primaryGreen : FloraXTheme.textPrimary,
          ),
        ),
        onTap: () => Navigator.pop(context, name),
      ),
    );
  }
}
