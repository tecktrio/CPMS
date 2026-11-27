import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/department_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/data_export_service.dart';
import '../../widgets/cpms_search_bar.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/export_options_dialog.dart';
import 'production_status_dialogs.dart';

enum ProductionQueue {
  inspection('Inspection queue', 'No orders are awaiting inspection'),
  packing('Packing queue', 'No orders are ready to pack'),
  dispatch('Dispatch queue', 'No orders are ready to dispatch');

  const ProductionQueue(this.title, this.emptyMessage);

  final String title;
  final String emptyMessage;

  bool matches(PurchaseOrderModel order) =>
      const {'CONFIRMED', 'IN_PRODUCTION'}.contains(
        order.status.trim().toUpperCase(),
      ) &&
      order.items.any(matchesLine);

  bool matchesLine(PurchaseOrderItemModel item) => switch (this) {
        inspection => item.completedCartons > 0 && !item.qcPassed,
        packing => item.qcPassed && item.packedCartons < item.completedCartons,
        dispatch => item.shippedCartons < item.packedCartons,
      };
}

class ProductionHubScreen extends StatefulWidget {
  const ProductionHubScreen({super.key, this.queue});

  final ProductionQueue? queue;

  @override
  State<ProductionHubScreen> createState() => _ProductionHubScreenState();
}

