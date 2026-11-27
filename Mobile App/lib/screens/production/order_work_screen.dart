import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../providers/production_provider.dart';
import '../../providers/tenant_provider.dart';
import '../dashboard/department_workspace.dart';
import 'order_account_detail_screen.dart';

typedef WorkRecord = Map<String, dynamic>;

List<WorkRecord> workRecords(Object? value) =>
    (value as List? ?? const []).cast<WorkRecord>();

String workText(WorkRecord record, String key) => record[key]?.toString() ?? '';

int _count(WorkRecord record, String key) =>
    (record[key] as num?)?.toInt() ?? 0;

String workDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '' : DateFormat.yMMMd().format(date.toLocal());
}

String workStatus(Object? value) =>
    value.toString().replaceAll('_', ' ').toLowerCase();

class OrderWorkScreen extends StatefulWidget {
  const OrderWorkScreen({super.key, required this.workspace});

  final DepartmentWorkspace workspace;

  @override
  State<OrderWorkScreen> createState() => _OrderWorkScreenState();
}

class _OrderWorkScreenState extends State<OrderWorkScreen> {
  late Future<List<WorkRecord>> _orders;
  late final ApiClient _api = context.read<TenantProvider>().apiClient;
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  Future<List<WorkRecord>> _load() async => workRecords(
    await _api.get('/order-work?department=${widget.workspace.orderWorkRole}'),
  );

  Future<void> _refresh() async {
    final updated = _load();
    setState(() => _orders = updated);
    try {
      await updated;
    } catch (_) {
      // FutureBuilder displays the load error.
    }
  }

  void _message(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) await _refresh();
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assign(
    WorkRecord order,
    WorkRecord item, {
    required bool quality,
    WorkRecord? existingAssignment,
  }) async {
    final production = context.read<ProductionProvider>();
    final WorkRecord staff;
    try {
      staff = await _api.get('/order-work/staff') as WorkRecord;
    } catch (error) {
      _message(error);
      return;
    }
    if (!mounted || _saving) return;

    final people = workRecords(staff[quality ? 'quality' : 'supervisors']);
    if (people.isEmpty) {
      _message(
        quality
            ? 'No QA users are assigned to this tenant.'
            : 'No supervisors are assigned to this tenant.',
      );
      return;
    }
    final assignments = workRecords(item['assignments']);
    final existingId = existingAssignment?['assignment_id'];
    final remaining = _count(item, 'cartons') - assignments
        .where((entry) => entry['assignment_id'] != existingId)
        .fold<int>(0, (sum, entry) => sum + _count(entry, 'assigned_cartons'));
    if (!quality && remaining < 1) {
      _message('All cartons on this item are already assigned.');
      return;
    }

    final assignment = await showDialog<_AssignmentInput>(
      context: context,
      builder: (_) => _AssignmentDialog(
        quality: quality,
        people: people,
        remaining: remaining,
        currentUserId: quality
            ? workText(item, 'qa_user_id')
            : workText(existingAssignment ?? const {}, 'assignee_id'),
        initialCartons: existingAssignment == null ? remaining : _count(existingAssignment, 'assigned_cartons'),
        initialDate: DateTime.tryParse((quality ? item['target_date'] : existingAssignment?['target_date'])?.toString() ?? '')?.toLocal(),
        editing: existingAssignment != null,

      ),
    );
    if (assignment == null || !mounted) return;
    final poId = workText(order, 'po_id');
    final itemId = workText(item, 'item_id');
    await _save(() async {
      if (quality) {
        await _api.patch(
          '/order-work/$poId/items/$itemId/quality-assignment',
          body: {
            'user_id': assignment.userId,
            if (assignment.date != null)
              'target_date': assignment.date!.toUtc().toIso8601String(),
          },
        );
      } else {
        final saved = existingAssignment == null
            ? await production.createAssignment(
                poId: poId,
                itemId: itemId,
                supervisorUserId: assignment.userId,
                assignedCartons: assignment.cartons,
                targetDate: assignment.date,
              )
            : await production.updateAssignment(
                assignmentId: workText(existingAssignment, 'assignment_id'),
                supervisorUserId: assignment.userId,
                assignedCartons: assignment.cartons,
                targetDate: assignment.date,
              );
        if (!saved)
          throw ApiException(
            production.errorMessage ?? 'Assignment could not be saved.',
          );
      }
    });
  }

