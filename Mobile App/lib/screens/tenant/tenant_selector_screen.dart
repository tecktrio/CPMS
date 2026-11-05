import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../dashboard/dashboard_screen.dart';

class TenantSelectorScreen extends StatefulWidget {
  const TenantSelectorScreen({super.key});

  @override
  State<TenantSelectorScreen> createState() => _TenantSelectorScreenState();
}

class _TenantSelectorScreenState extends State<TenantSelectorScreen> {
  final _newOrgController = TextEditingController();

  @override
  void dispose() {
    _newOrgController.dispose();
    super.dispose();
  }

  void _showCreateTenantDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Register Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter company or business name. You will be set as the Tenant Admin with full access across all departments.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newOrgController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Company / Facility Name',
                  hintText: 'e.g. Cyan Cold Chain Logistics',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _newOrgController.text.trim();
                if (name.isEmpty) return;

                Navigator.pop(dialogCtx);
                final tenantProvider = context.read<TenantProvider>();
                final authProvider = context.read<AuthProvider>();

                final created = await tenantProvider.createTenant(name);
                if (!mounted) return;

                if (created != null) {
                  // Add to authProvider list
                  final currentList = List<TenantOption>.from(authProvider.availableTenants);
                  currentList.add(created);
                  authProvider.updateAvailableTenants(currentList);

                  _newOrgController.clear();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tenantProvider.errorMessage ?? 'Failed to create organization'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tenantProvider = context.watch<TenantProvider>();
    final tenants = authProvider.availableTenants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Organization'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: tenants.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.domain_disabled_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Organization Memberships Found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You are not currently a member of any organization.\nCreate a new organization to start operating.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Register New Organization'),
                        onPressed: _showCreateTenantDialog,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  const Text(
                    'Choose an Organization',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select the operational tenant to access its cold storage and inventory.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  ...tenants.map((t) {
                    final isAdmin = t.isAdmin;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isAdmin
                              ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                              : const Color(0xFF0284C7).withValues(alpha: 0.12),
                          child: Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.business,
                            color: isAdmin ? const Color(0xFF0F766E) : const Color(0xFF0284C7),
                          ),
                        ),
                        title: Text(
                          t.companyName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isAdmin
                                      ? '👑 Tenant Admin (All Departments)'
                                      : 'Staff (${t.departmentIds.length} Dept${t.departmentIds.length == 1 ? '' : 's'})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isAdmin
                                        ? const Color(0xFF0F766E)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await tenantProvider.selectTenant(t);
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Register Another Organization'),
                    onPressed: _showCreateTenantDialog,
                  ),
                ],
              ),
      ),
    );
  }
}
