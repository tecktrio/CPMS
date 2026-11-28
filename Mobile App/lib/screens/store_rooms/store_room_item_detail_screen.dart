import '../../widgets/cpms_page_route.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cpms_page_title.dart';
import '../../widgets/cpms_form_page.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/app_footer.dart';
import '../items/item_detail_screen.dart';

/// Store Room Item Detail Page
/// Displays the specific inventory quantity, minimum count alert threshold,
/// store room division, temperature, and alert status for an item inside a store room.
class StoreRoomItemDetailScreen extends StatefulWidget {
  final String storeRoomId;
  final String itemId;
  final String? divisionId;

  const StoreRoomItemDetailScreen({
    super.key,
    required this.storeRoomId,
    required this.itemId,
    this.divisionId,
  });

  @override
  State<StoreRoomItemDetailScreen> createState() =>
      _StoreRoomItemDetailScreenState();
}

class _StoreRoomItemDetailScreenState extends State<StoreRoomItemDetailScreen> {
  void _showEditQuantityDialog(
    ItemModel item,
    StoreRoomItemModel sri,
    StoreRoomModel room,
  ) {
    final qtyCtrl = TextEditingController(
      text: sri.quantity.toStringAsFixed(
        sri.quantity.truncateToDouble() == sri.quantity ? 0 : 2,
      ),
    );
    final formKey = GlobalKey<FormState>();

    openCpmsPage(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CpmsFormPage(
          title: Text(
            'Update Quantity: ${item.itemName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stored in ${room.roomName} (${room.displayDivisionName(sri)})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${item.measurementUnit}) *',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.workspaceBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.workspaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter quantity';
                    }
                    final n = double.tryParse(val.trim());
                    if (n == null || n < 0) {
                      return 'Enter a valid non-negative number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminStorage,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final qty = double.parse(qtyCtrl.text.trim());
                Navigator.pop(ctx);
                final inventory = context.read<InventoryProvider>();
                await inventory.updateStoreRoomItemQuantity(
                  storeRoomId: room.storeRoomId,
                  itemId: item.itemId,
                  division: sri.division,
                  divisionId: room.divisionForItem(sri)?.divisionId ?? sri.divisionId,
                  quantity: qty,
                  minCount: sri.minCount,
                );
              },
              child: const Text(
                'Save Quantity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetMinimumCountDialog(
    ItemModel item,
    StoreRoomItemModel sri,
    StoreRoomModel room,
  ) {
    final controller = TextEditingController(
      text: sri.minCount.toStringAsFixed(
        sri.minCount.truncateToDouble() == sri.minCount ? 0 : 2,
      ),
    );
    final formKey = GlobalKey<FormState>();

    openCpmsPage(
      context: context,
      builder: (ctx) => CpmsFormPage(
        title: Text(
          'Minimum Quantity Alert: ${item.itemName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When stock in ${room.roomName} drops to or below this count, a low-stock alert is triggered.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Minimum Alert Quantity (${item.measurementUnit})',
                  helperText: 'Set to 0 to disable minimum alert.',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.workspaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.workspaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: Colors.black, width: 1.5),
                  ),
                ),
                validator: (value) {
                  final count = double.tryParse(value?.trim() ?? '');
                  if (count == null || count < 0) {
                    return 'Enter a valid non-negative count';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.adminStorage,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final minCount = double.parse(controller.text.trim());
              Navigator.pop(ctx);
              await context.read<InventoryProvider>().updateStoreRoomItemQuantity(
                    storeRoomId: room.storeRoomId,
                    itemId: item.itemId,
                  division: sri.division,
                  divisionId: room.divisionForItem(sri)?.divisionId ?? sri.divisionId,
                    quantity: sri.quantity,
                    minCount: minCount,
                  );
            },
            child: const Text(
              'Save Alert Threshold',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  late String? _divisionId = widget.divisionId;

  Future<void> _showMoveDivisionDialog(
    ItemModel item,
    StoreRoomItemModel source,
    StoreRoomModel room,
  ) async {
    final current = room.divisionForItem(source)?.divisionId ?? source.divisionId;
    final targets = room.configuredDivisions.where((division) => division.divisionId != current).toList();
    String? selected;
    final targetId = await openCpmsPage<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateDialog) => CpmsFormPage(
          icon: Icons.drive_file_move_outlined,
          title: Text('Move ${item.itemName}'),
          content: targets.isEmpty
              ? const Text('Add another division to this store room before moving this item.')
              : DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Destination division'),
                  items: [
                    for (final division in targets)
                      DropdownMenuItem(value: division.divisionId, child: Text(division.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (id) => updateDialog(() => selected = id),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(targets.isEmpty ? 'OK' : 'Cancel')),
            if (targets.isNotEmpty)
              FilledButton(
                onPressed: selected == null ? null : () => Navigator.pop(context, selected),
                child: const Text('Move item'),
              ),
          ],
        ),
      ),
    );
    if (targetId == null || !mounted) return;
    final inventory = context.read<InventoryProvider>();
    final moved = await inventory.moveStoreRoomItem(
      storeRoomId: room.storeRoomId,
      source: source,
      targetDivisionId: targetId,
    );
    if (!mounted) return;
    if (moved) setState(() => _divisionId = targetId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(moved ? 'Item moved to the selected division.' : inventory.errorMessage ?? 'Could not move the item.'),
    ));
  }

  void _confirmRemoveItem(
    ItemModel item,
    StoreRoomModel room,
  ) {
    final inventory = context.read<InventoryProvider>();

    openCpmsPage(
      context: context,
      builder: (ctx) => CpmsFormPage(
        title: const Text(
          'Remove from Store Room?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove "${item.itemName}" from "${room.roomName}"? The item will remain safe in your organization catalog.',
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await inventory.removeItemFromStoreRoom(
                storeRoomId: room.storeRoomId,
                itemId: item.itemId,
              );
              if (mounted) {
                if (ok) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(inventory.errorMessage ?? 'Failed to remove item'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove Item',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
    final canUpdate =
        isAdmin || tenant.hasPermission(AppPermissions.storeroomUpdate);
    final canRemoveItem = canUpdate;

    final currentRoom = inventory.storeRooms.firstWhere(
      (r) => r.storeRoomId == widget.storeRoomId,
      orElse: () => StoreRoomModel(
        storeRoomId: widget.storeRoomId,
        tenantId: '',
        roomCode: '',
        roomName: 'Store Room',
        divisions: [],
        items: [],
        isActive: true,
      ),
    );

    final sri = currentRoom.items.firstWhere(
      (it) => it.itemId == widget.itemId &&
          (_divisionId == null ||
              (currentRoom.divisionForItem(it)?.divisionId ?? it.divisionId) == _divisionId),
      orElse: () => StoreRoomItemModel(
        itemId: widget.itemId,
        division: '',
        quantity: 0.0,
        minCount: 0.0,
      ),
    );

    final item = inventory.items.firstWhere(
      (i) => i.itemId == widget.itemId,
      orElse: () => ItemModel(
        itemId: widget.itemId,
        tenantId: currentRoom.tenantId,
        sku: '',
        itemName: widget.itemId,
        itemType: 'FINISHED GOOD',
        measurementUnit: 'UNIT',
        reorderThresholdQuantity: 0,
        totalAvailableStock: sri.quantity,
        isBelowReorderThreshold: false,
        reorderShortfallQuantity: 0,
        isActive: true,
      ),
    );

    final isLowStock = sri.minCount > 0 && sri.quantity <= sri.minCount;
    final temperature = currentRoom.temperatureLabel;

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    final resolvedImageUrl = ApiConstants.resolveImageUrl(item.imageUrl);
    final unit = item.measurementUnit.isNotEmpty ? item.measurementUnit : 'Units';

    final totalOrgStock = item.totalAvailableStock;
    final allocationPercent = totalOrgStock > 0
        ? ((sri.quantity / totalOrgStock) * 100).clamp(0, 100).toStringAsFixed(1)
        : '100.0';

    return Scaffold(
      backgroundColor: AppTheme.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.adminCanvas,
        foregroundColor: AppTheme.adminInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.adminInk, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CpmsPageTitle(
              'Store room item',
              icon: Icons.inventory_2_outlined,
              accent: AppTheme.adminStorage,
            ),
            Text(
              '${currentRoom.roomName} • ${currentRoom.displayDivisionName(sri)}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) {
              if (val == 'edit_qty' && canUpdate) {
                _showEditQuantityDialog(item, sri, currentRoom);
              } else if (val == 'edit_min' && canUpdate) {
                _showSetMinimumCountDialog(item, sri, currentRoom);
              } else if (val == 'move_div' && canUpdate) {
                _showMoveDivisionDialog(item, sri, currentRoom);
              } else if (val == 'view_catalog') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
                );
              } else if (val == 'remove_item' && canRemoveItem) {
                _confirmRemoveItem(item, currentRoom);
              }
            },
            itemBuilder: (ctx) => [
              if (canUpdate)
                const PopupMenuItem(
                  value: 'edit_qty',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Update Quantity'),
                    ],
                  ),
                ),
              if (canUpdate)
                const PopupMenuItem(
                  value: 'edit_min',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 10),
                      Text('Set Minimum Alert'),
                    ],
                  ),
                ),
              if (canUpdate)
                const PopupMenuItem(
                  value: 'move_div',
                  child: Row(
                    children: [
                      Icon(Icons.drive_file_move_outlined, size: 18, color: Colors.black),
                      SizedBox(width: 10),
                      Text('Move Section'),
                    ],
                  ),
                ),
              if (isAdmin) const PopupMenuItem(
                value: 'view_catalog',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black),
                    SizedBox(width: 10),
                    Text('View in Product Catalog'),
                  ],
                ),
              ),
              if (canRemoveItem) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'remove_item',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Remove from Store Room', style: TextStyle(color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.workspaceBorder),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: () async {
          await Future.wait([
            inventory.loadStoreRooms(),
            inventory.loadItems(),
          ]);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 28 : 16,
                vertical: 20,
              ),
              children: [
                // 1. Item Header Overview Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.workspaceBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Photo / Icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.workspaceBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: resolvedImageUrl != null
                              ? Image.network(
                                  resolvedImageUrl,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 32,
                                  color: Color(0xFF94A3B8),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.itemType.replaceAll('_', ' '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '🏛️ ${currentRoom.roomName}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '📍 ${currentRoom.displayDivisionName(sri)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
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

                const SizedBox(height: 16),

                // 2. Alert Status Banner
                if (isLowStock)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Low Stock Alert Triggered',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'The current stock (${sri.quantity.toInt()} $unit) is at or below the minimum alert threshold of ${sri.minCount.toInt()} $unit in ${currentRoom.roomName}. Restocking is recommended.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F1D1D),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (sri.minCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Stock level is healthy (above minimum alert threshold of ${sri.minCount.toInt()} $unit).',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.workspaceBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No minimum alert quantity is set for this item. Set a threshold to receive automated low-stock warnings.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. Main Metrics: Store Room Quantity & Minimum Quantity
                Row(
                  children: [
                    // A. Current Quantity
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.workspaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ITEM QUANTITY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (canUpdate)
                                  InkWell(
                                    onTap: () => _showEditQuantityDialog(
                                        item, sri, currentRoom),
                                    child: const Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sri.quantity.toStringAsFixed(
                                sri.quantity.truncateToDouble() == sri.quantity
                                    ? 0
                                    : 2,
                              ),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              unit,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Stepper Controls
                            if (canUpdate)
                              Row(
                                children: [
                                  InkWell(
                                    onTap: sri.quantity > 0
                                        ? () async {
                                            final newQty =
                                                (sri.quantity - 1).clamp(0.0, double.infinity);
                                            await inventory
                                                .updateStoreRoomItemQuantity(
                                              storeRoomId:
                                                  currentRoom.storeRoomId,
                                              itemId: item.itemId,
                                              quantity: newQty,
                                              minCount: sri.minCount,
                                            );
                                          }
                                        : null,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('− 1',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      final newQty = sri.quantity + 1;
                                      await inventory
                                          .updateStoreRoomItemQuantity(
                                        storeRoomId: currentRoom.storeRoomId,
                                        itemId: item.itemId,
                                        quantity: newQty,
                                        minCount: sri.minCount,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('+ 1',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // B. Minimum Quantity (To Alert)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLowStock
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'MIN QUANTITY',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (canUpdate)
                                  InkWell(
                                    onTap: () => _showSetMinimumCountDialog(
                                        item, sri, currentRoom),
                                    child: const Text(
                                      'Set',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF14532D),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sri.minCount.toStringAsFixed(
                                sri.minCount.truncateToDouble() == sri.minCount
                                    ? 0
                                    : 2,
                              ),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: isLowStock
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF0F172A),
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'Alert threshold',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isLowStock
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  side: const BorderSide(
                                      color: AppTheme.workspaceBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                ),
                                onPressed: canUpdate
                                    ? () => _showSetMinimumCountDialog(
                                        item, sri, currentRoom)
                                    : null,
                                child: const Text(
                                  'Configure Alert',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. Store Room Location & Environment
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.workspaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROOM LOCATION & STORAGE SECTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.warehouse_outlined,
                        label: 'Store Room',
                        value: currentRoom.roomName,
                      ),
                      if (currentRoom.description.isNotEmpty) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildInfoRow(
                          icon: Icons.notes_outlined,
                          label: 'Room Description',
                          value: currentRoom.description,
                        ),
                      ],
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildInfoRow(
                        icon: Icons.grid_view,
                        label: 'Storage Section / Division',
                        value: currentRoom.displayDivisionName(sri),
                        trailing: canUpdate
                            ? TextButton(
                                onPressed: () => _showMoveDivisionDialog(
                                    item, sri, currentRoom),
                                child: const Text(
                                  'Move Section',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (temperature != null) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildInfoRow(
                          icon: Icons.thermostat_outlined,
                          label: 'Temperature',
                          value: temperature,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5. Global Organization Allocation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.workspaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL ORGANIZATION INVENTORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Across All Rooms',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${totalOrgStock.toStringAsFixed(totalOrgStock.truncateToDouble() == totalOrgStock ? 0 : 2)} $unit',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Share in This Room',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$allocationPercent%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: AppTheme.workspaceBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemDetailScreen(item: item),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text(
                            'View Full Catalog Profile',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const AppFooter(topPadding: 24, bottomPadding: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
