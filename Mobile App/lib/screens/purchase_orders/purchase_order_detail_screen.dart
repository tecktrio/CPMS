import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/department_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/purchase_order_export_service.dart';
import '../../widgets/cpms_form_dialog.dart';
import '../../widgets/cpms_page_title.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_export_screen.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String poId;

  const PurchaseOrderDetailScreen({super.key, required this.poId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DepartmentProvider>().loadTenantUsers();
      context.read<ProductionProvider>().loadAssignmentsByPo(widget.poId);
    });
  }

  Future<void> _handleDelete(PurchaseOrderModel po) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Delete Purchase Order',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        content: Text(
          'Are you sure you want to delete PO "${po.poNumber}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
          backgroundColor: Color(0xFF0F172A),
        ),
      );
      Navigator.pop(context);
    } else {
      final err = context.read<PurchaseOrderProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to delete purchase order'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _showStatusUpdate(
    PurchaseOrderModel order,
    PurchaseOrderProvider provider,
  ) async {
    final statuses = {
      'DRAFT': 'Draft',
      'CONFIRMED': 'Confirmed',
      'IN_PRODUCTION': 'In production',
      'SHIPPED': 'Shipped',
      'DELIVERED': 'Delivered',
      'CANCELLED': 'Cancelled',
    };
    var selected = order.status.toUpperCase();
    if (!statuses.containsKey(selected)) statuses[selected] = order.status;
    final initial = selected;
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !saving,
          child: CpmsFormDialog(
            icon: Icons.swap_horiz_rounded,
            title: const Text('Update order status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(order.poNumber, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: initial,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Order status'),
                  items: [
                    for (final status in statuses.entries)
                      DropdownMenuItem(value: status.key, child: Text(status.value)),
                  ],
                  onChanged: saving ? null : (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selected = value;
                      error = null;
                    });
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving || selected == initial ? null : () async {
                  setDialogState(() => saving = true);
                  final saved = await provider.updatePurchaseOrder(
                    poId: order.poId,
                    status: selected,
                  );
                  if (!dialogContext.mounted) return;
                  if (saved) {
                    Navigator.pop(dialogContext);
                  } else {
                    setDialogState(() {
                      saving = false;
                      error = provider.errorMessage ?? 'The order status could not be updated.';
                    });
                  }
                },
                child: Text(saving ? 'Saving…' : 'Save status'),
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final poProvider = context.watch<PurchaseOrderProvider>();
    final poList = poProvider.purchaseOrders;
    final tenant = context.watch<TenantProvider>();
    final poIndex = poList.indexWhere((order) =>
        order.poId == widget.poId &&
        order.tenantId == tenant.activeTenant?.tenantId &&
        (!tenant.isUserInSupervisorDepartment || order.wasConfirmed));

    if (poIndex < 0) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Purchase Order', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800)),
        ),
        body: RefreshIndicator(
          color: const Color(0xFF0F172A),
          onRefresh: () async {
            await poProvider.loadPurchaseOrders();
          },
          child: const Center(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Text(
                'Purchase Order not found',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
              ),
            ),
          ),
        ),
      );
    }

    final po = poList[poIndex];
    final isAdmin = tenant.isTenantAdmin;
    final canUpdatePo = isAdmin || tenant.hasPermission(AppPermissions.poUpdate);
    final canDeletePo = isAdmin || tenant.hasPermission(AppPermissions.poDelete);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const CpmsPageTitle(
          'Purchase order',
          icon: Icons.receipt_long_outlined,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A), size: 20),
            tooltip: 'Refresh',
            onPressed: () {
              poProvider.loadPurchaseOrders();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        onRefresh: () async {
          await poProvider.loadPurchaseOrders();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP PO HERO CARD
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        Text(
                          po.poNumber,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (po.customerName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(po.customerName, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Export Button
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PurchaseOrderExportScreen(po: po),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.file_upload_outlined, size: 16),
                              label: const Text('Export', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                            InkWell(
                              onTap: canUpdatePo
                                  ? () => _showStatusUpdate(po, poProvider)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _getStatusBg(po.status),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getStatusBorder(po.status)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _getStatusTextColor(po.status),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      po.status.replaceAll('_', ' ').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _getStatusTextColor(po.status),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    if (canUpdatePo) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 15,
                                        color: _getStatusTextColor(po.status),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Bottom Row inside Top Card: Dates & Counts Strip
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            // PO Date
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                const Text('PO Date: ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                Text(
                                  _dateFormat.format(po.poDate),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),

                            Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),

                            // Shipping Date
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                const Text('Shipping Date: ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                Text(
                                  po.expectedShippingDate != null
                                      ? _dateFormat.format(po.expectedShippingDate!)
                                      : 'Not set',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: po.expectedShippingDate != null ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),

                            Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),

                            // Total Items
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_outlined, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                const Text('Total Items: ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                Text(
                                  '${po.items.length}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),

                            Container(width: 1, height: 14, color: const Color(0xFFE2E8F0)),

                            // Total Cartons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                const Text('Total Cartons: ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                Text(
                                  '${po.totalCartons}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. PRODUCTION & FULFILLMENT STATUS CARD
                  _buildProductionWorkflowCard(po),

                  const SizedBox(height: 24),

                  // 3. SECTION: ITEMS & CARTON SPECIFICATION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ITEMS & CARTON SPECIFICATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${po.items.length} ${po.items.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Items Table
                  Container(
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
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Black Table Header
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text(
                                  'SL.',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Text(
                                  'ITEMS',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'PKT / CTN BOX',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'CTNS',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table rows
                        if (po.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
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
                            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final item = po.items[idx];
                              final itemDescription = item.specification.isNotEmpty
                                  ? item.specification
                                  : PurchaseOrderExportService.formatQtyPerPacketShort(
                                      item.quantityPerPacket,
                                      item.unit,
                                    );
                              return Container(
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '${idx + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.itemName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if (itemDescription.isNotEmpty)
                                            Text(
                                              '$itemDescription per packet',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.packetPerCarton}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.cartons}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        // Table Footer showing TOTAL CARTONS
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 36),
                              const Expanded(
                                flex: 6,
                                child: Text(
                                  'TOTAL CARTONS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${po.totalPackets} pkts',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${po.totalCartons}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. BOTTOM ACTION BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canDeletePo)
                        OutlinedButton.icon(
                          onPressed: () => _handleDelete(po),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                          label: const Text('Delete Order', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (canUpdatePo)
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreatePurchaseOrderScreen(existingPo: po),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                          label: const Text('Edit Purchase Order', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 5. COPYRIGHT FOOTER
                  const Center(
                    child: Text(
                      'Developed by Bigburry Hypersystems',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductionWorkflowCard(PurchaseOrderModel po) {
    final producedRatio = po.totalCartons > 0 ? (po.totalCompletedCartons / po.totalCartons).clamp(0.0, 1.0) : 0.0;
    final packedRatio = po.totalCartons > 0 ? (po.totalPackedCartons / po.totalCartons).clamp(0.0, 1.0) : 0.0;
    final shippedRatio = po.totalCartons > 0 ? (po.totalShippedCartons / po.totalCartons).clamp(0.0, 1.0) : 0.0;
    final qcRatio = po.items.isNotEmpty ? (po.totalQcPassedItems / po.items.length).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: const [
              Icon(Icons.sync, size: 18, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text(
                'PRODUCTION & FULFILLMENT STATUS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 650;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildStageCard(
                        title: '1. Production',
                        progressText: '${po.totalCompletedCartons}/${po.totalCartons} ctns',
                        ratio: producedRatio,
                        badgeColor: const Color(0xFF16A34A),
                        badgeBg: const Color(0xFFF0FDF4),
                        badgeBorder: const Color(0xFFDCFCE7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStageCard(
                        title: '2. QC Inspection',
                        progressText: '${po.totalQcPassedItems}/${po.items.length} items',
                        ratio: qcRatio,
                        badgeColor: const Color(0xFF16A34A),
                        badgeBg: const Color(0xFFF0FDF4),
                        badgeBorder: const Color(0xFFDCFCE7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStageCard(
                        title: '3. Packing',
                        progressText: '${po.totalPackedCartons}/${po.totalCartons} ctns',
                        ratio: packedRatio,
                        badgeColor: const Color(0xFF2563EB),
                        badgeBg: const Color(0xFFEFF6FF),
                        badgeBorder: const Color(0xFFDBEAFE),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStageCard(
                        title: '4. Shipping',
                        progressText: '${po.totalShippedCartons}/${po.totalCartons} ctns',
                        ratio: shippedRatio,
                        badgeColor: const Color(0xFF2563EB),
                        badgeBg: const Color(0xFFEFF6FF),
                        badgeBorder: const Color(0xFFDBEAFE),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStageCard(
                            title: '1. Production',
                            progressText: '${po.totalCompletedCartons}/${po.totalCartons} ctns',
                            ratio: producedRatio,
                            badgeColor: const Color(0xFF16A34A),
                            badgeBg: const Color(0xFFF0FDF4),
                            badgeBorder: const Color(0xFFDCFCE7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStageCard(
                            title: '2. QC Inspection',
                            progressText: '${po.totalQcPassedItems}/${po.items.length} items',
                            ratio: qcRatio,
                            badgeColor: const Color(0xFF16A34A),
                            badgeBg: const Color(0xFFF0FDF4),
                            badgeBorder: const Color(0xFFDCFCE7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStageCard(
                            title: '3. Packing',
                            progressText: '${po.totalPackedCartons}/${po.totalCartons} ctns',
                            ratio: packedRatio,
                            badgeColor: const Color(0xFF2563EB),
                            badgeBg: const Color(0xFFEFF6FF),
                            badgeBorder: const Color(0xFFDBEAFE),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStageCard(
                            title: '4. Shipping',
                            progressText: '${po.totalShippedCartons}/${po.totalCartons} ctns',
                            ratio: shippedRatio,
                            badgeColor: const Color(0xFF2563EB),
                            badgeBg: const Color(0xFFEFF6FF),
                            badgeBorder: const Color(0xFFDBEAFE),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard({
    required String title,
    required String progressText,
    required double ratio,
    required Color badgeColor,
    required Color badgeBg,
    required Color badgeBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  progressText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}
