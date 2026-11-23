import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../widgets/success_screen.dart';
import '../../widgets/cpms_search_bar.dart';
import 'manage_item_categories_modal.dart';
import 'manage_packaging_materials_modal.dart';
import '../../widgets/country_picker_modal.dart';

class EditItemScreen extends StatefulWidget {
  final ItemModel item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _descriptionController;
  final TextEditingController _ingredientSearchController =
      TextEditingController();
  late final TextEditingController _customPackageMaterialController;

  static const List<String> _packageMaterialOptions = [
    'Duplex',
    'Rider',
    'Pouches with rider',
    'Pouches',
    'Bucket',
    'Tub',
    'Custom',
  ];
  late String _selectedPackageMaterial;
  bool _hasMatchedAsyncMaterials = false;

  late bool _hasIngredients;
  late List<String> _selectedIngredientIds;
  final Map<String, TextEditingController> _qtyControllers = {};
  String _ingredientSearchQuery = '';

  late String _selectedItemType;
  late String _selectedUnit;
  late String _selectedCountry;
  bool _isSaving = false;

  XFile? _newPickedImage;
  Uint8List? _newPickedImageBytes;
  bool _imageMarkedForRemoval = false;

  final List<Map<String, String>> _itemTypes = [
    {'value': 'FINISHED_GOOD', 'label': 'Finished Goods'},
    {'value': 'RAW_MATERIAL', 'label': 'Raw Materials'},
    {'value': 'PACKAGING', 'label': 'Packing Materials'},
  ];

