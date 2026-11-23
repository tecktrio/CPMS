import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/cpms_search_bar.dart';

class ManageCountriesModal extends StatefulWidget {
  const ManageCountriesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManageCountriesModal(),
    );
  }

  @override
  State<ManageCountriesModal> createState() => _ManageCountriesModalState();
}

class _ManageCountriesModalState extends State<ManageCountriesModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddOrEditDialog({String? existingCountry}) async {
    final isEditing = existingCountry != null && existingCountry.isNotEmpty;
    final controller = TextEditingController(text: existingCountry ?? '');
    final formKey = GlobalKey<FormState>();
    final inventory = context.read<InventoryProvider>();
    final itemCount = isEditing ? inventory.getCountryItemsCount(existingCountry) : 0;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          isEditing ? 'Edit Country' : 'Add Target Country',
          style: const TextStyle(
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
              Text(
                isEditing
                    ? 'Update the country name. All $itemCount item(s) assigned to this country will automatically be updated.'
                    : 'Enter the country name this item is manufactured for or distributed in:',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
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
                  hintText: 'e.g. India, United States, Germany',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, controller.text.trim());
            },
            child: Text(
              isEditing ? 'Save Changes' : 'Add Country',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isLoading = true);
      if (isEditing) {
        await inventory.renameCountry(
          oldName: existingCountry,
          newName: result,
        );
      } else {
        await inventory.addCustomCountry(result);
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Country updated to "$result"'
                  : 'Country "$result" added successfully',
            ),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteCountry(String country) async {
    final inventory = context.read<InventoryProvider>();
    final count = inventory.getCountryItemsCount(country);

    if (count == 0) {
      // Direct deletion confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Text(
                'Delete Country',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "$country" from your countries list?',
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        setState(() => _isLoading = true);
        await inventory.deleteCountry(country);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Country "$country" removed'),
              backgroundColor: Colors.black,
            ),
          );
        }
      }
    } else {
      // Warning with reassign options!
      final otherCountries = inventory.availableCountries
          .where((c) => c.toLowerCase() != country.toLowerCase())
          .toList();

      String selectedReassign = ''; // '' represents Global / No Country

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reassign Items & Delete',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning Alert Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF87171)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'WARNING: There are $count item(s) currently assigned to "$country".',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Please select which country to reassign these items to before deleting:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedReassign,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Reassign items to',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('🌐 Global / No Country (None)'),
                    ),
                    ...otherCountries.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('🌐 $c'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() => selectedReassign = val);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reassign & Delete'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        setState(() => _isLoading = true);
        await inventory.deleteCountry(country, reassignTo: selectedReassign);
        if (mounted) {
          setState(() => _isLoading = false);
          final destLabel = selectedReassign.isNotEmpty ? selectedReassign : 'Global / None';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reassigned $count item(s) to "$destLabel" and deleted "$country"',
              ),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final allCountries = inventory.availableCountries;

    final q = _searchQuery.toLowerCase().trim();
    final filtered = q.isEmpty
        ? allCountries
        : allCountries.where((c) => c.toLowerCase().contains(q)).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Countries',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Configure target countries, rename, or reassign items.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddOrEditDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Country',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CpmsSearchBar(
              controller: _searchCtrl,
              hintText: 'Search countries...',
              onChanged: (val) => setState(() => _searchQuery = val),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ),

          const SizedBox(height: 12),

          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF0F172A),
              backgroundColor: Color(0xFFE2E8F0),
            ),

          // Countries List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.public_off_outlined,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            q.isNotEmpty
                                ? 'No countries match "$q"'
                                : 'No countries found',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final country = filtered[idx];
                      final count = inventory.getCountryItemsCount(country);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text('🌐', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    country,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: count > 0
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      count > 0
                                          ? '$count item(s) assigned'
                                          : '0 items assigned',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: count > 0
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 19,
                                color: Color(0xFF64748B),
                              ),
                              tooltip: 'Edit Country',
                              onPressed: () => _showAddOrEditDialog(
                                existingCountry: country,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 19,
                                color: Color(0xFFDC2626),
                              ),
                              tooltip: 'Delete Country',
                              onPressed: () => _handleDeleteCountry(country),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
