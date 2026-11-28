import '../../widgets/cpms_page_route.dart';

import 'package:flutter/material.dart';

import '../../widgets/cpms_form_page.dart';
import '../../widgets/cpms_loading_page.dart';
import '../../widgets/cpms_page_title.dart';
import '../../widgets/order_split_view.dart';
import '../../widgets/success_screen.dart';

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
  String? _selectedItemId;
  String _itemQuery = '';
  final _itemSearchController = TextEditingController();
  bool get _planning =>
      widget.workspace == DepartmentWorkspace.productionManager;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _itemSearchController.dispose();
    super.dispose();
  }

  bool _saving = false;
  _PendingAssignment? _pendingAssignment;
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
    setState(() {
      _orders = updated;
    });
    try {
      final orders = await updated;
      if (mounted && _planning && _selectedOrderId != null) {
        final order = orders
            .where((order) => workText(order, 'po_id') == _selectedOrderId)
            .firstOrNull;
        if (order == null) {
          setState(() {
            _selectedOrderId = null;
            _selectedItemId = null;
            _pendingAssignment = null;
          });
        } else if (_selectedItemId != null &&
            !workRecords(order['items'])
                .any((item) => workText(item, 'item_id') == _selectedItemId)) {
          setState(() {
            _selectedItemId = null;
            _pendingAssignment = null;
          });
        }
      }
    } catch (_) {
      // FutureBuilder displays the load error.
    }
  }

  void _message(Object message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message.toString())));
  }

  Future<void> _save(
    Future<void> Function() action, {
    String? successTitle,
    String? successMessage,
  }) async {
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
      if (mounted && successTitle != null && successMessage != null) {
        await openCpmsPage<void>(
          context: context,
          builder: (_) => SuccessScreen(
            title: successTitle,
            message: successMessage,
            returnLabel: 'Back to orders',
          ),
        );
      }
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _assign(
    WorkRecord order,
    WorkRecord item, {
    required _AssignmentStage stage,
    WorkRecord? existingAssignment,
    bool unassign = false,
  }) {
    if (_pendingAssignment != null || _saving) return;
    final remaining = _remainingCartons(
      item,
      editingAssignmentId: existingAssignment?['assignment_id'] as String?,
    );
    if (stage == _AssignmentStage.supervisor && remaining < 1) {
      _message('All cartons on this item are already assigned.');
      return;
    }
    final staff = unassign
        ? null
        : _api
              .get('/order-work/staff')
              .then(
                (response) =>
                    workRecords((response as WorkRecord)[stage.staffKey]),
              );
    setState(() {
      _pendingAssignment = _PendingAssignment(
        stage: stage,
        remaining: remaining,
        staff: staff,
        existing: existingAssignment,
      );
    });
  }

  void _closeAssignment() {
    if (!_saving) setState(() => _pendingAssignment = null);
  }

  Widget _assignmentPane(
    WorkRecord order,
    WorkRecord item,
    _PendingAssignment pending,
  ) {
    final stage = pending.stage;
    if (pending.staff == null) {
      return CpmsFormPage(
        automaticallyImplyLeading: false,
        title: Text('Unassign ${stage.label}?'),
        content: Text(
          'Remove ${workText(pending.existing ?? const {}, 'name')} from ${workText(item, 'item_name')}?',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _closeAssignment,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () => _saveAssignment(order, item, pending, null),
            child: Text(
              _saving ? 'Saving changes…' : 'Unassign ${stage.label}',
            ),
          ),
        ],
      );
    }
    return FutureBuilder<List<WorkRecord>>(
      future: pending.staff,
      builder: (context, snapshot) {
        final title = '${stage.label} assignment';
        final people = snapshot.data;
        if (people == null || people.isEmpty) {
          final waiting = snapshot.connectionState != ConnectionState.done;
          final message = waiting
              ? 'Loading ${stage.label} assignees…'
              : snapshot.hasError
              ? 'Could not load assignees. ${snapshot.error}'
              : 'No eligible ${stage.label} assignees found.';
          return CpmsFormPage(
            automaticallyImplyLeading: false,
            title: Text(title),
            content: Row(
              children: [
                if (waiting) ...[
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(child: Text(message)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _closeAssignment,
                child: const Text('Cancel'),
              ),
            ],
          );
        }
        final existing = pending.existing;
        return _AssignmentPage(
          stage: stage,
          orderNumber: workText(order, 'po_number'),
          itemName: workText(item, 'item_name'),
          sku: workText(item, 'sku'),
          people: people,
          remaining: pending.remaining,
          currentUserId: switch (stage) {
            _AssignmentStage.quality => workText(item, 'qa_user_id'),
            _AssignmentStage.supervisor => workText(
              existing ?? const {},
              'assignee_id',
            ),
            _ => workText(existing ?? const {}, 'user_id'),
          },
          initialCartons: existing == null
              ? pending.remaining
              : _count(existing, 'assigned_cartons'),
          initialDate: DateTime.tryParse(
            ((stage == _AssignmentStage.quality
                        ? item['target_date']
                        : existing?['target_date'])
                    ?.toString() ??
                ''),
          )?.toLocal(),
          editing: existing != null,
          saving: _saving,
          onCancel: _closeAssignment,
          onSave: (assignment) =>
              _saveAssignment(order, item, pending, assignment),
        );
      },
    );
  }

  Future<void> _saveAssignment(
    WorkRecord order,
    WorkRecord item,
    _PendingAssignment pending,
    _AssignmentInput? assignment,
  ) async {
    if (_saving || _pendingAssignment != pending) return;
    final stage = pending.stage;
    final existingAssignment = pending.existing;
    final poId = workText(order, 'po_id');
    final itemId = workText(item, 'item_id');
    setState(() => _saving = true);
    try {
      if (stage == _AssignmentStage.quality && assignment != null) {
        await _api.patch(
          '/order-work/$poId/items/$itemId/quality-assignment',
          body: {
            'user_id': assignment.userId,
            if (assignment.date != null)
              'target_date': assignment.date!.toUtc().toIso8601String(),
          },
        );
      } else if (stage == _AssignmentStage.supervisor && assignment != null) {
        final production = context.read<ProductionProvider>();
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
      } else if (stage.departmentAssignment) {
        final previous = workText(existingAssignment ?? const {}, 'user_id');
        await _api.patch(
          '/order-work/$poId/items/$itemId/assignments/${stage.staffKey}',
          body: {
            'user_id': assignment?.userId,
            'previous_user_id': previous.isEmpty ? null : previous,
          },
        );
      }
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      setState(() => _pendingAssignment = null);
      final editing = stage == _AssignmentStage.quality
          ? workText(item, 'qa_user_id').isNotEmpty
          : existingAssignment != null;
      final action = assignment == null
          ? 'unassigned'
          : editing
          ? 'reassigned'
          : 'assigned';
      _message('${stage.label} $action');
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    await _save(
      () async {
        if (!await production.cancelAssignment(
          workText(assignment, 'assignment_id'),
        )) {
          throw ApiException(
            production.errorMessage ?? 'Assignment could not be cancelled.',
          );
        }
      },
      successTitle: 'Supervisor unassigned',
      successMessage:
          '${workText(assignment, 'assignee')} was removed from this assignment.',
    );
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
        decoration: _planning
            ? InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Find by PO number or customer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xffcbd7e5)),
                ),
              )
            : const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Find by PO number or customer',
                border: OutlineInputBorder(),
              ),
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
    );
    return PopScope(
      canPop:
          !_planning || (_selectedItemId == null && _selectedOrderId == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _planning) _backToPlanningOverview();
      },
      child: Scaffold(
        backgroundColor: _planning
            ? Theme.of(context).colorScheme.surface
            : null,
        appBar: AppBar(
          primary: !widget.embedded,
          backgroundColor: _planning
              ? Theme.of(context).colorScheme.surface
              : null,
          bottom: _planning
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, color: Color(0xffdbe4ef)),
                )
              : null,
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
                    if (!split && (!_planning || _selectedOrderId == null))
                      searchField,
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
                          if (_planning && _selectedOrderId != null) {
                            final order =
                                (snapshot.data ?? const <WorkRecord>[])
                                    .where(
                                      (order) =>
                                          workText(order, 'po_id') ==
                                          _selectedOrderId,
                                    )
                                    .firstOrNull;
                            if (order != null) {
                              return _planningPane(order, compact: true);
                            }
                          }
                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: matching.length + 1,
                              itemBuilder: (context, index) {
                                if (index > 0) {
                                  return _orderCard(matching[index - 1]);
                                }
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
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
      ),
    );
  }

  Widget _splitOrders(List<WorkRecord> orders, Widget searchField) {
    final selected = orders
        .where((order) => workText(order, 'po_id') == _selectedOrderId)
        .firstOrNull;

    final sidebar = Column(
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
                  subtitle: Text(
                    _planning
                        ? _planningOrderSummary(order, order == selected)
                        : _orderSummary(order),
                  ),
                  trailing: _planning ? _planningStatus(order) : null,
                  shape: _planning
                      ? Border(
                          left: BorderSide(
                            color: order == selected
                                ? const Color(0xffad580e)
                                : Colors.transparent,
                            width: 4,
                          ),
                          bottom: const BorderSide(color: Color(0xffedf1f5)),
                        )
                      : null,
                  onTap: _planning && _saving
                      ? null
                      : () => _selectOrder(order),
                );
              },
            ),
          ),
        ),
      ],
    );
    final detail = selected == null ? null : _orderDetail(selected);
    if (_planning) {
      return LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            SizedBox(
              width:
                  constraints.maxWidth * (_selectedItemId == null ? .30 : .25),
              child: sidebar,
            ),
            const VerticalDivider(width: 1, color: Color(0xffdbe4ef)),
            Expanded(
              child:
                  detail ??
                  const Center(
                    child: Text('Select a purchase order to view its details.'),
                  ),
            ),
          ],
        ),
      );
    }
    return OrderSplitView(orders: sidebar, detail: detail);
  }

  void _selectOrder(WorkRecord order) {
    setState(() {
      _selectedOrderId = workText(order, 'po_id');
      _selectedItemId = null;
      _pendingAssignment = null;
      _itemQuery = '';
      _itemSearchController.clear();
    });
  }

  void _backToPlanningOverview() {
    if (_saving) return;
    setState(() {
      if (_pendingAssignment != null) {
        _pendingAssignment = null;
      } else if (_selectedItemId != null) {
        _selectedItemId = null;
      } else {
        _selectedOrderId = null;
      }
    });
  }

  String _planningOrderSummary(WorkRecord order, bool selected) => [
    workText(order, 'customer_name'),
    workDate(order['po_date']),
    if (selected && _selectedItemId != null)
      '${workRecords(order['items']).length} items',
  ].where((part) => part.isNotEmpty).join(' · ');

  Widget _planningStatus(WorkRecord order) {
    final status = workStatus(order['status'] ?? '');
    final color = switch (status) {
      'confirmed' => const Color(0xff9a4700),
      'scheduled' => const Color(0xff087558),
      _ => const Color(0xff50627a),
    };
    return _planningBadge(status, color);
  }

  Widget _planningPane(WorkRecord order, {bool compact = false}) {
    final items = workRecords(order['items']);
    final item = items
        .where((item) => workText(item, 'item_id') == _selectedItemId)
        .firstOrNull;
    final number = workText(order, 'po_number');
    final pending = _pendingAssignment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item != null || compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _backToPlanningOverview,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: Text(
                    pending != null && item != null
                        ? 'Back to item details'
                        : item != null
                        ? '$number Overview'
                        : 'Purchase orders / $number',
                  ),
                ),
                if (item != null)
                  Text(
                    '${workText(item, 'item_name')} (${workText(item, 'item_id')})',
                  ),
                if (item != null && pending == null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showHistory(order, item, item, quality: true),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('History Log'),
                  ),
              ],
            ),
          ),
        if (item != null || compact)
          const Divider(height: 1, color: Color(0xffdbe4ef)),
        Expanded(
          child: item == null
              ? _planningOverview(order, items)
              : pending == null
              ? _planningItemDetail(order, item)
              : _assignmentPane(order, item, pending),
        ),
      ],
    );
  }

  int _productionCartons(WorkRecord item) {
    final recorded = item['completed_cartons'];
    if (recorded is num) return recorded.toInt();
    return workRecords(item['assignments'])
        .where((assignment) => assignment['status'] != 'CANCELLED')
        .fold(
          0,
          (sum, assignment) => sum + _count(assignment, 'completed_cartons'),
        );
  }

  Widget _planningOverview(WorkRecord order, List<WorkRecord> items) {
    final cartons = items.fold(0, (sum, item) => sum + _count(item, 'cartons'));
    final checked = items.where((item) => item['checked_at'] != null).length;
    final metrics = [
      (
        'PRODUCTION',
        items.fold(0, (sum, item) => sum + _productionCartons(item)),
        cartons,
        'ctns',
      ),
      ('QA INSPECTION', checked, items.length, 'checked'),
      (
        'PACKING',
        items.fold(0, (sum, item) => sum + _count(item, 'packed_cartons')),
        cartons,
        'ctns',
      ),
      (
        'EXPORT',
        items.fold(0, (sum, item) => sum + _count(item, 'shipped_cartons')),
        cartons,
        'ctns',
      ),
    ];
    final matching = items
        .where(
          (item) => [
            workText(item, 'item_name'),
            workText(item, 'sku'),
            workText(item, 'qa_assignee'),
            ...workRecords(item['assignments'])
                .map((assignment) => workText(assignment, 'assignee')),
          ].any((value) => value.toLowerCase().contains(_itemQuery)),
        )
        .toList();
    return ListView(
      key: PageStorageKey(('planning', workText(order, 'po_id'))),
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (label, value, total, unit) in metrics)
                  SizedBox(
                    width: width,
                    child: _planningPanel(
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xff566a85),
                                letterSpacing: .5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$value',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  / $total $unit',
                                    style: const TextStyle(
                                      color: Color(0xff566a85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 7),
                            LinearProgressIndicator(
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: const Color(0xffedf2f7),
                              color: const Color(0xffad580e),
                              value: total == 0
                                  ? 0
                                  : (value / total).clamp(0, 1).toDouble(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _itemSearchController,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText:
                'Search items, SKU, QA, or supervisor in ${workText(order, 'po_number')}…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffdbe4ef)),
            ),
          ),
          onChanged: (value) =>
              setState(() => _itemQuery = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 14),
        for (final item in matching) ...[
          InkWell(
            onTap: () =>
                setState(() => _selectedItemId = workText(item, 'item_id')),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          workText(item, 'item_name'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        size: 19,
                        color: Color(0xff8a9bb1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_count(item, 'cartons')} ordered cartons',
                    style: const TextStyle(color: Color(0xff566a85)),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xffedf1f5)),
                  _planningStages(item, summary: true),
                ],
              ),
            ),
          ),
          if (item != matching.last)
            const Divider(height: 1, color: Color(0xffdbe4ef)),
        ],
        if (matching.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              items.isEmpty
                  ? 'No items on this order.'
                  : 'No items match your search.',
            ),
          ),
      ],
    );
  }

  Widget _planningStages(WorkRecord item, {bool summary = false}) {
    final total = _count(item, 'cartons');
    final produced = _productionCartons(item);
    final packed = _count(item, 'packed_cartons');
    final shipped = _count(item, 'shipped_cartons');
    final checked = item['checked_at'] != null;
    final stages = [
      (
        'Production: $produced/$total${summary && produced < total ? ' ctns' : ''}',
        total > 0 && produced >= total,
      ),
      ('QA: ${checked ? 'Checked' : 'Unchecked'}', checked),
      ('Packing: $packed/$total', total > 0 && packed >= total),
      ('Export: $shipped/$total ctns', total > 0 && shipped >= total),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (summary)
          const Text('Stages:', style: TextStyle(color: Color(0xff657990))),
        for (final (label, complete) in stages)
          _planningBadge(
            label,
            complete ? const Color(0xff087558) : const Color(0xffc12424),
            dot: !summary,
          ),
      ],
    );
  }

  Widget _planningBadge(String label, Color color, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        border: Border.all(color: color.withValues(alpha: dot ? .85 : .36)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planningPanel(Widget child) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: const Color(0xffdbe4ef)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: child,
  );

  Widget _planningSection({
    required String title,
    required Color indicator,
    required String status,
    Widget? action,
    required Widget child,
    Widget? footer,
  }) => _planningPanel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.circle, size: 9, color: indicator),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _planningBadge(status, indicator),
                ],
              ),
              ?action,
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffdbe4ef)),
        child,
        if (footer != null)
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(padding: const EdgeInsets.all(13), child: footer),
          ),
      ],
    ),
  );

  Widget _planningItemDetail(WorkRecord order, WorkRecord item) {
    final total = _count(item, 'cartons');
    final assignments = workRecords(item['assignments']);
    final remaining = _remainingCartons(item);
    final editable = !_saving && order['editable'] == true;
    final checked = item['checked_at'] != null;
    final green = const Color(0xff087558);
    final slate = const Color(0xff50627a);
    final due = workDate(item['target_date']);
    final target = due.isEmpty
        ? workDate(order['expected_shipping_date'])
        : due;
    final destination = workText(order, 'destination');
    final sku = workText(item, 'sku');
    return ListView(
      key: ValueKey((
        'planning-item',
        workText(order, 'po_id'),
        workText(item, 'item_id'),
      )),
      padding: const EdgeInsets.all(24),
      children: [
        _planningPanel(
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      workText(item, 'item_name'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _planningBadge(workText(item, 'item_id'), slate),
                    _planningBadge(
                      _count(item, 'shipped_cartons') >= total && total > 0
                          ? 'Shipped'
                          : 'In Pipeline',
                      green,
                    ),
                    if (target.isNotEmpty)
                      Text(
                        'Target Due Date: $target',
                        style: TextStyle(color: slate),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    '$total ordered cartons',
                    if (sku.isNotEmpty) 'SKU: $sku',
                    if (destination.isNotEmpty) 'Destination: $destination',
                  ].join(' · '),
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xffedf1f5)),
                const SizedBox(height: 10),
                _planningStages(item),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _planningSection(
          title: 'QA Inspection Assignment',
          indicator: checked ? green : const Color(0xffa75b00),
          status: checked ? 'QA Checked' : 'Pending QA Check',
          child: _qualityAssignment(order, item, due, editable),
        ),
        const SizedBox(height: 24),
        _planningSection(
          title: 'Supervisor Carton Assignments',
          indicator: green,
          status: '${total - remaining} of $total cartons assigned',
          action: editable && remaining > 0
              ? OutlinedButton(
                  onPressed: () =>
                      _assign(order, item, stage: _AssignmentStage.supervisor),
                  child: const Text('+ Split Quantity / Add Line'),
                )
              : null,
          child: _supervisorAssignments(order, item, assignments, editable),
          footer: Text('Remaining unassigned cartons: $remaining cartons'),
        ),
        for (final stage in [
          _AssignmentStage.packing,
          _AssignmentStage.export,
        ]) ...[
          const SizedBox(height: 24),
          _departmentAssignmentSection(order, item, stage, editable),
        ],
      ],
    );
  }

  Widget _departmentAssignmentSection(
    WorkRecord order,
    WorkRecord item,
    _AssignmentStage stage,
    bool editable,
  ) {
    final packing = stage == _AssignmentStage.packing;
    final assignment = item['${stage.staffKey}_assignment'] as WorkRecord?;
    final total = _count(item, 'cartons');
    final count = _count(item, packing ? 'packed_cartons' : 'shipped_cartons');
    final label = packing ? 'Packed' : 'Shipped';
    return _planningSection(
      title: packing
          ? 'Packing Carton Assignments'
          : 'Exporter Carton Assignments',
      indicator: const Color(0xff087558),
      status: '$count of $total cartons ${label.toLowerCase()}',
      action: editable
          ? OutlinedButton(
              onPressed: () => _assign(
                order,
                item,
                stage: stage,
                existingAssignment: assignment,
              ),
              child: Text(
                assignment == null
                    ? 'Assign ${stage.label}'
                    : 'Reassign ${stage.label}',
              ),
            )
          : null,
      child: ListTile(
        title: Text(
          assignment == null ? 'Unassigned' : workText(assignment, 'name'),
        ),
        subtitle: assignment == null
            ? null
            : Text(
                'Assigned ${workDate(assignment['assigned_at'])} · $total ordered cartons',
              ),
        trailing: editable && assignment != null
            ? OutlinedButton(
                onPressed: () => _assign(
                  order,
                  item,
                  stage: stage,
                  existingAssignment: assignment,
                  unassign: true,
                ),
                child: Text('Unassign ${stage.label}'),
              )
            : null,
      ),
    );
  }

  String _orderSummary(WorkRecord order) => [
    workText(order, 'customer_name'),
    workDate(order['po_date']),
    workStatus(order['status']),
  ].where((part) => part.isNotEmpty).join(' · ');

  Widget _orderDetail(WorkRecord order) {
    if (_planning) return _planningPane(order);
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

    if (_planning) {
      return ListTile(
        title: Text(number),
        subtitle: Text(_planningOrderSummary(order, false)),
        trailing: _planningStatus(order),
        onTap: () => _selectOrder(order),
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
      for (final item in workRecords(order['assigned_items']))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(workText(item, 'item_name')),
          subtitle: Text(
            'Assigned to you · ${_count(item, 'shipped_cartons')} of ${_count(item, 'cartons')} cartons shipped',
          ),
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
        if (widget.workspace == DepartmentWorkspace.packing) ...[
          Text('${_count(item, 'packed_cartons')} of $cartons cartons packed'),
          if (item['assigned_to_me'] == true) const Text('Assigned to you'),
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 540 ? 540 : constraints.maxWidth,
          child: _assignmentTable(
            columns: const ['QA Personnel', 'Due date', 'Assignment', 'Status'],
            columnWidths: const {2: FlexColumnWidth(1.5)},
            rows: [
              TableRow(
                children: [
                  _assignmentCell(
                    _planningPerson(
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
                              onPressed: () => _assign(
                                order,
                                item,
                                stage: _AssignmentStage.quality,
                              ),
                              child: Text(
                                assigned ? 'Reassign QA' : 'Assign QA',
                              ),
                            ),
                          )
                        : const Text('—'),
                  ),
                  _assignmentCell(
                    checked
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Tooltip(
                              message: 'View QA history',
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => _showHistory(
                                  order,
                                  item,
                                  item,
                                  quality: true,
                                ),
                                child: const Text('Checked'),
                              ),
                            ),
                          )
                        : const Text('Unchecked'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          width: constraints.maxWidth < 740 ? 740 : constraints.maxWidth,
          child: _assignmentTable(
            columns: const [
              'Supervisor',
              'Carton qty',
              'Assigned date',
              'Completion',
              'Reassign',
              'Unassign',
              'History',
            ],
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              4: FixedColumnWidth(120),
              5: FixedColumnWidth(120),
            },
            rows: [
              for (final assignment in assignments)
                _supervisorAssignmentRow(order, item, assignment, editable),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planningPerson(String name) => Row(
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: const Color(0xffe1e7ef),
        foregroundColor: const Color(0xff34455b),
        child: Text(
          name.isEmpty ? '—' : name.characters.first.toUpperCase(),
          style: const TextStyle(fontSize: 11),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(name)),
    ],
  );

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
        _assignmentCell(_planningPerson(workText(assignment, 'assignee'))),
        _assignmentCell(Text('$assigned ctns')),
        _assignmentCell(
          Tooltip(
            message: dueDate.isEmpty ? 'Assigned date' : 'Due $dueDate',
            child: Text(assignedDate.isEmpty ? '—' : assignedDate),
          ),
        ),
        _assignmentCell(Text(cancelled ? 'Cancelled' : '$completion%')),
        _assignmentCell(
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: canChange
                  ? () => _assign(
                      order,
                      item,
                      stage: _AssignmentStage.supervisor,
                      existingAssignment: assignment,
                    )
                  : null,
              child: const Text('Reassign'),
            ),
          ),
        ),
        _assignmentCell(
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: canChange ? () => _cancelAssignment(assignment) : null,
              child: const Text('Unassign'),
            ),
          ),
        ),
        _assignmentCell(
          IconButton(
            tooltip: 'View supervisor history',
            icon: const Icon(Icons.history),
            onPressed: () =>
                _showHistory(order, item, assignment, quality: false),
          ),
        ),
      ],
    );
  }

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
    return switch (widget.workspace) {
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

enum _AssignmentStage {
  quality('QA', 'quality'),
  supervisor('Supervisor', 'supervisors'),
  packing('Packing', 'packing'),
  export('Export', 'export');

  const _AssignmentStage(this.label, this.staffKey);

  final String label;
  final String staffKey;
  bool get departmentAssignment => this == packing || this == export;
}

class _PendingAssignment {
  const _PendingAssignment({
    required this.stage,
    required this.remaining,
    required this.staff,
    required this.existing,
  });

  final _AssignmentStage stage;
  final int remaining;
  final Future<List<WorkRecord>>? staff;
  final WorkRecord? existing;
}

class _AssignmentInput {
  const _AssignmentInput(this.userId, this.cartons, this.date);
  final String userId;
  final int cartons;
  final DateTime? date;
}

class _AssignmentPage extends StatefulWidget {
  const _AssignmentPage({
    required this.stage,
    required this.orderNumber,
    required this.itemName,
    required this.sku,
    required this.people,
    required this.remaining,
    required this.currentUserId,
    required this.initialCartons,
    required this.initialDate,
    required this.editing,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final _AssignmentStage stage;
  final String orderNumber;
  final String itemName;
  final String sku;
  final List<WorkRecord> people;
  final int remaining;
  final String currentUserId;
  final int initialCartons;
  final DateTime? initialDate;
  final bool editing;
  final bool saving;
  final VoidCallback onCancel;
  final ValueChanged<_AssignmentInput> onSave;

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
  DateTime? _calendarDate;
  bool _enterDate = false;
  final _dateForm = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contextLabel = [
      widget.orderNumber,
      widget.sku,
    ].where((value) => value.isNotEmpty).join(' · ');
    return CpmsFormPage(
      automaticallyImplyLeading: false,
      icon: widget.stage == _AssignmentStage.quality
          ? Icons.fact_check_outlined
          : Icons.assignment_ind_outlined,
      title: Text(
        '${widget.editing || widget.currentUserId.isNotEmpty ? 'Reassign' : 'Assign'} ${widget.stage.label}',
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
            Text(
              'Select an assignee for ${widget.stage.label}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _userId,
              onChanged: (value) => setState(() => _userId = value),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 12.0;
                  final width = constraints.maxWidth;
                  final cardWidth = width >= 500 ? (width - gap) / 2 : width;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final person in widget.people)
                        SizedBox(
                          width: cardWidth,
                          child: _assigneeCard(person),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (widget.stage == _AssignmentStage.supervisor) ...[
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
            if (!widget.stage.departmentAssignment && _calendarDate == null)
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _date == null ? 'Set due date (optional)' : workDate(_date),
                ),
                onPressed: widget.saving
                    ? null
                    : () {
                        final first = DateTime(2020);
                        final last = DateTime(2100);
                        final initial = _date ?? DateTime.now();
                        setState(
                          () => _calendarDate = initial.isBefore(first)
                              ? first
                              : initial.isAfter(last)
                              ? last
                              : initial,
                        );
                      },
              )
            else if (_calendarDate != null) ...[
              SizedBox(
                width: 360,
                child: _enterDate
                    ? Form(
                        key: _dateForm,
                        child: InputDatePickerFormField(
                          initialDate: _calendarDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          onDateSaved: (date) => _calendarDate = date,
                        ),
                      )
                    : CalendarDatePicker(
                        initialDate: _calendarDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        onDateChanged: (date) => _calendarDate = date,
                      ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _calendarDate = null;
                      _enterDate = false;
                    }),
                    child: const Text('Cancel date selection'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _enterDate = !_enterDate),
                    child: Text(_enterDate ? 'Use calendar' : 'Enter date'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_enterDate) {
                        final form = _dateForm.currentState!;
                        if (!form.validate()) return;
                        form.save();
                      }
                      setState(() {
                        _date = _calendarDate;
                        _calendarDate = null;
                        _enterDate = false;
                      });
                    },
                    child: const Text('Select date'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.saving ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _userId == null || widget.saving || _calendarDate != null
              ? null
              : () {
                  if (!_form.currentState!.validate()) return;
                  widget.onSave(
                    _AssignmentInput(
                      _userId!,
                      int.tryParse(_cartons.trim()) ?? 0,
                      _date,
                    ),
                  );
                },
          child: Text(widget.saving ? 'Saving changes…' : 'Save assignment'),
        ),
      ],
    );
  }

  Widget _assigneeCard(WorkRecord person) {
    final theme = Theme.of(context);
    final id = workText(person, 'user_id');
    final name = workText(person, 'name');
    final email = workText(person, 'email_address').trim();
    final phone = workText(person, 'phone_number').trim();
    final photoUrl = ApiConstants.resolveImageUrl(
      workText(person, 'avatar_url'),
    );
    final photo = photoUrl == null ? null : NetworkImage(photoUrl);
    final selected = _userId == id;

    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: RadioListTile<String>(
        value: id,
        selected: selected,
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: CircleAvatar(
          foregroundImage: photo,
          onForegroundImageError: photo == null ? null : (_, _) {},
          child: const Icon(Icons.person_outline),
        ),
        title: Text(name),
        subtitle: email.isEmpty && phone.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (email.isNotEmpty) Text(email, softWrap: true),
                  if (phone.isNotEmpty) Text(phone),
                ],
              ),
      ),
    );
  }
}
