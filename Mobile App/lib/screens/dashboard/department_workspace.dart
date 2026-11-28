import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/tenant_provider.dart';
import '../departments/departments_list_screen.dart';
import '../items/items_list_screen.dart';
import '../production/order_work_screen.dart';
import '../purchase_orders/purchase_orders_list_screen.dart';
import '../store_rooms/store_rooms_list_screen.dart';

enum DepartmentWorkspace {
  administrator(
    'Administration',
    'Organization overview',
    Icons.admin_panel_settings_outlined,
    0xFF163E37,
  ),
  sales('Sales', 'Customer orders', Icons.storefront_outlined, 0xFF234A80),
  storeRoom(
    'Store Room',
    'Stock and storage',
    Icons.warehouse_outlined,
    0xFF285C49,
  ),
  productionManager(
    'Production',
    'Production planning',
    Icons.account_tree_outlined,
    0xFF684218,
  ),
  supervisor(
    'Supervision',
    'Production floor',
    Icons.assignment_outlined,
    0xFF804322,
  ),
  quality(
    'Quality',
    'Quality inspections',
    Icons.fact_check_outlined,
    0xFF534287,
  ),
  packing('Packing', 'Packing station', Icons.inventory_2_outlined, 0xFF125E68),
  export('Export', 'Dispatch desk', Icons.local_shipping_outlined, 0xFF354771),
  accounts(
    'Accounts',
    'Order reconciliation',
    Icons.calculate_outlined,
    0xFF385969,
  );

  const DepartmentWorkspace(this.label, this.title, this.icon, this.colorValue);

  final String label;
  final String title;
  final IconData icon;
  final int colorValue;

  Color get color => Color(colorValue);

  static DepartmentWorkspace? resolve(TenantProvider tenant) {
    if (tenant.isTenantAdmin) return administrator;
    return switch (tenant.selectedDepartmentName?.trim().toLowerCase()) {
      'sales' => sales,
      'store room' || 'store rooms' || 'storeroom' => storeRoom,
      'production manager' || 'production managers' => productionManager,
      'supervisor' || 'supervisors' => supervisor,
      'qc' ||
      'qa' ||
      'quality control' ||
      'quality assurance' ||
      'quality assurance team' => quality,
      'packer' || 'packers' || 'packing' => packing,
      'export' || 'exports' || 'exporting team' => export,
      'accounts' || 'accounts team' || 'accounting' => accounts,
      _ => null,
    };
  }

  String? get orderWorkRole => switch (this) {
    productionManager => 'PRODUCTION_MANAGER',
    supervisor => 'SUPERVISOR',
    quality => 'QC',
    packing => 'PACKER',
    export => 'EXPORT',
    accounts => 'ACCOUNTS',
    _ => null,
  };
}

class DepartmentWorkspaceView extends StatelessWidget {
  const DepartmentWorkspaceView({
    super.key,
    required this.workspace,
    required this.onRefresh,
    this.userName,
    this.userAvatarUrl,
    this.onProfileTap,
  });

  final DepartmentWorkspace workspace;
  final Future<void> Function() onRefresh;
  final String? userName;
  final String? userAvatarUrl;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final (label, icon, permission) = switch (workspace) {
      DepartmentWorkspace.sales => (
        'Manage purchase orders',
        Icons.receipt_long_outlined,
        AppPermissions.poRead,
      ),
      DepartmentWorkspace.storeRoom => (
        'Manage room inventory',
        Icons.warehouse_outlined,
        AppPermissions.storeroomRead,
      ),
      DepartmentWorkspace.productionManager => (
        'Manage confirmed orders',
        Icons.account_tree_outlined,
        AppPermissions.productionRead,
      ),
      DepartmentWorkspace.supervisor => (
        'My assigned items',
        Icons.assignment_outlined,
        AppPermissions.productionRead,
      ),
      DepartmentWorkspace.quality => (
        'My assigned inspections',
        Icons.fact_check_outlined,
        AppPermissions.qcCheck,
      ),
      DepartmentWorkspace.packing => (
        'Mark items packed',
        Icons.inventory_2_outlined,
        AppPermissions.packingUpdate,
      ),
      DepartmentWorkspace.export => (
        'View order readiness',
        Icons.local_shipping_outlined,
        AppPermissions.exportRead,
      ),
      DepartmentWorkspace.accounts => (
        'Review confirmed orders',
        Icons.receipt_long_outlined,
        AppPermissions.poRead,
      ),
      DepartmentWorkspace.administrator => (
        'Manage users and departments',
        Icons.groups_outlined,
        AppPermissions.userRead,
      ),
    };

