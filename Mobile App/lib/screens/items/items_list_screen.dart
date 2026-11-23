import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../widgets/country_picker_modal.dart';
import '../../widgets/cpms_search_bar.dart';
import '../../widgets/app_footer.dart';
import 'create_item_screen.dart';
import 'item_detail_screen.dart';
import 'manage_item_categories_modal.dart';
import 'manage_countries_modal.dart';

class ItemsListScreen extends StatefulWidget {
  final bool manageMode;
  const ItemsListScreen({super.key, this.manageMode = false});

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  String _selectedCountry = 'ALL';

  // Infinite Scroll Pagination state
  int _displayedCount = 30;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadItems();
      context.read<InventoryProvider>().loadItemCategories(silent: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Trigger when user is within 250 pixels of the bottom
    if (maxScroll - currentScroll <= 250) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final inventory = context.read<InventoryProvider>();
    final allItems = inventory.items;
    final filteredCount = allItems.where((item) {
      final matchesSearch = item.itemName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.specification.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.country.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat =
          _selectedCategory == 'ALL' || item.itemType == _selectedCategory;
      final matchesCountry = _selectedCountry == 'ALL' ||
          (_selectedCountry == 'GLOBAL'
              ? item.country.isEmpty
              : item.country.toLowerCase() == _selectedCountry.toLowerCase());
      return matchesSearch && matchesCat && matchesCountry;
    }).length;

    if (_displayedCount < filteredCount) {
      setState(() {
        _isLoadingMore = true;
      });
      // Brief debounce / smooth UI transition
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _displayedCount = (_displayedCount + _pageSize).clamp(0, filteredCount);
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
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
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.specification.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.country.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat =
          _selectedCategory == 'ALL' || item.itemType == _selectedCategory;
      final matchesCountry = _selectedCountry == 'ALL' ||
          (_selectedCountry == 'GLOBAL'
              ? item.country.isEmpty
              : item.country.toLowerCase() == _selectedCountry.toLowerCase());
      return matchesSearch && matchesCat && matchesCountry;
    }).toList();

