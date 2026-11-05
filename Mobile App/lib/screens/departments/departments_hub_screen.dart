import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/tenant_provider.dart';
import 'departments_list_screen.dart';
import 'create_department_screen.dart';
import 'add_tenant_user_screen.dart';
import '../../widgets/user_profile_avatar.dart';

class DepartmentsHubScreen extends StatelessWidget {
  const DepartmentsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;

    final canReadDept = isAdmin || tenant.hasPermission(AppPermissions.departmentRead);
    final canCreateDept = isAdmin || tenant.hasPermission(AppPermissions.departmentCreate);
    final canReadUser = isAdmin || tenant.hasPermission(AppPermissions.userRead);
    final canAddUser = isAdmin || tenant.hasPermission(AppPermissions.userAdd);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments & Staff Roles Hub'),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFFD97706), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Department-Centric RBAC Operations',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD97706)),
                      ),
                      Text(
                        'Choose an operation page based on your allocated permissions.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (canCreateDept)
            _buildPermissionPageCard(
              context: context,
              title: 'Create Department',
              description: 'Define organizational departments and allocate specific module permissions.',
              permissionId: AppPermissions.departmentCreate,
              icon: Icons.add_home_work_outlined,
              color: const Color(0xFFD97706),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateDepartmentScreen()),
                );
              },
            ),

          if (canReadDept)
            _buildPermissionPageCard(
              context: context,
              title: 'View & Manage Departments',
              description: 'Browse configured departments, inspect allocated permissions, and edit roles.',
              permissionId: AppPermissions.departmentRead,
              icon: Icons.apartment,
              color: const Color(0xFF0F766E),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DepartmentsListScreen()),
                );
              },
            ),

          if (canAddUser)
            _buildPermissionPageCard(
              context: context,
              title: 'Add Staff Member',
              description: 'Invite new staff by email and assign them to departments to grant permissions.',
              permissionId: AppPermissions.userAdd,
              icon: Icons.person_add_outlined,
              color: const Color(0xFF0284C7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTenantUserScreen()),
                );
              },
            ),

          if (canReadUser)
            _buildPermissionPageCard(
              context: context,
              title: 'View Staff Directory',
              description: 'View members of this organization, department assignments, and access privileges.',
              permissionId: AppPermissions.userRead,
              icon: Icons.people_outline,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DepartmentsListScreen()),
                );
              },
            ),

          if (!canCreateDept && !canReadDept && !canAddUser && !canReadUser)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No accessible operations in this module. Contact your Tenant Admin.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionPageCard({
    required BuildContext context,
    required String title,
    required String description,
    required String permissionId,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Requires: $permissionId',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

