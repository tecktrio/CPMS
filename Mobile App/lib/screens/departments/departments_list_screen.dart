import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'edit_department_screen.dart';
import 'update_user_departments_screen.dart';

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove User from Organization',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove ${user.fullName.isNotEmpty ? user.fullName : user.emailAddress} from this organization and all its departments?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text('Remove User', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDepartment(DepartmentModel dept) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Deactivate Department',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to deactivate "${dept.departmentName}"? Users assigned to this department will lose its associated permissions.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text('Deactivate', style: TextStyle(fontWeight: FontWeight.w700)),
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
    if (_tabController.index == 0 && canAddUser) {
      fab = Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          icon: const Icon(Icons.person_add_outlined, size: 18, color: Colors.white),
          label: const Text(
            'Add User',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UpdateUserDepartmentsScreen(),
              ),
            ).then((_) => _loadData());
          },
        ),
      );
    } else if (_tabController.index == 1 && canCreateDept) {
      fab = Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text(
            'Create Department',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditDepartmentScreen(),
              ),
            ).then((_) => _loadData());
          },
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              children: const [
                Text(
                  'Users & Departments',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.black,
                    indicatorWeight: 2.5,
                    labelColor: Colors.black,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    unselectedLabelStyle:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: [
                      Tab(
                        text: 'Users (${deptProvider.tenantUsers.length})',
                      ),
                      Tab(
                        text:
                            'Departments (${tenant.tenantDepartments.length})',
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: fab,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: TabBarView(
            controller: _tabController,
            children: [
              // -------------------------------------------------------------------
              // Tab 1: Users List
              // -------------------------------------------------------------------
              RefreshIndicator(
                onRefresh: _loadData,
                child: deptProvider.tenantUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 14),
                            const Text(
                              'No users registered yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add staff members to grant department access.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : isWide
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 96),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  screenWidth >= 1050 ? 2 : 1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 148,
                            ),
                            itemCount: deptProvider.tenantUsers.length,
                            itemBuilder: (context, index) {
                              return _buildUserCard(
                                  context,
                                  deptProvider.tenantUsers[index],
                                  tenant,
                                  canUpdateUser,
                                  canDeleteUser);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                            itemCount: deptProvider.tenantUsers.length + 1,
                            itemBuilder: (context, index) {
                              if (index == deptProvider.tenantUsers.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Developed by Bigburry Hypersystems LLP',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildUserCard(
                                    context,
                                    deptProvider.tenantUsers[index],
                                    tenant,
                                    canUpdateUser,
                                    canDeleteUser),
                              );
                            },
                          ),
              ),

              // -------------------------------------------------------------------
              // Tab 2: Departments List
              // -------------------------------------------------------------------
              RefreshIndicator(
                onRefresh: _loadData,
                child: tenant.tenantDepartments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apartment,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 14),
                            const Text(
                              'No departments configured yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create departments to organize operational permissions.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : isWide
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 96),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  screenWidth >= 1050 ? 2 : 1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 148,
                            ),
                            itemCount: tenant.tenantDepartments.length,
                            itemBuilder: (context, index) {
                              return _buildDepartmentCard(
                                  context,
                                  tenant.tenantDepartments[index],
                                  canUpdateDept,
                                  canDeleteDept);
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                            itemCount:
                                tenant.tenantDepartments.length + 1,
                            itemBuilder: (context, index) {
                              if (index ==
                                  tenant.tenantDepartments.length) {
                                return const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Developed by Bigburry Hypersystems LLP',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildDepartmentCard(
                                    context,
                                    tenant.tenantDepartments[index],
                                    canUpdateDept,
                                    canDeleteDept),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    TenantUserModel u,
    TenantProvider tenant,
    bool canUpdateUser,
    bool canDeleteUser,
  ) {
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

    String userInitials = 'U';
    if (u.fullName.trim().isNotEmpty) {
      final parts = u.fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        userInitials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].length >= 2) {
        userInitials = parts[0].substring(0, 2).toUpperCase();
      } else {
        userInitials = parts[0][0].toUpperCase();
      }
    } else if (u.emailAddress.isNotEmpty) {
      userInitials = u.emailAddress[0].toUpperCase();
    }

    final resolvedAvatar = ApiConstants.resolveImageUrl(u.avatarUrl);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: resolvedAvatar != null
                      ? Image.network(
                          resolvedAvatar,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: Text(
                              userInitials,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: Text(
                            userInitials,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
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
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.emailAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canUpdateUser)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Update Departments',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UpdateUserDepartmentsScreen(existingUser: u),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
              if (canDeleteUser)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Color(0xFFDC2626)),
                  tooltip: 'Remove from Tenant',
                  onPressed: () => _confirmRemoveUser(u),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ASSIGNED DEPARTMENTS',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: assignedDeptNames.isEmpty
                    ? [
                        const Text(
                          'No departments assigned',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ]
                    : assignedDeptNames.map((name) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        );
                      }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(
    BuildContext context,
    DepartmentModel d,
    bool canUpdateDept,
    bool canDeleteDept,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.apartment,
                    color: Colors.black, size: 20),
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
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (d.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        d.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${d.permissionIds.length} Perms',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              if (canUpdateDept)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Department & Permissions',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditDepartmentScreen(
                          existingDepartment: d,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
              if (canDeleteDept)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Color(0xFFDC2626)),
                  tooltip: 'Deactivate Department',
                  onPressed: () => _confirmDeleteDepartment(d),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: d.permissionIds.take(6).map((permId) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  permId,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569)),
                ),
              );
            }).toList()
              ..addAll(
                d.permissionIds.length > 6
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${d.permissionIds.length - 6} more',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ]
                    : [],
              ),
          ),
        ],
      ),
    );
  }
}
