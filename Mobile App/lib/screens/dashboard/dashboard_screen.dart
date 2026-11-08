import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../items/items_list_screen.dart';
import '../store_rooms/store_rooms_list_screen.dart';
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
    await tenant.loadTenantPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final activeTenant = tenant.activeTenant;
    final isAdmin = tenant.isTenantAdmin;
    final deptCount = tenant.userDepartmentCount;

    String singleDeptName = 'Assigned Department';
    if (!isAdmin && activeTenant != null && activeTenant.departmentIds.length == 1) {
      final match = tenant.tenantDepartments.firstWhere(
        (d) => d.departmentId == activeTenant.departmentIds.first,
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

    // Permission checks per module
    final hasItemAccess = isAdmin || tenant.hasAnyPermissionInModule('item');
    final hasStoreRoomAccess = isAdmin || tenant.hasAnyPermissionInModule('storeroom');
    final hasDeptAccess = isAdmin || tenant.hasAnyPermissionInModule('department');
    final hasUserAccess = isAdmin || tenant.hasAnyPermissionInModule('user');

    // Build module action tags
    List<String> itemActions = [];
    if (hasItemAccess) {
      itemActions.add('View');
      if (isAdmin || tenant.hasPermission(AppPermissions.itemCreate)) itemActions.add('Add');
      if (isAdmin || tenant.hasPermission(AppPermissions.itemUpdate)) itemActions.add('Edit');
      if (isAdmin || tenant.hasPermission(AppPermissions.itemDelete)) itemActions.add('Delete');
    }

    List<String> storeRoomActions = [];
    if (hasStoreRoomAccess) {
      storeRoomActions.add('View');
      if (isAdmin || tenant.hasPermission(AppPermissions.storeroomCreate)) storeRoomActions.add('Add');
      if (isAdmin || tenant.hasPermission(AppPermissions.storeroomUpdate)) storeRoomActions.add('Edit');
      if (isAdmin || tenant.hasPermission(AppPermissions.storeroomDelete)) storeRoomActions.add('Delete');
    }

    List<String> deptActions = [];
    if (hasDeptAccess) {
      deptActions.add('View');
      if (isAdmin || tenant.hasPermission(AppPermissions.departmentCreate)) deptActions.add('Add');
      if (isAdmin || tenant.hasPermission(AppPermissions.departmentUpdate)) deptActions.add('Edit');
      if (isAdmin || tenant.hasPermission(AppPermissions.departmentDelete)) deptActions.add('Deactivate');
    }

    List<String> userActions = [];
    if (hasUserAccess) {
      userActions.add('View');
      if (isAdmin || tenant.hasPermission(AppPermissions.userAdd)) userActions.add('Invite');
      if (isAdmin || tenant.hasPermission(AppPermissions.userUpdate)) userActions.add('Edit');
      if (isAdmin || tenant.hasPermission(AppPermissions.userDelete)) userActions.add('Remove');
    }

    final modules = <_DashboardModuleItem>[
      _DashboardModuleItem(
        title: 'Items & Products',
        subtitle: 'Catalog & Stock',
        actions: itemActions,
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF0F766E),
        isPermitted: hasItemAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ItemsListScreen()),
          );
        },
      ),
      _DashboardModuleItem(
        title: 'Store Rooms',
        subtitle: 'Storage & Sections',
        actions: storeRoomActions,
        icon: Icons.meeting_room_outlined,
        color: const Color(0xFF0284C7),
        isPermitted: hasStoreRoomAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreRoomsListScreen()),
          );
        },
      ),
      _DashboardModuleItem(
        title: 'Departments',
        subtitle: 'Structure & RBAC',
        actions: deptActions,
        icon: Icons.apartment,
        color: const Color(0xFFD97706),
        isPermitted: hasDeptAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DepartmentsListScreen(initialTabIndex: 0)),
          );
        },
      ),
      _DashboardModuleItem(
        title: 'Staff Directory',
        subtitle: 'Team & Access',
        actions: userActions,
        icon: Icons.people_outline,
        color: const Color(0xFF7C3AED),
        isPermitted: hasUserAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DepartmentsListScreen(initialTabIndex: 1)),
          );
        },
      ),
    ];

    // Filter to only the modules this user is permitted to see
    final allowedModules = modules.where((m) => m.isPermitted).toList();

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
            // Header message
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Text(
                    'Operational Modules',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${allowedModules.length} Active',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Modules Grid (Empty state if no permissions)
            if (allowedModules.isEmpty)
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
                    mainAxisSpacing: 0, // Contiguous square layout
                    childAspectRatio: 0.95,
                  ),
                  itemCount: allowedModules.length,
                  itemBuilder: (context, index) {
                    return _buildModuleGridCell(
                      allowedModules[index],
                      index: index,
                      totalCount: allowedModules.length,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleGridCell(
    _DashboardModuleItem mod, {
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
          onTap: mod.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: mod.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(mod.icon, color: mod.color, size: 28),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  mod.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mod.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mod.color,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: mod.actions.map((act) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        act,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    );
                  }).toList(),
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
            'No Modules Assigned',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Your account currently has no active modules assigned in this organization. Contact your administrator to allocate permissions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _DashboardModuleItem {
  final String title;
  final String subtitle;
  final List<String> actions;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPermitted;

  const _DashboardModuleItem({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isPermitted,
  });
}