class _ProductionHubScreenState extends State<ProductionHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  bool _showOrderHistory = false;
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
      context.read<ProductionProvider>().loadAllAssignments(),
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

    final queue = _showOrderHistory ? null : widget.queue;
    final nonDraftOrders = poProvider.purchaseOrders.where((po) {
      if (po.tenantId != tenant.activeTenant?.tenantId) return false;
      final status = po.status.trim().toUpperCase();
      if (queue != null) return queue.matches(po);
      if (isSupervisor || widget.queue != null) return po.wasConfirmed;
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
        title: Text(
          widget.queue?.title ?? (isSupervisor ? 'Production lines' : 'Production Hub'),
          style: const TextStyle(
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
                        Text(
                          queue?.emptyMessage ?? 'No production orders found',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (widget.queue == null) const SizedBox(height: 4),
                        if (widget.queue == null) const Text(
                          'Purchase orders appear here after confirmation.',
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
                        queue: queue,
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
        if (widget.queue != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show order history'),
            value: _showOrderHistory,
            onChanged: (value) => setState(() {
              _showOrderHistory = value;
              _statusFilter = 'ALL';
            }),
          ),
        if (widget.queue == null || _showOrderHistory) ...[
          const SizedBox(height: 12),

          // Status pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('ALL', 'All orders'),
                _buildFilterPill('CONFIRMED', 'Confirmed'),
                _buildFilterPill('IN_PRODUCTION', 'In Production'),
                _buildFilterPill('SHIPPED', 'Shipped'),
                _buildFilterPill('DELIVERED', 'Delivered'),
              ],
            ),
          ),
        ],
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
    required ProductionQueue? queue,
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
    final visibleItems = queue == null
        ? po.items
        : po.items.where(queue.matchesLine).toList();
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

                    // Export Full Production, QA, Supervisors & Users Report Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final prodProv = context.read<ProductionProvider>();
                        final deptProv = context.read<DepartmentProvider>();
                        final tenantProv = context.read<TenantProvider>();

                        await Future.wait([
                          prodProv.loadAssignmentsByPo(po.poId),
                          prodProv.loadQcReportsByPo(po.poId),
                        ]);

                        if (!mounted) return;
                        final assignments = prodProv.poAssignments
                            .where((a) => a.poId == po.poId)
                            .toList();
                        final qcReports = prodProv.poQcReports
                            .where((q) => q.poId == po.poId)
                            .toList();
                        final safePo = po.poNumber
                            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

                        await ExportOptionsDialog.show(
                          context,
                          title: 'Export PO #${po.poNumber} Production Report',
                          subtitle:
                              'Includes line items, supervisor assignments, QA reports, export/packing details, and all involved staff.',
                          baseFileName: 'CPMS-Production-PO-$safePo',
                          onGeneratePdf: () =>
                              DataExportService.generatePoProductionPdf(
                            po: po,
                            assignments: assignments,
                            qcReports: qcReports,
                            tenantUsers: deptProv.tenantUsers,
                            departments: tenantProv.tenantDepartments,
                            tenantName: tenantProv.activeTenant?.companyName,
                          ),
                          onGenerateCsv: () async =>
                              DataExportService.generatePoProductionCsvBytes(
                            po: po,
                            assignments: assignments,
                            qcReports: qcReports,
                            tenantUsers: deptProv.tenantUsers,
                            departments: tenantProv.tenantDepartments,
                          ),
                        );
                      },
                      icon: const Icon(Icons.file_download_outlined,
                          size: 14, color: Color(0xFF0F172A)),
                      label: const Text(
                        'Export',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

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
                        'LINE ITEMS (${visibleItems.length})',
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
            LayoutBuilder(
              builder: (context, constraints) {
                const minTableWidth = 640.0;
                final needsHorizontalScroll = constraints.maxWidth < minTableWidth;

                final tableContent = SizedBox(
                  width: needsHorizontalScroll ? minTableWidth : constraints.maxWidth,
                  child: Column(
                    children: [
                      // Table Column Header Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(color: Color(0xFFF1F5F9)),
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 38,
                              child: Text(
                                'SL.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'ITEM DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const SizedBox(
                              width: 95,
                              child: Text(
                                'PKT / CTN BOX',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const SizedBox(
                              width: 90,
                              child: Text(
                                'TOTAL CTNS',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (canAssignTask || (!isSupervisor && !isPacker && !isQc && !isExport && (canDoQc || canUpdatePacking || canUpdateShipping))) ...[
                              const SizedBox(width: 14),
                              SizedBox(
                                width: canAssignTask ? 164 : 40,
                                child: const Text(
                                  'ACTION',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Line Items Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final item = visibleItems[idx];
                          final unitSubtitle = item.specification.isNotEmpty
                              ? item.specification
                              : (item.unit.isNotEmpty ? item.unit.toUpperCase() : '454 GRAM');

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Index Number Badge
                                SizedBox(
                                  width: 38,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
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
                                  ),
                                ),

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

                            // Assigned Supervisors Summary Row
                            Builder(
                              builder: (context) {
                                final itemAssignments = context
                                    .watch<ProductionProvider>()
                                    .assignmentsForItem(po.poId, item.itemId);
                                if (itemAssignments.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final totalAssigned = itemAssignments.fold<int>(
                                    0, (s, a) => s + a.assignedCartons);
                                final rem = item.cartons - totalAssigned;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...itemAssignments.map((a) {
                                        final name = a.supervisorName.isNotEmpty
                                            ? a.supervisorName
                                            : 'Supervisor';
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            border: Border.all(
                                                color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.person_outline,
                                                size: 12,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$name: ${a.completedCartons}/${a.assignedCartons} ctns${a.targetDate != null ? ' • ${_dateFormat.format(a.targetDate!)}' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1E40AF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (rem > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            border: Border.all(
                                                color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            'Unassigned: $rem ctns',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFB45309),
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
                      ),
                                const SizedBox(width: 14),

                                // No of Pkt in 1 Carton Box Column
                                SizedBox(
                                  width: 95,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '${item.packetPerCarton}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'pkts / ctn',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Total Cartons Column
                                SizedBox(
                                  width: 90,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${item.cartons} ctns',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.packetPerCarton * item.cartons} pkts',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions (Assign Task + menu)
                                if (canAssignTask || (!isSupervisor && !isPacker && !isQc && !isExport && (canDoQc || canUpdatePacking || canUpdateShipping))) ...[
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: canAssignTask ? 164 : 40,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (canAssignTask)
                                          Builder(
                                            builder: (context) {
                                              final existing = context
                                                  .watch<ProductionProvider>()
                                                  .assignmentsForItem(
                                                      po.poId, item.itemId);
                                              final label = existing.isNotEmpty
                                                  ? 'Manage'
                                                  : 'Assign Task';
                                              return OutlinedButton.icon(
                                                onPressed: () =>
                                                    ProductionStatusDialogs
                                                        .showAssignSupervisorsDialog(
                                                  context,
                                                  po,
                                                  item,
                                                  onUpdated: () async {
                                                    await context
                                                        .read<
                                                            PurchaseOrderProvider>()
                                                        .loadPurchaseOrders();
                                                    if (context.mounted) {
                                                      await context
                                                          .read<
                                                              ProductionProvider>()
                                                          .loadAllAssignments();
                                                    }
                                                  },
                                                ),
                                                icon: Icon(
                                                  existing.isNotEmpty
                                                      ? Icons.manage_accounts_outlined
                                                      : Icons.person_add_alt_1_outlined,
                                                  size: 14,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                label: Text(
                                                  label,
                                                  style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                      color: Color(0xFFCBD5E1)),
                                                  backgroundColor:
                                                      const Color(0xFFF8FAFC),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6)),
                                                ),
                                              );
                                            },
                                          ),
                                        if (!isSupervisor && !isPacker && !isQc && !isExport && (canDoQc || canUpdatePacking || canUpdateShipping)) ...[
                                          const SizedBox(width: 4),
                                          PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

                if (needsHorizontalScroll) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tableContent,
                  );
                }
                return tableContent;
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
