import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../models/production_assignment_model.dart';
import '../../providers/department_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import 'production_status_dialogs.dart';

class ProductionHubScreen extends StatefulWidget {
  const ProductionHubScreen({super.key});

  @override
  State<ProductionHubScreen> createState() => _ProductionHubScreenState();
}

class _ProductionHubScreenState extends State<ProductionHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  final Set<String> _collapsedPoIds = {};
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<ProductionProvider>().loadMyAssignments(),
      context.read<PurchaseOrderProvider>().loadPurchaseOrders(),
      context.read<DepartmentProvider>().loadTenantUsers(),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFFECFDF5);
      case 'IN_PRODUCTION':
        return const Color(0xFFFEF3C7);
      case 'SHIPPED':
        return const Color(0xFFEFF6FF);
      case 'DELIVERED':
        return const Color(0xFFF0FDFA);
      case 'CANCELLED':
        return const Color(0xFFFEF2F2);
      case 'DRAFT':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFF047857);
      case 'IN_PRODUCTION':
        return const Color(0xFFB45309);
      case 'SHIPPED':
        return const Color(0xFF1D4ED8);
      case 'DELIVERED':
        return const Color(0xFF0F766E);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      case 'DRAFT':
      default:
        return const Color(0xFF475569);
    }
  }

  void _showProgressDialog(
      BuildContext context, ProductionAssignmentModel assignment) {
    final controller = TextEditingController(
      text: assignment.completedCartons.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Update Progress: ${assignment.itemName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PO: ${assignment.poNumber}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Assigned to you: ${assignment.assignedCartons} cartons',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Completed Cartons:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0 to ${assignment.assignedCartons}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14532D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val == null || val < 0 || val > assignment.assignedCartons) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a valid count between 0 and ${assignment.assignedCartons}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              final ok = await context
                  .read<ProductionProvider>()
                  .updateProgress(
                    assignmentId: assignment.assignmentId,
                    completedCartons: val,
                  );

              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Production progress updated successfully!'),
                    backgroundColor: Color(0xFF14532D),
                  ),
                );
                await context.read<PurchaseOrderProvider>().loadPurchaseOrders();
              }
            },
            child: const Text('Save Progress'),
          ),
        ],
      ),
    );
  }

  Widget _buildStageBadge({
    required String label,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final prod = context.watch<ProductionProvider>();
    final poProvider = context.watch<PurchaseOrderProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canManageProd = isAdmin ||
        tenant.hasPermission(AppPermissions.productionCreate) ||
        tenant.hasPermission(AppPermissions.productionUpdate);
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
        title: const Text(
          'Production Hub',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF14532D),
                labelColor: const Color(0xFF14532D),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.precision_manufacturing_outlined,
                            size: 16),
                        const SizedBox(width: 6),
                        const Text('Active Orders'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${nonDraftOrders.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_ind_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text('My Line Tasks'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${prod.myAssignments.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ],
          ),
        ),
      ),
    ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: ACTIVE PRODUCTION ORDERS (NON-DRAFT)
              RefreshIndicator(
                color: const Color(0xFF14532D),
                onRefresh: _loadData,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    // Search and Filter Bar
                    _buildOrdersFilterBar(),
                    const SizedBox(height: 14),

                    if (poProvider.isLoading && nonDraftOrders.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: Color(0xFF14532D)),
                        ),
                      )
                    else if (nonDraftOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                            canDoQc: canDoQc,
                            canUpdatePacking: canUpdatePacking,
                            canUpdateShipping: canUpdateShipping,
                          )),
                  ],
                ),
              ),

              // TAB 2: MY LINE TASKS
              RefreshIndicator(
                color: const Color(0xFF14532D),
                onRefresh: _loadData,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    if (prod.isLoading && prod.myAssignments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: Color(0xFF14532D)),
                        ),
                      )
                    else if (prod.myAssignments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No lines assigned to you',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'When a production manager assigns tasks to your supervisor account, they will display here.',
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
                      ...prod.myAssignments.map((a) {
                        final pct = a.assignedCartons > 0
                            ? (a.completedCartons / a.assignedCartons)
                                .clamp(0.0, 1.0)
                            : 0.0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _showProgressDialog(context, a),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          a.itemName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: a.status == 'COMPLETED'
                                              ? const Color(0xFFF0FDF4)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: a.status == 'COMPLETED'
                                                ? const Color(0xFFBBF7D0)
                                                : const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: Text(
                                          a.status,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: a.status == 'COMPLETED'
                                                ? const Color(0xFF15803D)
                                                : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'PO #${a.poNumber} • ${a.completedCartons} of ${a.assignedCartons} Cartons Done',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 7,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        a.status == 'COMPLETED'
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF14532D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: const [
                                      Text(
                                        'Tap to log progress →',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF14532D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by PO number or customer...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
          ),
        ),
        const SizedBox(height: 10),

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
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _statusFilter = code),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF14532D) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF14532D)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionOrderCard(
    PurchaseOrderModel po, {
    required bool canManageProd,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PO Number & Customer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'PO #${po.poNumber}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getStatusBg(po.status),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getStatusTextColor(po.status)
                                          .withValues(alpha: 0.3),
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
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: _getStatusTextColor(po.status),
                                        ),
                                      ),
                                      if (canManageProd) ...[
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.arrow_drop_down,
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
                          const SizedBox(height: 3),
                          Text(
                            po.customerName.isNotEmpty
                                ? po.customerName
                                : 'Default Customer',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Update Status Quick Button
                    if (canManageProd)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
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
                            size: 13, color: Color(0xFF0F172A)),
                        label: const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Order Metadata Row
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Ordered: ${_dateFormat.format(po.poDate)}',
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    if (po.expectedShippingDate != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.local_shipping_outlined,
                          size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        'Target Ship: ${_dateFormat.format(po.expectedShippingDate!)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Fulfillment Progress Overview Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: prodProgress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF14532D)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Production: $totalCompleted / ${po.totalCartons} ctns (${(prodProgress * 100).toInt()}%)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    Text(
                      'Packed: $totalPacked | Shipped: $totalShipped',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Section Toggle: Line Items
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFAFAFA),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.view_list_rounded,
                          size: 16, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        'Line Items (${po.items.length})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isCollapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 20,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Line Items Listing with Status Badges and Action Controls
          if (!isCollapsed)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: po.items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final item = po.items[idx];
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Name & Quantities
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                if (item.specification.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    item.specification,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.cartons} ctns',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${item.totalPackets} pkts',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Status Stage Badges Row
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStageBadge(
                                label:
                                    'Produced: ${item.completedCartons}/${item.cartons}',
                                color: item.completedCartons >= item.cartons
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                                bgColor: item.completedCartons >= item.cartons
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFEF3C7),
                                icon: Icons.precision_manufacturing_outlined,
                              ),
                              const SizedBox(width: 6),
                              _buildStageBadge(
                                label: item.qcPassed
                                    ? 'QC: PASSED'
                                    : 'QC: PENDING',
                                color: item.qcPassed
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF64748B),
                                bgColor: item.qcPassed
                                    ? const Color(0xFFF0FDFA)
                                    : const Color(0xFFF1F5F9),
                                icon: item.qcPassed
                                    ? Icons.verified
                                    : Icons.verified_outlined,
                              ),
                              const SizedBox(width: 6),
                              _buildStageBadge(
                                label:
                                    'Packed: ${item.packedCartons}/${item.cartons}',
                                color: item.packedCartons >= item.cartons
                                    ? const Color(0xFF4338CA)
                                    : const Color(0xFF64748B),
                                bgColor: item.packedCartons >= item.cartons
                                    ? const Color(0xFFEEF2FF)
                                    : const Color(0xFFF1F5F9),
                                icon: Icons.inventory_2_outlined,
                              ),
                              const SizedBox(width: 6),
                              _buildStageBadge(
                                label:
                                    'Shipped: ${item.shippedCartons}/${item.cartons}',
                                color: item.shippedCartons >= item.cartons
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF64748B),
                                bgColor: item.shippedCartons >= item.cartons
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF1F5F9),
                                icon: Icons.local_shipping_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Operational Action Buttons (Production Manager / Authorized Roles)
                      if (canManageProd ||
                          canDoQc ||
                          canUpdatePacking ||
                          canUpdateShipping) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (canManageProd)
                                _buildActionButton(
                                  label: 'Assign Task',
                                  icon: Icons.person_add_alt_1_outlined,
                                  color: Colors.black,
                                  onPressed: () => ProductionStatusDialogs
                                      .showAssignSupervisorsDialog(
                                    context,
                                    po,
                                    item,
                                    onUpdated: () => context
                                        .read<PurchaseOrderProvider>()
                                        .loadPurchaseOrders(),
                                  ),
                                ),
                              if (canDoQc || canManageProd)
                                _buildActionButton(
                                  label: 'QC Inspect',
                                  icon: Icons.fact_check_outlined,
                                  color: const Color(0xFF0F766E),
                                  onPressed: () => ProductionStatusDialogs
                                      .showQcInspectionDialog(
                                    context,
                                    po,
                                    item,
                                    onUpdated: () => context
                                        .read<PurchaseOrderProvider>()
                                        .loadPurchaseOrders(),
                                  ),
                                ),
                              if (canUpdatePacking || canManageProd)
                                _buildActionButton(
                                  label: 'Pack',
                                  icon: Icons.archive_outlined,
                                  color: const Color(0xFF4338CA),
                                  onPressed: () => ProductionStatusDialogs
                                      .showPackingDialog(
                                    context,
                                    po,
                                    item,
                                    onUpdated: () => context
                                        .read<PurchaseOrderProvider>()
                                        .loadPurchaseOrders(),
                                  ),
                                ),
                              if (canUpdateShipping || canManageProd)
                                _buildActionButton(
                                  label: 'Ship',
                                  icon: Icons.local_shipping_outlined,
                                  color: const Color(0xFF1D4ED8),
                                  onPressed: () => ProductionStatusDialogs
                                      .showShippingDialog(
                                    context,
                                    po,
                                    item,
                                    onUpdated: () => context
                                        .read<PurchaseOrderProvider>()
                                        .loadPurchaseOrders(),
                                  ),
                                ),
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
  }
}
