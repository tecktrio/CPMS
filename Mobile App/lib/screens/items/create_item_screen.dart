import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _stockQuantityController = TextEditingController(text: '0');
  final _customDivisionController = TextEditingController();

  String _selectedItemType = 'RAW_MATERIAL';
  String _selectedUnit = 'KILOGRAM';
  String? _selectedStoreRoomId;
  String? _selectedDivision;
  bool _isSubmitting = false;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventory = context.read<InventoryProvider>();
      await inventory.loadStoreRooms();
      if (mounted && inventory.storeRooms.isNotEmpty) {
        final firstRoom = inventory.storeRooms.first;
        setState(() {
          _selectedStoreRoomId = firstRoom.storeRoomId;
          if (firstRoom.divisions.isNotEmpty) {
            _selectedDivision = firstRoom.divisions.first;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _reorderThresholdController.dispose();
    _stockQuantityController.dispose();
    _customDivisionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImage = picked;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final chosenDivision = _selectedDivision ??
        (_customDivisionController.text.trim().isNotEmpty
            ? _customDivisionController.text.trim()
            : 'Default Section');

    String? uploadedImageUrl;
    if (_selectedImageBytes != null && _selectedImage != null) {
      uploadedImageUrl = await inventory.uploadItemImage(
        _selectedImageBytes!,
        _selectedImage!.name,
      );
    }

    final success = await inventory.createItem(
      sku: _skuController.text.trim().toUpperCase(),
      itemName: _nameController.text.trim(),
      itemType: _selectedItemType,
      measurementUnit: _selectedUnit,
      reorderThreshold:
          double.tryParse(_reorderThresholdController.text.trim()) ?? 0,
      stockQuantity:
          double.tryParse(_stockQuantityController.text.trim()) ?? 0,
      storeRoomId: _selectedStoreRoomId!,
      division: chosenDivision,
      locationCode: chosenDivision,
      imageUrl: uploadedImageUrl,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Item SKU "${_skuController.text.toUpperCase()}" registered successfully!'),
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

    StoreRoomModel? selectedRoom;
    if (_selectedStoreRoomId != null) {
      final matches = inventory.storeRooms
          .where((r) => r.storeRoomId == _selectedStoreRoomId);
      if (matches.isNotEmpty) selectedRoom = matches.first;
    }

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
                    Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF0F766E), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operational Module: Items & Products\nPermission: permission.item.create',
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

              // Item Photo Picker Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _selectedImageBytes != null
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedImage?.name ?? 'Item Photo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ready to upload to AWS S3',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0F766E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Color(0xFF0F766E)),
                            tooltip: 'Change Photo',
                            onPressed: _pickImage,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                            tooltip: 'Remove',
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                                _selectedImageBytes = null;
                              });
                            },
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 32,
                                color: Color(0xFF0F766E),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add Item Image (Optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Supports JPEG, PNG, WEBP — 1 image per item',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Item Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g., Raw Organic Almonds',
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
                  hintText: 'e.g., RAW-ALMD-001',
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
                      decoration:
                          const InputDecoration(labelText: 'Item Type *'),
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

              // Storage Store Room
              DropdownButtonFormField<String>(
                initialValue: _selectedStoreRoomId,
                decoration: const InputDecoration(
                  labelText: 'Store Room *',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                items: inventory.storeRooms
                    .map((room) => DropdownMenuItem(
                          value: room.storeRoomId,
                          child: Text(
                            '${room.roomName} (${room.temperature != null ? '${room.temperature}°C' : 'Ambient'})',
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedStoreRoomId = val;
                    final r = inventory.storeRooms.firstWhere(
                      (rm) => rm.storeRoomId == val,
                      orElse: () => inventory.storeRooms.first,
                    );
                    if (r.divisions.isNotEmpty) {
                      _selectedDivision = r.divisions.first;
                    } else {
                      _selectedDivision = null;
                    }
                  });
                },
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please select a storage store room';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Division Pickup
              if (selectedRoom != null && selectedRoom.divisions.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey('div_${_selectedStoreRoomId}_$_selectedDivision'),
                  initialValue: _selectedDivision,
                  decoration: const InputDecoration(
                    labelText: 'Store Room Division / Section *',
                    prefixIcon: Icon(Icons.grid_view_outlined),
                    helperText: 'Pick which division or section inside the room',
                  ),
                  items: selectedRoom.divisions.toSet().toList()
                      .map((div) => DropdownMenuItem(
                            value: div,
                            child: Text(div),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedDivision = val);
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select a division';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _customDivisionController,
                  decoration: const InputDecoration(
                    labelText: 'Division / Section Identifier',
                    hintText: 'e.g. Section A, Shelf 1',
                    prefixIcon: Icon(Icons.grid_view_outlined),
                  ),
                ),
              const SizedBox(height: 16),

              // Current Stock Quantity & Reorder Threshold
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Initial Stock Quantity *',
                        prefixIcon: Icon(Icons.inventory_outlined),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val.trim()) == null) {
                          return 'Enter valid quantity';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderThresholdController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Reorder Level *',
                        prefixIcon: Icon(Icons.warning_amber),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val.trim()) == null) {
                          return 'Enter valid number';
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
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                      _isSubmitting ? 'Registering SKU...' : 'Save & Register SKU'),
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
