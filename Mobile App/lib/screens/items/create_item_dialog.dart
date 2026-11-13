import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/success_screen.dart';

class CreateItemDialog extends StatefulWidget {
  const CreateItemDialog({super.key});

  @override
  State<CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<CreateItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _reorderThresholdController = TextEditingController(text: '50');
  final _locationCodeController = TextEditingController(text: 'LOC-A1');

  String _selectedItemType = 'RAW_MATERIAL';
  String _selectedUnit = 'KILOGRAM';
  String? _selectedStoreRoomId;
  bool _isSubmitting = false;

  final List<String> _itemTypes = [
    'RAW_MATERIAL',
    'FINISHED_GOOD',
    'PACKAGING',
  ];

  final List<String> _units = [
    'KILOGRAM',
    'GRAM',
    'LITRE',
    'MILLILITRE',
    'PIECE',
    'UNIT',
    'CARTOON_BOX',
  ];

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();
    if (inventory.storeRooms.isNotEmpty) {
      _selectedStoreRoomId = inventory.storeRooms.first.storeRoomId;
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _reorderThresholdController.dispose();
    _locationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final inventory = context.read<InventoryProvider>();
    final success = await inventory.createItem(
      sku: _skuController.text.trim().toUpperCase(),
      itemName: _nameController.text.trim(),
      itemType: _selectedItemType,
      measurementUnit: _selectedUnit,
      quantity: double.tryParse(_quantityController.text.trim()) ?? 1.0,
      reorderThreshold: double.tryParse(_reorderThresholdController.text) ?? 0,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      await showSuccessScreen(
        context,
        title: 'Item added',
        message: 'Item SKU ${_skuController.text.toUpperCase()} was added successfully.',
        returnLabel: 'Return to items',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to create item.'),
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
        constraints: const BoxConstraints(maxWidth: 520),
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
                      child: const Icon(Icons.add_box, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Register New Item SKU',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SKU Code
                TextFormField(
                  controller: _skuController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'SKU Identifier *',
                    hintText: 'e.g. MILK-RAW-001',
                    prefixIcon: Icon(Icons.qr_code, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'SKU is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Item Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name / Description *',
                    hintText: 'e.g. Pasteurized Fresh Whole Milk',
                    prefixIcon: Icon(Icons.label_outline, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Item name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Item Type
                DropdownButtonFormField<String>(
                  initialValue: _selectedItemType,
                  decoration: const InputDecoration(
                    labelText: 'Item Category',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _itemTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedItemType = val);
                  },
                ),
                const SizedBox(height: 14),

                // Quantity & Unit
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          hintText: 'e.g. 100',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || double.tryParse(val.trim()) == null || (double.tryParse(val.trim()) ?? 0) <= 0) {
                            return 'Valid quantity > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Measurement Unit',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _units.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedUnit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reorder Threshold
                TextFormField(
                  controller: _reorderThresholdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reorder Threshold Alert Quantity',
                    hintText: 'e.g. 50',
                    prefixIcon: Icon(Icons.notifications_active_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || double.tryParse(val) == null) {
                      return 'Enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Default Cold Store Room
                DropdownButtonFormField<String>(
                  initialValue: _selectedStoreRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Default Cold Store Room *',
                    prefixIcon: Icon(Icons.ac_unit, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: inventory.storeRooms.map((room) {
                    return DropdownMenuItem(
                      value: room.storeRoomId,
                      child: Text(
                        '${room.roomName} (${room.roomCode} - ${room.temperature}°C)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedStoreRoomId = val);
                  },
                  validator: (val) => val == null ? 'Please select a store room' : null,
                ),
                const SizedBox(height: 14),

                // Storage Location Code
                TextFormField(
                  controller: _locationCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Rack / Shelf Bin Code',
                    hintText: 'e.g. RACK-A-SHELF-01',
                    prefixIcon: Icon(Icons.grid_view_outlined, size: 20),
                  ),
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
                          : const Text('Register Item'),
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
