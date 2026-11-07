import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';

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
                            final isAlert = item.isBelowReorderThreshold;

                            final room = inventory.storeRooms.firstWhere(
                              (r) => r.storeRoomId == item.storeRoomId,
                              orElse: () => StoreRoomModel(
                                storeRoomId: '',
                                tenantId: '',
                                roomCode: '',
                                roomName: 'Unassigned',
                                totalCapacityUnits: 0,
                                currentOccupancyUnits: 0,
                                capacityUtilizationPercentage: 0,
                                activeBatchesCount: 0,
                                isActive: true,
                              ),
                            );

                            final divisionDisplay = (item.division != null && item.division!.isNotEmpty)
                                ? item.division!
                                : (item.locationCode != null && item.locationCode!.isNotEmpty
                                    ? item.locationCode!
                                    : 'Default Section');

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.sku,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F766E),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.itemType.replaceAll('_', ' '),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Store Room & Division Location Details Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.meeting_room_outlined, size: 14, color: Color(0xFF0284C7)),
                                          const SizedBox(width: 4),
                                          Text(
                                            room.storeRoomId.isNotEmpty
                                                ? '${room.roomName} (${room.roomCode})'
                                                : 'Store Room: Not Specified',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.grid_view_outlined, size: 13, color: Color(0xFF0F766E)),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              divisionDisplay,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F766E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Reorder Threshold & Alert Banner
                                    if (isAlert)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Color(0xFFD97706),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Reorder Shortfall: ${item.reorderShortfallQuantity.toStringAsFixed(1)} ${item.measurementUnit} (Threshold: ${item.reorderThresholdQuantity.toStringAsFixed(1)})',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Text(
                                        'Reorder threshold: ${item.reorderThresholdQuantity.toStringAsFixed(1)} ${item.measurementUnit}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),

                                    // Update & Delete Actions
                                    if (canUpdate || canDelete) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (canUpdate)
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF0F766E),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              icon: const Icon(Icons.edit_outlined, size: 16),
                                              label: const Text(
                                                'Update',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () => _showEditDialog(context, item),
                                            ),
                                          if (canDelete) ...[
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              icon: const Icon(Icons.delete_outline, size: 16),
                                              label: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () => _confirmDelete(context, item),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ItemModel item) {
    final inventory = context.read<InventoryProvider>();
    final nameCtrl = TextEditingController(text: item.itemName);
    final thresholdCtrl =
        TextEditingController(text: item.reorderThresholdQuantity.toString());
    final stockCtrl =
        TextEditingController(text: item.totalAvailableStock.toString());

    final List<Map<String, String>> typeOptions = [
      {'value': 'RAW_MATERIAL', 'label': 'Raw Material'},
      {'value': 'FINISHED_GOOD', 'label': 'Finished Good'},
      {'value': 'PACKAGING', 'label': 'Packaging'},
    ];
    String selectedType = item.itemType;
    if (!typeOptions.any((t) => t['value'] == selectedType)) {
      typeOptions.add({'value': selectedType, 'label': selectedType});
    }

    final List<Map<String, String>> unitOptions = [
      {'value': 'KILOGRAM', 'label': 'Kilogram (KG)'},
      {'value': 'LITER', 'label': 'Liter (L)'},
      {'value': 'LITRE', 'label': 'Litre (L)'},
      {'value': 'PIECE', 'label': 'Piece (PC)'},
      {'value': 'CARTOON_BOX', 'label': 'Carton Box'},
      {'value': 'CARTON', 'label': 'Carton'},
      {'value': 'GRAM', 'label': 'Gram (G)'},
      {'value': 'MILLILITRE', 'label': 'Millilitre (ML)'},
      {'value': 'UNIT', 'label': 'Unit'},
    ];
    String selectedUnit = item.measurementUnit;
    if (!unitOptions.any((u) => u['value'] == selectedUnit)) {
      unitOptions.add({'value': selectedUnit, 'label': selectedUnit});
    }

    String? selectedRoomId = item.storeRoomId;
    if (selectedRoomId != null &&
        !inventory.storeRooms.any((r) => r.storeRoomId == selectedRoomId)) {
      selectedRoomId = null;
    }
    if (selectedRoomId == null && inventory.storeRooms.isNotEmpty) {
      selectedRoomId = inventory.storeRooms.first.storeRoomId;
    }

    String? selectedDivision = item.division;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          StoreRoomModel? currentRoom;
          if (selectedRoomId != null) {
            final matches =
                inventory.storeRooms.where((r) => r.storeRoomId == selectedRoomId);
            if (matches.isNotEmpty) currentRoom = matches.first;
          }

          final divisions = currentRoom?.divisions ?? [];
          if (divisions.isNotEmpty &&
              (selectedDivision == null || !divisions.contains(selectedDivision))) {
            selectedDivision = divisions.first;
          }

          return AlertDialog(
            title: Text('Update Item: ${item.sku}'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item Name *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Item Type'),
                      items: typeOptions
                          .map((t) => DropdownMenuItem(
                                value: t['value'],
                                child: Text(t['label']!),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration:
                          const InputDecoration(labelText: 'Measurement Unit'),
                      items: unitOptions
                          .map((u) => DropdownMenuItem(
                                value: u['value'],
                                child: Text(u['label']!),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedUnit = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      decoration: const InputDecoration(labelText: 'Store Room'),
                      items: inventory.storeRooms
                          .map((r) => DropdownMenuItem(
                                value: r.storeRoomId,
                                child: Text('${r.roomName} (${r.roomCode})'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedRoomId = val;
                            final newRoom = inventory.storeRooms
                                .firstWhere((r) => r.storeRoomId == val);
                            if (newRoom.divisions.isNotEmpty) {
                              selectedDivision = newRoom.divisions.first;
                            } else {
                              selectedDivision = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (divisions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedDivision,
                        decoration:
                            const InputDecoration(labelText: 'Division / Section'),
                        items: divisions
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedDivision = val);
                        },
                      )
                    else
                      TextFormField(
                        initialValue: selectedDivision ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Division / Section Identifier',
                          hintText: 'e.g. Section A',
                        ),
                        onChanged: (val) => selectedDivision = val,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Stock Quantity *'),
                            validator: (v) {
                              if (v == null || double.tryParse(v) == null) {
                                return 'Enter number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: thresholdCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Reorder Level *'),
                            validator: (v) {
                              if (v == null || double.tryParse(v) == null) {
                                return 'Enter number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                  Navigator.pop(ctx);
                  final ok = await inventory.updateItem(
                    itemId: item.itemId,
                    itemName: nameCtrl.text.trim(),
                    itemType: selectedType,
                    measurementUnit: selectedUnit,
                    reorderThreshold: double.parse(thresholdCtrl.text.trim()),
                    stockQuantity: double.parse(stockCtrl.text.trim()),
                    storeRoomId: selectedRoomId,
                    division: selectedDivision,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Item updated successfully'
                            : (inventory.errorMessage ?? 'Update failed')),
                        backgroundColor:
                            ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                      ),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Item: ${item.sku}?'),
        content: Text(
          'Are you sure you want to permanently delete "${item.itemName}"?',
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Item deleted successfully'
                        : (inventory.errorMessage ?? 'Delete failed')),
                    backgroundColor:
                        ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Delete'),
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
