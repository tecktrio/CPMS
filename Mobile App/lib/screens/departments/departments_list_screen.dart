import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'update_user_departments_screen.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Remove User from Organization',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove ${user.fullName.isNotEmpty ? user.fullName : user.emailAddress} from this organization?',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = tenant.isTenantAdmin ||
        (tenant.activeTenant?.isAdmin ?? false) ||
        (auth.availableTenants.any((t) => t.tenantId == tenant.activeTenant?.tenantId && t.isAdmin));

    final canAddUser = isAdmin || tenant.hasPermission(AppPermissions.userAdd);
    final canUpdateUser = isAdmin || tenant.hasPermission(AppPermissions.userUpdate);
    final canDeleteUser = isAdmin || tenant.hasPermission(AppPermissions.userDelete);

    final allUsers = deptProvider.tenantUsers;
    final filteredUsers = allUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchName = u.fullName.toLowerCase().contains(q);
      final matchUsername = u.userName.toLowerCase().contains(q);
      final matchEmail = u.emailAddress.toLowerCase().contains(q);
      final matchDept = u.departmentIds.any((id) {
        final d = tenant.tenantDepartments.firstWhere(
          (dept) => dept.departmentId == id,
          orElse: () => DepartmentModel(
            departmentId: '',
            tenantId: '',
            departmentName: '',
            description: '',
            permissionIds: [],
            isActive: true,
          ),
        );
        return d.departmentName.toLowerCase().contains(q);
      });
      return matchName || matchUsername || matchEmail || matchDept;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    Widget? fab;
    if (canAddUser) {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
        title: Row(
          children: [
            const Text(
              'Users & Departments',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${allUsers.length} Users',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: fab,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: RefreshIndicator(
            color: const Color(0xFF064E3B),
            onRefresh: _loadData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                // Info banner explaining the fixed departments rule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Select any user below to reassign them to any of the fixed organizational departments.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Search Bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search staff by name, email, or department...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),

                const SizedBox(height: 14),

                if (deptProvider.isLoading && allUsers.isEmpty)
                  const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF064E3B)),
                    ),
                  )
                else if (allUsers.isEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: Center(
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
                            'Tap "Add User" below to invite staff members to this organization.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else if (isWide)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenWidth >= 1050 ? 2 : 1,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 132,
                    ),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(
                        context,
                        filteredUsers[index],
                        tenant,
                        canUpdateUser,
                        canDeleteUser,
                      );
                    },
                  )
                else
                  ...filteredUsers.map((u) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUserCard(
                        context,
                        u,
                        tenant,
                        canUpdateUser,
                        canDeleteUser,
                      ),
                    );
                  }),

                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Cyan CPMS • Preset Department Management',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (canUpdateUser) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UpdateUserDepartmentsScreen(existingUser: u),
                ),
              ).then((_) => _loadData());
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: resolvedAvatar != null
                            ? Image.network(
                                resolvedAvatar,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFF064E3B),
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
                                color: const Color(0xFF064E3B),
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u.userName.isNotEmpty
                                ? '@${u.userName} • ${u.emailAddress}'
                                : u.emailAddress,
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
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF064E3B)),
                        tooltip: 'Reassign Department',
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
                        tooltip: 'Remove from Organization',
                        onPressed: () => _confirmRemoveUser(u),
                      ),
                    if (canUpdateUser)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'DEPARTMENT: ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Expanded(
                      child: assignedDeptNames.isEmpty
                          ? const Text(
                              'Not assigned',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFDCFCE7)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.apartment,
                                    size: 13,
                                    color: Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      assignedDeptNames.first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF064E3B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
