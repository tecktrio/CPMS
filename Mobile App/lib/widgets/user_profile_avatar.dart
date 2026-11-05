import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../screens/tenant/tenant_selector_screen.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenant = context.watch<TenantProvider>();
    final user = auth.user;
    final activeTenant = tenant.activeTenant;

    final initial = (user != null && user.fullName.isNotEmpty)
        ? user.fullName[0].toUpperCase()
        : 'U';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Tooltip(
        message: user?.fullName ?? 'User Profile',
        child: InkWell(
          onTap: () => _showProfileDialog(context, user, activeTenant, tenant, auth),
          borderRadius: BorderRadius.circular(24),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF0F766E),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(
    BuildContext context,
    AuthUser? user,
    TenantOption? activeTenant,
    TenantProvider tenant,
    AuthProvider auth,
  ) {
    final isAdmin = tenant.isTenantAdmin;
    final deptCount = tenant.userDepartmentCount;

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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // User details
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                      child: Text(
                        (user != null && user.fullName.isNotEmpty)
                            ? user.fullName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Operator',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            user?.emailAddress ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                                  : const Color(0xFF0284C7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAdmin
                                  ? '👑 Organization Admin'
                                  : (deptCount == 1 ? '🏛️ $singleDeptName' : '🏛️ $deptCount Departments'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isAdmin ? const Color(0xFF0F766E) : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9)),

                // Organization info
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.business_outlined, color: Color(0xFF0F766E)),
                  title: const Text('Active Organization', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  subtitle: Text(
                    activeTenant?.companyName ?? 'Cyan CIMS',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Switch Org'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TenantSelectorScreen()),
                      );
                    },
                  ),
                ),

                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Sign Out
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      context.read<TenantProvider>().clear();
                      await auth.signOut();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
