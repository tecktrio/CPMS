import 'package:cpms_mobile/core/constants/permissions.dart';
import 'package:cpms_mobile/core/network/api_client.dart';
import 'package:cpms_mobile/providers/purchase_order_provider.dart';
import 'package:cpms_mobile/screens/production/order_work_screen.dart';
import 'package:cpms_mobile/providers/tenant_provider.dart';
import 'package:cpms_mobile/screens/dashboard/department_workspace.dart';
import 'package:cpms_mobile/screens/production/production_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = ApiClient();
      final tenant = _WorkspaceTenant(client, name, {
        AppPermissions.poRead,
        permission,
      });
      final workspace = DepartmentWorkspace.resolve(tenant);
      expect(workspace, expectedWorkspace);

      await tester.pumpWidget(
        ChangeNotifierProvider<TenantProvider>.value(
          value: tenant,
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

      expect(find.text(expectedWorkspace.title), findsOneWidget);
      expect(find.widgetWithText(ListTile, action), findsOneWidget);
      expect(
        find.byType(ListTile),
        findsNWidgets(name == 'Administrator' ? 3 : 1),
      );
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
  bool hasPermission(String permissionId) => permissions.contains(permissionId);
}

class _WorkClient extends ApiClient {
  String? lastGet;

  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    lastGet = endpoint;
    return <Map<String, dynamic>>[
      {
        'po_id': 'order-124',
        'po_number': 'PO-124',
        'customer_name': 'Test Customer',
        'status': 'CONFIRMED',
        'total_cartons': 10,
        'packed_cartons': 4,
        'items': [
          {'item_name': 'Private line'},
        ],
      },
    ];
  }
}
