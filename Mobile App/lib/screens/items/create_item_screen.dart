import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({super.key});

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
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
    'UNIT',
    'CARTON',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventory = context.read<InventoryProvider>();
      await inventory.loadStoreRooms();
      if (mounted && inventory.storeRooms.isNotEmpty) {
        setState(() {
          _selectedStoreRoomId = inventory.storeRooms.first.storeRoomId;
        });
      }
    });
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _reorderThresholdController.dispose();
    _locationCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStoreRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a storage store room first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final inventory = context.read<InventoryProvider>();
    final success = await inventory.createItem(
      sku: _skuController.text.trim().toUpperCase(),
      itemName: _nameController.text.trim(),
      itemType: _selectedItemType,
      measurementUnit: _selectedUnit,
      reorderThreshold: double.tryParse(_reorderThresholdController.text) ?? 0,
      storeRoomId: _selectedStoreRoomId!,
      locationCode: _locationCodeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item SKU "${_skuController.text.toUpperCase()}" registered successfully!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Item SKU'),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
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
                    Icon(Icons.inventory_2_outlined, color: Color(0xFF0F766E), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operational Module: Items & Raw Materials\nPermission: permission.item.create',
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

              // Item Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g., Frozen Atlantic Salmon Fillet',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SKU Code
              TextFormField(
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Product SKU *',
                  hintText: 'e.g., RAW-SALM-001',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'SKU is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Item Type & Unit
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedItemType,
                      decoration: const InputDecoration(labelText: 'Item Type *'),
                      items: _itemTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.replaceAll('_', ' ')),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedItemType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit *'),
                      items: _units
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Storage Cold Room
              DropdownButtonFormField<String>(
                initialValue: _selectedStoreRoomId,
                decoration: const InputDecoration(
                  labelText: 'Primary Cold Storage Room *',
                  prefixIcon: Icon(Icons.ac_unit),
                ),
                items: inventory.storeRooms
                    .map((room) => DropdownMenuItem(
                          value: room.storeRoomId,
                          child: Text('${room.roomName} (${room.temperature}°C)'),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedStoreRoomId = val);
                },
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please select a storage store room';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reorder threshold & Rack location
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reorderThresholdController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level *',
                        prefixIcon: Icon(Icons.warning_amber),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val) == null) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _locationCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Default Rack *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Location required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Submit Button
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
                      : const Icon(Icons.check),
                  label: Text(_isSubmitting ? 'Registering SKU...' : 'Save & Register SKU'),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
