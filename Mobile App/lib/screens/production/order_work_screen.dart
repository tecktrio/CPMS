import '../../widgets/cpms_page_route.dart';

import 'package:flutter/material.dart';

import '../../widgets/cpms_form_page.dart';
import '../../widgets/cpms_loading_page.dart';
import '../../widgets/cpms_page_title.dart';
import '../../widgets/order_split_view.dart';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../providers/production_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../utils/file_downloader/file_downloader.dart';
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
  const OrderWorkScreen({
    super.key,
    required this.workspace,
    this.embedded = false,
  });

  final bool embedded;
  final DepartmentWorkspace workspace;

  @override
  State<OrderWorkScreen> createState() => _OrderWorkScreenState();
}

class _OrderWorkScreenState extends State<OrderWorkScreen> {
  late Future<List<WorkRecord>> _orders;
  late final ApiClient _api = context.read<TenantProvider>().apiClient;
  String _query = '';
  String? _selectedOrderId;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _saving = false;
  bool _openingAssignment = false;
  bool _exportingHistory = false;

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
      await runWithLoadingPage<void>(
        context,
        message: 'Saving changes…',
        operation: () async {
          await action();
          if (mounted) await _refresh();
        },
      );
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
    if (_openingAssignment || _saving) return;
    _openingAssignment = true;
    try {
      await _openAssignment(
        order,
        item,
        quality: quality,
        existingAssignment: existingAssignment,
      );
    } finally {
      _openingAssignment = false;
    }
  }

  Future<void> _openAssignment(
    WorkRecord order,
    WorkRecord item, {
    required bool quality,
    WorkRecord? existingAssignment,
  }) async {
    final production = context.read<ProductionProvider>();
    final remaining = _remainingCartons(
      item,
      editingAssignmentId: existingAssignment?['assignment_id'] as String?,
    );
    if (!quality && remaining < 1) {
      _message('All cartons on this item are already assigned.');
      return;
    }

    final staff = _api
        .get('/order-work/staff')
        .then(
          (response) => workRecords(
            (response as WorkRecord)[quality ? 'quality' : 'supervisors'],
          ),
        );
    final assignment = await openCpmsPage<_AssignmentInput>(
      context: context,
      builder: (_) => FutureBuilder<List<WorkRecord>>(
        future: staff,
        builder: (context, snapshot) {
          final people = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return PopScope(
              canPop: false,
              child: CpmsFormPage(
                title: Text(
                  quality ? 'QA assignment' : 'Supervisor assignment',
                ),
                content: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      quality
                          ? 'Loading QA assignees…'
                          : 'Loading supervisors…',
                    ),
                  ],
                ),
                actions: const [],
              ),
            );
          }
          if (people == null || people.isEmpty) {
            final message = snapshot.hasError
                ? 'Could not load assignees. ${snapshot.error}'
                : quality
                ? 'No eligible Quality Assurance users found.'
                : 'No supervisors are assigned to this tenant.';
            return CpmsFormPage(
              title: Text(quality ? 'QA assignment' : 'Supervisor assignment'),
              content: Text(message),
              actions: const [],
            );
          }
          return _AssignmentPage(
            quality: quality,
            orderNumber: workText(order, 'po_number'),
            itemName: workText(item, 'item_name'),
            sku: workText(item, 'sku'),
            people: people,
            remaining: remaining,
            currentUserId: quality
                ? workText(item, 'qa_user_id')
                : workText(existingAssignment ?? const {}, 'assignee_id'),
            initialCartons: existingAssignment == null
                ? remaining
                : _count(existingAssignment, 'assigned_cartons'),
            initialDate: DateTime.tryParse(
              (quality
                          ? item['target_date']
                          : existingAssignment?['target_date'])
                      ?.toString() ??
                  '',
            )?.toLocal(),
            editing: existingAssignment != null,
          );
        },
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
        if (!saved) {
          throw ApiException(
            production.errorMessage ?? 'Assignment could not be saved.',
          );
        }
      }
    });
  }

  Future<void> _cancelAssignment(WorkRecord assignment) async {
    final production = context.read<ProductionProvider>();
    final confirmed = await openCpmsPage<bool>(
      context: context,
      builder: (context) => CpmsFormPage(
        icon: Icons.event_busy_outlined,
        title: const Text('Unassign supervisor?'),
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
            child: const Text('Unassign'),
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
    final completed = await openCpmsPage<int>(
      context: context,
      builder: (context) => CpmsFormPage(
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
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input.trim()));
              }
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
      if (!saved) {
        throw ApiException(
          production.errorMessage ?? 'Progress could not be saved.',
        );
      }
    });
  }

  Future<void> _check(WorkRecord order, WorkRecord item) async {
    var note = '';
    final checkedNote = await openCpmsPage<String>(
      context: context,
      builder: (context) => CpmsFormPage(
        icon: Icons.fact_check_outlined,
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

  Future<void> _pack(WorkRecord order, WorkRecord item) async {
    final cartons = _count(item, 'cartons');
    final confirmed = await openCpmsPage<bool>(
      context: context,
      builder: (context) => CpmsFormPage(
        icon: Icons.inventory_2_outlined,
        title: const Text('Mark item packed'),
        content: Text(
          '${workText(item, 'item_name')} · ${workText(order, 'po_number')}\n'
          'Record all $cartons cartons as packed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark packed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(() async {
      final poId = workText(order, 'po_id');
      final itemId = workText(item, 'item_id');
      await _api.patch(
        '${ApiConstants.purchaseOrders}/$poId/items/$itemId/packing',
        body: {'packed_cartons': cartons},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.workspace.color;
    final searchField = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Find by PO number or customer',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        primary: !widget.embedded,
        automaticallyImplyLeading: !widget.embedded,
        title: CpmsPageTitle(
          widget.workspace.title,
          icon: widget.workspace.icon,
          accent: accent,
        ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _refresh,
            tooltip: 'Refresh orders',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final split =
              widget.embedded &&
              constraints.maxWidth >= OrderSplitView.minimumWidth;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: split ? double.infinity : 920,
              ),
              child: Column(
                children: [
                  if (_saving) LinearProgressIndicator(color: accent),
                  if (!split) searchField,
                  Expanded(
                    child: FutureBuilder<List<WorkRecord>>(
                      future: _orders,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                        if (split) return _splitOrders(matching, searchField);
                        return RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: matching.length + 1,
                            itemBuilder: (context, index) {
                              if (index > 0)
                                return _orderCard(matching[index - 1]);
                              if (matching.isEmpty) {
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        Icon(
                                          widget.workspace.icon,
                                          color: accent,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _query.isEmpty
                                              ? 'No orders in this workspace yet.'
                                              : 'No orders match your search.',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  6,
                                ),
                                child: Text(
                                  '${matching.length} ${matching.length == 1 ? 'order' : 'orders'}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _splitOrders(List<WorkRecord> orders, Widget searchField) {
    final selected = orders
        .where((order) => workText(order, 'po_id') == _selectedOrderId)
        .firstOrNull;

    return OrderSplitView(
      orders: Column(
        children: [
          searchField,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: orders.isEmpty ? 1 : orders.length,
                itemBuilder: (context, index) {
                  if (orders.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _query.isEmpty
                            ? 'No orders in this workspace yet.'
                            : 'No orders match your search.',
                      ),
                    );
                  }
                  final order = orders[index];
                  return ListTile(
                    selected: order == selected,
                    selectedTileColor: widget.workspace.color.withValues(
                      alpha: 0.10,
                    ),
                    selectedColor: widget.workspace.color,
                    title: Text(workText(order, 'po_number')),
                    subtitle: Text(_orderSummary(order)),
                    onTap: () => setState(() {
                      _selectedOrderId = workText(order, 'po_id');
                    }),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      detail: selected == null ? null : _orderDetail(selected),
    );
  }

  String _orderSummary(WorkRecord order) => [
    workText(order, 'customer_name'),
    workDate(order['po_date']),
    workStatus(order['status']),
  ].where((part) => part.isNotEmpty).join(' · ');

  Widget _orderDetail(WorkRecord order) {
    final id = workText(order, 'po_id');
    if (widget.workspace == DepartmentWorkspace.accounts) {
      return OrderAccountDetailScreen(
        key: ValueKey(id),
        poId: id,
        embedded: true,
      );
    }

    return ListView(
      key: ValueKey(id),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          workText(order, 'po_number'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(_orderSummary(order)),
        const SizedBox(height: 16),
        if (widget.workspace == DepartmentWorkspace.export)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _exportReadiness(order),
              ),
            ),
          )
        else
          ..._orderLines(order),
      ],
    );
  }

  Widget _orderCard(WorkRecord order) {
    final number = workText(order, 'po_number');
    final summary = _orderSummary(order);

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
      return Card(
        child: ListTile(
          title: Text(number),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(summary), ..._exportReadiness(order)],
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
        children: _orderLines(order),
      ),
    );
  }

  List<Widget> _exportReadiness(WorkRecord order) {
    final total = _count(order, 'total_cartons');
    final packed = _count(order, 'packed_cartons');
    final fraction = total == 0 ? 0.0 : (packed / total).clamp(0.0, 1.0);
    final shippingDate = workDate(order['expected_shipping_date']);
    return [
      if (shippingDate.isNotEmpty) Text('Expected shipping $shippingDate'),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: fraction, color: widget.workspace.color),
      Text(
        '${(fraction * 100).round()}% ready · $packed of $total cartons packed',
      ),
    ];
  }

  List<Widget> _orderLines(WorkRecord order) {
    final items = workRecords(order['items']);
    final editable = !_saving && order['editable'] == true;
    return [
      for (final item in items)
        Card.outlined(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _line(order, item, editable),
          ),
        ),
      if (items.isEmpty) const Text('No assigned items on this order.'),
    ];
  }

  Widget _line(WorkRecord order, WorkRecord item, bool editable) {
    final assignments = workRecords(item['assignments']);
    final cartons = _count(item, 'cartons');
    final checked = item['checked_at'] != null;
    final sku = workText(item, 'sku');
    final manager = widget.workspace == DepartmentWorkspace.productionManager;
    final qaDate = workDate(item['target_date']);
    final actions = _itemActions(order, item, editable);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(workText(item, 'item_name'), style: theme.textTheme.titleMedium),
        if (sku.isNotEmpty)
          Text(
            sku,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        if (manager) ...[
          Text('$cartons ordered cartons'),
          const SizedBox(height: 12),
          _qualityAssignment(order, item, qaDate, editable),
          if (assignments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _supervisorAssignments(order, item, assignments, editable),
          ],
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
        ],
        if (widget.workspace == DepartmentWorkspace.packing)
          Text('${_count(item, 'packed_cartons')} of $cartons cartons packed'),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }

  Widget _qualityAssignment(
    WorkRecord order,
    WorkRecord item,
    String dueDate,
    bool editable,
  ) {
    final assignee = workText(item, 'qa_assignee');
    final assigned =
        workText(item, 'qa_user_id').isNotEmpty || assignee.isNotEmpty;
    final checked = item['checked_at'] != null;
    return _assignmentTable(
      columns: const ['QA', 'Due date', 'Assignment', 'History'],
      columnWidths: const {2: FlexColumnWidth(1.5)},
      rows: [
        TableRow(
          children: [
            _assignmentCell(
              Text(
                assignee.isNotEmpty
                    ? assignee
                    : assigned
                    ? 'Assigned'
                    : 'Unassigned',
              ),
            ),
            _assignmentCell(Text(dueDate.isEmpty ? '—' : dueDate)),
            _assignmentCell(
              editable && !checked
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () => _assign(order, item, quality: true),
                        child: Text(assigned ? 'Reassign QA' : 'Assign QA'),
                      ),
                    )
                  : Text(checked ? 'Checked' : '—'),
            ),
            _assignmentCell(
              _historyButton(order, item, record: item, quality: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _supervisorAssignments(
    WorkRecord order,
    WorkRecord item,
    List<WorkRecord> assignments,
    bool editable,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 680 ? 680 : constraints.maxWidth,
          child: _assignmentTable(
            columns: const [
              'Carton qty',
              'Supervisor',
              'Assigned date',
              'Completion',
              'Reassign',
              'Unassign',
              'History',
            ],
            columnWidths: const {1: FlexColumnWidth(1.5)},
            rows: [
              for (final assignment in assignments)
                _supervisorAssignmentRow(order, item, assignment, editable),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assignmentTable({
    required List<String> columns,
    required Map<int, TableColumnWidth> columnWidths,
    required List<TableRow> rows,
  }) {
    final theme = Theme.of(context);
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
          ),
          children: [
            for (final label in columns)
              _assignmentCell(Text(label, style: theme.textTheme.labelMedium)),
          ],
        ),
        ...rows,
      ],
    );
  }

  TableRow _supervisorAssignmentRow(
    WorkRecord order,
    WorkRecord item,
    WorkRecord assignment,
    bool editable,
  ) {
    final assigned = _count(assignment, 'assigned_cartons');
    final completed = _count(assignment, 'completed_cartons');
    final completion = assigned > 0 ? (completed / assigned * 100).round() : 0;
    final assignedDate = workDate(assignment['assigned_at']);
    final dueDate = workDate(assignment['target_date']);
    final cancelled = assignment['status'] == 'CANCELLED';
    final canChange = editable && completed == 0 && !cancelled;

    return TableRow(
      children: [
        _assignmentCell(Text('$assigned')),
        _assignmentCell(Text(workText(assignment, 'assignee'))),
        _assignmentCell(
          Tooltip(
            message: dueDate.isEmpty ? 'Assigned date' : 'Due $dueDate',
            child: Text(assignedDate.isEmpty ? '—' : assignedDate),
          ),
        ),
        _assignmentCell(Text(cancelled ? 'Cancelled' : '$completion%')),
        _assignmentCell(
          IconButton(
            tooltip: 'Reassign supervisor',
            icon: const Icon(Icons.swap_horiz),
            onPressed: canChange
                ? () => _assign(
                    order,
                    item,
                    quality: false,
                    existingAssignment: assignment,
                  )
                : null,
          ),
        ),
        _assignmentCell(
          IconButton(
            tooltip: 'Unassign supervisor',
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: canChange ? () => _cancelAssignment(assignment) : null,
          ),
        ),
        _assignmentCell(
          _historyButton(order, item, record: assignment, quality: false),
        ),
      ],
    );
  }

  Widget _historyButton(
    WorkRecord order,
    WorkRecord item, {
    required WorkRecord record,
    required bool quality,
  }) => IconButton(
    tooltip: quality ? 'View QA history' : 'View supervisor history',
    icon: const Icon(Icons.history),
    onPressed: () => _showHistory(order, item, record, quality: quality),
  );

  Future<void> _showHistory(
    WorkRecord order,
    WorkRecord item,
    WorkRecord record, {
    required bool quality,
  }) {
    final entries = workRecords(
      record[quality ? 'qa_completion_history' : 'progress_history'],
    );
    final title = quality
        ? 'QA completion history'
        : 'Supervisor progress history';
    final orderNumber = workText(order, 'po_number');
    final itemName = workText(item, 'item_name');
    final assignmentId = workText(record, 'assignment_id');
    final heading = '$orderNumber · $itemName';
    final columns = quality
        ? const ['Date and time', 'QA assignee', 'Note']
        : const [
            'Date and time',
            'Supervisor',
            'Previous cartons',
            'Completed cartons',
          ];
    final rows = [
      for (final entry in entries.reversed)
        [
          _historyTimestamp(entry['at']),
          if (quality) ...[
            workText(entry, 'user_id') == workText(item, 'qa_user_id') &&
                    workText(item, 'qa_assignee').isNotEmpty
                ? workText(item, 'qa_assignee')
                : workText(entry, 'user_id'),
            workText(entry, 'note'),
          ] else ...[
            workText(entry, 'supervisor_name'),
            workText(entry, 'previous_cartons'),
            workText(entry, 'completed_cartons'),
          ],
        ],
    ];

    return openCpmsPage<void>(
      context: context,
      builder: (dialogContext) => CpmsFormPage(
        icon: Icons.history,
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                heading,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Text('No recorded activity yet.')
              else
                _assignmentTable(
                  columns: columns,
                  columnWidths: const {0: FlexColumnWidth(1.4)},
                  rows: [
                    for (final row in rows)
                      TableRow(
                        children: [
                          for (final value in row) _assignmentCell(Text(value)),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: rows.isEmpty
                ? null
                : () => _exportHistory(
                    title: title,
                    heading: heading,
                    filename: [
                      orderNumber,
                      workText(item, 'item_id'),
                      quality ? 'qa' : assignmentId,
                      'history',
                    ].join('-').replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_'),
                    columns: columns,
                    rows: rows,
                  ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export PDF'),
          ),
        ],
      ),
    );
  }

  String _historyTimestamp(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${DateFormat.yMMMd().add_jms().format(date)} ${date.timeZoneName}';
  }

  Future<void> _exportHistory({
    required String title,
    required String heading,
    required String filename,
    required List<String> columns,
    required List<List<String>> rows,
  }) async {
    if (_exportingHistory) return;
    _exportingHistory = true;
    try {
      final bytes = await runWithLoadingPage(
        context,
        message: 'Preparing history export…',
        operation: () async {
          final regular = await PdfGoogleFonts.interRegular();
          final bold = await PdfGoogleFonts.interBold();
          final document = pw.Document();
          document.addPage(
            pw.MultiPage(
              maxPages: rows.length + 1,
              pageFormat: PdfPageFormat.a4,
              theme: pw.ThemeData.withFont(base: regular, bold: bold),
              header: (_) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(heading),
                  ],
                ),
              ),
              build: (_) => [
                pw.TableHelper.fromTextArray(headers: columns, data: rows),
              ],
            ),
          );
          return document.save();
        },
      );
      if (!mounted) return;
      await FileDownloader.download(
        bytes: bytes,
        filename: '$filename.pdf',
        mimeType: 'application/pdf',
      );
    } catch (error) {
      _message('Could not export history: $error');
    } finally {
      _exportingHistory = false;
    }
  }

  Widget _assignmentCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: child,
  );

  int _remainingCartons(WorkRecord item, {String? editingAssignmentId}) {
    final assigned = workRecords(item['assignments'])
        .where(
          (entry) =>
              entry['status'] != 'CANCELLED' &&
              (editingAssignmentId == null ||
                  entry['assignment_id'] != editingAssignmentId),
        )
        .fold<int>(0, (sum, entry) => sum + _count(entry, 'assigned_cartons'));
    return _count(item, 'cartons') - assigned;
  }

  List<Widget> _itemActions(WorkRecord order, WorkRecord item, bool editable) {
    if (!editable) return const [];
    final checked = item['checked_at'] != null;
    final remaining = _remainingCartons(item);
    return switch (widget.workspace) {
      DepartmentWorkspace.productionManager => [
        if (remaining > 0)
          OutlinedButton(
            onPressed: () => _assign(order, item, quality: false),
            child: Text(
              'Assign remaining $remaining ${remaining == 1 ? 'carton' : 'cartons'} to supervisors',
            ),
          ),
      ],
      DepartmentWorkspace.quality when !checked => [
        FilledButton(
          onPressed: () => _check(order, item),
          child: const Text('Mark checked'),
        ),
      ],
      DepartmentWorkspace.packing
          when _count(item, 'packed_cartons') < _count(item, 'cartons') =>
        [
          FilledButton(
            onPressed: () => _pack(order, item),
            child: const Text('Mark packed'),
          ),
        ],
      _ => const [],
    };
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

class _AssignmentPage extends StatefulWidget {
  const _AssignmentPage({
    required this.quality,
    required this.orderNumber,
    required this.itemName,
    required this.sku,
    required this.people,
    required this.remaining,
    required this.currentUserId,
    required this.initialCartons,
    required this.initialDate,
    required this.editing,
  });

  final bool quality;
  final String orderNumber;
  final String itemName;
  final String sku;
  final List<WorkRecord> people;
  final int remaining;
  final String currentUserId;
  final int initialCartons;
  final DateTime? initialDate;
  final bool editing;

  @override
  State<_AssignmentPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<_AssignmentPage> {
  final _form = GlobalKey<FormState>();
  late String _cartons = '${widget.initialCartons}';
  late String? _userId =
      widget.people.any((person) => person['user_id'] == widget.currentUserId)
      ? widget.currentUserId
      : null;
  late DateTime? _date = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contextLabel = [
      widget.orderNumber,
      widget.sku,
    ].where((value) => value.isNotEmpty).join(' · ');
    return CpmsFormPage(
      icon: widget.quality
          ? Icons.fact_check_outlined
          : Icons.assignment_ind_outlined,
      title: Text(
        widget.quality
            ? (widget.currentUserId.isEmpty ? 'Assign QA' : 'Reassign QA')
            : widget.editing
            ? 'Edit supervisor assignment'
            : 'Assign supervisor',
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.itemName, style: theme.textTheme.titleSmall),
                  if (contextLabel.isNotEmpty)
                    Text(contextLabel, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _userId,
              decoration: InputDecoration(
                labelText: widget.quality ? 'QA assignee' : 'Supervisor',
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
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
            if (!widget.quality) ...[
              const SizedBox(height: 14),
              TextFormField(
                initialValue: _cartons,
                decoration: InputDecoration(
                  labelText: 'Cartons to assign',
                  helperText: '${widget.remaining} available',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _cartons = value,
                validator: (value) {
                  final count = int.tryParse(value?.trim() ?? '');
                  return count == null || count < 1 || count > widget.remaining
                      ? 'Enter 1 to ${widget.remaining} cartons.'
                      : null;
                },
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _date == null ? 'Set due date (optional)' : workDate(_date),
              ),
              onPressed: () async {
                final picked = await openCpmsDatePage(
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
