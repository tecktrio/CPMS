import 'package:flutter/material.dart';
import '../../widgets/cpms_page_title.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../widgets/cpms_search_bar.dart';
import '../../widgets/app_footer.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_detail_screen.dart';

class PurchaseOrdersListScreen extends StatefulWidget {
  const PurchaseOrdersListScreen({super.key, this.initialStatus = 'ALL'});

  final String initialStatus;

  @override
  State<PurchaseOrdersListScreen> createState() =>
      _PurchaseOrdersListScreenState();
}

class _PurchaseOrdersListScreenState extends State<PurchaseOrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String _searchQuery = '';
  late String _selectedStatus = widget.initialStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final prov = context.read<PurchaseOrderProvider>();
    await Future.wait([
      prov.loadPurchaseOrders(),
      prov.loadCustomers(),
    ]);
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

  @override
  Widget build(BuildContext context) {
    final poProvider = context.watch<PurchaseOrderProvider>();
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canCreatePo = isAdmin || tenant.hasPermission(AppPermissions.poCreate);
    final isSupervisor = tenant.isUserInSupervisorDepartment;
    final allOrders = poProvider.purchaseOrders.where((order) =>
        order.tenantId == tenant.activeTenant?.tenantId &&
        (!isSupervisor || order.wasConfirmed));

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    final filteredOrders = allOrders.where((po) {
      final matchesSearch = po.poNumber
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          po.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _selectedStatus == 'ALL' || po.status.toUpperCase() == _selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    final inProductionCount = allOrders
        .where((po) => po.status.toUpperCase() == 'IN_PRODUCTION')
        .length;

    return Scaffold(
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
        title: const CpmsPageTitle('Purchase Orders', icon: Icons.receipt_long_outlined),
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
              // Search & Filter Controls
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
                              child: _buildStatusChipsRow(isSupervisor: isSupervisor),
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
                            child: _buildStatusChipsRow(isSupervisor: isSupervisor),
                          ),
                        ],
                      ),
              ),

              // Metrics Banner (Total Orders & Total Cartons - Uber Style)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedStatus = 'ALL';
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _selectedStatus == 'ALL'
                                  ? Colors.black
                                  : const Color(0xFFE5E5E5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL ORDERS',
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
                                    '${allOrders.length}',
                                    style: const TextStyle(
                                      fontSize: 28,
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
                                      Icons.description_outlined,
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedStatus = 'IN_PRODUCTION';
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _selectedStatus == 'IN_PRODUCTION'
                                  ? Colors.black
                                  : const Color(0xFFE5E5E5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'IN PRODUCTION',
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
                                    '$inProductionCount',
                                    style: const TextStyle(
                                      fontSize: 28,
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
                                      Icons.precision_manufacturing_outlined,
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
                    ),
                  ],
                ),
              ),

              // Active Orders Section Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 24 : 16,
                  16,
                  isWide ? 24 : 16,
                  8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'ACTIVE ORDERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF71717A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Sorted by Date',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),

              // Orders List / Grid
              Expanded(
                child: poProvider.isLoading && allOrders.isEmpty
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Colors.black),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        color: Colors.black,
                        child: filteredOrders.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.35,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F4F5),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.receipt_long_outlined,
                                              size: 24,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No purchase orders match "$_searchQuery"'
                                                : 'No purchase orders found',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Tap "+ Create PO" below to register an order.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
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
                                  _buildDrivePoTableHeader(isWide: isWide),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.only(bottom: 96),
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: filteredOrders.length + 1,
                                      separatorBuilder: (_, _) =>
                                          const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Color(0xFFF1F5F9),
                                      ),
                                      itemBuilder: (context, idx) {
                                        if (idx == filteredOrders.length) {
                                          return const AppFooter(topPadding: 16, bottomPadding: 24);
                                        }
                                        final po = filteredOrders[idx];
                                        return _buildDriveRowPo(context, po, isWide: isWide);
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
      floatingActionButton: canCreatePo
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF14532D), // Dark Green
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Create PO',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePurchaseOrderScreen(),
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return CpmsSearchBar(
      controller: _searchController,
      hintText: 'Search PO number or customer...',
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
      },
      onClear: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildStatusChipsRow({required bool isSupervisor}) {
    return Row(
      children: [
        _buildStatusChip('ALL', 'All Orders'),
        const SizedBox(width: 8),
        _buildStatusChip('CONFIRMED', 'Confirmed'),
        const SizedBox(width: 8),
        _buildStatusChip('IN_PRODUCTION', 'In Production'),
        const SizedBox(width: 8),
        _buildStatusChip('SHIPPED', 'Shipped'),
        const SizedBox(width: 8),
        _buildStatusChip('DELIVERED', 'Delivered'),
        if (!isSupervisor) ...[
          const SizedBox(width: 8),
          _buildStatusChip('DRAFT', 'Draft'),
        ],
      ],
    );
  }

  Widget _buildStatusChip(String code, String label) {
    final isSelected = _selectedStatus == code;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = code;
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
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDrivePoTableHeader({required bool isWide}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 20 : 12,
        vertical: 10,
      ),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Order / Name Header
          Expanded(
            flex: isWide ? 4 : 5,
            child: Row(
              children: const [
                Text(
                  'Order',
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
            // Status Header
            const SizedBox(
              width: 130,
              child: Text(
                'Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // Cartons Header
            const SizedBox(
              width: 90,
              child: Text(
                'Cartons',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
          // Date Header
          SizedBox(
            width: isWide ? 110 : 90,
            child: Text(
              'Date',
              textAlign: isWide ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Actions spacer
          const SizedBox(
            width: 36,
            child: Icon(Icons.more_vert, size: 16, color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveRowPo(BuildContext context, PurchaseOrderModel po, {required bool isWide}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: const Color(0xFFF1F5F9),
        splashColor: const Color(0xFFE2E8F0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PurchaseOrderDetailScreen(poId: po.poId),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 20 : 12,
            vertical: 11,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading: Icon + PO number & Customer
              Expanded(
                flex: isWide ? 4 : 5,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            po.poNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  po.customerName.isNotEmpty
                                      ? po.customerName
                                      : 'No Customer Assigned',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (po.totalCompletedCartons > 0 ||
                                  po.totalPackedCartons > 0 ||
                                  po.totalShippedCartons > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Text(
                                    '${po.totalCompletedCartons}/${po.totalCartons} done',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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

                // Status Column
                SizedBox(
                  width: 130,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getStatusBg(po.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          po.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _getStatusTextColor(po.status),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Cartons Column
                SizedBox(
                  width: 90,
                  child: Text(
                    '${po.totalCartons} ctns',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],

              // Date Column
              SizedBox(
                width: isWide ? 110 : 90,
                child: Text(
                  _dateFormat.format(po.poDate),
                  textAlign: isWide ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Actions Icon
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
                        builder: (_) => PurchaseOrderDetailScreen(poId: po.poId),
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
}
