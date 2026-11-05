import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class InwardBatchDialog extends StatefulWidget {
  final String? initialItemId;

  const InwardBatchDialog({super.key, this.initialItemId});

  @override
  State<InwardBatchDialog> createState() => _InwardBatchDialogState();
}

class _InwardBatchDialogState extends State<InwardBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationIdController = TextEditingController(text: 'LOC-A1');

  String? _selectedItemId;
  String? _selectedStoreRoomId;
  DateTime _manufacturingDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();
    if (widget.initialItemId != null) {
      _selectedItemId = widget.initialItemId;
    } else if (inventory.items.isNotEmpty) {
      _selectedItemId = inventory.items.first.itemId;
    }

    if (inventory.storeRooms.isNotEmpty) {
      _selectedStoreRoomId = inventory.storeRooms.first.storeRoomId;
    }

    // Auto-generate a batch number
    _batchNumberController.text = 'BTH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _locationIdController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isManufacturing}) async {
    final initialDate = isManufacturing ? _manufacturingDate : _expiryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        if (isManufacturing) {
          _manufacturingDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemId == null || _selectedStoreRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both an item and a destination cold store room.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_expiryDate.isBefore(_manufacturingDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry date cannot be earlier than manufacturing date.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final inventory = context.read<InventoryProvider>();

    final success = await inventory.inwardBatchReceipt(
      itemId: _selectedItemId!,
      batchNumber: _batchNumberController.text.trim().toUpperCase(),
      storeRoomId: _selectedStoreRoomId!,
      storageLocationId: _locationIdController.text.trim(),
      quantity: double.tryParse(_quantityController.text) ?? 0,
      manufacturingDate: _manufacturingDate,
      expiryDate: _expiryDate,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch "${_batchNumberController.text.toUpperCase()}" received into cold room!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to inward batch receipt.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.input_rounded, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Inward Stock Batch Receipt',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Item Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedItemId,
                  decoration: const InputDecoration(
                    labelText: 'Item SKU *',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: inventory.items.map((item) {
                    return DropdownMenuItem(
                      value: item.itemId,
                      child: Text(
                        '${item.sku} - ${item.itemName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedItemId = val);
                  },
                  validator: (val) => val == null ? 'Please select an item' : null,
                ),
                const SizedBox(height: 14),

                // Batch Number
                TextFormField(
                  controller: _batchNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Batch Number Identifier *',
                    hintText: 'e.g. BTH-2026-X1',
                    prefixIcon: Icon(Icons.qr_code, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Batch number required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Cold Store Room
                DropdownButtonFormField<String>(
                  initialValue: _selectedStoreRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Destination Cold Store Room *',
                    prefixIcon: Icon(Icons.ac_unit, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: inventory.storeRooms.map((room) {
                    final isFull = room.capacityUtilizationPercentage >= 100;
                    return DropdownMenuItem(
                      value: room.storeRoomId,
                      child: Text(
                        '${room.roomName} (${room.temperature}°C) — ${room.capacityUtilizationPercentage.toStringAsFixed(0)}% full${isFull ? ' [FULL]' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isFull ? Colors.red : null,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedStoreRoomId = val);
                  },
                  validator: (val) => val == null ? 'Please select a store room' : null,
                ),
                const SizedBox(height: 14),

                // Quantity & Rack Bin
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          hintText: 'e.g. 100',
                          prefixIcon: Icon(Icons.scale_outlined, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null || double.parse(val) <= 0) {
                            return 'Enter valid quantity > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _locationIdController,
                        decoration: const InputDecoration(
                          labelText: 'Location / Bin',
                          hintText: 'e.g. LOC-A1',
                          prefixIcon: Icon(Icons.grid_view_outlined, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Manufacturing & Expiry Date pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isManufacturing: true),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Mfg Date',
                            prefixIcon: Icon(Icons.event, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Text(
                            _dateFormat.format(_manufacturingDate),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isManufacturing: false),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expiry Date (FEFO)',
                            prefixIcon: Icon(Icons.event_busy, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Text(
                            _dateFormat.format(_expiryDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Receive Batch'),
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
