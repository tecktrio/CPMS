import 'package:cpms_mobile/widgets/cpms_form_page.dart';

import 'dart:async';

import 'package:cpms_mobile/providers/department_provider.dart';
import 'package:cpms_mobile/providers/production_provider.dart';
import 'package:cpms_mobile/screens/purchase_orders/purchase_order_detail_screen.dart';
import 'package:cpms_mobile/providers/auth_provider.dart';
import 'package:cpms_mobile/providers/inventory_provider.dart';
import 'package:cpms_mobile/core/constants/permissions.dart';
import 'package:cpms_mobile/core/network/api_client.dart';
import 'package:cpms_mobile/providers/purchase_order_provider.dart';
import 'package:cpms_mobile/screens/production/order_work_screen.dart';
import 'package:cpms_mobile/providers/tenant_provider.dart';
import 'package:cpms_mobile/screens/dashboard/department_workspace.dart';
import 'package:cpms_mobile/screens/production/production_hub_screen.dart';
import 'package:cpms_mobile/screens/purchase_orders/purchase_orders_list_screen.dart';
import 'package:cpms_mobile/screens/store_rooms/store_rooms_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final cases = [
    (
      'Administrator',
      DepartmentWorkspace.administrator,
      'Manage users and departments',
      AppPermissions.userRead,
    ),
    (
      'Sales',
      DepartmentWorkspace.sales,
      'Manage purchase orders',
      AppPermissions.poCreate,
    ),
    (
      'Store Room',
      DepartmentWorkspace.storeRoom,
      'Manage room inventory',
      AppPermissions.storeroomRead,
    ),
    (
      'Production Manager',
      DepartmentWorkspace.productionManager,
      'Manage confirmed orders',
      AppPermissions.productionRead,
    ),
    (
      'Supervisor',
      DepartmentWorkspace.supervisor,
      'My assigned items',
      AppPermissions.productionRead,
    ),
    (
      'QC',
      DepartmentWorkspace.quality,
      'My assigned inspections',
      AppPermissions.qcCheck,
    ),
    (
      'Packer',
      DepartmentWorkspace.packing,
      'Mark items packed',
      AppPermissions.packingUpdate,
    ),
    (
      'Export',
      DepartmentWorkspace.export,
      'View order readiness',
      AppPermissions.exportRead,
    ),
    (
      'Accounts',
      DepartmentWorkspace.accounts,
      'Review confirmed orders',
      AppPermissions.poRead,
    ),
  ];

  for (final (name, expectedWorkspace, action, permission) in cases) {
    testWidgets('$name receives its department workflow', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final client = _WorkClient();
      final tenant = _WorkspaceTenant(client, name, {
        AppPermissions.poRead,
        permission,
      });
      final workspace = DepartmentWorkspace.resolve(tenant);
      expect(workspace, expectedWorkspace);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TenantProvider>.value(value: tenant),
            ChangeNotifierProvider(
              create: (_) => PurchaseOrderProvider(apiClient: client),
            ),
            ChangeNotifierProvider<InventoryProvider>(
              create: (_) => _WorkspaceInventory(apiClient: client),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DepartmentWorkspaceView(
                workspace: workspace!,
                onRefresh: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      if (name == 'Administrator') {
        expect(find.text('Administration'), findsOneWidget);
        expect(find.byType(Card), findsNWidgets(3));
        expect(find.text(action), findsOneWidget);
        final tiles = find.byType(Card);
        expect(
          tester.getTopLeft(tiles.at(0)).dy,
          tester.getTopLeft(tiles.at(1)).dy,
        );
        expect(
          tester.getTopLeft(tiles.at(0)).dx,
          lessThan(tester.getTopLeft(tiles.at(1)).dx),
        );
      } else {
        final screen = switch (expectedWorkspace) {
          DepartmentWorkspace.sales => PurchaseOrdersListScreen,
          DepartmentWorkspace.storeRoom => StoreRoomsListScreen,
          _ => OrderWorkScreen,
        };
        expect(find.byType(screen), findsOneWidget);
        expect(find.widgetWithText(ListTile, action), findsNothing);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        if (screen == PurchaseOrdersListScreen) {
          expect(find.text('PO-124'), findsOneWidget);
        }
        if (screen == OrderWorkScreen) {
          expect(
            client.lastGet,
            '/order-work?department=${workspace!.orderWorkRole}',
          );
          expect(find.text('PO-124'), findsOneWidget);
        }
      }
    });
  }

  for (final (name, workspace, permission) in [
    ('Sales', DepartmentWorkspace.sales, AppPermissions.poUpdate),
    ('Packer', DepartmentWorkspace.packing, AppPermissions.packingUpdate),
    (
      'Production Manager',
      DepartmentWorkspace.productionManager,
      AppPermissions.productionRead,
    ),
  ]) {
    testWidgets('$name opens the selected order alongside the list', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final client = _WorkClient(includeSecondOrder: true);
      final tenant = _WorkspaceTenant(client, name, {
        AppPermissions.poRead,
        permission,
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TenantProvider>.value(value: tenant),
            ChangeNotifierProvider(
              create: (_) => PurchaseOrderProvider(apiClient: client),
            ),
            ChangeNotifierProvider(
              create: (_) => DepartmentProvider(apiClient: client),
            ),
            ChangeNotifierProvider(
              create: (_) => ProductionProvider(apiClient: client),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DepartmentWorkspaceView(
                workspace: workspace,
                onRefresh: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Select a purchase order to view its details.'),
        findsOneWidget,
      );
      final first = find.widgetWithText(ListTile, 'PO-124');
      final second = find.widgetWithText(ListTile, 'PO-125');
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(first).selected, isTrue);
      expect(second, findsOneWidget);
      final actionLabel = switch (workspace) {
        DepartmentWorkspace.sales => 'Edit Purchase Order',
        DepartmentWorkspace.productionManager =>
          'Assign remaining 5 cartons to supervisors',
        _ => 'Mark packed',
      };
      final detailCard = find.ancestor(
        of: find.text('Private line'),
        matching: find.byType(Card),
      );
      final action = workspace == DepartmentWorkspace.sales
          ? find.text(actionLabel)
          : find.descendant(of: detailCard, matching: find.text(actionLabel));
      expect(action, findsOneWidget);
      expect(tester.getSize(first).width, lessThan(260));
      expect(
        tester.getCenter(action).dx,
        greaterThan(tester.getCenter(first).dx),
      );
      if (workspace == DepartmentWorkspace.sales) {
        expect(
          find.ancestor(of: action, matching: find.byType(AppBar)),
          findsOneWidget,
        );
      } else {
        final item = find.text('Private line');

        expect(detailCard, findsOneWidget);
        expect(
          find.descendant(of: detailCard, matching: action),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(action).dy,
          greaterThan(tester.getBottomLeft(item).dy),
        );
        if (workspace == DepartmentWorkspace.productionManager) {
          expect(
            find.descendant(of: detailCard, matching: find.byType(Table)),
            findsNWidgets(2),
          );
          expect(find.text('Assigned date'), findsOneWidget);
          expect(find.text('Nov 27, 2026'), findsOneWidget);
          expect(find.text('40%'), findsOneWidget);
          expect(find.text('Reassign'), findsOneWidget);
          expect(find.text('Unassign'), findsOneWidget);
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton &&
                        widget.tooltip == 'Reassign supervisor',
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton &&
                        widget.tooltip == 'Unassign supervisor',
                  ),
                )
                .onPressed,
            isNull,
          );
          for (final (tooltip, title, value) in [
            (
              'View supervisor history',
              'Supervisor progress history',
              'Previous cartons',
            ),
            ('View QA history', 'QA completion history', 'Inspection passed'),
          ]) {
            final history = find.descendant(
              of: detailCard,
              matching: find.byTooltip(tooltip),
            );
            await tester.ensureVisible(history);
            await tester.tap(history);
            await tester.pumpAndSettle();
            final dialog = find.byType(CpmsFormPage);
            expect(
              find.descendant(of: dialog, matching: find.text(title)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: dialog, matching: find.text(value)),
              findsOneWidget,
            );
            final export = find.descendant(
              of: dialog,
              matching: find.widgetWithText(FilledButton, 'Export PDF'),
            );
            expect(tester.widget<FilledButton>(export).onPressed, isNotNull);
            await tester.tap(find.widgetWithText(TextButton, 'Close'));
            await tester.pumpAndSettle();
          }
        }
      }
      if (workspace == DepartmentWorkspace.productionManager) {
        final otherCard = find.ancestor(
          of: find.text('Additional line'),
          matching: find.byType(Card),
        );
        expect(otherCard, findsOneWidget);
        expect(
          find.descendant(
            of: detailCard,
            matching: find.text('Additional line'),
          ),
          findsNothing,
        );
        final assignQa = find.descendant(
          of: otherCard,
          matching: find.widgetWithText(OutlinedButton, 'Assign QA'),
        );
        final staffResponse = Completer<Map<String, dynamic>>();
        client.staffResponse = staffResponse.future;
        await tester.ensureVisible(assignQa);
        final openAssignment = tester
            .widget<OutlinedButton>(assignQa)
            .onPressed!;
        openAssignment();
        openAssignment();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Loading QA assignees…'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Loading QA assignees…'), findsOneWidget);
        expect(client.staffRequests, 1);
        staffResponse.complete({
          'quality': [
            {
              'user_id': 'qa-1',
              'name': 'QA Tester',
              'email_address': 'qa@example.com',
              'phone_number': '+91 90000 00001',
            },
            {'user_id': 'qa-2', 'name': 'Backup QA'},
          ],
        });
        await tester.pumpAndSettle();
        expect(find.text('Loading QA assignees…'), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        final dialog = find.byType(CpmsFormPage);
        expect(
          find.descendant(of: dialog, matching: find.text('Additional line')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text('PO-124 · SKU-126')),
          findsOneWidget,
        );
        expect(find.text('Cartons to assign'), findsNothing);
        final save = find.widgetWithText(FilledButton, 'Save assignment');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(find.text('qa@example.com'), findsOneWidget);
        expect(find.text('+91 90000 00001'), findsOneWidget);
        final cards = find.byType(RadioListTile<String>);
        expect(
          tester.getTopLeft(cards.first).dy,
          tester.getTopLeft(cards.last).dy,
        );
        expect(
          tester.getTopLeft(cards.first).dx,
          lessThan(tester.getTopLeft(cards.last).dx),
        );
        await tester.tap(find.text('Backup QA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('QA Tester'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RadioListTile<String>>(
                find.widgetWithText(RadioListTile<String>, 'QA Tester'),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<RadioListTile<String>>(
                find.widgetWithText(RadioListTile<String>, 'Backup QA'),
              )
              .selected,
          isFalse,
        );
        await tester.tap(find.text('Set due date (optional)'));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDatePicker), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('QA Tester'), findsOneWidget);
        final saveResponse = Completer<void>();
        client.saveResponse = saveResponse.future;
        await tester.tap(save);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Saving changes…'), findsOneWidget);
        saveResponse.complete();
        await tester.pumpAndSettle();
        expect(find.text('Saving changes…'), findsNothing);
        expect(
          client.lastPatch,
          '/order-work/order-124/items/item-126/quality-assignment',
        );
        expect(client.patchBody, {'user_id': 'qa-1'});
        expect(find.text('QA assigned'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        await tester.tap(find.text('Back to orders'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: otherCard, matching: find.text('Reassign QA')),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
      }
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(second).selected, isTrue);
      expect(tester.widget<ListTile>(first).selected, isFalse);
      if (name == 'Sales') {
        final detail = tester.widget<PurchaseOrderDetailScreen>(
          find.byType(PurchaseOrderDetailScreen),
        );
        expect(detail.poId, 'order-125');
      } else {
        expect(find.text('Second item'), findsOneWidget);
        expect(find.text('Private line'), findsNothing);
      }
    });
  }

  testWidgets('Export shows readiness without order actions or item details', (
    tester,
  ) async {
    final client = _WorkClient();
    final tenant = _WorkspaceTenant(client, 'Export', {
      AppPermissions.exportRead,
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<TenantProvider>.value(
        value: tenant,
        child: const MaterialApp(
          home: OrderWorkScreen(workspace: DepartmentWorkspace.export),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.lastGet, '/order-work?department=EXPORT');
    expect(find.text('PO-124'), findsOneWidget);
    expect(find.text('40% ready · 4 of 10 cartons packed'), findsOneWidget);
    expect(find.text('Mark packed'), findsNothing);
    expect(find.text('Private line'), findsNothing);
  });

  testWidgets('packing changes only after the update dialog is confirmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = _WorkClient();
    final tenant = _WorkspaceTenant(client, 'Packer', {
      AppPermissions.packingUpdate,
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<TenantProvider>.value(
        value: tenant,
        child: const MaterialApp(
          home: OrderWorkScreen(workspace: DepartmentWorkspace.packing),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PO-124'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark packed'));
    await tester.pumpAndSettle();
    expect(find.text('Mark item packed'), findsOneWidget);
    expect(client.lastPatch, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(client.lastPatch, isNull);

    await tester.tap(find.text('Mark packed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mark packed').last);
    await tester.pumpAndSettle();
    expect(
      client.lastPatch,
      '/purchase-orders/order-124/items/item-123/packing',
    );
    expect(client.patchBody, {'packed_cartons': 10});
    expect(tester.takeException(), isNull);
  });

  test(
    'Operational queues follow carton progress and confirmed order status',
    () {
      PurchaseOrderModel order(String status, Map<String, dynamic> item) =>
          PurchaseOrderModel.fromJson({
            'status': status,
            'items': [item],
          });

      final line = {
        'cartons': 10,
        'completed_cartons': 10,
        'packed_cartons': 5,
        'shipped_cartons': 1,
      };
      expect(
        ProductionQueue.inspection.matches(order('IN_PRODUCTION', line)),
        isTrue,
      );
      final passed = {...line, 'qc_passed': true};
      expect(
        ProductionQueue.inspection.matches(order('IN_PRODUCTION', passed)),
        isFalse,
      );
      expect(
        ProductionQueue.packing.matches(order('IN_PRODUCTION', passed)),
        isTrue,
      );
      expect(
        ProductionQueue.dispatch.matches(order('IN_PRODUCTION', passed)),
        isTrue,
      );
      expect(ProductionQueue.packing.matches(order('DRAFT', passed)), isFalse);
      expect(order('DRAFT', passed).wasConfirmed, isFalse);
      expect(order('CANCELLED', passed).wasConfirmed, isFalse);
      expect(order('DELIVERED', passed).wasConfirmed, isTrue);
    },
  );
}

class _WorkspaceTenant extends TenantProvider {
  _WorkspaceTenant(ApiClient client, this.name, this.permissions)
    : super(apiClient: client);

  final String name;
  final Set<String> permissions;

  @override
  String get selectedDepartmentName => name;

  @override
  bool get isTenantAdmin => name == 'Administrator';

  @override
  TenantOption get activeTenant => TenantOption(
    tenantId: 'test-tenant',
    companyName: isTenantAdmin ? '' : 'Test Organization',
    isAdmin: isTenantAdmin,
  );

  @override
  bool hasPermission(String permissionId) => permissions.contains(permissionId);
}

class _WorkClient extends ApiClient {
  _WorkClient({this.includeSecondOrder = false});

  final bool includeSecondOrder;
  String? lastGet;
  String? lastPatch;
  Object? patchBody;
  Future<Map<String, dynamic>>? staffResponse;
  Future<void>? saveResponse;
  int staffRequests = 0;

  @override
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    lastPatch = endpoint;
    patchBody = body;
    await saveResponse;
    return {'success': true};
  }

  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    lastGet = endpoint;
    if (endpoint == '/order-work/staff') {
      staffRequests++;
      final response = staffResponse;
      if (response != null) return response;
      return {
        'quality': [
          {'user_id': 'qa-1', 'name': 'QA Tester'},
        ],
      };
    }
    if (endpoint != '/purchase-orders' &&
        !endpoint.startsWith('/order-work?')) {
      return <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[
      {
        'tenant_id': 'test-tenant',
        'po_id': 'order-124',
        'po_number': 'PO-124',
        'customer_name': 'Test Customer',
        'status': includeSecondOrder ? 'DRAFT' : 'CONFIRMED',
        'editable': true,
        'total_cartons': 10,
        'packed_cartons': 4,
        'items': [
          {
            'item_id': 'item-123',
            'item_name': 'Private line',
            'cartons': 10,
            if (includeSecondOrder &&
                endpoint == '/order-work?department=PRODUCTION_MANAGER') ...{
              'qa_user_id': 'qa-1',
              'qa_assignee': 'QA Tester',
              'checked_at': '2026-11-28T11:15:00Z',
              'qa_completion_history': [
                {
                  'at': '2026-11-28T11:15:00Z',
                  'user_id': 'qa-1',
                  'note': 'Inspection passed',
                },
              ],
            },
            if (includeSecondOrder &&
                endpoint == '/order-work?department=PRODUCTION_MANAGER')
              'assignments': [
                {
                  'assignment_id': 'assignment-1',
                  'assignee': 'Supervisor Tester',
                  'assigned_cartons': 5,
                  'completed_cartons': 2,
                  'assigned_at': '2026-11-27',
                  'target_date': '2026-12-10',
                  'progress_history': [
                    {
                      'at': '2026-11-28T11:10:00Z',
                      'supervisor_name': 'Supervisor Tester',
                      'previous_cartons': 0,
                      'completed_cartons': 2,
                    },
                  ],
                },
              ],
          },
          if (includeSecondOrder &&
              endpoint == '/order-work?department=PRODUCTION_MANAGER')
            {
              'item_id': 'item-126',
              'item_name': 'Additional line',
              'sku': 'SKU-126',
              'cartons': 5,
              if (lastPatch ==
                  '/order-work/order-124/items/item-126/quality-assignment') ...{
                'qa_user_id': 'qa-1',
                'qa_assignee': 'QA Tester',
              },
            },
        ],
      },
      if (includeSecondOrder)
        {
          'tenant_id': 'test-tenant',
          'po_id': 'order-125',
          'po_number': 'PO-125',
          'customer_name': 'Second Customer',
          'status': 'DRAFT',
          'editable': true,
          'items': [
            {'item_id': 'item-125', 'item_name': 'Second item', 'cartons': 5},
          ],
        },
    ];
  }
}

class _WorkspaceInventory extends InventoryProvider {
  _WorkspaceInventory({required super.apiClient});

  @override
  void dispose() {
    syncManager.dispose();
    super.dispose();
  }
}
