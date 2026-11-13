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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canCreate = isAdmin || tenant.hasPermission(AppPermissions.itemCreate);
    final canUpdate = isAdmin || tenant.hasPermission(AppPermissions.itemUpdate);
    final canDelete = isAdmin || tenant.hasPermission(AppPermissions.itemDelete);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    final allItems = inventory.items;

    final filteredItems = allItems.where((item) {
      final matchesSearch = item.itemName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat =
          _selectedCategory == 'ALL' || item.itemType == _selectedCategory;
      return matchesSearch && matchesCat;
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
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              children: [
                Text(
                  pageTitle,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // Search & Filter Controls (Uber Style)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 16,
                  8,
                  isWide ? 24 : 16,
                  10,
                ),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildSearchBar(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildCategoryChipsRow(),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildCategoryChipsRow(),
                          ),
                        ],
                      ),
              ),

              // Summary Metric (Total Items Only - Uber Style)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 16,
                  0,
                  isWide ? 24 : 16,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL ITEMS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF71717A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${allItems.length}',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    height: 1.0,
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                        color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.black87,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Items Content
              Expanded(
                child: RefreshIndicator(
                  color: Colors.black,
                  onRefresh: () async {
                    await inventory.loadItems();
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
                          : isWide
                              ? GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 6, 24, 90),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        screenWidth >= 1050 ? 3 : 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    mainAxisExtent: 88,
                                  ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (context, index) {
                                    return _buildItemCard(
                                        filteredItems[index]);
                                  },
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 6, 16, 90),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _buildItemCard(
                                          filteredItems[index]),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
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

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: Color(0xFF71717A), size: 18),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Search SKU or item title...',
                hintStyle: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Color(0xFF71717A), size: 16),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChipsRow() {
    final categories = [
      {'code': 'ALL', 'label': 'All Materials'},
      {'code': 'RAW_MATERIAL', 'label': 'Raw Materials'},
      {'code': 'FINISHED_GOOD', 'label': 'Finished Goods'},
      {'code': 'PACKAGING', 'label': 'Packaging'},
      {'code': 'SPARE_PARTS', 'label': 'Spare Parts'},
    ];

    return Row(
      children: categories.map((cat) {
        final code = cat['code']!;
        final label = cat['label']!;
        final isSelected = _selectedCategory == code;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = code;
              });
            },
            borderRadius: BorderRadius.circular(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isSelected ? Colors.black : const Color(0xFFE5E5E5),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemCard(ItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        hoverColor: const Color(0xFFF8FAFC),
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
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? Image.network(
                        ApiConstants.resolveImageUrl(item.imageUrl)!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildItemThumbnailFallback(item),
                      )
                    : _buildItemThumbnailFallback(item),
              ),
              const SizedBox(width: 14),

              // Item Name & SKU / Type / Unit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.sku} • ${item.itemType.replaceAll('_', ' ').toUpperCase()} • ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.measurementUnit.toUpperCase()}',
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

              // Trailing Navigation Chevron
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnailFallback(ItemModel item) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
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