    final actions = <(String, IconData, Widget)>[
      if (tenant.hasPermission(permission))
        (
          label,
          icon,
          switch (workspace) {
            DepartmentWorkspace.sales => const PurchaseOrdersListScreen(),
            DepartmentWorkspace.storeRoom => const StoreRoomsListScreen(),
            DepartmentWorkspace.administrator => const DepartmentsListScreen(),
            _ => OrderWorkScreen(workspace: workspace),
          },
        ),
      if (workspace == DepartmentWorkspace.administrator) ...[
        (
          'Manage store rooms',
          Icons.warehouse_outlined,
          const StoreRoomsListScreen(),
        ),
        ('Manage items', Icons.view_in_ar_outlined, const ItemsListScreen()),
      ],
    ];

    if (workspace == DepartmentWorkspace.administrator) {
      return _buildAdministration(context, tenant, actions);
    }

    return RefreshIndicator(
      color: workspace.color,
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: workspace.color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(workspace.icon, color: Colors.white, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        workspace.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final (title, icon, screen) in actions)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(icon, color: workspace.color),
                    title: Text(title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => screen)),
                  ),
                ),
              if (actions.isEmpty)
                const Text(
                  'No workflow access is available for this department.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdministration(
    BuildContext context,
    TenantProvider tenant,
    List<(String, IconData, Widget)> actions,
  ) {
    final theme = Theme.of(context);
    final name = userName?.trim();
    final organization = tenant.activeTenant?.companyName.trim();
    final initial = name == null || name.isEmpty
        ? 'A'
        : name.characters.first.toUpperCase();

    return ColoredBox(
      color: AppTheme.adminCanvas,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onProfileTap,
                    tooltip: 'Account profile',
                    padding: EdgeInsets.zero,
                    icon: CircleAvatar(
                      radius: 25,
                      foregroundImage: userAvatarUrl == null
                          ? null
                          : NetworkImage(userAvatarUrl!),
                      onForegroundImageError: userAvatarUrl == null
                          ? null
                          : (_, _) {},
                      backgroundColor: AppTheme.adminTint,
                      foregroundColor: AppTheme.adminInk,
                      child: Text(initial),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name == null || name.isEmpty ? 'Administration' : 'Hi, $name',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (organization != null && organization.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(organization, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    final columns = constraints.maxWidth >= 720
                        ? 3
                        : constraints.maxWidth >= 280
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * gap) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final (title, icon, screen) in actions)
                          SizedBox(
                            width: width,
                            child: _AdministrationTile(
                              title: title,
                              icon: icon,
                              screen: screen,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdministrationTile extends StatelessWidget {
  const _AdministrationTile({
    required this.title,
    required this.icon,
    required this.screen,
  });

  final String title;
  final IconData icon;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final (color, description) = switch (screen) {
      DepartmentsListScreen() => (
        AppTheme.adminPeople,
        'Assign staff to departments',
      ),
      StoreRoomsListScreen() => (
        AppTheme.adminStorage,
        'Manage rooms and stock',
      ),
      _ => (AppTheme.adminItems, 'Maintain the item catalog'),
    };
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => screen)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 172),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Icon(icon, size: 22),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
