import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              inventory.loadItems();
              inventory.loadStoreRooms();
            },
          ),
          const UserProfileAvatar(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search SKU or item title...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    fillColor: Color(0xFFF8FAFC),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Store Room Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedStoreRoomFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.filter_list, size: 20),
                      hint: const Row(
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 18, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('Filter by Store Room: All Rooms'),
                        ],
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.all_inclusive, size: 18, color: Color(0xFF0F766E)),
                              SizedBox(width: 8),
                              Text('All Store Rooms', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        ...inventory.storeRooms.map((room) {
                          return DropdownMenuItem<String?>(
                            value: room.storeRoomId,
                            child: Row(
                              children: [
                                const Icon(Icons.meeting_room_outlined, size: 18, color: Color(0xFF0284C7)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${room.roomName} (${room.roomCode})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedStoreRoomFilter = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Items'),
                      _buildFilterChip('RAW_MATERIAL', 'Raw Materials'),
                      _buildFilterChip('FINISHED_GOOD', 'Finished Goods'),
                      _buildFilterChip('PACKAGING', 'Packaging'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await inventory.loadItems();
                await inventory.loadStoreRooms();
              },
              child: inventory.isLoading
                  ? const Center(child: CircularProgressIndicator())
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
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Create item master records to begin managing inventory.',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ItemDetailScreen(item: item),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Title & Description
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.itemName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.sku} • ${item.itemType.replaceAll('_', ' ')}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Quantity & Stock Update +/- Buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (canUpdate)
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(20),
                                                onTap: () {
                                                  final newStock = (item.totalAvailableStock - 1.0)
                                                      .clamp(0.0, 99999999.0);
                                                  inventory.updateItemStock(item.itemId, newStock);
                                                },
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.remove,
                                                    size: 18,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: canUpdate
                                                ? () => _showQuickStockDialog(context, item)
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    item.totalAvailableStock.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Text(
                                                    item.measurementUnit,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (canUpdate)
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(20),
                                                onTap: () {
                                                  final newStock = (item.totalAvailableStock + 1.0)
                                                      .clamp(0.0, 99999999.0);
                                                  inventory.updateItemStock(item.itemId, newStock);
                                                },
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0F766E),
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.add,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
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
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Register Item', style: TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
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
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String cat, String label) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
        checkmarkColor: const Color(0xFF0F766E),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF475569),
        ),
        onSelected: (_) {
          setState(() {
            _selectedCategory = cat;
          });
        },
      ),
    );
  }
}
