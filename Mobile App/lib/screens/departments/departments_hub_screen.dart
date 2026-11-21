import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/tenant_provider.dart';
import 'departments_list_screen.dart';
import 'add_tenant_user_screen.dart';
import '../../widgets/user_profile_avatar.dart';

class DepartmentsHubScreen extends StatelessWidget {
  const DepartmentsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;

    final canReadDept = isAdmin || tenant.hasPermission(AppPermissions.departmentRead);
    final canReadUser = isAdmin || tenant.hasPermission(AppPermissions.userRead);
    final canAddUser = isAdmin || tenant.hasPermission(AppPermissions.userAdd);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & Roles Hub'),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
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
                Icon(Icons.badge_outlined, color: Color(0xFF14532D), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preset Role-Based System (9 Fixed Departments)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF14532D)),
                      ),
                      Text(
                        'Assign team members to fixed organizational roles with dedicated module access.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF14532D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (canReadDept)
            _buildPermissionPageCard(
              context: context,
              title: 'View Organizational Roles & Departments',
              description: 'Browse the 9 fixed preset departments and see their respective module permissions.',
              permissionId: AppPermissions.departmentRead,
              icon: Icons.apartment,
              color: const Color(0xFF14532D),
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

          if (!canReadDept && !canAddUser && !canReadUser)
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
    ),
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

