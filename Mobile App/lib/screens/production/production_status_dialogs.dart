import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/purchase_order_provider.dart';

class ProductionStatusDialogs {
  /// Assign supervisor to a PO line item
  static void showAssignSupervisorsDialog(
    BuildContext context,
    PurchaseOrderModel po,
    PurchaseOrderItemModel item, {
    VoidCallback? onUpdated,
  }) {
    final deptProv = context.read<DepartmentProvider>();
    final users = deptProv.tenantUsers;
    String? selectedUserId = users.isNotEmpty ? users.first.userId : null;
    final remainingCartons = item.cartons - item.completedCartons > 0
        ? item.cartons - item.completedCartons
        : item.cartons;
    final cartonsController = TextEditingController(text: '$remainingCartons');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined,
                  size: 20, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assign: ${item.itemName}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text('Select Supervisor',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: users.map((u) {
                    final display = u.fullName.isNotEmpty
                        ? '${u.fullName} (@${u.userName})'
                        : u.emailAddress;
                    return DropdownMenuItem(
                      value: u.userId,
                      child: Text(display,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedUserId = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text('Assigned Cartons',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: cartonsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 50',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Production Instructions / Notes',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Target line, specific machinery, shift...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
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
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () async {
                final qty = int.tryParse(cartonsController.text.trim()) ?? 0;
                if (selectedUserId == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please select a supervisor and valid carton count.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final prodProv = context.read<ProductionProvider>();
                final poProv = context.read<PurchaseOrderProvider>();
                final success = await prodProv.createAssignment(
                  poId: po.poId,
                  itemId: item.itemId,
                  supervisorUserId: selectedUserId!,
                  assignedCartons: qty,
                  notes: notesController.text.trim(),
                );
                if (success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Successfully assigned $qty cartons to supervisor.'),
                        backgroundColor: const Color(0xFF15803D),
                      ),
                    );
                  }
                  await poProv.loadPurchaseOrders();
                  onUpdated?.call();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(prodProv.errorMessage ??
                            'Failed to assign supervisor.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Assign Task'),
            ),
          ],
        ),
      ),
    );
  }

  /// Perform QC inspection on a PO line item
  static void showQcInspectionDialog(
    BuildContext context,
    PurchaseOrderModel po,
    PurchaseOrderItemModel item, {
    VoidCallback? onUpdated,
  }) {
    String qcStatus = 'PASSED';
    final inspectedController = TextEditingController(text: '${item.cartons}');
    final rejectedController = TextEditingController(text: '0');
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 20, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QC: ${item.itemName}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text('Verdict',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: qcStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'PASSED',
                        child: Text('PASSED (Approved)',
                            style: TextStyle(
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w700))),
                    DropdownMenuItem(
                        value: 'CONDITIONAL_PASS',
                        child: Text('CONDITIONAL PASS',
                            style: TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w700))),
                    DropdownMenuItem(
                        value: 'FAILED',
                        child: Text('FAILED (Rejected)',
                            style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w700))),
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
                          const Text('Inspected',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: inspectedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
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
                          const Text('Rejected',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: rejectedController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Remarks',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: remarksController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Weight check, sealing, etc.',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
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
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () async {
                final insp = int.tryParse(inspectedController.text.trim()) ??
                    item.cartons;
                final rej = int.tryParse(rejectedController.text.trim()) ?? 0;
                Navigator.pop(ctx);
                final prodProv = context.read<ProductionProvider>();
                final poProv = context.read<PurchaseOrderProvider>();
                final success = await prodProv.submitQcReport(
                  poId: po.poId,
                  itemId: item.itemId,
                  status: qcStatus,
                  inspectedCartons: insp,
                  rejectedCartons: rej,
                  remarks: remarksController.text.trim(),
                );
                if (success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('QC report submitted: marked as $qcStatus.'),
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                    );
                  }
                  await poProv.loadPurchaseOrders();
                  onUpdated?.call();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(prodProv.errorMessage ??
                            'Failed to submit QC report.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit QC Report'),
            ),
          ],
        ),
      ),
    );
  }

  /// Update packing count for a PO line item
  static void showPackingDialog(
    BuildContext context,
    PurchaseOrderModel po,
    PurchaseOrderItemModel item, {
    VoidCallback? onUpdated,
  }) {
    final controller = TextEditingController(
        text:
            '${item.packedCartons > 0 ? item.packedCartons : item.cartons}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 20, color: Color(0xFF4338CA)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pack: ${item.itemName}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
            const Text('Total Packed Cartons',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6)),
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
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
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
              if (success) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Updated packing: $packed / ${item.cartons} cartons.'),
                      backgroundColor: const Color(0xFF4338CA),
                    ),
                  );
                }
                onUpdated?.call();
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          poProv.errorMessage ?? 'Failed to update packing.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update Packing'),
          ),
        ],
      ),
    );
  }

  /// Update shipping count and line item status
  static void showShippingDialog(
    BuildContext context,
    PurchaseOrderModel po,
    PurchaseOrderItemModel item, {
    VoidCallback? onUpdated,
  }) {
    final controller = TextEditingController(
        text:
            '${item.shippedCartons > 0 ? item.shippedCartons : item.cartons}');
    String itemStatus =
        item.itemStatus.isNotEmpty ? item.itemStatus : 'SHIPPED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 20, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shipping: ${item.itemName}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
              const Text('Total Shipped Cartons',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Line Item Status',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: itemStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'IN_PRODUCTION', child: Text('IN PRODUCTION')),
                  DropdownMenuItem(value: 'SHIPPED', child: Text('SHIPPED')),
                  DropdownMenuItem(
                      value: 'DELIVERED', child: Text('DELIVERED')),
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
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
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
                if (success) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Updated shipping: $shipped / ${item.cartons} cartons ($itemStatus).'),
                        backgroundColor: const Color(0xFF1D4ED8),
                      ),
                    );
                  }
                  onUpdated?.call();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(poProv.errorMessage ??
                            'Failed to update shipping.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update Shipping'),
            ),
          ],
        ),
      ),
    );
  }

  /// Change overall PO status (Confirmed, In Production, Shipped, Delivered, Cancelled)
  static void showStatusChangeModal(
    BuildContext context,
    PurchaseOrderModel po, {
    VoidCallback? onUpdated,
  }) {
    final availableStatuses = [
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
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
                      'Update Production Order Status',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a new status for PO #${po.poNumber}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                      color:
                          isCurrent ? const Color(0xFFFAFAFA) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrent
                            ? Colors.black
                            : const Color(0xFFE5E5E5),
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(icon, size: 18, color: col),
                      ),
                      title: Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
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
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF71717A)),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check,
                              color: Colors.black, size: 18)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (code == po.status.toUpperCase()) return;

                        final poProvider =
                            context.read<PurchaseOrderProvider>();
                        final success =
                            await poProvider.updatePurchaseOrder(
                          poId: po.poId,
                          status: code,
                        );

                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'PO #${po.poNumber} status updated to $label'),
                                backgroundColor: const Color(0xFF14532D),
                              ),
                            );
                            onUpdated?.call();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(poProvider.errorMessage ??
                                    'Failed to update PO status'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }
}
