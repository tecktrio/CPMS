import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_detail_screen.dart';

class PurchaseOrdersListScreen extends StatefulWidget {
  const PurchaseOrdersListScreen({super.key});

  @override
  State<PurchaseOrdersListScreen> createState() =>
      _PurchaseOrdersListScreenState();
}

class _PurchaseOrdersListScreenState extends State<PurchaseOrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  String _searchQuery = '';
  String _selectedStatus = 'ALL';

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
      case 'DRAFT':
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poProvider = context.watch<PurchaseOrderProvider>();
    final allOrders = poProvider.purchaseOrders;

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
              children: const [
                Text(
                  'Purchase Orders',
                  style: TextStyle(
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
                              child: _buildStatusChipsRow(),
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
                            child: _buildStatusChipsRow(),
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
                            : isWide
                                ? GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 6, 24, 80),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 520,
                                      mainAxisExtent: 175,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                    ),
                                    itemCount: filteredOrders.length,
                                    itemBuilder: (context, idx) {
                                      final po = filteredOrders[idx];
                                      return _buildPoCard(context, po);
                                    },
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 6, 16, 80),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: filteredOrders.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, idx) {
                                      final po = filteredOrders[idx];
                                      return _buildPoCard(context, po);
                                    },
                                  ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
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
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search PO number or customer...',
                hintStyle: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Color(0xFF71717A), size: 16),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChipsRow() {
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
        _buildStatusChip('DRAFT', 'Draft'),
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

  Widget _buildPoCard(BuildContext context, PurchaseOrderModel po) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          hoverColor: const Color(0xFFF8FAFC),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PurchaseOrderDetailScreen(poId: po.poId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: PO Number + Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'PO # ',
                                style: TextStyle(
                                  color: Color(0xFF71717A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: po.poNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusBg(po.status),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        po.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _getStatusTextColor(po.status),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Customer Name
                Row(
                  children: [
                    const Icon(
                      Icons.business_outlined,
                      size: 15,
                      color: Color(0xFF71717A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        po.customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Dates info in subtle grey container
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Color(0xFF71717A),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'PO: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF71717A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _dateFormat.format(po.poDate),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      if (po.expectedShippingDate != null) ...[
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 14,
                          color: Color(0xFF71717A),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Exp: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF71717A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _dateFormat.format(po.expectedShippingDate!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Bottom row: items count & Cartons badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${po.items.length} ${po.items.length == 1 ? 'item' : 'items'} (${po.totalPackets} pkts)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF71717A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.crop_square_outlined,
                            size: 13,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${po.totalCartons} Cartons',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
