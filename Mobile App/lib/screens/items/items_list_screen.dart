import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'create_item_screen.dart';
import 'item_detail_screen.dart';

class ItemsListScreen extends StatefulWidget {
  final bool manageMode;
  const ItemsListScreen({super.key, this.manageMode = false});

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  String? _selectedStoreRoomFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inv = context.read<InventoryProvider>();
      inv.loadItems();
      inv.loadStoreRooms();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showStoreRoomPicker(BuildContext context, List<StoreRoomModel> rooms) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle pill
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Store Room',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.all_inclusive, color: Colors.black),
                      title: const Text(
                        'All Store Rooms',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      trailing: _selectedStoreRoomFilter == null
                          ? const Icon(Icons.check_circle, color: Colors.black)
                          : null,
                      onTap: () {
                        setState(() => _selectedStoreRoomFilter = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ...rooms.map((room) {
                      final isSelected = _selectedStoreRoomFilter == room.storeRoomId;
                      return ListTile(
                        leading: const Icon(Icons.meeting_room_outlined, color: Colors.black),
                        title: Text(
                          room.roomName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Code: ${room.roomCode}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.black)
                            : null,
                        onTap: () {
                          setState(() => _selectedStoreRoomFilter = room.storeRoomId);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final categories = [
      {'code': 'ALL', 'label': 'All Materials'},
      {'code': 'RAW_MATERIAL', 'label': 'Raw Materials'},
      {'code': 'FINISHED_GOOD', 'label': 'Finished Goods'},
      {'code': 'PACKAGING', 'label': 'Packaging'},
      {'code': 'SPARE_PARTS', 'label': 'Spare Parts & Tools'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Material Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ...categories.map((cat) {
                final isSelected = _selectedCategory == cat['code'];
                return ListTile(
                  leading: const Icon(Icons.category_outlined, color: Colors.black),
                  title: Text(
                    cat['label']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.black)
                      : null,
                  onTap: () {
                    setState(() => _selectedCategory = cat['code']!);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canCreate = isAdmin || tenant.hasPermission(AppPermissions.itemCreate);
    final canUpdate = isAdmin || tenant.hasPermission(AppPermissions.itemUpdate);
    final canDelete = isAdmin || tenant.hasPermission(AppPermissions.itemDelete);

    final filteredItems = inventory.items.where((item) {
      final matchesSearch = item.itemName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat =
          _selectedCategory == 'ALL' || item.itemType == _selectedCategory;
      final matchesRoom = _selectedStoreRoomFilter == null ||
          item.storeRoomId == _selectedStoreRoomFilter;
      return matchesSearch && matchesCat && matchesRoom;
    }).toList();

    String pageTitle = 'Items & Materials';
    if (widget.manageMode) {
      if (canUpdate && !canDelete) {
        pageTitle = 'Update Items';
      } else if (!canUpdate && canDelete) {
        pageTitle = 'Delete Items';
      } else {
        pageTitle = 'Manage Items';
      }
    }

    // Determine current store room label
    String storeRoomLabel = 'All Store Rooms';
    if (_selectedStoreRoomFilter != null) {
      final match = inventory.storeRooms
          .where((r) => r.storeRoomId == _selectedStoreRoomFilter);
      if (match.isNotEmpty) {
        storeRoomLabel = match.first.roomName;
      }
    }

    // Determine current category label
    String categoryLabel = 'All Materials';
    if (_selectedCategory == 'RAW_MATERIAL') {
      categoryLabel = 'Raw Materials';
    } else if (_selectedCategory == 'FINISHED_GOOD') {
      categoryLabel = 'Finished Goods';
    } else if (_selectedCategory == 'PACKAGING') {
      categoryLabel = 'Packaging';
    } else if (_selectedCategory == 'SPARE_PARTS') {
      categoryLabel = 'Spare Parts & Tools';
    }

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
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: UserProfileAvatar(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            height: 48,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search SKU or item title...',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.cancel, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),

          // Store Room Filter Button
          GestureDetector(
            onTap: () => _showStoreRoomPicker(context, inventory.storeRooms),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 20, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      storeRoomLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.swap_horiz, size: 20, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          // Material Category Filter Button
          GestureDetector(
            onTap: () => _showCategoryPicker(context),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_outlined, size: 20, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.swap_horiz, size: 20, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: RefreshIndicator(
              color: Colors.black,
              onRefresh: () async {
                await inventory.loadItems();
                await inventory.loadStoreRooms();
              },
              child: inventory.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Items Found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Create item master records to begin managing inventory.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ItemDetailScreen(item: item),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 1 Thumbnail (Image or Fallback Initial)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: (item.imageUrl != null &&
                                                item.imageUrl!.isNotEmpty)
                                            ? Image.network(
                                                ApiConstants.resolveImageUrl(
                                                    item.imageUrl)!,
                                                width: 52,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, stackTrace) =>
                                                        _buildItemThumbnailFallback(
                                                            item),
                                              )
                                            : _buildItemThumbnailFallback(item),
                                      ),
                                      const SizedBox(width: 14),

                                      // Item Name & SKU / Type
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.itemName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.sku} • ${item.itemType.replaceAll('_', ' ').toUpperCase()}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Quantity Controls
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Minus Button
                                          GestureDetector(
                                            onTap: canUpdate
                                                ? () {
                                                    final newStock =
                                                        (item.totalAvailableStock - 1.0)
                                                            .clamp(0.0, 99999999.0);
                                                    inventory.updateItemStock(
                                                        item.itemId, newStock);
                                                  }
                                                : null,
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(0xFFCBD5E1),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.remove,
                                                size: 18,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),

                                          // Stock Value and Unit
                                          GestureDetector(
                                            onTap: canUpdate
                                                ? () => _showQuickStockDialog(
                                                    context, item)
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    item.totalAvailableStock
                                                        .toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  Text(
                                                    item.measurementUnit
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Plus Button
                                          GestureDetector(
                                            onTap: canUpdate
                                                ? () {
                                                    final newStock =
                                                        (item.totalAvailableStock + 1.0)
                                                            .clamp(0.0, 99999999.0);
                                                    inventory.updateItemStock(
                                                        item.itemId, newStock);
                                                  }
                                                : null,
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.black,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.add,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'Register Item',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateItemScreen()),
                );
              },
            )
          : null,
    );
  }

  void _showQuickStockDialog(BuildContext context, ItemModel item) {
    final stockCtrl =
        TextEditingController(text: item.totalAvailableStock.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Update Stock: ${item.itemName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final qty = double.parse(stockCtrl.text.trim());
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.updateItemStock(item.itemId, qty);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Stock updated to $qty ${item.measurementUnit}'
                        : (inventory.errorMessage ?? 'Stock update failed')),
                    backgroundColor:
                        ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Update Stock', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemThumbnailFallback(ItemModel item) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          item.itemName.isNotEmpty ? item.itemName[0].toUpperCase() : 'I',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
