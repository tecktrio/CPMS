import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import 'edit_item_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final ItemModel item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isUpdatingStock = false;
  bool _isUploadingImage = false;

  Future<void> _updateItemImage(String itemId) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final filename = picked.name;

      if (!mounted) return;
      final inventory = context.read<InventoryProvider>();

      setState(() => _isUploadingImage = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Uploading item image to AWS S3...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final ok = await inventory.updateItemImage(itemId, bytes, filename);
      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item image updated successfully!'),
              backgroundColor: Color(0xFF0F766E),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(inventory.errorMessage ?? 'Image update failed'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _adjustStock(ItemModel item, double delta) async {
    if (_isUpdatingStock) return;
    final newStock = (item.totalAvailableStock + delta).clamp(0.0, 99999999.0);
    setState(() => _isUpdatingStock = true);
    final inventory = context.read<InventoryProvider>();
    final ok = await inventory.updateItemStock(item.itemId, newStock);
    if (mounted) {
      setState(() => _isUpdatingStock = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inventory.errorMessage ?? 'Failed to update stock'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showSetStockDialog(ItemModel item) {
    final stockCtrl =
        TextEditingController(text: item.totalAvailableStock.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock: ${item.itemName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock: ${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: stockCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'New Stock Quantity (${item.measurementUnit}) *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter quantity';
                  final num = double.tryParse(val.trim());
                  if (num == null || num < 0) return 'Enter a valid non-negative number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final qty = double.parse(stockCtrl.text.trim());
              Navigator.pop(ctx);

              setState(() => _isUpdatingStock = true);
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.updateItemStock(item.itemId, qty);
              if (mounted) {
                setState(() => _isUpdatingStock = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Stock updated successfully to $qty ${item.measurementUnit}'
                        : (inventory.errorMessage ?? 'Stock update failed')),
                    backgroundColor:
                        ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Item: ${item.sku}?'),
        content: Text(
          'Are you sure you want to permanently delete "${item.itemName}"? Note that an item can only be deleted if its remaining stock is zero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.deleteItem(item.itemId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Item deleted successfully'
                        : (inventory.errorMessage ?? 'Delete failed')),
                    backgroundColor:
                        ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
                if (ok) {
                  Navigator.pop(context); // Return to list screen
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canUpdate = isAdmin || tenant.hasPermission(AppPermissions.itemUpdate);
    final canDelete = isAdmin || tenant.hasPermission(AppPermissions.itemDelete);

    // Get live item from provider state if available
    final currentItem = inventory.items.firstWhere(
      (i) => i.itemId == widget.item.itemId,
      orElse: () => widget.item,
    );

    // Find store room name
    StoreRoomModel? room;
    if (currentItem.storeRoomId != null && currentItem.storeRoomId!.isNotEmpty) {
      final matches = inventory.storeRooms
          .where((r) => r.storeRoomId == currentItem.storeRoomId);
      if (matches.isNotEmpty) room = matches.first;
    }

    final divisionDisplay = (currentItem.division != null &&
            currentItem.division!.isNotEmpty)
        ? currentItem.division!
        : (currentItem.locationCode != null &&
                currentItem.locationCode!.isNotEmpty
            ? currentItem.locationCode!
            : 'Default Section');

    final isAlert = currentItem.isBelowReorderThreshold;

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
        title: Text(
          currentItem.itemName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Refresh',
            onPressed: () {
              inventory.loadItems();
              inventory.loadStoreRooms();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Image Display / Banner
                  if (currentItem.imageUrl != null && currentItem.imageUrl!.isNotEmpty)
                    Stack(
                      children: [
                        Image.network(
                          ApiConstants.resolveImageUrl(currentItem.imageUrl)!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined, size: 40, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        if (canUpdate)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _isUploadingImage ? null : () => _updateItemImage(currentItem.itemId),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Change Photo',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (canUpdate)
                    InkWell(
                      onTap: _isUploadingImage ? null : () => _updateItemImage(currentItem.itemId),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        color: const Color(0xFFF8FAFC),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 20, color: Color(0xFF0F766E)),
                            SizedBox(width: 8),
                            Text(
                              'Add Item Photo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentItem.sku,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentItem.itemType.replaceAll('_', ' '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: currentItem.isActive
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: currentItem.isActive
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Text(
                                currentItem.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: currentItem.isActive
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentItem.itemName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Measurement Unit: ${currentItem.measurementUnit}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stock & Quantity Management Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 18, color: Color(0xFF0F766E)),
                        SizedBox(width: 8),
                        Text(
                          'Stock & Inventory Level',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Stock Counter Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Stock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${currentItem.totalAvailableStock.toStringAsFixed(1)} ${currentItem.measurementUnit}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Quick Stock Stepper Buttons
                          if (canUpdate) ...[
                            IconButton.filledTonal(
                              tooltip: 'Decrease by 1',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF334155),
                              ),
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: _isUpdatingStock
                                  ? null
                                  : () => _adjustStock(currentItem, -1.0),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filled(
                              tooltip: 'Increase by 1',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: _isUpdatingStock
                                  ? null
                                  : () => _adjustStock(currentItem, 1.0),
                            ),
                            const SizedBox(width: 6),
                            IconButton.outlined(
                              tooltip: 'Set Exact Stock',
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              icon: const Icon(Icons.edit_note, size: 20),
                              onPressed: _isUpdatingStock
                                  ? null
                                  : () => _showSetStockDialog(currentItem),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Threshold Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reorder Threshold',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '${currentItem.reorderThresholdQuantity.toStringAsFixed(1)} ${currentItem.measurementUnit}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),

                    // Shortfall Warning Banner
                    if (isAlert) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reorder Shortfall: ${currentItem.reorderShortfallQuantity.toStringAsFixed(1)} ${currentItem.measurementUnit} (Stock is below minimum threshold)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Storage Room & Division Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 18, color: Color(0xFF0284C7)),
                        SizedBox(width: 8),
                        Text(
                          'Storage Location Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Store Room
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.store_mall_directory_outlined,
                            size: 20,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Store Room',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room != null
                                    ? '${room.roomName} (${room.roomCode})'
                                    : (currentItem.storeRoomId != null &&
                                            currentItem.storeRoomId!.isNotEmpty
                                        ? currentItem.storeRoomId!
                                        : 'Not Assigned'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),

                    // Section / Division
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.grid_view_outlined,
                            size: 20,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Section / Division',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                divisionDisplay,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F766E),
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
            ),
            const SizedBox(height: 24),

            // Action Buttons Based on Permissions
            if (canUpdate || canDelete) ...[
              const Text(
                'Management Actions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              if (canUpdate) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Edit Item Details',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final inv = context.read<InventoryProvider>();
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditItemScreen(item: currentItem),
                        ),
                      );
                      if (updated == true) {
                        inv.loadItems();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: const Text(
                      'Set Stock Quantity',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _showSetStockDialog(currentItem),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (canDelete) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(
                      'Delete Item',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _confirmDelete(currentItem),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
