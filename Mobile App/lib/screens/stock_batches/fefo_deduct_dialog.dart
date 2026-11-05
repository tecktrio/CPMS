import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class FefoDeductDialog extends StatefulWidget {
  final String? initialItemId;

  const FefoDeductDialog({super.key, this.initialItemId});

  @override
  State<FefoDeductDialog> createState() => _FefoDeductDialogState();
}

class _FefoDeductDialogState extends State<FefoDeductDialog> {
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
    final inventory = context.read<InventoryProvider>();
    if (widget.initialItemId != null) {
      _selectedItemId = widget.initialItemId;
    } else if (inventory.items.isNotEmpty) {
      _selectedItemId = inventory.items.first.itemId;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _purposeController.dispose();
    for (final ctrl in _batchControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _calculateFefoAllocation() async {
    if (_selectedItemId == null) return;
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid requested quantity greater than 0.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCalculating = true);
    final inventory = context.read<InventoryProvider>();

    final result = await inventory.getFefoAllocationSuggestion(
      itemId: _selectedItemId!,
      requestedQuantity: qty,
    );

    if (!mounted) return;
    setState(() {
      _isCalculating = false;
      _allocationResult = result;
      // Initialize editable controllers for Option B
      _batchControllers.clear();
      if (result != null) {
        for (final b in result.suggestedBatches) {
          _batchControllers[b.batchId] = TextEditingController(
            text: b.suggestedDeductionQuantity.toStringAsFixed(1),
          );
        }
      }
    });

    if (result == null && inventory.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeduction() async {
    if (_allocationResult == null || _selectedItemId == null) return;

    final deductions = <Map<String, dynamic>>[];
    double totalDeduct = 0;

    for (final batch in _allocationResult!.suggestedBatches) {
      final ctrl = _batchControllers[batch.batchId];
      final val = double.tryParse(ctrl?.text ?? '0') ?? 0;
      if (val > 0) {
        if (val > batch.availableStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deduction for batch ${batch.batchNumber} ($val) cannot exceed available stock (${batch.availableStock}).',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        deductions.add({
          'batch_id': batch.batchId,
          'deducted_quantity': val,
        });
        totalDeduct += val;
      }
    }

    if (deductions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please allocate at least one batch quantity > 0.'),
          backgroundColor: Colors.orange,
        ),
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FEFO Deduction of $totalDeduct units completed successfully!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Deduction failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Option B: FEFO Stock Picking',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'System suggests earliest expiry; operator reviews & edits.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Select Item SKU
                DropdownButtonFormField<String>(
                  initialValue: _selectedItemId,
                  decoration: const InputDecoration(
                    labelText: 'Select Item SKU *',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: inventory.items.map((item) {
                    return DropdownMenuItem(
                      value: item.itemId,
                      child: Text(
                        '${item.sku} - ${item.itemName} (${item.totalAvailableStock} ${item.measurementUnit} available)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedItemId = val;
                      _allocationResult = null;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Requested Quantity & Calculate Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Requested Quantity *',
                          hintText: 'e.g. 120',
                          prefixIcon: Icon(Icons.production_quantity_limits, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _isCalculating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.calculate_outlined, size: 18),
                          label: const Text('Get FEFO', style: TextStyle(fontSize: 13)),
                          onPressed: _isCalculating ? null : _calculateFefoAllocation,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Purpose
                TextFormField(
                  controller: _purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Deduction Purpose / Batch Run ID',
                    hintText: 'e.g. Daily Bottling Run #481',
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                // Option B FEFO Suggested Allocations Table
                if (_allocationResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _allocationResult!.hasShortfall
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _allocationResult!.hasShortfall
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF99F6E4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _allocationResult!.hasShortfall
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: _allocationResult!.hasShortfall
                              ? const Color(0xFFD97706)
                              : const Color(0xFF0F766E),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _allocationResult!.hasShortfall
                              ? 'Inventory Shortfall: Short by ${_allocationResult!.shortfallQuantity.toStringAsFixed(1)} units of requested ${_allocationResult!.requestedQuantity.toStringAsFixed(1)}.'
                              : 'Full quantity of ${_allocationResult!.totalAllocatedQuantity.toStringAsFixed(1)} units matched via First-Expired-First-Out.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _allocationResult!.hasShortfall
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Option B: Operator Editable Batch Deductions',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  ..._allocationResult!.suggestedBatches.map((batch) {
                    final expiryStr = batch.expiryDate != null
                        ? dateFormat.format(batch.expiryDate!)
                        : 'No Expiry';
                    final ctrl = _batchControllers[batch.batchId];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Batch ${batch.batchNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Expires: $expiryStr • Avail: ${batch.availableStock}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  labelText: 'Deduct Qty',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 20),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Confirm Deduction'),
                      onPressed: (_allocationResult == null || _isSubmitting)
                          ? null
                          : _confirmDeduction,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
