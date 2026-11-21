import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/department_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/purchase_order_export_service.dart';
import '../../widgets/user_profile_avatar.dart';
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

  void _showAssignSupervisorsDialog(PurchaseOrderModel po, PurchaseOrderItemModel item) {
    final deptProv = context.read<DepartmentProvider>();
    final users = deptProv.tenantUsers;
    String? selectedUserId = users.isNotEmpty ? users.first.userId : null;
    final remainingCartons = item.cartons - item.completedCartons > 0 ? item.cartons - item.completedCartons : item.cartons;
    final cartonsController = TextEditingController(text: '$remainingCartons');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, size: 20, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assign: ${item.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total PO Requirement: ${item.cartons} ctns (${item.completedCartons} produced)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text('Select Supervisor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: users.map((u) {
                    final deptName = u.departmentIds.isNotEmpty ? ' (${u.departmentIds.length} roles)' : '';
                    return DropdownMenuItem(
                      value: u.userId,
                      child: Text('${u.fullName.isNotEmpty ? u.fullName : u.emailAddress}$deptName', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedUserId = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Assigned Cartons', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: cartonsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter carton count e.g. 20',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Production Notes (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Batch details, line number, or instructions',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () async {
                final qty = int.tryParse(cartonsController.text.trim()) ?? 0;
                if (selectedUserId == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a supervisor and valid carton count.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final prodProv = context.read<ProductionProvider>();
                final success = await prodProv.createAssignment(
                  poId: po.poId,
                  itemId: item.itemId,
                  supervisorUserId: selectedUserId!,
                  assignedCartons: qty,
                  notes: notesController.text.trim(),
                );
                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully assigned $qty cartons to supervisor.'),
                      backgroundColor: const Color(0xFF15803D),
                    ),
                  );
                  await context.read<PurchaseOrderProvider>().loadPurchaseOrders();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(prodProv.errorMessage ?? 'Failed to assign supervisor.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Assign Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQcInspectionDialog(PurchaseOrderModel po, PurchaseOrderItemModel item) {
    String qcStatus = 'PASSED';
    final inspectedController = TextEditingController(text: '${item.cartons}');
    final rejectedController = TextEditingController(text: '0');
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 20, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QC: ${item.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Cartons: ${item.cartons} | Produced: ${item.completedCartons}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text('Verdict', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: qcStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PASSED', child: Text('PASSED (Approved)', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700))),
                    DropdownMenuItem(value: 'CONDITIONAL_PASS', child: Text('CONDITIONAL PASS', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700))),
                    DropdownMenuItem(value: 'FAILED', child: Text('FAILED (Rejected)', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => qcStatus = val);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inspected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: inspectedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rejected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: rejectedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: remarksController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Weight check, sealing, etc.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () async {
                final insp = int.tryParse(inspectedController.text.trim()) ?? item.cartons;
                final rej = int.tryParse(rejectedController.text.trim()) ?? 0;
                Navigator.pop(ctx);
                final prodProv = context.read<ProductionProvider>();
                final success = await prodProv.submitQcReport(
                  poId: po.poId,
                  itemId: item.itemId,
                  status: qcStatus,
                  inspectedCartons: insp,
                  rejectedCartons: rej,
                  remarks: remarksController.text.trim(),
                );
                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('QC report submitted: marked as $qcStatus.'),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                  );
                  await context.read<PurchaseOrderProvider>().loadPurchaseOrders();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(prodProv.errorMessage ?? 'Failed to submit QC report.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Submit QC Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPackingDialog(PurchaseOrderModel po, PurchaseOrderItemModel item) {
    final controller = TextEditingController(text: '${item.packedCartons > 0 ? item.packedCartons : item.cartons}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF4338CA)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pack: ${item.itemName}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Cartons Required: ${item.cartons} | Produced: ${item.completedCartons}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            const Text('Total Packed Cartons', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
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
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              final packed = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx);
              final poProv = context.read<PurchaseOrderProvider>();
              final success = await poProv.updateItemPacking(
                poId: po.poId,
                itemId: item.itemId,
                packedCartons: packed,
              );
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated packing: $packed / ${item.cartons} cartons.'),
                    backgroundColor: const Color(0xFF4338CA),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(poProv.errorMessage ?? 'Failed to update packing.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update Packing'),
          ),
        ],
      ),
    );
  }

  void _showShippingDialog(PurchaseOrderModel po, PurchaseOrderItemModel item) {
    final controller = TextEditingController(text: '${item.shippedCartons > 0 ? item.shippedCartons : item.cartons}');
    String itemStatus = item.itemStatus.isNotEmpty ? item.itemStatus : 'SHIPPED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shipping: ${item.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Cartons: ${item.cartons} | Packed: ${item.packedCartons}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text('Total Shipped Cartons', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Line Item Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: itemStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'IN_PRODUCTION', child: Text('IN PRODUCTION')),
                  DropdownMenuItem(value: 'SHIPPED', child: Text('SHIPPED')),
                  DropdownMenuItem(value: 'DELIVERED', child: Text('DELIVERED')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => itemStatus = val);
                },
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
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () async {
                final shipped = int.tryParse(controller.text.trim()) ?? 0;
                Navigator.pop(ctx);
                final poProv = context.read<PurchaseOrderProvider>();
                final success = await poProv.updateItemShipping(
                  poId: po.poId,
                  itemId: item.itemId,
                  shippedCartons: shipped,
                  itemStatus: itemStatus,
                );
                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated shipping: $shipped / ${item.cartons} cartons ($itemStatus).'),
                      backgroundColor: const Color(0xFF1D4ED8),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(poProv.errorMessage ?? 'Failed to update shipping.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update Shipping'),
            ),
          ],
        ),
      ),
    );
  }

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
        body: RefreshIndicator(
          color: Colors.black,
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
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canUpdatePo = isAdmin || tenant.hasPermission(AppPermissions.poUpdate);
    final canDeletePo = isAdmin || tenant.hasPermission(AppPermissions.poDelete);
    final canAssignProduction = isAdmin || tenant.hasPermission(AppPermissions.productionCreate);
    final canDoQc = isAdmin || tenant.hasPermission(AppPermissions.qcCreate);
    final canUpdatePacking = isAdmin || tenant.hasPermission(AppPermissions.packingUpdate);
    final canUpdateShipping = isAdmin || tenant.hasPermission(AppPermissions.exportUpdate);
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
            constraints: const BoxConstraints(maxWidth: 1100),
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
            icon: const Icon(Icons.file_upload_outlined, color: Colors.black, size: 20),
            tooltip: 'Export',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseOrderExportScreen(po: po),
                ),
              );
            },
          ),
          if (canUpdatePo)
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
          if (canDeletePo)
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
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: () async {
          await poProvider.loadPurchaseOrders();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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

                const SizedBox(height: 14),

                // Production & Order Lifecycle Progress Card
                _buildProductionWorkflowCard(po),

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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 1.2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Black Table Header matching Edit PO
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 26,
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
                                  'PKT/CTN',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'CTNS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table rows
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: po.items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          itemBuilder: (context, idx) {
                            final item = po.items[idx];
                            final itemDescription = item.specification.isNotEmpty
                                ? item.specification
                                : PurchaseOrderExportService.formatQtyPerPacketShort(
                                    item.quantityPerPacket,
                                    item.unit,
                                  );
                            return Container(
                              color: idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 26,
                                        child: Text(
                                          '${idx + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.itemName,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                            ),
                                            const SizedBox(height: 1),
                                            if (itemDescription.isNotEmpty)
                                              Text(
                                                '$itemDescription per packet',
                                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${item.packetPerCarton}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${item.cartons}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Lifecycle Stage Tracking Badges
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 26),
                                        // Produced badge
                                        _buildStageBadge(
                                          label: 'Produced: ${item.completedCartons}/${item.cartons}',
                                          color: item.completedCartons >= item.cartons
                                              ? const Color(0xFF15803D)
                                              : (item.completedCartons > 0 ? const Color(0xFFB45309) : const Color(0xFF64748B)),
                                          bgColor: item.completedCartons >= item.cartons
                                              ? const Color(0xFFF0FDF4)
                                              : (item.completedCartons > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9)),
                                          icon: Icons.precision_manufacturing_outlined,
                                        ),
                                        const SizedBox(width: 6),
                                        // QC badge
                                        _buildStageBadge(
                                          label: item.qcPassed ? 'QC: PASSED' : 'QC: PENDING',
                                          color: item.qcPassed ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                                          bgColor: item.qcPassed ? const Color(0xFFF0FDFA) : const Color(0xFFF1F5F9),
                                          icon: item.qcPassed ? Icons.verified : Icons.verified_outlined,
                                        ),
                                        const SizedBox(width: 6),
                                        // Packed badge
                                        _buildStageBadge(
                                          label: 'Packed: ${item.packedCartons}/${item.cartons}',
                                          color: item.packedCartons >= item.cartons ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                                          bgColor: item.packedCartons >= item.cartons ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                                          icon: Icons.inventory_2_outlined,
                                        ),
                                        const SizedBox(width: 6),
                                        // Shipped badge
                                        _buildStageBadge(
                                          label: 'Shipped: ${item.shippedCartons}/${item.cartons}',
                                          color: item.shippedCartons >= item.cartons ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                          bgColor: item.shippedCartons >= item.cartons ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                          icon: Icons.local_shipping_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Role-based Quick Action Buttons
                                  if (canAssignProduction || canDoQc || canUpdatePacking || canUpdateShipping) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 26),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (canAssignProduction)
                                            _buildActionButton(
                                              label: 'Assign Task',
                                              icon: Icons.person_add_alt_1_outlined,
                                              color: Colors.black,
                                              onPressed: () => _showAssignSupervisorsDialog(po, item),
                                            ),
                                          if (canDoQc)
                                            _buildActionButton(
                                              label: 'QC Inspect',
                                              icon: Icons.fact_check_outlined,
                                              color: const Color(0xFF0F766E),
                                              onPressed: () => _showQcInspectionDialog(po, item),
                                            ),
                                          if (canUpdatePacking)
                                            _buildActionButton(
                                              label: 'Pack',
                                              icon: Icons.archive_outlined,
                                              color: const Color(0xFF4338CA),
                                              onPressed: () => _showPackingDialog(po, item),
                                            ),
                                          if (canUpdateShipping)
                                            _buildActionButton(
                                              label: 'Ship',
                                              icon: Icons.local_shipping_outlined,
                                              color: const Color(0xFF1D4ED8),
                                              onPressed: () => _showShippingDialog(po, item),
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

                        // Table Footer showing TOTAL CARTONS
                        Container(
                          color: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: Row(
                            children: [
                              const SizedBox(width: 26),
                              const Expanded(
                                flex: 6,
                                child: Text(
                                  'TOTAL CARTONS',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${po.totalPackets} pkts',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${po.totalCartons}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Primary Export Button - Solid Black Rectangle
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PurchaseOrderExportScreen(po: po),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.file_upload_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Export',
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

                if (canUpdatePo) ...[
                  const SizedBox(height: 12),

                  // Edit Action Button - Clean Outline
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
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Edit Purchase Order',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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
                ],

                if (canDeletePo) ...[
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
                ],

                const SizedBox(height: 32),
              ],
            ),
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

  Widget _buildProductionWorkflowCard(PurchaseOrderModel po) {
    final producedRatio = po.totalCartons > 0 ? (po.totalCompletedCartons / po.totalCartons).clamp(0.0, 1.0) : 0.0;
    final packedRatio = po.totalCartons > 0 ? (po.totalPackedCartons / po.totalCartons).clamp(0.0, 1.0) : 0.0;
    final shippedRatio = po.totalCartons > 0 ? (po.totalShippedCartons / po.totalCartons).clamp(0.0, 1.0) : 0.0;
    final qcRatio = po.items.isNotEmpty ? (po.totalQcPassedItems / po.items.length).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.track_changes, size: 16, color: Color(0xFF0F172A)),
              SizedBox(width: 8),
              Text(
                'PRODUCTION & FULFILLMENT STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStageProgressItem(
                  stage: '1. Production',
                  progressText: '${po.totalCompletedCartons}/${po.totalCartons} ctns',
                  ratio: producedRatio,
                  color: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStageProgressItem(
                  stage: '2. QC Inspection',
                  progressText: '${po.totalQcPassedItems}/${po.items.length} items',
                  ratio: qcRatio,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStageProgressItem(
                  stage: '3. Packing',
                  progressText: '${po.totalPackedCartons}/${po.totalCartons} ctns',
                  ratio: packedRatio,
                  color: const Color(0xFF4338CA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStageProgressItem(
                  stage: '4. Shipping',
                  progressText: '${po.totalShippedCartons}/${po.totalCartons} ctns',
                  ratio: shippedRatio,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageProgressItem({
    required String stage,
    required String progressText,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(stage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text(progressText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildStageBadge({
    required String label,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
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
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
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
}
