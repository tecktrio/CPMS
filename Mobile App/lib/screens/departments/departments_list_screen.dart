import 'package:flutter/material.dart';

import '../../widgets/cpms_page_title.dart';

import 'package:provider/provider.dart';

import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../widgets/cpms_search_bar.dart';
import '../../widgets/app_footer.dart';
import '../../services/data_export_service.dart';
import '../../widgets/export_options_dialog.dart';
import 'update_user_departments_screen.dart';
import 'tenant_user_detail_screen.dart';

class DepartmentsListScreen extends StatefulWidget {
  final int initialTabIndex;
  const DepartmentsListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DepartmentsListScreen> createState() => _DepartmentsListScreenState();
}

class _DepartmentsListScreenState extends State<DepartmentsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tenant = context.read<TenantProvider>();
    final dept = context.read<DepartmentProvider>();
    await Future.wait([
      tenant.loadTenantDepartments(force: true),
      dept.loadTenantUsers(),
      dept.loadSystemPermissions(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin =
        tenant.isTenantAdmin ||
        (tenant.activeTenant?.isAdmin ?? false) ||
        (auth.availableTenants.any(
          (t) => t.tenantId == tenant.activeTenant?.tenantId && t.isAdmin,
        ));

    final canAddUser = isAdmin || tenant.hasPermission(AppPermissions.userAdd);
    final canUpdateUser =
        isAdmin || tenant.hasPermission(AppPermissions.userUpdate);
    final canDeleteUser =
        isAdmin || tenant.hasPermission(AppPermissions.userDelete);

    final departmentNames = {
      for (final department in tenant.tenantDepartments)
        department.departmentId: department.departmentName,
    };
    final allUsers = deptProvider.tenantUsers;
    final query = _searchQuery.toLowerCase();
    final filteredUsers = allUsers.where((user) {
      return [
        user.fullName,
        user.userName,
        user.emailAddress,
        for (final id in user.departmentIds) departmentNames[id] ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();

    final addUser = FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: AppTheme.adminPeople),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Add user'),
      onPressed: () async {
        final added = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const UpdateUserDepartmentsScreen(),
          ),
        );
        if (mounted && added == true) await _loadData();
      },
    );
    final search = CpmsSearchBar(
      controller: _searchController,
      hintText: 'Search staff or departments',
      accentColor: AppTheme.adminPeople,
      height: 48,
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
    );

    return Scaffold(
      backgroundColor: AppTheme.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.adminCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppTheme.adminInk,
        title: const CpmsPageTitle(
          'Users & Departments',
          icon: Icons.groups_outlined,
          accent: AppTheme.adminPeople,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.file_download_outlined,
              color: AppTheme.adminInk,
              size: 22,
            ),
            tooltip: 'Export Users',
            onPressed: () {
              ExportOptionsDialog.show(
                context,
                title: 'Export Users Directory',
                subtitle:
                    'Export ${filteredUsers.length} user(s) as PDF, CSV, or print.',
                baseFileName:
                    'CPMS-Users-${DateTime.now().millisecondsSinceEpoch}',
                onGeneratePdf: () => DataExportService.generateUsersPdf(
                  users: filteredUsers,
                  departments: tenant.tenantDepartments,
                  tenantName: tenant.activeTenant?.companyName,
                ),
                onGenerateCsv: () async =>
                    DataExportService.generateUsersCsvBytes(
                      users: filteredUsers,
                      departments: tenant.tenantDepartments,
                    ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.adminInk, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const UserProfileAvatar(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            color: AppTheme.adminPeople,
            onRefresh: _loadData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (!canAddUser) return search;
                    if (constraints.maxWidth >= 520) {
                      return Row(
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 12),
                          addUser,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [search, const SizedBox(height: 12), addUser],
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (allUsers.isNotEmpty) ...[
                  Text(
                    query.isEmpty
                        ? '${allUsers.length} ${allUsers.length == 1 ? 'user' : 'users'}'
                        : '${filteredUsers.length} of ${allUsers.length} users',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.adminInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (deptProvider.isLoading && allUsers.isEmpty)
                  const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF064E3B),
                      ),
                    ),
                  )
                else if (allUsers.isEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: AppTheme.adminPeople,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No users registered yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.adminInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Use Add user to invite staff to this organization.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (filteredUsers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No users matching "$_searchQuery"',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < filteredUsers.length;
                          index++
                        ) ...[
                          if (index > 0) const Divider(height: 1),
                          _buildUserRow(
                            context,
                            filteredUsers[index],
                            departmentNames,
                            canUpdateUser: canUpdateUser,
                            canDeleteUser: canDeleteUser,
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                const AppFooter(topPadding: 16, bottomPadding: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(
    BuildContext context,
    TenantUserModel user,
    Map<String, String> departmentNames, {
    required bool canUpdateUser,
    required bool canDeleteUser,
  }) {
    final name = tenantUserDisplayName(user);
    final department = user.departmentIds
        .map((id) => departmentNames[id])
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .join(', ');
    final subtitle = [
      if (user.userName.isNotEmpty) '@${user.userName}',
      department.isEmpty ? 'Unassigned' : department,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: TenantUserAvatar(user: user),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.adminInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.adminPeople,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TenantUserDetailScreen(
            userId: user.userId,
            canUpdate: canUpdateUser,
            canDelete: canDeleteUser,
          ),
        ),
      ),
    );
  }
}