  Future<void> _cancelAssignment(WorkRecord assignment) async {
    final production = context.read<ProductionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel assignment?'),
        content: Text(
          'This will remove the allocation for ${workText(assignment, 'assignee')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel assignment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(() async {
      if (!await production.cancelAssignment(
        workText(assignment, 'assignment_id'),
      )) {
        throw ApiException(
          production.errorMessage ?? 'Assignment could not be cancelled.',
        );
      }
    });
  }

  Future<void> _progress(WorkRecord assignment) async {
    final production = context.read<ProductionProvider>();
    final assigned = _count(assignment, 'assigned_cartons');
    var input = '${_count(assignment, 'completed_cartons')}';
    final form = GlobalKey<FormState>();
    final completed = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update production'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Completed cartons out of $assigned',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => input = value,
            validator: (value) {
              final cartons = int.tryParse(value?.trim() ?? '');
              return cartons == null || cartons < 0 || cartons > assigned
                  ? 'Enter a whole number from 0 to $assigned.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(context, int.parse(input.trim()));
            },
            child: const Text('Save progress'),
          ),
        ],
      ),
    );
    if (completed == null || !mounted) return;
    await _save(() async {
      final saved = await production.updateProgress(
        assignmentId: workText(assignment, 'assignment_id'),
        completedCartons: completed,
      );
      if (!saved)
        throw ApiException(
          production.errorMessage ?? 'Progress could not be saved.',
        );
    });
  }

  Future<void> _check(WorkRecord order, WorkRecord item) async {
    var note = '';
    final checkedNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark item checked'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Optional note'),
          maxLength: 1000,
          maxLines: 3,
          onChanged: (value) => note = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, note.trim()),
            child: const Text('Mark checked'),
          ),
        ],
      ),
    );
    if (checkedNote == null || !mounted) return;
    await _save(() async {
      final poId = workText(order, 'po_id');
      final itemId = workText(item, 'item_id');
      await _api.patch(
        '/order-work/$poId/items/$itemId/quality-check',
        body: {'note': checkedNote},
      );
    });
  }

  Future<void> _pack(WorkRecord order, WorkRecord item) => _save(() async {
    final poId = workText(order, 'po_id');
    final itemId = workText(item, 'item_id');
    await _api.patch(
      '${ApiConstants.purchaseOrders}/$poId/items/$itemId/packing',
      body: {'packed_cartons': _count(item, 'cartons')},
    );
  });

  @override
  Widget build(BuildContext context) {
    final accent = widget.workspace.color;
    return Scaffold(
      appBar: AppBar(title: Text(widget.workspace.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              if (_saving) LinearProgressIndicator(color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Find by PO number or customer',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<WorkRecord>>(
                  future: _orders,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            'Retry loading orders · ${snapshot.error}',
                          ),
                        ),
                      );
                    }
                    final matching = (snapshot.data ?? const [])
                        .where(
                          (order) =>
                              '${order['po_number']} ${order['customer_name']}'
                                  .toLowerCase()
                                  .contains(_query),
                        )
                        .toList();
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: matching.isEmpty ? 1 : matching.length,
                        itemBuilder: (context, index) => matching.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text('No matching orders.'),
                                ),
                              )
                            : _orderCard(matching[index]),
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

  Widget _orderCard(WorkRecord order) {
    final number = workText(order, 'po_number');
    final summary = [
      workText(order, 'customer_name'),
      workDate(order['po_date']),
      workStatus(order['status']),
    ].where((part) => part.isNotEmpty).join(' · ');
    final items = workRecords(order['items']);
    final editable = !_saving && order['editable'] == true;

    if (widget.workspace == DepartmentWorkspace.accounts) {
      return Card(
        child: ListTile(
          title: Text(number),
          subtitle: Text(summary),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  OrderAccountDetailScreen(poId: workText(order, 'po_id')),
            ),
          ),
        ),
      );
    }

    if (widget.workspace == DepartmentWorkspace.export) {
      final total = _count(order, 'total_cartons');
      final packed = _count(order, 'packed_cartons');
      final fraction = total == 0 ? 0.0 : (packed / total).clamp(0.0, 1.0);
      final shippingDate = workDate(order['expected_shipping_date']);
      return Card(
        child: ListTile(
          title: Text(number),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary),
              if (shippingDate.isNotEmpty)
                Text('Expected shipping $shippingDate'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: fraction,
                color: widget.workspace.color,
              ),
              Text(
                '${(fraction * 100).round()}% ready · $packed of $total cartons packed',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(workText(order, 'po_id')),
        title: Text(number),
        subtitle: Text(summary),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final item in items) ...[
            const Divider(),
            _line(order, item, editable),
          ],
          if (items.isEmpty) const Text('No assigned items on this order.'),
        ],
      ),
    );
  }

  Widget _line(WorkRecord order, WorkRecord item, bool editable) {
    final assignments = workRecords(item['assignments']);
    final cartons = _count(item, 'cartons');
    final checked = item['checked_at'] != null;
    final sku = workText(item, 'sku');
    final manager = widget.workspace == DepartmentWorkspace.productionManager;
    final qaDate = workDate(item['target_date']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          workText(item, 'item_name'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (sku.isNotEmpty) Text(sku),
        if (manager) ...[
          Text('$cartons ordered cartons'),
          if (workText(item, 'qa_assignee').isNotEmpty)
            Text(
              'QA · ${item['qa_assignee']}${qaDate.isEmpty ? '' : ' · $qaDate'}${checked ? ' · Checked' : ''}',
            ),
          for (final assignment in assignments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(workText(assignment, 'assignee')),
              subtitle: Text(_assignmentSummary(assignment)),
              trailing: editable && _count(assignment, 'completed_cartons') == 0
                  ? PopupMenuButton<String>(
                      tooltip: 'Manage assignment',
                      onSelected: (choice) {
                        if (choice == 'edit') {
                          _assign(order, item, quality: false, existingAssignment: assignment);
                        } else {
                          _cancelAssignment(assignment);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit assignment')),
                        PopupMenuItem(value: 'cancel', child: Text('Cancel assignment')),
                      ],
                    )
                  : null,
            ),
          if (editable)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _assign(order, item, quality: false),
                  child: const Text('Assign supervisor'),
                ),
                if (!checked)
                  OutlinedButton(
                    onPressed: () => _assign(order, item, quality: true),
                    child: Text(
                      workText(item, 'qa_user_id').isEmpty
                          ? 'Assign QA'
                          : 'Reassign QA',
                    ),
                  ),
              ],
            ),
        ],
        if (widget.workspace == DepartmentWorkspace.supervisor)
          for (final assignment in assignments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_assignmentSummary(assignment)),
              subtitle: workText(assignment, 'notes').isEmpty
                  ? null
                  : Text(workText(assignment, 'notes')),
              trailing: editable
                  ? IconButton(
                      tooltip: 'Update production',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _progress(assignment),
                    )
                  : null,
            ),
        if (widget.workspace == DepartmentWorkspace.quality) ...[
          Text('$cartons cartons${qaDate.isEmpty ? '' : ' · Due $qaDate'}'),
          if (checked) Text('Checked ${workDate(item['checked_at'])}'),
          if (checked && workText(item, 'note').isNotEmpty)
            Text(workText(item, 'note')),
          if (!checked && editable)
            FilledButton(
              onPressed: () => _check(order, item),
              child: const Text('Mark checked'),
            ),
        ],
        if (widget.workspace == DepartmentWorkspace.packing) ...[
          Text('${_count(item, 'packed_cartons')} of $cartons cartons packed'),
          if (editable && _count(item, 'packed_cartons') < cartons)
            FilledButton(
              onPressed: () => _pack(order, item),
              child: const Text('Mark packed'),
            ),
        ],
      ],
    );
  }

  String _assignmentSummary(WorkRecord assignment) => [
    '${_count(assignment, 'completed_cartons')} of ${_count(assignment, 'assigned_cartons')} cartons',
    workStatus(assignment['status']),
    workDate(assignment['target_date']),
  ].where((part) => part.isNotEmpty).join(' · ');
}

