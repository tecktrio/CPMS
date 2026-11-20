import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/success_screen.dart';
import 'manage_item_categories_modal.dart';
import 'manage_packaging_materials_modal.dart';

class CreateItemDialog extends StatefulWidget {
  const CreateItemDialog({super.key});

  @override
  State<CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<CreateItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _reorderThresholdController = TextEditingController(text: '50');
  final _locationCodeController = TextEditingController(text: 'LOC-A1');
  final _customPackageMaterialController = TextEditingController();

  static const List<String> _packageMaterialOptions = [
    'Duplex',
    'Rider',
    'Pouches with rider',
    'Pouches',
    'Bucket',
    'Tub',
    'Custom',
  ];
  String _selectedPackageMaterial = _packageMaterialOptions.first;

  String _selectedItemType = 'RAW_MATERIAL';
  String _selectedUnit = 'KILOGRAM';
  String? _selectedStoreRoomId;
  bool _isSubmitting = false;

  final List<String> _units = [
    'KILOGRAM',
    'GRAM',
    'LITRE',
    'MILLILITRE',
    'PIECE',
  ];

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();
    if (inventory.storeRooms.isNotEmpty) {
      _selectedStoreRoomId = inventory.storeRooms.first.storeRoomId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inv = context.read<InventoryProvider>();
      inv.loadItemCategories(silent: true);
      inv.loadPackagingMaterials(silent: true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _reorderThresholdController.dispose();
    _locationCodeController.dispose();
    _customPackageMaterialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final inventory = context.read<InventoryProvider>();

    String finalItemName = _nameController.text.trim();
    if (_selectedItemType == 'PACKAGING' || finalItemName.isEmpty) {
      if (_selectedPackageMaterial == 'Custom') {
        finalItemName = _customPackageMaterialController.text.trim();
      } else {
        finalItemName = _selectedPackageMaterial;
      }
    }

    final success = await inventory.createItem(
      itemName: finalItemName,
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
        message: 'Item "$finalItemName" was added successfully.',
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
                        'Register New Item',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Item Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name / Description *',
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

                // Item Type / Category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Consumer<TenantProvider>(
                      builder: (context, tenant, _) {
                        final canManage = tenant.isTenantAdmin ||
                            tenant.hasPermission(AppPermissions.itemCategoryManage);
                        if (!canManage) return const SizedBox.shrink();
                        return InkWell(
                          onTap: () => ManageItemCategoriesModal.show(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Manage Categories',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Consumer<InventoryProvider>(
                  builder: (context, inventory, _) {
                    final categoryOptions = <Map<String, String>>[];
                    if (inventory.itemCategories.isNotEmpty) {
                      for (final c in inventory.itemCategories) {
                        categoryOptions.add({'code': c.code, 'label': c.label});
                      }
                    } else {
                      categoryOptions.addAll([
                        {'code': 'RAW_MATERIAL', 'label': 'Raw Materials'},
                        {'code': 'FINISHED_GOOD', 'label': 'Finished Goods'},
                        {'code': 'PACKAGING', 'label': 'Packing Materials'},
                      ]);
                    }

                    if (!categoryOptions.any((c) => c['code'] == _selectedItemType)) {
                      _selectedItemType = categoryOptions.first['code']!;
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedItemType,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: categoryOptions.map((type) {
                        return DropdownMenuItem(
                          value: type['code']!,
                          child: Text(
                            type['label']!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedItemType = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Packaging Material Row (Below category)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Packing Material',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Consumer<TenantProvider>(
                      builder: (context, tenant, _) {
                        final canManage = tenant.isTenantAdmin ||
                            tenant.hasPermission(AppPermissions.packagingMaterialManage) ||
                            tenant.hasPermission(AppPermissions.itemCategoryManage);
                        if (!canManage) return const SizedBox.shrink();
                        return InkWell(
                          onTap: () => ManagePackagingMaterialsModal.show(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Manage Materials',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Consumer<InventoryProvider>(
                  builder: (context, inventory, _) {
                    final materialOptions = <String>[];
                    if (inventory.packagingMaterials.isNotEmpty) {
                      for (final m in inventory.packagingMaterials) {
                        materialOptions.add(m.name);
                      }
                    } else {
                      materialOptions.addAll([
                        'Duplex',
                        'Rider',
                        'Pouches with rider',
                        'Pouches',
                        'Bucket',
                        'Tub',
                      ]);
                    }
                    if (!materialOptions.contains('Custom')) {
                      materialOptions.add('Custom');
                    }

                    if (!materialOptions.contains(_selectedPackageMaterial)) {
                      _selectedPackageMaterial = materialOptions.first;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPackageMaterial,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: materialOptions.map((opt) {
                            return DropdownMenuItem(
                              value: opt,
                              child: Text(opt, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPackageMaterial = val);
                            }
                          },
                        ),
                        if (_selectedPackageMaterial == 'Custom') ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _customPackageMaterialController,
                            decoration: const InputDecoration(
                              labelText: 'Custom Packing Material *',
                              prefixIcon: Icon(Icons.edit_note, size: 20),
                            ),
                            validator: (val) {
                              if (_selectedPackageMaterial == 'Custom' &&
                                  (val == null || val.trim().isEmpty)) {
                                return 'Packing material name is required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    );
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