  final List<Map<String, String>> _units = [
    {'value': 'GRAM', 'label': 'GRAM (G)', 'abbr': 'G'},
    {'value': 'KILOGRAM', 'label': 'KILOGRAM (KG)', 'abbr': 'KG'},
    {'value': 'LITRE', 'label': 'LITRE (L)', 'abbr': 'L'},
    {'value': 'MILLILITRE', 'label': 'MILLILITRE (ML)', 'abbr': 'ML'},
    {'value': 'PIECE', 'label': 'PIECE (PC)', 'abbr': 'PC'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.itemName);
    _selectedCountry = widget.item.country;
    final q = widget.item.quantity;
    _quantityController = TextEditingController(
      text: q.toStringAsFixed(q.truncateToDouble() == q ? 0 : 2),
    );
    _descriptionController =
        TextEditingController(text: widget.item.description);
    _hasIngredients = widget.item.hasIngredients;
    _selectedIngredientIds =
        widget.item.ingredients.map((i) => i.itemId).toList();
    for (final ing in widget.item.ingredients) {
      final qtyStr = ing.quantity.toStringAsFixed(
          ing.quantity.truncateToDouble() == ing.quantity ? 0 : 2);
      _qtyControllers[ing.itemId] = TextEditingController(text: qtyStr);
    }

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

    // Normalizing package material
    final matchedPreset = _packageMaterialOptions
        .where((opt) => opt != 'Custom')
        .firstWhere(
          (opt) =>
              opt.toLowerCase() == widget.item.itemName.trim().toLowerCase(),
          orElse: () => '',
        );

    if (matchedPreset.isNotEmpty) {
      _selectedPackageMaterial = matchedPreset;
      _customPackageMaterialController =
          TextEditingController(text: widget.item.itemName);
      _hasMatchedAsyncMaterials = true;
    } else {
      _selectedPackageMaterial = 'Custom';
      _customPackageMaterialController =
          TextEditingController(text: widget.item.itemName);
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
    _descriptionController.dispose();
    _ingredientSearchController.dispose();
    _customPackageMaterialController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final inventory = context.read<InventoryProvider>();

    try {
      String? finalImageUrl;

      // Handle image update or removal
      if (_newPickedImageBytes != null && _newPickedImage != null) {
        finalImageUrl = await inventory.uploadItemImage(
          _newPickedImageBytes!,
          _newPickedImage!.name,
        );
      } else if (_imageMarkedForRemoval) {
        finalImageUrl = '';
      }

      final ingredientsPayload = _selectedIngredientIds.map((id) {
        final ctrl = _qtyControllers[id];
        final qty = (ctrl != null)
            ? (double.tryParse(ctrl.text.trim()) ?? 1.0)
            : 1.0;
        return ItemIngredientModel(
          itemId: id,
          quantity: qty,
        );
      }).toList();

      String finalItemName = _nameController.text.trim();
      if (_selectedItemType == 'PACKAGING' || finalItemName.isEmpty) {
        if (_selectedPackageMaterial == 'Custom') {
          finalItemName = _customPackageMaterialController.text.trim();
        } else {
          finalItemName = _selectedPackageMaterial;
        }
      }

      if (finalItemName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please provide an item name or select a packing material.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final ok = await inventory.updateItem(
        itemId: widget.item.itemId,
        itemName: finalItemName,
        itemType: _selectedItemType,
        measurementUnit: _selectedUnit,
        quantity: double.tryParse(_quantityController.text.trim()) ?? 1.0,
        reorderThreshold: widget.item.reorderThresholdQuantity,
        description: _descriptionController.text.trim(),
        country: _selectedCountry.trim(),
        hasIngredients: _hasIngredients,
        ingredients: _hasIngredients ? ingredientsPayload : [],
        imageUrl: finalImageUrl,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (ok) {
        await showSuccessScreen(
          context,
          title: 'Item updated',
          message: 'Your item changes were saved successfully.',
          returnLabel: 'Return to item',
        );
        if (!mounted) return;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          inventory.errorMessage ?? 'Failed to delete item'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child:
                const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label,
      {bool isRequired = false, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
              children: [
                TextSpan(text: label),
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFCBD5E1),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingImage =
        widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty;
    final showImage = (_newPickedImageBytes != null) ||
        (hasExistingImage && !_imageMarkedForRemoval);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    final initialLetter = widget.item.itemName.trim().isNotEmpty
        ? widget.item.itemName.trim()[0].toUpperCase()
        : 'A';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Row(
              children: const [
                Text(
                  'Edit Item',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 16,
              24,
              isWide ? 28 : 16,
              32,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header Title & Subtitle
                  const Text(
                    'Edit Item',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Update item master specifications, packaging configurations, and units.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Card Container
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Section: Avatar Box & Item Name / Category Row
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAvatarBadge(showImage, initialLetter),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildNameAndCategoryFields(),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: _buildAvatarBadge(
                                          showImage, initialLetter),
                                    ),
                                    const SizedBox(height: 18),
                                    _buildNameAndCategoryFields(),
                                  ],
                                ),

                              const SizedBox(height: 18),

                              // Description Field
                              _buildFieldLabel('DESCRIPTION'),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: _buildInputDecoration(
                                  hintText: 'Enter item description...',
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Packing Material & Custom Packing Material Row
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildPackagingMaterialDropdown(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildCustomPackagingMaterialField(),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPackagingMaterialDropdown(),
                                    const SizedBox(height: 16),
                                    _buildCustomPackagingMaterialField(),
                                  ],
                                ),

                              const SizedBox(height: 18),

                              // Country Selector
                              _buildCountrySelector(),

                              const SizedBox(height: 18),

                              // Quantity & Unit Row
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildQuantityField(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildUnitDropdown(),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildQuantityField(),
                                    const SizedBox(height: 16),
                                    _buildUnitDropdown(),
                                  ],
                                ),

                              const SizedBox(height: 18),

                              // Ingredients Checkbox Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _hasIngredients = !_hasIngredients;
                                      if (!_hasIngredients) {
                                        _selectedIngredientIds.clear();
                                      }
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _hasIngredients,
                                          activeColor: const Color(0xFF0F172A),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              _hasIngredients = val ?? false;
                                              if (!_hasIngredients) {
                                                _selectedIngredientIds.clear();
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'Ingredients',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Check to select raw material items used as ingredients',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Ingredients Expansion Selection Area
                              if (_hasIngredients) ...[
                                const SizedBox(height: 16),
                                _buildIngredientsSelector(),
                              ],
                            ],
                          ),
                        ),

                        // Card Bottom Actions Divider & Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Delete Item Button
                              InkWell(
                                onTap: _confirmDelete,
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Color(0xFFEF4444),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Delete Item',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Cancel and Save Changes Buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF334155),
                                      elevation: 0,
                                      side: const BorderSide(
                                          color: Color(0xFFE2E8F0)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _isSaving ? null : _saveChanges,
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check,
                                                  size: 16,
                                                  color: Colors.white),
                                              SizedBox(width: 6),
                                              Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Page Footer
                  const Center(
                    child: Text(
                      'Developed by Bigburry Hypersystems',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarBadge(bool showImage, String initialLetter) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: showImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _newPickedImageBytes != null
                          ? Image.memory(
                              _newPickedImageBytes!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              ApiConstants.resolveImageUrl(
                                  widget.item.imageUrl)!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                initialLetter,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                    )
                  : Text(
                      initialLetter,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.edit,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Click badge to update photo',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNameAndCategoryFields() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    final nameField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('ITEM NAME', isRequired: true),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: _buildInputDecoration(
            prefixIcon: const Icon(
              Icons.local_offer_outlined,
              size: 18,
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
      ],
    );

    final categoryField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(
          'ITEM TYPE / CATEGORY',
          isRequired: true,
          trailing: Consumer<TenantProvider>(
            builder: (context, tenant, _) {
              final canManage = tenant.isTenantAdmin ||
                  tenant.hasPermission(AppPermissions.itemCategoryManage);
              if (!canManage) return const SizedBox.shrink();
              return InkWell(
                onTap: () => ManageItemCategoriesModal.show(context),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Manage Categories',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Consumer<InventoryProvider>(
          builder: (context, inventory, _) {
            final categoryOptions = <Map<String, String>>[];
            if (inventory.itemCategories.isNotEmpty) {
              for (final c in inventory.itemCategories) {
                categoryOptions.add({'value': c.code, 'label': c.label});
              }
            } else {
              categoryOptions.addAll(_itemTypes);
            }

            if (!categoryOptions.any((c) => c['value'] == _selectedItemType)) {
              categoryOptions.insert(0, {
                'value': _selectedItemType,
                'label': _selectedItemType.replaceAll('_', ' ').toUpperCase(),
              });
            }

            return DropdownButtonFormField<String>(
              key: ValueKey('edit_item_type_$_selectedItemType'),
              initialValue: _selectedItemType,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: _buildInputDecoration(),
              items: categoryOptions
                  .map((type) => DropdownMenuItem(
                        value: type['value'],
                        child: Text(type['label']!),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedItemType = val;
                    if (val == 'PACKAGING') {
                      if (_selectedPackageMaterial == 'Custom') {
                        if (_customPackageMaterialController.text
                            .trim()
                            .isNotEmpty) {
                          _nameController.text =
                              _customPackageMaterialController.text.trim();
                        }
                      } else {
                        _nameController.text = _selectedPackageMaterial;
                      }
                    }
                  });
                }
              },
            );
          },
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: nameField),
          const SizedBox(width: 16),
          Expanded(child: categoryField),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nameField,
          const SizedBox(height: 16),
          categoryField,
        ],
      );
    }
  }

  Widget _buildPackagingMaterialDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(
          'PACKING MATERIAL',
          trailing: Consumer<TenantProvider>(
            builder: (context, tenant, _) {
              final canManage = tenant.isTenantAdmin ||
                  tenant.hasPermission(AppPermissions.packagingMaterialManage) ||
                  tenant.hasPermission(AppPermissions.itemCategoryManage);
              if (!canManage) return const SizedBox.shrink();
              return InkWell(
                onTap: () => ManagePackagingMaterialsModal.show(context),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Manage Materials',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Consumer<InventoryProvider>(
          builder: (context, inventory, _) {
            final materialOptions = <String>[];
            if (inventory.packagingMaterials.isNotEmpty) {
              for (final m in inventory.packagingMaterials) {
                if (!materialOptions.contains(m.name)) {
                  materialOptions.add(m.name);
                }
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

            if (!_hasMatchedAsyncMaterials &&
                inventory.packagingMaterials.isNotEmpty) {
              final currentName = widget.item.itemName.trim().toLowerCase();
              final match = inventory.packagingMaterials.firstWhere(
                (m) => m.name.toLowerCase() == currentName,
                orElse: () => PackagingMaterialModel(
                    materialId: '', name: '', isPreset: false),
              );
              if (match.name.isNotEmpty) {
                _selectedPackageMaterial = match.name;
                _customPackageMaterialController.text = '';
              }
              _hasMatchedAsyncMaterials = true;
            }

            if (!materialOptions.contains(_selectedPackageMaterial)) {
              _selectedPackageMaterial = materialOptions.contains('Custom')
                  ? 'Custom'
                  : materialOptions.first;
            }

            return DropdownButtonFormField<String>(
              key: ValueKey('edit_pkg_mat_$_selectedPackageMaterial'),
              initialValue: _selectedPackageMaterial,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: _buildInputDecoration(),
              items: materialOptions
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPackageMaterial = val;
                    if (_selectedItemType == 'PACKAGING') {
                      if (val == 'Custom') {
                        _nameController.text =
                            _customPackageMaterialController.text.trim();
                      } else {
                        _nameController.text = val;
                      }
                    } else if (_nameController.text.trim().isEmpty) {
                      if (val != 'Custom') {
                        _nameController.text = val;
                      }
                    }
                  });
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomPackagingMaterialField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('CUSTOM PACKING MATERIAL', isRequired: true),
        TextFormField(
          controller: _customPackageMaterialController,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: _buildInputDecoration(
            prefixIcon: const Icon(
              Icons.notes,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ),
          onChanged: (text) {
            if (_selectedPackageMaterial == 'Custom' &&
                _selectedItemType == 'PACKAGING') {
              _nameController.text = text.trim();
            }
          },
          validator: (val) {
            if (_selectedPackageMaterial == 'Custom' &&
                (val == null || val.trim().isEmpty)) {
              return 'Packing material name is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCountrySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel('TARGET COUNTRY'),
            InkWell(
              onTap: () async {
                final newCountry =
                    await CountryPickerModal.showAddNewCountryDialog(context);
                if (newCountry != null && newCountry.isNotEmpty && mounted) {
                  setState(() => _selectedCountry = newCountry);
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: Color(0xFF0F766E),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '+ Add New Country',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            CountryPickerModal.show(
              context,
              currentCountry: _selectedCountry,
              onSelected: (val) {
                setState(() => _selectedCountry = val);
              },
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.public,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCountry.isNotEmpty
                        ? _selectedCountry
                        : 'Select country (e.g. India, United States)...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedCountry.isNotEmpty
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                if (_selectedCountry.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _selectedCountry = ''),
                    child: const Icon(
                      Icons.clear,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF64748B),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('QUANTITY', isRequired: true),
        TextFormField(
          controller: _quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: _buildInputDecoration(
            prefixIcon: const Icon(
              Icons.scale_outlined,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Quantity required';
            }
            final n = double.tryParse(val.trim());
            if (n == null || n <= 0) {
              return 'Must be > 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('UNIT', isRequired: true),
        DropdownButtonFormField<String>(
          key: ValueKey('edit_unit_$_selectedUnit'),
          initialValue: _selectedUnit,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF64748B),
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: _buildInputDecoration(),
          items: _units
              .map((u) => DropdownMenuItem(
                    value: u['value'],
                    child: Text(u['label']!),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedUnit = val);
          },
        ),
      ],
    );
  }

  Widget _buildIngredientsSelector() {
    final inventory = context.watch<InventoryProvider>();
    final rawMaterials = inventory.items
        .where((i) =>
            i.itemType == 'RAW_MATERIAL' &&
            i.itemId != widget.item.itemId &&
            i.isActive)
        .toList();

    final filtered = rawMaterials.where((item) {
      if (_ingredientSearchQuery.isEmpty) return true;
      final q = _ingredientSearchQuery.toLowerCase();
      return item.itemName.toLowerCase().contains(q) ||
          item.sku.toLowerCase().contains(q);
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FORMULATION INGREDIENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${_selectedIngredientIds.length} Selected',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          CpmsSearchBar(
            controller: _ingredientSearchController,
            hintText: 'Search raw materials by name or SKU...',
            onChanged: (val) =>
                setState(() => _ingredientSearchQuery = val.trim()),
            onClear: () {
              _ingredientSearchController.clear();
              setState(() => _ingredientSearchQuery = '');
            },
          ),
          const SizedBox(height: 12),

          if (rawMaterials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No raw materials registered yet in inventory.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No matching raw materials found.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final rm = filtered[idx];
                final isSelected = _selectedIngredientIds.contains(rm.itemId);
                final qtyCtrl = _qtyControllers[rm.itemId] ??=
                    TextEditingController(text: '1.0');

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIngredientIds.add(rm.itemId);
                            } else {
                              _selectedIngredientIds.remove(rm.itemId);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rm.itemName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${rm.sku} • Stock: ${rm.totalAvailableStock} ${rm.measurementUnit}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        SizedBox(
                          width: 90,
                          height: 38,
                          child: TextFormField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              suffixText: rm.measurementUnit.toLowerCase(),
                              suffixStyle: const TextStyle(
                                  fontSize: 10, color: Color(0xFF64748B)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0F172A), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