class _AssignmentInput {
  const _AssignmentInput(this.userId, this.cartons, this.date);
  final String userId;
  final int cartons;
  final DateTime? date;
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({
    required this.quality,
    required this.people,
    required this.remaining,
    required this.currentUserId,
    required this.initialCartons,
    required this.initialDate,
    required this.editing,
  });

  final bool quality;
  final List<WorkRecord> people;
  final int remaining;
  final String currentUserId;
  final int initialCartons;
  final DateTime? initialDate;
  final bool editing;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _form = GlobalKey<FormState>();
  late String _cartons = '${widget.initialCartons}';
  late String? _userId =
      widget.people.any((person) => person['user_id'] == widget.currentUserId)
      ? widget.currentUserId
      : null;
  late DateTime? _date = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.quality ? 'Assign quality check' : widget.editing ? 'Edit production assignment' : 'Assign production',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _userId,
                decoration: InputDecoration(
                  labelText: widget.quality ? 'QA user' : 'Supervisor',
                ),
                items: [
                  for (final person in widget.people)
                    DropdownMenuItem(
                      value: workText(person, 'user_id'),
                      child: Text(
                        workText(person, 'name'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => _userId = value,
                validator: (value) =>
                    value == null ? 'Choose an assignee.' : null,
              ),
              if (!widget.quality)
                TextFormField(
                  initialValue: _cartons,
                  decoration: InputDecoration(
                    labelText: 'Cartons · ${widget.remaining} available',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _cartons = value,
                  validator: (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    return count == null ||
                            count < 1 ||
                            count > widget.remaining
                        ? 'Enter 1 to ${widget.remaining} cartons.'
                        : null;
                  },
                ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _date == null ? 'Set due date (optional)' : workDate(_date),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) setState(() => _date = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                _AssignmentInput(
                  _userId!,
                  int.tryParse(_cartons.trim()) ?? 0,
                  _date,
                ),
              );
            }
          },
          child: Text(widget.editing ? 'Save assignment' : 'Assign'),
        ),
      ],
    );
  }
}
