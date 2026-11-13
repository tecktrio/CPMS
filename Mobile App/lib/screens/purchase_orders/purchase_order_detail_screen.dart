import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String poId;

  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> _handleDelete(PurchaseOrderModel po) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'Delete Purchase Order',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete PO "${po.poNumber}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context
        .read<PurchaseOrderProvider>()
        .deletePurchaseOrder(po.poId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase order deleted successfully'),
          backgroundColor: Colors.black,
        ),
      );
      Navigator.pop(context);
    } else {
      final err = context.read<PurchaseOrderProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to delete purchase order'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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

  void _showStatusChangeModal(PurchaseOrderModel po) {
    final availableStatuses = [
      {
        'code': 'DRAFT',
        'label': 'Draft',
        'description': 'Order saved as draft, awaiting confirmation',
        'icon': Icons.edit_note_outlined,
        'bg': const Color(0xFFF1F5F9),
        'color': const Color(0xFF475569),
      },
      {
        'code': 'CONFIRMED',
        'label': 'Confirmed',
        'description': 'Order confirmed and queued for production',
        'icon': Icons.check_circle_outline,
        'bg': const Color(0xFFECFDF5),
        'color': const Color(0xFF047857),
      },
      {
        'code': 'IN_PRODUCTION',
        'label': 'In Production',
        'description': 'Goods are being manufactured and packed',
        'icon': Icons.precision_manufacturing_outlined,
        'bg': const Color(0xFFFEF3C7),
        'color': const Color(0xFFB45309),
      },
      {
        'code': 'SHIPPED',
        'label': 'Shipped',
        'description': 'Dispatched with carrier / logistics freight',
        'icon': Icons.local_shipping_outlined,
        'bg': const Color(0xFFEFF6FF),
        'color': const Color(0xFF1D4ED8),
      },
      {
        'code': 'DELIVERED',
        'label': 'Delivered',
        'description': 'Received and signed by consignee',
        'icon': Icons.done_all,
        'bg': const Color(0xFFF0FDFA),
        'color': const Color(0xFF0F766E),
      },
      {
        'code': 'CANCELLED',
        'label': 'Cancelled',
        'description': 'Order has been cancelled or voided',
        'icon': Icons.cancel_outlined,
        'bg': const Color(0xFFFEF2F2),
        'color': const Color(0xFFDC2626),
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Update PO Status',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a new status for PO #${po.poNumber}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                ...availableStatuses.map((st) {
                  final code = st['code'] as String;
                  final label = st['label'] as String;
                  final desc = st['description'] as String;
                  final icon = st['icon'] as IconData;
                  final bg = st['bg'] as Color;
                  final col = st['color'] as Color;
                  final isCurrent = po.status.toUpperCase() == code;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFFFAFAFA) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isCurrent ? Colors.black : const Color(0xFFE5E5E5),
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Icon(icon, size: 18, color: col),
                      ),
                      title: Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        desc,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check, color: Colors.black, size: 18)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (isCurrent) return;

                        final success = await context
                            .read<PurchaseOrderProvider>()
                            .updatePurchaseOrder(
                              poId: po.poId,
                              status: code,
                            );

                        if (!mounted) return;

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PO status updated to "$label"'),
                              backgroundColor: Colors.black,
                            ),
                          );
                        } else {
                          final err = context.read<PurchaseOrderProvider>().errorMessage;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? 'Failed to update status'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final poProvider = context.watch<PurchaseOrderProvider>();
    final poList = poProvider.purchaseOrders;
    final poIndex = poList.indexWhere((p) => p.poId == widget.poId);

    if (poIndex < 0) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Purchase Order', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ),
        body: const Center(
          child: Text(
            'Purchase Order not found',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
          ),
        ),
      );
    }

    final po = poList[poIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

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
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Row(
              children: [
                Text(
                  'PO # ${po.poNumber}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black, size: 20),
            tooltip: 'Edit PO',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePurchaseOrderScreen(existingPo: po),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
            tooltip: 'Delete PO',
            onPressed: () => _handleDelete(po),
          ),
          const SizedBox(width: 4),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileAvatar(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top PO Card - Uber Style
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: PO # + Status badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
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
                              const SizedBox(width: 10),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'PO # ',
                                      style: TextStyle(
                                        color: Color(0xFF71717A),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    TextSpan(
                                      text: po.poNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showStatusChangeModal(po),
                            borderRadius: BorderRadius.circular(2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusBg(po.status),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: _getStatusTextColor(po.status).withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    po.status.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _getStatusTextColor(po.status),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 14,
                                    color: _getStatusTextColor(po.status),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Consignee Row
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 16,
                            color: Color(0xFF71717A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              po.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (po.customerAddress.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Color(0xFF71717A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                po.customerAddress,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF52525B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (po.customerContact.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: Color(0xFF71717A),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              po.customerContact,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF52525B),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Dates Strip - Grey Container
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Color(0xFF71717A),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'PO: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF71717A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _dateFormat.format(po.poDate),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.local_shipping_outlined,
                              size: 15,
                              color: Color(0xFF71717A),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Exp: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF71717A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              po.expectedShippingDate != null
                                  ? _dateFormat.format(po.expectedShippingDate!)
                                  : 'Not set',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: po.expectedShippingDate != null
                                    ? Colors.black
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (po.notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notes_outlined,
                                size: 14,
                                color: Color(0xFF71717A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  po.notes,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF3F3F46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Stat Metric Cards - Uber Style
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        label: 'TOTAL ITEMS',
                        value: '${po.items.length}',
                        icon: Icons.description_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        label: 'TOTAL CARTONS',
                        value: '${po.totalCartons}',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Section Header: ACTIVE ITEMS & CARTON SPECIFICATION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ITEMS & CARTON SPECIFICATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF71717A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${po.items.length} ${po.items.length == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF71717A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Items list cards - Uber Style
                if (po.items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: const Center(
                      child: Text(
                        'No items configured in this purchase order.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: po.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = po.items[idx];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top item row
                            Row(
                              children: [
                                if (item.sku.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F4F5),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      item.sku,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF52525B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                Text(
                                  '#${idx + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Specs row inside grey box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Packets / Ctn: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF71717A),
                                        ),
                                      ),
                                      Text(
                                        '${item.packetPerCarton}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        'Cartons: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF71717A),
                                        ),
                                      ),
                                      Text(
                                        '${item.cartons}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        'Total: ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF71717A),
                                        ),
                                      ),
                                      Text(
                                        '${item.totalPackets} pkts',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Primary Action Button - Solid Black Rectangle
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatePurchaseOrderScreen(existingPo: po),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Edit Purchase Order',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Change Status Button - Clean Outline
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFD4D4D8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () => _showStatusChangeModal(po),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_alt, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Change Status (${po.status.replaceAll('_', ' ').toUpperCase()})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Secondary Delete Button - Clean Outline
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () => _handleDelete(po),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Delete Order',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF71717A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Icon(icon, size: 16, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
