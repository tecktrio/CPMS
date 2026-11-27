import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/production_assignment_model.dart';
import '../../providers/department_provider.dart';
import '../../providers/production_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';

class ProductionStatusDialogs {
  /// Assign supervisor to a PO line item
  static void showAssignSupervisorsDialog(
    BuildContext context,
    PurchaseOrderModel po,
    PurchaseOrderItemModel item, {
    VoidCallback? onUpdated,
  }) {
    final deptProv = context.read<DepartmentProvider>();
    final tenantProv = context.read<TenantProvider>();

    // Resolve the Supervisor & Admin department IDs
    final supervisorDeptIds = tenantProv.tenantDepartments
        .where((d) =>
            d.departmentName.trim().toLowerCase() == 'supervisor' ||
            d.departmentName.trim().toLowerCase().contains('supervisor'))
        .map((d) => d.departmentId)
        .toSet();

    final adminDeptIds = tenantProv.tenantDepartments
        .where((d) =>
            d.departmentName.trim().toLowerCase() == 'administrator' ||
            d.departmentName.trim().toLowerCase().contains('admin'))
        .map((d) => d.departmentId)
        .toSet();

    final totalDepartmentsCount = tenantProv.tenantDepartments.length;

    // Filter to only users who strictly belong to the Supervisor department
    // Exclude administrators, tenant owners, or users with access to all departments
    final supervisorUsers = deptProv.tenantUsers.where((u) {
      if (u.accountStatus.isNotEmpty &&
          u.accountStatus.toUpperCase() != 'ACTIVE') {
        return false;
      }

      final hasSupervisorDept =
          u.departmentIds.any((id) => supervisorDeptIds.contains(id));
      if (!hasSupervisorDept) return false;

      // Exclude users assigned to the Administrator department
      final hasAdminDept =
          u.departmentIds.any((id) => adminDeptIds.contains(id));
      if (hasAdminDept) return false;

      // Exclude users assigned to all departments (e.g. tenant creator/owner)
      if (totalDepartmentsCount > 1 &&
          u.departmentIds.length >= totalDepartmentsCount) {
        return false;
      }

      return true;
    }).toList();

    String? selectedUserId = supervisorUsers.isNotEmpty ? supervisorUsers.first.userId : null;
    final prodProvInit = context.read<ProductionProvider>();
    final initialExisting = prodProvInit.assignmentsForItem(po.poId, item.itemId);
    final initialAssigned = initialExisting.fold<int>(0, (s, a) => s + a.assignedCartons);
    final initialRemaining = item.cartons - initialAssigned;
    int assignedQty = initialRemaining > 0 ? initialRemaining : 0;
    final notesController = TextEditingController();
    DateTime selectedTargetDate = po.expectedShippingDate ?? DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final prodProv = ctx.watch<ProductionProvider>();
          final existingAssignments = prodProv.assignmentsForItem(po.poId, item.itemId);
          final totalAssigned = existingAssignments.fold<int>(0, (s, a) => s + a.assignedCartons);
          final remainingToAssign = (item.cartons - totalAssigned).clamp(0, item.cartons);
          final canAssignMore = remainingToAssign > 0 && supervisorUsers.isNotEmpty;
          if (remainingToAssign <= 0) {
            assignedQty = 0;
          } else if (assignedQty <= 0 || assignedQty > remainingToAssign) {
            assignedQty = remainingToAssign;
          }

          return AlertDialog(
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
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary metrics strip
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _summaryChip('PO Requirement: ${item.cartons} ctns', const Color(0xFFF1F5F9), const Color(0xFF334155)),
                        _summaryChip('Assigned: $totalAssigned ctns', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                        _summaryChip(
                          remainingToAssign > 0 ? 'Remaining: $remainingToAssign ctns' : 'Fully Assigned',
                          remainingToAssign > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                          remainingToAssign > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D),
                        ),
                      ],
                    ),

