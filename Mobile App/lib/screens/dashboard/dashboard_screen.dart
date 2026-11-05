import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/tenant_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/department_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../items/create_item_screen.dart';
import '../items/items_list_screen.dart';
import '../store_rooms/create_store_room_screen.dart';
import '../store_rooms/store_rooms_list_screen.dart';
import '../stock_batches/inward_batch_screen.dart';
import '../stock_batches/fefo_picking_screen.dart';
import '../stock_batches/stock_batches_list_screen.dart';
import '../departments/create_department_screen.dart';
import '../departments/add_tenant_user_screen.dart';
import '../departments/departments_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final inventory = context.read<InventoryProvider>();
    final tenant = context.read<TenantProvider>();
    final dept = context.read<DepartmentProvider>();

    await Future.wait([
      tenant.loadTenantDepartments(),
      inventory.loadStoreRooms(),
      inventory.loadItems(),
      inventory.loadStockBatches(),
      inventory.loadExpiringSoon(7),
      dept.loadSystemPermissions(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final inventory = context.watch<InventoryProvider>();

    final activeTenant = tenant.activeTenant;
    final isAdmin = tenant.isTenantAdmin;
    final deptCount = tenant.userDepartmentCount;

    // Resolve name of department if user belongs to exactly 1 department
    String singleDeptName = 'Assigned Department';
    if (!isAdmin && deptCount == 1 && activeTenant != null) {
      final deptId = activeTenant.departmentIds.firstOrNull;
      final match = tenant.tenantDepartments.firstWhere(
        (d) => d.departmentId == deptId,
        orElse: () => DepartmentModel(
          departmentId: '',
          tenantId: '',
          departmentName: 'Assigned Department',
          description: '',
          permissionIds: [],
          isActive: true,
        ),
      );
      if (match.departmentName.isNotEmpty) {
        singleDeptName = match.departmentName;
      }
    }

    // Grid operations user can perform based on permissions
    final operations = <_DashboardOperationItem>[
      _DashboardOperationItem(
        title: 'Create Items',
        tag: 'Register SKU',
        icon: Icons.add_box_outlined,
        color: const Color(0xFF0F766E),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.itemCreate),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateItemScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'View Items',
        tag: '${inventory.items.length} Products',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF0F766E),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.itemRead),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ItemsListScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Create Cold Room',
        tag: 'New Storage Room',
        icon: Icons.add_home_work_outlined,
        color: const Color(0xFF0284C7),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.storeroomCreate),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStoreRoomScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'View Cold Rooms',
        tag: '${inventory.storeRooms.length} Rooms Active',
        icon: Icons.ac_unit,
        color: const Color(0xFF0284C7),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.storeroomRead),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreRoomsListScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Inward Batches',
        tag: 'Stock Lot Intake',
        icon: Icons.move_to_inbox_outlined,
        color: const Color(0xFF8B5CF6),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.batchCreate),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InwardBatchScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'FEFO Picking',
        tag: 'Option B Deduct',
        icon: Icons.rule_folder_outlined,
        color: const Color(0xFF8B5CF6),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.batchDeduct),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FefoPickingScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Stock on Rack',
        tag: '${inventory.stockBatches.length} Batches',
        icon: Icons.qr_code_scanner_outlined,
        color: const Color(0xFF8B5CF6),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.batchRead),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockBatchesListScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Create Department',
        tag: 'RBAC Roles',
        icon: Icons.domain_add_outlined,
        color: const Color(0xFFD97706),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.departmentCreate),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateDepartmentScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'View Departments',
        tag: '${tenant.tenantDepartments.length} Departments',
        icon: Icons.badge_outlined,
        color: const Color(0xFFD97706),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.departmentRead),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DepartmentsListScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Add Staff User',
        tag: 'Invite Member',
        icon: Icons.person_add_outlined,
        color: const Color(0xFFD97706),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.userAdd),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTenantUserScreen()),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Staff Directory',
        tag: 'Team Roster',
        icon: Icons.people_outline,
        color: const Color(0xFFD97706),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.userRead),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DepartmentsListScreen(initialTabIndex: 1)),
          );
        },
      ),
    ];

    // Filter to only the operations this user is allowed to perform
    final allowedOperations = operations.where((op) => op.isPermitted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeTenant?.companyName ?? 'Cyan CIMS',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              isAdmin ? 'Organization Admin' : (deptCount == 1 ? singleDeptName : '$deptCount Departments'),
              style: TextStyle(
                fontSize: 11,
                color: isAdmin ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Alert Shortfalls / Expiring Soon Banners
            if (isAdmin || tenant.hasPermission(AppPermissions.itemRead) || tenant.hasPermission(AppPermissions.batchRead))
              _buildAlertsSection(inventory),

            // Operations Grid (Empty state if no permissions)
            if (allowedOperations.isEmpty)
              _buildEmptyState()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 modules in 1 row
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0, // Each cell as square
                ),
                itemCount: allowedOperations.length,
                itemBuilder: (context, index) {
                  return _buildOperationGridCard(allowedOperations[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationGridCard(_DashboardOperationItem op) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: op.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: op.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(op.icon, color: op.color, size: 24),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                op.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                op.tag,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: op.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.lock_clock_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 14),
          Text(
            'No Operations Assigned',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Your account currently has no active operations in this organization. Contact your administrator to allocate permissions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(InventoryProvider inventory) {
    final shortfallItems =
        inventory.items.where((i) => i.isBelowReorderThreshold).toList();
    final expiringBatches = inventory.expiringSoonBatches;

    if (shortfallItems.isEmpty && expiringBatches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          if (shortfallItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${shortfallItems.length} item(s) below reorder threshold. Stock shortfall detected!',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (expiringBatches.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled,
                      color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${expiringBatches.length} batch(es) expiring within 7 days. Prioritize FEFO allocation!',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardOperationItem {
  final String title;
  final String tag;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPermitted;

  const _DashboardOperationItem({
    required this.title,
    required this.tag,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isPermitted,
  });
}
