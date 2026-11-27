import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/purchase_order_provider.dart';
import '../../providers/tenant_provider.dart';
import 'order_work_screen.dart';

class OrderAccountDetailScreen extends StatefulWidget {
  const OrderAccountDetailScreen({super.key, required this.poId});

  final String poId;

  @override
  State<OrderAccountDetailScreen> createState() =>
      _OrderAccountDetailScreenState();
}

class _OrderAccountDetailScreenState extends State<OrderAccountDetailScreen> {
  late Future<WorkRecord> _detail = _load();

  Future<WorkRecord> _load() async =>
      await context.read<TenantProvider>().apiClient.get(
        '/order-work/accounts/${widget.poId}',
      ) as WorkRecord;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase order details')),
      body: FutureBuilder<WorkRecord>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _detail = _load()),
                child: Text('Retry loading purchase order · ${snapshot.error}'),
              ),
            );
          }
          final detail = snapshot.data;
          if (detail == null)
            return const Center(child: CircularProgressIndicator());
          return _AccountOrder(detail: detail);
        },
      ),
    );
  }
}

class _AccountOrder extends StatelessWidget {
  const _AccountOrder({required this.detail});

  final WorkRecord detail;

  @override
  Widget build(BuildContext context) {
    final rawOrder = detail['order'] as WorkRecord;
    final order = PurchaseOrderModel.fromJson(rawOrder);
    final names = detail['names'] as WorkRecord;
    final events = workRecords(rawOrder['activity']).reversed;
    final assignments = workRecords(detail['assignments']);
    final reports = workRecords(detail['reports']);
    final orderItems = workRecords(rawOrder['items']);
    final checked = orderItems.where((item) => item['qa_checked_at'] != null).length;

    String actor(Object? id) =>
        names[id]?.toString() ?? id?.toString() ?? 'Unknown user';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              order.poNumber,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            _line('Status', workStatus(order.status)),
            _line('Customer', order.customerName),
            _line('Customer address', order.customerAddress),
            _line('Customer contact', order.customerContact),
            _line('Order date', workDate(order.poDate)),
            _line('Expected shipping', workDate(order.expectedShippingDate)),
            _line('Order notes', order.notes),
            _line(
              'Cartons',
              '${order.totalCartons} ordered · ${order.totalAssignedCartons} assigned · ${order.totalCompletedCartons} produced · ${order.totalPackedCartons} packed · ${order.totalShippedCartons} shipped',
            ),
            _line('Packets', '${order.totalPackets}'),
            _line(
              'QA',
              '$checked of ${order.totalItemsCount} items marked checked',
            ),
            _heading(context, 'Order items'),
            for (final item in order.items)
              Card(
                child: ListTile(
                  title: Text('${item.itemName} · ${item.sku}'),
                  subtitle: Text(
                    [
                      item.specification,
                      '${item.cartons} cartons · ${item.packetPerCarton} packets per carton · ${item.totalPackets} packets',
                      '${item.quantityPerPacket} ${item.unit} per packet',
                      '${item.completedCartons} produced · ${item.packedCartons} packed · ${item.shippedCartons} shipped',
                      workStatus(item.itemStatus),
                    ].where((part) => part.trim().isNotEmpty).join('\n'),
                  ),
                ),
              ),
            _heading(context, 'Production assignments'),
            if (assignments.isEmpty)
              const Text('No production assignments recorded.'),
            for (final entry in assignments)
              Card(
                child: ListTile(
                  title: Text(
                    '${entry['supervisor_name']} · ${entry['item_name']}',
                  ),
                  subtitle: Text(
                    [
                      'Assigned by ${actor(entry['assigned_by_user_id'])}',
                      '${entry['completed_cartons']} of ${entry['assigned_cartons']} cartons · ${workStatus(entry['status'])}',
                      if (entry['target_date'] != null)
                        'Due ${workDate(entry['target_date'])}',
                      if (entry['completed_at'] != null)
                        'Completed ${workDate(entry['completed_at'])}',
                      workText(entry, 'notes'),
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                ),
              ),
            _heading(context, 'Quality assurance'),
            for (final item in workRecords(
              rawOrder['items'],
            ).where((item) => workText(item, 'qa_user_id').isNotEmpty))
              Card(
                child: ListTile(
                  title: Text(
                    '${actor(item['qa_user_id'])} · ${item['item_name']}',
                  ),
                  subtitle: Text(
                    [
                      if (item['qa_checked_at'] != null)
                        'Checked ${workDate(item['qa_checked_at'])}'
                      else
                        'Assigned',
                      if (item['qa_target_date'] != null)
                        'Due ${workDate(item['qa_target_date'])}',
                      workText(item, 'qa_note'),
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                ),
              ),
            for (final report in reports)
              Card(
                child: ListTile(
                  title: Text(
                    '${report['inspector_name']} · ${report['item_name']}',
                  ),
                  subtitle: Text(
                    [
                      '${workStatus(report['status'])} · ${workDate(report['inspected_at'])}',
                      '${report['inspected_cartons']} inspected · ${report['rejected_cartons']} rejected',
                      workText(report, 'remarks'),
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                ),
              ),
            _heading(context, 'Order activity'),
            if (events.isEmpty) const Text('No activity history recorded.'),
            for (final event in events)
              Card(
                child: ListTile(
                  title: Text(workText(event, 'action')),
                  subtitle: Text(
                    [
                      '${actor(event['user_id'])} · ${event['department']} · ${_timestamp(event['at'])}',
                      workText(event, 'detail'),
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$label · $value'),
        );

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  String _timestamp(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? ''
        : DateFormat.yMMMd().add_jm().format(date.toLocal());
  }
}
