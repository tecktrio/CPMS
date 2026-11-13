import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class FefoPickingScreen extends StatefulWidget {
  final String? initialItemId;

  const FefoPickingScreen({super.key, this.initialItemId});

  @override
  State<FefoPickingScreen> createState() => _FefoPickingScreenState();
}

class _FefoPickingScreenState extends State<FefoPickingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _purposeController = TextEditingController(text: 'Production Batch Execution');

  String? _selectedItemId;
  FefoAllocationResult? _allocationResult;
  final Map<String, TextEditingController> _batchControllers = {};

  bool _isCalculating = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.initialItemId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventory = context.read<InventoryProvider>();
      await inventory.loadItems();
      if (mounted && _selectedItemId == null && inventory.items.isNotEmpty) {
        setState(() {
          _selectedItemId = inventory.items.first.itemId;
        });
      }
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _purposeController.dispose();
    for (final c in _batchControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _calculateFefoAllocation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemId == null) return;

    final targetQty = double.tryParse(_qtyController.text) ?? 0;
    if (targetQty <= 0) return;

    setState(() => _isCalculating = true);

    final inventory = context.read<InventoryProvider>();
    final result = await inventory.getFefoAllocationSuggestion(
      itemId: _selectedItemId!,
      requestedQuantity: targetQty,
    );

    if (!mounted) return;
    setState(() => _isCalculating = false);

    if (result != null) {
      for (final c in _batchControllers.values) {
        c.dispose();
      }
      _batchControllers.clear();

      for (final alloc in result.suggestedBatches) {
        _batchControllers[alloc.batchId] =
            TextEditingController(text: alloc.suggestedDeductionQuantity.toString());
      }

      setState(() => _allocationResult = result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Unable to calculate FEFO picking allocation.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeduct() async {
    if (_allocationResult == null) return;

    final List<Map<String, dynamic>> deductions = [];
    double totalDeducted = 0;

    for (final entry in _batchControllers.entries) {
      final qty = double.tryParse(entry.value.text) ?? 0;
      if (qty > 0) {
        deductions.add({
          'batch_id': entry.key,
          'deducted_quantity': qty,
        });
        totalDeducted += qty;
      }
    }

    if (deductions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify quantity to deduct.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final inventory = context.read<InventoryProvider>();
    final success = await inventory.confirmBatchDeduction(
      itemId: _selectedItemId!,
      deductions: deductions,
      purpose: _purposeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deducted ${totalDeducted.toStringAsFixed(1)} units following FEFO rules.'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to complete FEFO picking.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('FEFO Picking Engine (Option B)'),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: () async {
          await Future.wait([
            inventory.loadItems(),
            inventory.loadStockBatches(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome_motion, color: Color(0xFF0F766E), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operational Module: Stock Batches & FEFO Picking\nPermission: permission.batch.deduct',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Item Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedItemId,
                decoration: const InputDecoration(
                  labelText: 'Select Product SKU to Pick *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: inventory.items
                    .map((item) => DropdownMenuItem(
                          value: item.itemId,
                          child: Text('${item.sku} — ${item.itemName} (${item.specification}) • ${item.totalAvailableStock} in stock'),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedItemId = val;
                    _allocationResult = null;
                  });
                },
                validator: (val) => val == null ? 'Please select item' : null,
              ),
              const SizedBox(height: 16),

              // Target Pick Quantity & Calculate Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity Needed *',
                        prefixIcon: Icon(Icons.shopping_cart_checkout),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val) == null) {
                          return 'Enter valid qty';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      icon: _isCalculating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt),
                      label: const Text('Suggest FEFO'),
                      onPressed: _isCalculating ? null : _calculateFefoAllocation,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Purpose / Production Order
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Usage Purpose / Work Order ID *',
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Purpose required' : null,
              ),
              const SizedBox(height: 24),

              // FEFO Allocation Breakdown Table
              if (_allocationResult != null) ...[
                Row(
                  children: [
                    const Icon(Icons.fact_check_outlined, size: 18, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    const Text(
                      'Operator Confirmation (Review & Adjust)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !_allocationResult!.hasShortfall ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: !_allocationResult!.hasShortfall ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Text(
                        !_allocationResult!.hasShortfall ? 'Full Allocation' : 'Shortfall Detected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: !_allocationResult!.hasShortfall ? const Color(0xFF16A34A) : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _allocationResult!.suggestedBatches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final b = _allocationResult!.suggestedBatches[idx];
                    final controller = _batchControllers[b.batchId];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${idx + 1} FEFO',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.batchNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    b.expiryDate != null
                                        ? 'Expires: ${dateFormat.format(b.expiryDate!)}'
                                        : 'Available: ${b.availableStock}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Pick',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Confirm Deduct
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isSubmitting ? 'Deducting Stock...' : 'Confirm & Dispatch Stock'),
                    onPressed: _isSubmitting ? null : _confirmDeduct,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}
