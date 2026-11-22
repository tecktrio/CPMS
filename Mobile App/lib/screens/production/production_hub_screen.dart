import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/department_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/cpms_search_bar.dart';
import '../../widgets/app_footer.dart';
import 'production_status_dialogs.dart';

class ProductionHubScreen extends StatefulWidget {
  const ProductionHubScreen({super.key});

  @override
  State<ProductionHubScreen> createState() => _ProductionHubScreenState();
}

class _ProductionHubScreenState extends State<ProductionHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  final Set<String> _collapsedPoIds = {};
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
      context.read<DepartmentProvider>().loadTenantUsers(),
      context.read<TenantProvider>().loadTenantDepartments(),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFFF0FDF4);
      case 'IN_PRODUCTION':
        return const Color(0xFFFFFBEB);
      case 'SHIPPED':
        return const Color(0xFFEFF6FF);
      case 'DELIVERED':
        return const Color(0xFFECFDF5);
      case 'CANCELLED':
        return const Color(0xFFFEF2F2);
      case 'DRAFT':
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  Color _getStatusBorder(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFFBBF7D0);
      case 'IN_PRODUCTION':
        return const Color(0xFFFDE68A);
      case 'SHIPPED':
        return const Color(0xFFBFDBFE);
      case 'DELIVERED':
        return const Color(0xFFA7F3D0);
      case 'CANCELLED':
        return const Color(0xFFFECACA);
      case 'DRAFT':
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFF16A34A);
      case 'IN_PRODUCTION':
        return const Color(0xFFD97706);
      case 'SHIPPED':
        return const Color(0xFF2563EB);
      case 'DELIVERED':
        return const Color(0xFF059669);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      case 'DRAFT':
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildStageBadge({
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final poProvider = context.watch<PurchaseOrderProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canManageProd = isAdmin ||
        tenant.hasPermission(AppPermissions.productionCreate) ||
        tenant.hasPermission(AppPermissions.productionUpdate);
    final isSupervisor = tenant.isUserInSupervisorDepartment;
    final isPacker = tenant.isUserInPackerDepartment;
    final isQc = tenant.isUserInQcDepartment;
    final isExport = tenant.isUserInExportDepartment;
    final canAssignTask = !isSupervisor && !isPacker && !isQc && !isExport && canManageProd;
    final canDoQc = isAdmin || tenant.hasPermission(AppPermissions.qcCreate);
    final canUpdatePacking =
        isAdmin || tenant.hasPermission(AppPermissions.packingUpdate);
    final canUpdateShipping =
        isAdmin || tenant.hasPermission(AppPermissions.exportUpdate);

    // Filter POs: strictly NON-DRAFT purchase orders
    final nonDraftOrders = poProvider.purchaseOrders.where((po) {
      final status = po.status.trim().toUpperCase();
      return status != 'DRAFT';
    }).where((po) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return po.poNumber.toLowerCase().contains(q) ||
          po.customerName.toLowerCase().contains(q);
    }).where((po) {
      if (_statusFilter == 'ALL') return true;
      return po.status.toUpperCase() == _statusFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Production Hub',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: RefreshIndicator(
            color: const Color(0xFF0F172A),
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // Search and Filter Bar
                _buildOrdersFilterBar(),
                const SizedBox(height: 18),

                if (poProvider.isLoading && nonDraftOrders.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF0F172A)),
                    ),
                  )
                else if (nonDraftOrders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No active production orders found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Purchase Orders will automatically appear here once confirmed or moved to production stage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...nonDraftOrders.map((po) => _buildProductionOrderCard(
                        po,
                        canManageProd: canManageProd,
                        canAssignTask: canAssignTask,
                        isSupervisor: isSupervisor,
                        isPacker: isPacker,
                        isQc: isQc,
                        isExport: isExport,
                        canDoQc: canDoQc,
                        canUpdatePacking: canUpdatePacking,
                        canUpdateShipping: canUpdateShipping,
                      )),
                const AppFooter(topPadding: 16, bottomPadding: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        CpmsSearchBar(
          controller: _searchController,
          hintText: 'Search by PO number or customer...',
          onChanged: (val) {
            setState(() => _searchQuery = val.trim());
          },
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: 12),

        // Status pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterPill('ALL', 'All Active'),
              _buildFilterPill('CONFIRMED', 'Confirmed'),
              _buildFilterPill('IN_PRODUCTION', 'In Production'),
              _buildFilterPill('SHIPPED', 'Shipped'),
              _buildFilterPill('DELIVERED', 'Delivered'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String code, String label) {
    final isSelected = _statusFilter == code;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _statusFilter = code),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionOrderCard(
    PurchaseOrderModel po, {
    required bool canManageProd,
    required bool canAssignTask,
    required bool isSupervisor,
    required bool isPacker,
    required bool isQc,
    required bool isExport,
    required bool canDoQc,
    required bool canUpdatePacking,
    required bool canUpdateShipping,
  }) {
    final isCollapsed = _collapsedPoIds.contains(po.poId);
    final totalCompleted =
        po.items.fold<int>(0, (sum, i) => sum + i.completedCartons);
    final totalPacked =
        po.items.fold<int>(0, (sum, i) => sum + i.packedCartons);
    final totalShipped =
        po.items.fold<int>(0, (sum, i) => sum + i.shippedCartons);
    final totalCartons = po.totalCartons > 0 ? po.totalCartons : 1;
    final prodProgress = (totalCompleted / totalCartons).clamp(0.0, 1.0);
    final packingProgress = (totalPacked / totalCartons).clamp(0.0, 1.0);
    final shippingProgress = (totalShipped / totalCartons).clamp(0.0, 1.0);
    final totalQcPassed = po.items.where((i) => i.qcPassed).length;
    final totalItems = po.items.isNotEmpty ? po.items.length : 1;
    final qcProgress = (totalQcPassed / totalItems).clamp(0.0, 1.0);

    String? daysLeftStr;
    Color daysLeftBg = const Color(0xFFFEF3C7);
    Color daysLeftBorder = const Color(0xFFFDE68A);
    Color daysLeftText = const Color(0xFFB45309);

    if (po.expectedShippingDate != null) {
      final now = DateTime.now();
      final target = DateTime(po.expectedShippingDate!.year, po.expectedShippingDate!.month, po.expectedShippingDate!.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = target.difference(today).inDays;
      if (diff > 0) {
        daysLeftStr = '$diff days left';
      } else if (diff == 0) {
        daysLeftStr = 'Due today';
      } else {
        daysLeftStr = '${-diff} days overdue';
        daysLeftBg = const Color(0xFFFEF2F2);
        daysLeftBorder = const Color(0xFFFECACA);
        daysLeftText = const Color(0xFFDC2626);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Order Header Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PO Title + Status Badge
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'PO #${po.poNumber}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: canManageProd
                                ? () => ProductionStatusDialogs
                                    .showStatusChangeModal(
                                      context,
                                      po,
                                      onUpdated: () => context
                                          .read<PurchaseOrderProvider>()
                                          .loadPurchaseOrders(),
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getStatusBg(po.status),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusBorder(po.status),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    po.status
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _getStatusTextColor(po.status),
                                    ),
                                  ),
                                  if (canManageProd) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 14,
                                      color: _getStatusTextColor(po.status),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Update Status Button
                    if (canManageProd)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            ProductionStatusDialogs.showStatusChangeModal(
                          context,
                          po,
                          onUpdated: () => context
                              .read<PurchaseOrderProvider>()
                              .loadPurchaseOrders(),
                        ),
                        icon: const Icon(Icons.sync_alt,
                            size: 14, color: Color(0xFF0F172A)),
                        label: const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Customer Line
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    children: [
                      const TextSpan(text: 'Customer: '),
                      TextSpan(
                        text: po.customerName.isNotEmpty ? po.customerName : 'kdm',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Dates Line with Countdown Pill
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Ordered: ${_dateFormat.format(po.poDate)}',
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    if (po.expectedShippingDate != null) ...[
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      const SizedBox(width: 8),
                      const Icon(Icons.local_shipping_outlined,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          children: [
                            const TextSpan(text: 'Shipping: '),
                            TextSpan(
                              text: _dateFormat.format(po.expectedShippingDate!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (daysLeftStr != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: daysLeftBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: daysLeftBorder),
                          ),
                          child: Text(
                            daysLeftStr,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: daysLeftText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: isPacker
                        ? packingProgress
                        : isQc
                            ? qcProgress
                            : isExport
                                ? shippingProgress
                                : prodProgress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPacker
                          ? const Color(0xFF2563EB)
                          : isQc
                              ? const Color(0xFF0F766E)
                              : isExport
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isPacker)
                      Text(
                        'Packing: $totalPacked / ${po.totalCartons} ctns (${(packingProgress * 100).toInt()}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      )
                    else if (isQc)
                      Text(
                        'QC Inspection: $totalQcPassed / ${po.items.length} items passed (${(qcProgress * 100).toInt()}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      )
                    else if (isExport)
                      Text(
                        'Export / Shipped: $totalShipped / ${po.totalCartons} ctns (${(shippingProgress * 100).toInt()}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      )
                    else ...[
                      Text(
                        'Production: $totalCompleted / ${po.totalCartons} ctns (${(prodProgress * 100).toInt()}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      if (!isSupervisor)
                        Text(
                          'Packed: $totalPacked | Shipped: $totalShipped',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Collapsible Line Items Header
          InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedPoIds.remove(po.poId);
                } else {
                  _collapsedPoIds.add(po.poId);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFFAFAFA),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_list_bulleted,
                          size: 16, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      Text(
                        'LINE ITEMS (${po.items.length})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Line Items List
          if (!isCollapsed)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: po.items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = po.items[idx];
                final unitSubtitle = item.specification.isNotEmpty
                    ? item.specification
                    : (item.unit.isNotEmpty ? item.unit.toUpperCase() : '454 GRAM');

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Index Number Badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Item Details & Badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              unitSubtitle,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Stage Badges Row / Supervisor Stepper View
                            if (isSupervisor)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Status Badge: PRODUCED / IN PRODUCTION / PENDING
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.completedCartons >= item.cartons
                                          ? const Color(0xFFF0FDF4)
                                          : item.completedCartons > 0
                                              ? const Color(0xFFFFFBEB)
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: item.completedCartons >= item.cartons
                                            ? const Color(0xFFBBF7D0)
                                            : item.completedCartons > 0
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.completedCartons >= item.cartons
                                              ? Icons.check_circle
                                              : Icons.handyman_outlined,
                                          size: 13,
                                          color: item.completedCartons >= item.cartons
                                              ? const Color(0xFF16A34A)
                                              : item.completedCartons > 0
                                                  ? const Color(0xFFD97706)
                                                  : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.completedCartons >= item.cartons
                                              ? 'PRODUCED'
                                              : item.completedCartons > 0
                                                  ? 'IN PRODUCTION'
                                                  : 'PENDING',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item.completedCartons >= item.cartons
                                                ? const Color(0xFF16A34A)
                                                : item.completedCartons > 0
                                                    ? const Color(0xFFB45309)
                                                    : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Produced Stepper (+ and - buttons)
                                  Container(
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                                          onTap: item.completedCartons > 0
                                              ? () => _updateProducedCount(po, item, item.completedCartons - 1)
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            child: Text(
                                              '−',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: item.completedCartons > 0
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                        InkWell(
                                          onTap: () => _showEditProducedDialog(po, item),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '${item.completedCartons} / ${item.cartons} ctns',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                                          onTap: item.completedCartons < item.cartons
                                              ? () => _updateProducedCount(po, item, item.completedCartons + 1)
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            child: Text(
                                              '+',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: item.completedCartons < item.cartons
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (isPacker)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Status Badge: PACKED / IN PACKING / PENDING
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.packedCartons >= item.cartons
                                          ? const Color(0xFFF0FDF4)
                                          : item.packedCartons > 0
                                              ? const Color(0xFFEFF6FF)
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: item.packedCartons >= item.cartons
                                            ? const Color(0xFFBBF7D0)
                                            : item.packedCartons > 0
                                                ? const Color(0xFFBFDBFE)
                                                : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.packedCartons >= item.cartons
                                              ? Icons.check_circle
                                              : Icons.inventory_2_outlined,
                                          size: 13,
                                          color: item.packedCartons >= item.cartons
                                              ? const Color(0xFF16A34A)
                                              : item.packedCartons > 0
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.packedCartons >= item.cartons
                                              ? 'PACKED'
                                              : item.packedCartons > 0
                                                  ? 'IN PACKING'
                                                  : 'PENDING',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item.packedCartons >= item.cartons
                                                ? const Color(0xFF16A34A)
                                                : item.packedCartons > 0
                                                    ? const Color(0xFF2563EB)
                                                    : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Packed Stepper (+ and - buttons)
                                  Container(
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                                          onTap: item.packedCartons > 0
                                              ? () => _updatePackedCount(po, item, item.packedCartons - 1)
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            child: Text(
                                              '−',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: item.packedCartons > 0
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                        InkWell(
                                          onTap: () => _showEditPackedDialog(po, item),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '${item.packedCartons} / ${item.cartons} ctns',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                                          onTap: item.packedCartons < item.cartons
                                              ? () => _updatePackedCount(po, item, item.packedCartons + 1)
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            child: Text(
                                              '+',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: item.packedCartons < item.cartons
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (isQc)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // QC Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.qcPassed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: item.qcPassed ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.qcPassed ? Icons.check_circle : Icons.pending_actions_outlined,
                                          size: 13,
                                          color: item.qcPassed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.qcPassed ? 'QC: PASSED' : 'QC: PENDING',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item.qcPassed ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Update QC Button
                                  InkWell(
                                    onTap: () => ProductionStatusDialogs.showQcInspectionDialog(
                                      context,
                                      po,
                                      item,
                                      onUpdated: () => context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      height: 30,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: item.qcPassed ? const Color(0xFFF8FAFC) : const Color(0xFF0F766E),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: item.qcPassed ? const Color(0xFFCBD5E1) : const Color(0xFF0F766E),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.qcPassed ? Icons.edit_outlined : Icons.verified_outlined,
                                            size: 13,
                                            color: item.qcPassed ? const Color(0xFF334155) : Colors.white,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            item.qcPassed ? 'Edit QC' : 'Inspect & Approve',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: item.qcPassed ? const Color(0xFF334155) : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (isExport)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Export / Shipping Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.shippedCartons >= item.cartons
                                          ? const Color(0xFFF0FDF4)
                                          : item.shippedCartons > 0
                                              ? const Color(0xFFEEF2FF)
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: item.shippedCartons >= item.cartons
                                            ? const Color(0xFFBBF7D0)
                                            : item.shippedCartons > 0
                                                ? const Color(0xFFC7D2FE)
                                                : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.shippedCartons >= item.cartons
                                              ? Icons.check_circle
                                              : Icons.local_shipping_outlined,
                                          size: 13,
                                          color: item.shippedCartons >= item.cartons
                                              ? const Color(0xFF16A34A)
                                              : item.shippedCartons > 0
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item.shippedCartons >= item.cartons
                                              ? 'SHIPPED'
                                              : item.shippedCartons > 0
                                                  ? 'IN DISPATCH'
                                                  : 'PENDING',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: item.shippedCartons >= item.cartons
                                                ? const Color(0xFF16A34A)
                                                : item.shippedCartons > 0
                                                    ? const Color(0xFF4F46E5)
                                                    : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Export Stepper (+ and - buttons)
                                  Container(
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                                          onTap: item.shippedCartons > 0
                                              ? () => _updateShippedCount(po, item, item.shippedCartons - 1)
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            child: Text(
                                              '−',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: item.shippedCartons > 0
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                        InkWell(
                                          onTap: () => _showEditShippedDialog(po, item),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '${item.shippedCartons} / ${item.cartons} ctns',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                                          onTap: item.shippedCartons < item.cartons
                                              ? () => _updateShippedCount(po, item, item.shippedCartons + 1)
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            child: Text(
                                              '+',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: item.shippedCartons < item.cartons
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildStageBadge(
                                      label: 'Produced: ${item.completedCartons}/${item.cartons}',
                                      color: item.completedCartons >= item.cartons
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFB45309),
                                      bgColor: item.completedCartons >= item.cartons
                                          ? const Color(0xFFF0FDF4)
                                          : const Color(0xFFFFFBEB),
                                      borderColor: item.completedCartons >= item.cartons
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFFDE68A),
                                      icon: Icons.handyman_outlined,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStageBadge(
                                      label: 'QC: ${item.qcPassed ? 'PASSED' : 'PENDING'}',
                                      color: item.qcPassed
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFF64748B),
                                      bgColor: item.qcPassed
                                          ? const Color(0xFFF0FDFA)
                                          : const Color(0xFFF8FAFC),
                                      borderColor: item.qcPassed
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFE2E8F0),
                                      icon: Icons.check_circle_outline,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStageBadge(
                                      label: 'Packed: ${item.packedCartons}/${item.cartons}',
                                      color: item.packedCartons >= item.cartons
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B),
                                      bgColor: item.packedCartons >= item.cartons
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF8FAFC),
                                      borderColor: item.packedCartons >= item.cartons
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFFE2E8F0),
                                      icon: Icons.inventory_2_outlined,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStageBadge(
                                      label: 'Shipped: ${item.shippedCartons}/${item.cartons}',
                                      color: item.shippedCartons >= item.cartons
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B),
                                      bgColor: item.shippedCartons >= item.cartons
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF8FAFC),
                                      borderColor: item.shippedCartons >= item.cartons
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFFE2E8F0),
                                      icon: Icons.local_shipping_outlined,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Quantity + Assign Task Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.cartons} ctns',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${item.packetPerCarton * item.cartons} pkts',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Assign Task Button (hidden for Supervisor, Packer, QC, Export roles)
                      if (canAssignTask)
                        OutlinedButton.icon(
                          onPressed: () => ProductionStatusDialogs
                              .showAssignSupervisorsDialog(
                            context,
                            po,
                            item,
                            onUpdated: () => context
                                .read<PurchaseOrderProvider>()
                                .loadPurchaseOrders(),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_outlined, size: 14, color: Color(0xFF0F172A)),
                          label: const Text('Assign Task', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            backgroundColor: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),

                      if (!isSupervisor && !isPacker && !isQc && !isExport && (canDoQc || canUpdatePacking || canUpdateShipping)) ...[
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                          onSelected: (val) {
                            if (val == 'qc') {
                              ProductionStatusDialogs.showQcInspectionDialog(
                                context, po, item, onUpdated: () => context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
                              );
                            } else if (val == 'pack') {
                              ProductionStatusDialogs.showPackingDialog(
                                context, po, item, onUpdated: () => context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
                              );
                            } else if (val == 'ship') {
                              ProductionStatusDialogs.showShippingDialog(
                                context, po, item, onUpdated: () => context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (canDoQc)
                              const PopupMenuItem(value: 'qc', child: Text('QC Inspect', style: TextStyle(fontSize: 13))),
                            if (canUpdatePacking)
                              const PopupMenuItem(value: 'pack', child: Text('Pack Line Item', style: TextStyle(fontSize: 13))),
                            if (canUpdateShipping)
                              const PopupMenuItem(value: 'ship', child: Text('Ship Line Item', style: TextStyle(fontSize: 13))),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _updateProducedCount(
    PurchaseOrderModel po,
    PurchaseOrderItemModel item,
    int newCount,
  ) async {
    final clamped = newCount.clamp(0, item.cartons);
    if (clamped == item.completedCartons) return;

    final poProv = context.read<PurchaseOrderProvider>();
    final success = await poProv.updateItemProduction(
      poId: po.poId,
      itemId: item.itemId,
      completedCartons: clamped,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(poProv.errorMessage ?? 'Failed to update produced cartons.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditProducedDialog(
    PurchaseOrderModel po,
    PurchaseOrderItemModel item,
  ) {
    final controller = TextEditingController(text: '${item.completedCartons}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Update Produced: ${item.itemName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total required: ${item.cartons} cartons',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Produced Cartons',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? item.completedCartons;
              Navigator.pop(ctx);
              _updateProducedCount(po, item, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePackedCount(
    PurchaseOrderModel po,
    PurchaseOrderItemModel item,
    int newCount,
  ) async {
    final clamped = newCount.clamp(0, item.cartons);
    if (clamped == item.packedCartons) return;

    final poProv = context.read<PurchaseOrderProvider>();
    final success = await poProv.updateItemPacking(
      poId: po.poId,
      itemId: item.itemId,
      packedCartons: clamped,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(poProv.errorMessage ?? 'Failed to update packed cartons.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditPackedDialog(
    PurchaseOrderModel po,
    PurchaseOrderItemModel item,
  ) {
    final controller = TextEditingController(text: '${item.packedCartons}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Update Packed: ${item.itemName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total required: ${item.cartons} cartons | Currently packed: ${item.packedCartons}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Packed Cartons',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? item.packedCartons;
              Navigator.pop(ctx);
              _updatePackedCount(po, item, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateShippedCount(
    PurchaseOrderModel po,
    PurchaseOrderItemModel item,
    int newCount,
  ) async {
    final clamped = newCount.clamp(0, item.cartons);
    if (clamped == item.shippedCartons) return;

    final poProv = context.read<PurchaseOrderProvider>();
    final success = await poProv.updateItemShipping(
      poId: po.poId,
      itemId: item.itemId,
      shippedCartons: clamped,
      itemStatus: clamped >= item.cartons ? 'SHIPPED' : (clamped > 0 ? 'SHIPPING' : 'PENDING'),
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(poProv.errorMessage ?? 'Failed to update shipped cartons.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditShippedDialog(
    PurchaseOrderModel po,
    PurchaseOrderItemModel item,
  ) {
    final controller = TextEditingController(text: '${item.shippedCartons}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Update Shipped: ${item.itemName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total required: ${item.cartons} cartons | Currently shipped: ${item.shippedCartons}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Shipped Cartons',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? item.shippedCartons;
              Navigator.pop(ctx);
              _updateShippedCount(po, item, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
