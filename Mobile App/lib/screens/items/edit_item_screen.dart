import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class EditItemScreen extends StatefulWidget {
  final ItemModel item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _reorderThresholdController;

  late String _selectedItemType;
  late String _selectedUnit;
  bool _isSaving = false;

  XFile? _newPickedImage;
  Uint8List? _newPickedImageBytes;
  bool _imageMarkedForRemoval = false;

  final List<Map<String, String>> _itemTypes = [
    {'value': 'RAW_MATERIAL', 'label': 'RAW MATERIAL'},
    {'value': 'FINISHED_GOOD', 'label': 'FINISHED GOOD'},
    {'value': 'PACKAGING', 'label': 'PACKAGING'},
    {'value': 'SPARE_PARTS', 'label': 'SPARE PARTS'},
  ];

  final List<Map<String, String>> _units = [
    {'value': 'KILOGRAM', 'label': 'KILOGRAM (KG)', 'abbr': 'KG'},
    {'value': 'GRAM', 'label': 'GRAM (G)', 'abbr': 'G'},
    {'value': 'LITRE', 'label': 'LITRE (L)', 'abbr': 'L'},
    {'value': 'MILLILITRE', 'label': 'MILLILITRE (ML)', 'abbr': 'ML'},
    {'value': 'PIECE', 'label': 'PIECE (PC)', 'abbr': 'PC'},
    {'value': 'UNIT', 'label': 'UNIT', 'abbr': 'UNIT'},
    {'value': 'CARTOON_BOX', 'label': 'CARTON (BOX)', 'abbr': 'BOX'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _reorderThresholdController = TextEditingController(
      text: widget.item.reorderThresholdQuantity.toStringAsFixed(0),
    );

    // Normalizing item type
    _selectedItemType = widget.item.itemType;
    if (!_itemTypes.any((t) => t['value'] == _selectedItemType)) {
      _itemTypes.add({
        'value': _selectedItemType,
        'label': _selectedItemType.replaceAll('_', ' ').toUpperCase(),
      });
    }

    // Normalizing unit
    _selectedUnit = widget.item.measurementUnit.toUpperCase();
    if (_selectedUnit == 'KG') _selectedUnit = 'KILOGRAM';
    if (_selectedUnit == 'L') _selectedUnit = 'LITRE';
    if (_selectedUnit == 'PC') _selectedUnit = 'PIECE';
    if (!_units.any((u) => u['value'] == _selectedUnit)) {
      _units.add({
        'value': _selectedUnit,
        'label': _selectedUnit,
        'abbr': _selectedUnit,
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reorderThresholdController.dispose();
    super.dispose();
  }

  String _getUnitAbbr() {
    final match = _units.firstWhere(
      (u) => u['value'] == _selectedUnit,
      orElse: () => {'abbr': _selectedUnit},
    );
    return match['abbr'] ?? _selectedUnit;
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
          _newPickedImage = picked;
          _newPickedImageBytes = bytes;
          _imageMarkedForRemoval = false;
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

  void _removeImage() {
    setState(() {
      _newPickedImage = null;
      _newPickedImageBytes = null;
      _imageMarkedForRemoval = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final inventory = context.read<InventoryProvider>();

    try {
      String? finalImageUrl;

      // Handle image update or removal
      if (_newPickedImageBytes != null && _newPickedImage != null) {
        // Upload new image to S3
        finalImageUrl = await inventory.uploadItemImage(
          _newPickedImageBytes!,
          _newPickedImage!.name,
        );
      } else if (_imageMarkedForRemoval) {
        finalImageUrl = ''; // Empty string signals removal to inventory_provider
      }

      final ok = await inventory.updateItem(
        itemId: widget.item.itemId,
        itemName: _nameController.text.trim(),
        itemType: _selectedItemType,
        measurementUnit: _selectedUnit,
        reorderThreshold:
            double.tryParse(_reorderThresholdController.text.trim()) ??
                widget.item.reorderThresholdQuantity,
        imageUrl: finalImageUrl,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item changes saved successfully!'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inventory.errorMessage ?? 'Failed to update item.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Item: ${widget.item.sku}?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${widget.item.itemName}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.deleteItem(widget.item.itemId);
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item deleted successfully'),
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                  Navigator.pop(context, true); // Close EditItemScreen
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(inventory.errorMessage ?? 'Failed to delete item'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required Widget prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingImage =
        widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty;
    final showImage =
        (_newPickedImageBytes != null) || (hasExistingImage && !_imageMarkedForRemoval);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Edit Item',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black, size: 22),
            tooltip: 'Item Audit History',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item audit logs are up to date.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Centered Item Image with Edit & Remove Buttons
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: showImage
                                ? (_newPickedImageBytes != null
                                    ? Image.memory(
                                        _newPickedImageBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        ApiConstants.resolveImageUrl(
                                            widget.item.imageUrl)!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) =>
                                            const Center(
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            size: 48,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ))
                                : Center(
                                    child: Text(
                                      widget.item.itemName.isNotEmpty
                                          ? widget.item.itemName[0]
                                              .toUpperCase()
                                          : 'I',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        // Circular Edit Button on Bottom Right
                        Positioned(
                          bottom: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (showImage)
                      GestureDetector(
                        onTap: _removeImage,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Color(0xFFDC2626),
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Remove',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Item Name
              _buildFieldLabel('ITEM NAME *'),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                decoration: _buildInputDecoration(
                  hintText: 'e.g. Frozen Beef Tenderloin',
                  prefixIcon: const Icon(
                    Icons.local_offer_outlined,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Product SKU (Locked format)
              _buildFieldLabel(
                'PRODUCT SKU *',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LOCKED FORMAT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code_2_outlined,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.sku,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.qr_code_scanner_outlined,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.item.sku));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'SKU "${widget.item.sku}" copied to clipboard!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy_outlined,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Item Type & Unit Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('ITEM TYPE *'),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedItemType,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF64748B),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.black, width: 1.5),
                            ),
                          ),
                          items: _itemTypes
                              .map((type) => DropdownMenuItem(
                                    value: type['value'],
                                    child: Text(type['label']!),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedItemType = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('UNIT *'),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF64748B),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.black, width: 1.5),
                            ),
                          ),
                          items: _units
                              .map((unit) => DropdownMenuItem(
                                    value: unit['value'],
                                    child: Text(unit['label']!),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedUnit = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Reorder Level
              _buildFieldLabel('REORDER LEVEL *'),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _reorderThresholdController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (val) {
                          if (val == null ||
                              double.tryParse(val.trim()) == null) {
                            return 'Enter number';
                          }
                          return null;
                        },
                      ),
                    ),
                    Text(
                      _getUnitAbbr(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Delete Item Button
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Delete Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
