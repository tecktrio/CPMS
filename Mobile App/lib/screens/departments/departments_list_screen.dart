import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'add_tenant_user_dialog.dart';
import 'create_department_dialog.dart';

class DepartmentsListScreen extends StatefulWidget {
  final int initialTabIndex;
  const DepartmentsListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DepartmentsListScreen> createState() => _DepartmentsListScreenState();
}

class _DepartmentsListScreenState extends State<DepartmentsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tenant = context.read<TenantProvider>();
    final dept = context.read<DepartmentProvider>();
    await Future.wait([
      tenant.loadTenantDepartments(),
      dept.loadTenantUsers(),
      dept.loadSystemPermissions(),
    ]);
  }

  void _confirmRemoveUser(TenantUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove User from Organization'),
        content: Text(
          'Are you sure you want to remove ${user.fullName.isNotEmpty ? user.fullName : user.emailAddress} from this organization and all its departments?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final deptProvider = context.read<DepartmentProvider>();
              final success = await deptProvider.removeUserFromTenant(user.userId);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User removed from organization successfully.'),
                    backgroundColor: Color(0xFF0F766E),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(deptProvider.errorMessage ?? 'Failed to remove user.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Remove User'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDepartment(DepartmentModel dept) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Department'),
        content: Text(
          'Are you sure you want to deactivate "${dept.departmentName}"? Users assigned to this department will lose its associated permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final deptProvider = context.read<DepartmentProvider>();
              final tenantProvider = context.read<TenantProvider>();
              final success =
                  await deptProvider.deleteDepartment(dept.departmentId);
              if (!mounted) return;
              if (success) {
                await tenantProvider.loadTenantDepartments();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Department "${dept.departmentName}" deactivated successfully.',
                    ),
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      deptProvider.errorMessage ??
                          'Failed to deactivate department.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = tenant.isTenantAdmin ||
        (tenant.activeTenant?.isAdmin ?? false) ||
        (auth.availableTenants.any((t) => t.tenantId == tenant.activeTenant?.tenantId && t.isAdmin));

    final canCreateDept = isAdmin ||
        tenant.hasPermission(AppPermissions.departmentCreate);
    final canUpdateDept = isAdmin ||
        tenant.hasPermission(AppPermissions.departmentUpdate) ||
        tenant.hasPermission(AppPermissions.departmentCreate);
    final canDeleteDept = isAdmin ||
        tenant.hasPermission(AppPermissions.departmentDelete);
    final canAddUser = isAdmin || tenant.hasPermission(AppPermissions.userAdd);
    final canUpdateUser = isAdmin || tenant.hasPermission(AppPermissions.userUpdate);
    final canDeleteUser = isAdmin || tenant.hasPermission(AppPermissions.userDelete);

    Widget? fab;
    if (_tabController.index == 0 && canCreateDept) {
      fab = FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Department', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const CreateDepartmentDialog(),
          );
        },
      );
    } else if (_tabController.index == 1 && canAddUser) {
      fab = FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Staff User', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddTenantUserDialog(),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments & Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          const UserProfileAvatar(),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF0F766E),
          labelColor: const Color(0xFF0F766E),
          unselectedLabelColor: const Color(0xFF64748B),
          tabs: [
            Tab(
              icon: const Icon(Icons.apartment, size: 20),
              text: 'Departments (${tenant.tenantDepartments.length})',
            ),
            Tab(
              icon: const Icon(Icons.people_outline, size: 20),
              text: 'Staff Members (${deptProvider.tenantUsers.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Departments List
          RefreshIndicator(
            onRefresh: _loadData,
            child: tenant.tenantDepartments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apartment, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No departments configured yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tenant.tenantDepartments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final d = tenant.tenantDepartments[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.apartment, color: Color(0xFFD97706)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.departmentName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (d.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            d.description,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDFA),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFF99F6E4)),
                                        ),
                                        child: Text(
                                          '${d.permissionIds.length} Perms',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                      if (canUpdateDept)
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0F766E)),
                                          tooltip: 'Edit Department & Permissions',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => CreateDepartmentDialog(
                                                existingDepartment: d,
                                              ),
                                            );
                                          },
                                        ),
                                      if (canDeleteDept)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          tooltip: 'Deactivate Department',
                                          onPressed: () => _confirmDeleteDepartment(d),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: d.permissionIds.take(6).map((permId) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      permId,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                    ),
                                  );
                                }).toList()
                                  ..addAll(
                                    d.permissionIds.length > 6
                                        ? [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '+${d.permissionIds.length - 6} more',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ]
                                        : [],
                                  ),
                              ),
                                if (canUpdateDept || canDeleteDept) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (canUpdateDept)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF0F766E),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                          label: const Text(
                                            'Edit Permissions',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => CreateDepartmentDialog(
                                                existingDepartment: d,
                                              ),
                                            );
                                          },
                                        ),
                                      if (canDeleteDept) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                          label: const Text(
                                            'Deactivate',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () => _confirmDeleteDepartment(d),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Tab 2: Tenant Users List
          RefreshIndicator(
            onRefresh: _loadData,
            child: deptProvider.tenantUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No staff members in directory',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: deptProvider.tenantUsers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final u = deptProvider.tenantUsers[index];

                      // Map user department names
                      final assignedDeptNames = u.departmentIds.map((deptId) {
                        final found = tenant.tenantDepartments.firstWhere(
                          (d) => d.departmentId == deptId,
                          orElse: () => DepartmentModel(
                            departmentId: deptId,
                            tenantId: '',
                            departmentName: deptId,
                            description: '',
                            permissionIds: [],
                            isActive: true,
                          ),
                        );
                        return found.departmentName;
                      }).toList();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                    child: Text(
                                      (u.fullName.isNotEmpty
                                              ? u.fullName[0]
                                              : u.emailAddress[0])
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.fullName.isNotEmpty ? u.fullName : 'Staff Member',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          u.emailAddress,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canUpdateUser)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Update Departments',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AddTenantUserDialog(existingUser: u),
                                        );
                                      },
                                    ),
                                  if (canDeleteUser)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Remove from Tenant',
                                      onPressed: () => _confirmRemoveUser(u),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Assigned Departments:',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: assignedDeptNames.isEmpty
                                    ? [
                                        const Text(
                                          'No departments assigned',
                                          style: TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ]
                                    : assignedDeptNames.map((name) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDFA),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF99F6E4)),
                                          ),
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F766E),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: fab,
    );
  }
}
