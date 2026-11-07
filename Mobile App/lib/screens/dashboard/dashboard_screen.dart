import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/tenant_provider.dart';
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
    final tenant = context.read<TenantProvider>();
    // Dedicated API to get available operations & permissions for this tenant
    await tenant.loadTenantPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();

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

    // Grid operations user can perform - each permission has its own separate option
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
        tag: 'Stock & Products',
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
        title: 'Update Items',
        tag: 'Edit SKU & Master',
        icon: Icons.edit_note_outlined,
        color: const Color(0xFF0F766E),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.itemUpdate),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ItemsListScreen(manageMode: true),
            ),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Delete Items',
        tag: 'Remove SKU Catalog',
        icon: Icons.delete_outline,
        color: const Color(0xFF0F766E),
        isPermitted: isAdmin || tenant.hasPermission(AppPermissions.itemDelete),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ItemsListScreen(manageMode: true),
            ),
          );
        },
      ),
      _DashboardOperationItem(
        title: 'Create Cold Room',
        tag: 'Storage Facility',
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
        tag: 'Storage Directory',
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
        tag: 'Stock Receipt',
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
        title: 'FEFO Deductions',
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
        tag: 'Batch Inventory',
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
        tag: 'Department Directory',
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
            // Operations Grid (Empty state if no permissions)
            if (allowedOperations.isEmpty)
              _buildEmptyState()
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 modules in 1 row
                    crossAxisSpacing: 0, // No margin/spacing between cells
                    mainAxisSpacing: 0, // Corners touch nearest ones
                    childAspectRatio: 1.0, // Each cell as exact square
                  ),
                  itemCount: allowedOperations.length,
                  itemBuilder: (context, index) {
                    return _buildOperationGridCell(
                      allowedOperations[index],
                      index: index,
                      totalCount: allowedOperations.length,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationGridCell(
    _DashboardOperationItem op, {
    required int index,
    required int totalCount,
  }) {
    final isLeftColumn = index % 2 == 0;
    final row = index ~/ 2;
    final totalRows = (totalCount / 2).ceil();
    final isLastRow = row == totalRows - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: isLeftColumn
              ? const BorderSide(color: Color(0xFFE2E8F0), width: 1)
              : BorderSide.none,
          bottom: !isLastRow
              ? const BorderSide(color: Color(0xFFE2E8F0), width: 1)
              : BorderSide.none,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: op.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: op.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(op.icon, color: op.color, size: 26),
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