                    if (existingAssignments.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Already Assigned Supervisors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...existingAssignments.map((a) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18, color: Color(0xFF0F172A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.supervisorName.isNotEmpty ? a.supervisorName : a.supervisorUserId,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Assigned: ${a.assignedCartons} ctns • Produced: ${a.completedCartons}/${a.assignedCartons} (${a.status})${a.targetDate != null ? ' • Date: ${dateFmt.format(a.targetDate!)}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (a.notes.isNotEmpty)
                                      Text(
                                        a.notes,
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF0F766E)),
                                tooltip: 'Reassign / Edit Qty',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                onPressed: () async {
                                  final poProv = context.read<PurchaseOrderProvider>();
                                  final prodProvInner = context.read<ProductionProvider>();
                                  await _showEditAssignmentDialog(
                                    context,
                                    assignment: a,
                                    maxAllowedCartons: item.cartons - (totalAssigned - a.assignedCartons),
                                    supervisorUsers: supervisorUsers,
                                    tenantDepartments: tenantProv.tenantDepartments,
                                    onUpdated: () async {
                                      await poProv.loadPurchaseOrders();
                                      await prodProvInner.loadAllAssignments();
                                      final updatedList = prodProvInner.assignmentsForItem(po.poId, item.itemId);
                                      final newAssigned = updatedList.fold<int>(0, (s, x) => s + x.assignedCartons);
                                      final newRem = item.cartons - newAssigned;
                                      setDialogState(() => assignedQty = newRem > 0 ? newRem : 0);
                                      onUpdated?.call();
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFDC2626)),
                                tooltip: 'Unassign',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                onPressed: () async {
                                  final poProv = context.read<PurchaseOrderProvider>();
                                  final prodProvInner = context.read<ProductionProvider>();
                                  final ok = await prodProvInner.cancelAssignment(a.assignmentId);
                                  if (ok) {
                                    await poProv.loadPurchaseOrders();
                                    final updatedList = prodProvInner.assignmentsForItem(po.poId, item.itemId);
                                    final newAssigned = updatedList.fold<int>(0, (s, x) => s + x.assignedCartons);
                                    final newRem = item.cartons - newAssigned;
                                    setDialogState(() => assignedQty = newRem > 0 ? newRem : 0);
                                    onUpdated?.call();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    ],

                    const SizedBox(height: 6),
                    Text(
                      existingAssignments.isNotEmpty
                          ? 'Assign Another / Additional Supervisor'
                          : 'Select Supervisor',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                if (supervisorUsers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your tenant has no supervisors to assign.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: supervisorUsers.map((u) {
                      final dept = tenantProv.tenantDepartments.firstWhere(
                        (d) => u.departmentIds.contains(d.departmentId),
                        orElse: () => DepartmentModel(
                          departmentId: '',
                          tenantId: '',
                          departmentName: 'Supervisor',
                          description: '',
                          permissionIds: [],
                          isActive: true,
                        ),
                      );
                      final name = u.fullName.isNotEmpty ? u.fullName : u.userName;
                      final username = u.userName.isNotEmpty ? '(@${u.userName})' : '';
                      final display = '$name $username • ${dept.departmentName}'.trim();
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Assigned Cartons',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155))),
                    Text(
                      'Max available: $remainingToAssign ctns',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: remainingToAssign > 0
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildCartonStepper(
                  value: assignedQty,
                  min: remainingToAssign > 0 ? 1 : 0,
                  max: remainingToAssign,
                  enabled: canAssignMore,
                  onChanged: (val) => setDialogState(() => assignedQty = val),
                ),
                const SizedBox(height: 14),
                const Text('Target / Assigned Date',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: canAssignMore
                      ? () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedTargetDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedTargetDate = picked);
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: canAssignMore
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateFmt.format(selectedTargetDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(Icons.edit_calendar_outlined,
                            size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                if (remainingToAssign <= 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Color(0xFF15803D)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '0 cartons left to assign. Edit or unassign an existing supervisor above to free cartons.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Production Instructions / Notes',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  enabled: canAssignMore,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canAssignMore ? Colors.black : const Color(0xFF94A3B8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: !canAssignMore
                  ? null
                  : () async {
                      final qty = assignedQty;
                      if (selectedUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Your tenant has no supervisors to assign.')),
                        );
                        return;
                      }
                      if (qty <= 0 || qty > remainingToAssign) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Please select a carton count between 1 and $remainingToAssign.')),
                        );
                        return;
                      }
                      final prodProv = context.read<ProductionProvider>();
                      final poProv = context.read<PurchaseOrderProvider>();
                      final success = await prodProv.createAssignment(
                        poId: po.poId,
                        itemId: item.itemId,
                        supervisorUserId: selectedUserId!,
                        assignedCartons: qty,
                        notes: notesController.text.trim(),
                        targetDate: selectedTargetDate,
                      );
                      if (success) {
                        notesController.clear();
                        await poProv.loadPurchaseOrders();
                        await prodProv.loadAllAssignments();
                        final updatedList = prodProv.assignmentsForItem(po.poId, item.itemId);
                        final newAssigned = updatedList.fold<int>(0, (s, x) => s + x.assignedCartons);
                        final newRem = item.cartons - newAssigned;
                        setDialogState(() => assignedQty = newRem > 0 ? newRem : 0);
                        onUpdated?.call();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Successfully assigned $qty cartons to supervisor.'),
                              backgroundColor: const Color(0xFF15803D),
                            ),
                          );
                        }
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
        );
      },
    ),
    );
  }

  static Widget _summaryChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  static Widget _buildCartonStepper({
    required int value,
    required int min,
    required int max,
    required bool enabled,
    required ValueChanged<int> onChanged,
  }) {
    final canDecrement = enabled && value > min;
    final canIncrement = enabled && value < max;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: canDecrement ? () => onChanged(value - 1) : null,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(5)),
            child: Container(
              width: 48,
              height: double.infinity,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Icon(
                Icons.remove,
                size: 18,
                color: canDecrement ? Colors.black : const Color(0xFFCBD5E1),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value ctns',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: canIncrement ? () => onChanged(value + 1) : null,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(5)),
            child: Container(
              width: 48,
              height: double.infinity,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: canIncrement ? Colors.black : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showEditAssignmentDialog(
    BuildContext context, {
    required ProductionAssignmentModel assignment,
    required int maxAllowedCartons,
    required List<TenantUserModel> supervisorUsers,
    required List<DepartmentModel> tenantDepartments,
    required Future<void> Function() onUpdated,
  }) async {
    String? editedSupervisorId =
        supervisorUsers.any((u) => u.userId == assignment.supervisorUserId)
            ? assignment.supervisorUserId
            : (supervisorUsers.isNotEmpty ? supervisorUsers.first.userId : null);
    final minAllowed =
        assignment.completedCartons > 0 ? assignment.completedCartons : 1;
    int editedQty = assignment.assignedCartons.clamp(minAllowed, maxAllowedCartons);
    final notesCtrl = TextEditingController(text: assignment.notes);
    DateTime editedDate = assignment.targetDate ?? DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Reassign / Edit Assignment',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Produced so far: ${assignment.completedCartons} ctns',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                const Text('Supervisor',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (supervisorUsers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: editedSupervisorId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: supervisorUsers.map((u) {
                      final dept = tenantDepartments.firstWhere(
                        (d) => u.departmentIds.contains(d.departmentId),
                        orElse: () => DepartmentModel(
                          departmentId: '',
                          tenantId: '',
                          departmentName: 'Supervisor',
                          description: '',
                          permissionIds: [],
                          isActive: true,
                        ),
                      );
                      final name = u.fullName.isNotEmpty ? u.fullName : u.userName;
                      final username = u.userName.isNotEmpty ? '(@${u.userName})' : '';
                      return DropdownMenuItem(
                        value: u.userId,
                        child: Text(
                          '$name $username • ${dept.departmentName}'.trim(),
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => editedSupervisorId = v);
                    },
                  ),
                const SizedBox(height: 12),
                Text('Assigned Cartons (Max: $maxAllowedCartons)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _buildCartonStepper(
                  value: editedQty,
                  min: minAllowed,
                  max: maxAllowedCartons,
                  enabled: maxAllowedCartons >= minAllowed,
                  onChanged: (val) => setDlgState(() => editedQty = val),
                ),
                const SizedBox(height: 12),
                const Text('Target / Assigned Date',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: editedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDlgState(() => editedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateFmt.format(editedDate),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Notes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
              ),
              onPressed: () async {
                final newQty = editedQty;
                if (newQty < minAllowed || newQty > maxAllowedCartons) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Assigned cartons must be between $minAllowed and $maxAllowedCartons.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final ok = await context.read<ProductionProvider>().updateAssignment(
                      assignmentId: assignment.assignmentId,
                      supervisorUserId: editedSupervisorId,
                      assignedCartons: newQty,
                      notes: notesCtrl.text.trim(),
                      targetDate: editedDate,
                    );
                if (ok) {
                  await onUpdated();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assignment updated successfully.'),
                        backgroundColor: Color(0xFF15803D),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
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