    final totalFiltered = filteredItems.length;
    final displayLimit = _displayedCount.clamp(0, totalFiltered);
    final pagedItems = filteredItems.take(displayLimit).toList();
    final hasMore = displayLimit < totalFiltered;

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
                    await Future.wait([
                      inventory.loadItems(),
                      inventory.loadStoreRooms(),
                    ]);
                  },
                  child: inventory.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        )
                      : filteredItems.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.45,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildDriveTableHeader(isWide: isWide),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFE2E8F0),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 96),
                                    itemCount: pagedItems.length +
                                        (hasMore
                                            ? 1
                                            : (totalFiltered > 0 ? 1 : 0)),
                                    separatorBuilder: (context, index) =>
                                        const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    itemBuilder: (context, index) {
                                      if (index < pagedItems.length) {
                                        return _buildDriveRowItem(
                                          pagedItems[index],
                                          isWide: isWide,
                                        );
                                      }
                                      if (hasMore) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF14532D),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Loading more (${pagedItems.length} of $totalFiltered)...',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'All $totalFiltered items loaded',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                            const AppFooter(topPadding: 16, bottomPadding: 16),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF14532D), // Dark Green
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const StadiumBorder(),
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
    return CpmsSearchBar(
      controller: _searchController,
      hintText: 'Search items or materials...',
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
          _displayedCount = 30;
        });
      },
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _displayedCount = 30;
        });
      },
    );
  }

  Widget _buildCategoryChipsRow() {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final canManage = tenant.isTenantAdmin ||
        tenant.hasPermission(AppPermissions.itemCategoryManage);

    final categories = <Map<String, String>>[
      {'code': 'ALL', 'label': 'All Materials'},
    ];

    if (inventory.itemCategories.isNotEmpty) {
      for (final c in inventory.itemCategories) {
        categories.add({'code': c.code, 'label': c.label});
      }
    } else {
      categories.addAll([
        {'code': 'RAW_MATERIAL', 'label': 'Raw Materials'},
        {'code': 'FINISHED_GOOD', 'label': 'Finished Goods'},
        {'code': 'PACKAGING', 'label': 'Packing Materials'},
      ]);
    }

    return Row(
      children: [
        ...categories.map((cat) {
          final code = cat['code']!;
          final label = cat['label']!;
          final isSelected = _selectedCategory == code;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = code;
                  _displayedCount = 30;
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
        }),
        // Country Filter Chip
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {
              CountryPickerModal.show(
                context,
                currentCountry: _selectedCountry == 'ALL' ? '' : _selectedCountry,
                onSelected: (c) {
                  setState(() {
                    _selectedCountry = c.isEmpty ? 'ALL' : c;
                    _displayedCount = 30;
                  });
                },
              );
            },
            borderRadius: BorderRadius.circular(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedCountry != 'ALL' ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: _selectedCountry != 'ALL' ? const Color(0xFF0F172A) : const Color(0xFFE5E5E5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.public,
                    size: 14,
                    color: _selectedCountry != 'ALL' ? Colors.white : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedCountry == 'ALL' ? 'Country: All' : 'Country: $_selectedCountry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedCountry != 'ALL' ? FontWeight.w800 : FontWeight.w600,
                      color: _selectedCountry != 'ALL' ? Colors.white : Colors.black,
                    ),
                  ),
                  if (_selectedCountry != 'ALL') ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCountry = 'ALL';
                          _displayedCount = 30;
                        });
                      },
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (canManage) ...[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => ManageCountriesModal.show(context),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: const Color(0xFF99F6E4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.public,
                      size: 14,
                      color: Color(0xFF0F766E),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Manage Countries',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => ManageItemCategoriesModal.show(context),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: const Color(0xFF99F6E4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 14,
                      color: Color(0xFF0F766E),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Manage Categories',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDriveTableHeader({required bool isWide}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 20 : 12,
        vertical: 10,
      ),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Name Header
          Expanded(
            flex: isWide ? 4 : 6,
            child: Row(
              children: const [
                Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_downward, size: 13, color: Color(0xFF64748B)),
              ],
            ),
          ),
          if (isWide) ...[
            // Owner Header
            const SizedBox(
              width: 100,
              child: Text(
                'Owner',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // Category Header
            const SizedBox(
              width: 130,
              child: Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // Spec / Pack Size Header
            const SizedBox(
              width: 110,
              child: Text(
                'Pack Size',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
          // Stock / Quantity Header
          SizedBox(
            width: isWide ? 110 : 90,
            child: Text(
              'Stock',
              textAlign: isWide ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Action icon header placeholder
          const SizedBox(
            width: 36,
            child: Icon(Icons.more_vert, size: 16, color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveRowItem(ItemModel item, {required bool isWide}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: const Color(0xFFF1F5F9),
        splashColor: const Color(0xFFE2E8F0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 20 : 12,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Leading Icon / Thumbnail + Name
              Expanded(
                flex: isWide ? 4 : 6,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                          ? Image.network(
                              ApiConstants.resolveImageUrl(item.imageUrl)!,
                              width: 26,
                              height: 26,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildItemMiniThumbnail(item),
                            )
                          : _buildItemMiniThumbnail(item),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF202124),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isWide) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${item.itemType.replaceAll('_', ' ')} • ${item.specification}${item.country.isNotEmpty ? ' • 🌐 ${item.country}' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isWide) ...[
                // Owner Column (Google Drive style)
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF202124),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.person, size: 13, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'me',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF3C4043),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Column
                SizedBox(
                  width: 130,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.itemType == 'PACKAGING'
                              ? 'Packing'
                              : item.itemType.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Spec / Pack size Column
                SizedBox(
                  width: 110,
                  child: Text(
                    item.specification.isNotEmpty ? item.specification : '-',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Stock / Qty Column
              SizedBox(
                width: isWide ? 110 : 90,
                child: Text(
                  '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.measurementUnit}',
                  textAlign: isWide ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Trailing Action Icon (Google Drive 3-dots)
              SizedBox(
                width: 36,
                child: IconButton(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(item: item),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemMiniThumbnail(ItemModel item) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.insert_drive_file_outlined,
        size: 16,
        color: Color(0xFF5F6368),
      ),
    );
  }
}
