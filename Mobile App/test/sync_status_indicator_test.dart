import 'dart:async';

import 'package:cpms_mobile/core/network/api_client.dart';
import 'package:cpms_mobile/core/sync/sync_manager.dart';
import 'package:cpms_mobile/widgets/sync_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the dot follows unsynced changes and has no visible text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = _SyncClient()
      ..setActiveTenantId('tenant')
      ..setAuthToken('token');
    final manager = SyncManager();
    manager.initialize(apiClient: client);
    await manager.restoreQueue();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncStatusIndicator())),
    );

    Color? dotColor() {
      final finder = find.descendant(
        of: find.byType(SyncStatusIndicator),
        matching: find.byType(DecoratedBox),
      );
      return (tester.widget<DecoratedBox>(finder).decoration as BoxDecoration)
          .color;
    }

    SyncOperation operation(String id) => SyncOperation(
      id: id,
      type: SyncOperationType.updateStoreRoom,
      targetId: 'room',
      payload: {'room_name': 'Updated room'},
      createdAt: DateTime.now(),
    );

    expect(dotColor(), const Color(0xFF16A34A));
    await manager.enqueue(operation('first'));
    await tester.pump();
    expect(dotColor(), const Color(0xFFDC2626));
    expect(find.byType(Text), findsNothing);
    expect(manager.pendingCount, 1);

    client.response.complete({'success': true});
    await tester.pumpAndSettle();
    expect(dotColor(), const Color(0xFF16A34A));

    client.response = Completer<dynamic>();
    await manager.enqueue(operation('second'));
    await tester.pump();
    client.response.completeError(ApiException('Rejected', statusCode: 400));
    await tester.pumpAndSettle();
    expect(manager.pendingCount, 1);
    expect(dotColor(), const Color(0xFFDC2626));

    manager.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _SyncClient extends ApiClient {
  Completer<dynamic> response = Completer<dynamic>();

  @override
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) => response.future;
}
