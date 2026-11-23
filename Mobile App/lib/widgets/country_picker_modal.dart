import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import 'cpms_search_bar.dart';

/// Modal bottom sheet and dialog for searching, selecting, and adding target countries.
class CountryPickerModal extends StatefulWidget {
  final String currentCountry;
  final ValueChanged<String> onSelected;

  const CountryPickerModal({
    super.key,
    required this.currentCountry,
    required this.onSelected,
  });

  /// Opens the searchable country selection modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String currentCountry,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CountryPickerModal(
        currentCountry: currentCountry,
        onSelected: onSelected,
      ),
    );
  }

  /// Opens a quick dialog to create and select a new country.
  static Future<String?> showAddNewCountryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Add Target Country',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the country name this item is manufactured for or distributed in:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: 'Country Name *',
                  hintText: 'e.g. United States, Germany, India',
                  hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a country name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name = controller.text.trim();
              ctx.read<InventoryProvider>().addCustomCountry(name);
              Navigator.pop(ctx, name);
            },
            child: const Text('Add Country', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  State<CountryPickerModal> createState() => _CountryPickerModalState();
}

class _CountryPickerModalState extends State<CountryPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final allCountries = inventory.availableCountries;

    final q = _searchQuery.toLowerCase().trim();
    final filtered = allCountries.where((c) {
      if (q.isEmpty) return true;
      return c.toLowerCase().contains(q);
    }).toList();

    final hasExactMatch = allCountries.any(
      (c) => c.toLowerCase() == q,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Target Country',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        final added = await CountryPickerModal.showAddNewCountryDialog(context);
                        if (added != null && added.isNotEmpty && mounted) {
                          widget.onSelected(added);
                          nav.pop();
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          '+ Add New Country',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CpmsSearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search country name...',
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  onClear: () {
                    setState(() => _searchQuery = '');
                  },
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Countries List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    // Option 1: Global / All Countries (No Specific Country)
                    ListTile(
                      leading: const Icon(
                        Icons.public,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                      title: const Text(
                        'Global / All Countries',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: const Text(
                        'Applicable globally without country restrictions',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      trailing: widget.currentCountry.isEmpty
                          ? const Icon(Icons.check, color: Color(0xFF16A34A), size: 20)
                          : null,
                      onTap: () {
                        widget.onSelected('');
                        Navigator.pop(context);
                      },
                    ),

                    const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),

                    // Option to add typed query if not in existing list
                    if (q.isNotEmpty && !hasExactMatch)
                      ListTile(
                        leading: const Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: Color(0xFF0F766E),
                        ),
                        title: Text(
                          'Add "${_searchCtrl.text.trim()}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        subtitle: const Text(
                          'Save as new country and select',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        onTap: () {
                          final name = _searchCtrl.text.trim();
                          inventory.addCustomCountry(name);
                          widget.onSelected(name);
                          Navigator.pop(context);
                        },
                      ),

                    // Filtered Country Items
                    ...filtered.map((country) {
                      final isSelected =
                          widget.currentCountry.toLowerCase() == country.toLowerCase();
                      return ListTile(
                        leading: const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        title: Text(
                          country,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF16A34A), size: 20)
                            : null,
                        onTap: () {
                          widget.onSelected(country);
                          Navigator.pop(context);
                        },
                      );
                    }),

                    if (filtered.isEmpty && q.isNotEmpty && hasExactMatch)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No matching countries found.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
