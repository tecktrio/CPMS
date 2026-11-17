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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantProvider = context.read<TenantProvider>();
      if (tenantProvider.activeTenant != null) {
        tenantProvider.loadTenantDepartments();
      }
    });
  }

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

  Future<void> _handleTenantSelect(TenantOption t, TenantProvider tenantProvider) async {
    await tenantProvider.selectTenant(t);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _handleDepartmentSelect(
    String deptName,
    TenantOption t,
    TenantProvider tenantProvider,
  ) async {
    await tenantProvider.selectTenant(t, initialDepartmentName: deptName);
    tenantProvider.setSelectedDepartment(deptName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to $deptName'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _showDeleteOrganizationDialog(
    TenantOption t,
    TenantProvider tenantProvider,
    AuthProvider authProvider,
  ) {
    final confirmController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isConfirmed = confirmController.text.trim().toLowerCase() ==
                t.companyName.trim().toLowerCase();

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delete Organization',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ CRITICAL WARNING',
                            style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This action is irreversible. Deleting this organization will permanently wipe all items, store rooms, stock batches, purchase orders, departments, and user assignments related to it.',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        children: [
                          const TextSpan(text: 'To confirm, type '),
                          TextSpan(
                            text: t.companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const TextSpan(text: ' below:'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmController,
                      autofocus: true,
                      enabled: !isDeleting,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: t.companyName,
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: (!isConfirmed || isDeleting)
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final success = await tenantProvider.deleteTenant(t.tenantId);
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);

                          if (success) {
                            // Refresh available tenants in AuthProvider
                            final updatedList = authProvider.availableTenants
                                .where((item) => item.tenantId != t.tenantId)
                                .toList();
                            authProvider.updateAvailableTenants(updatedList);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Organization "${t.companyName}" deleted successfully.'),
                                backgroundColor: const Color(0xFF0F766E),
                              ),
                            );

                            // If there are other tenants available, auto-select the first one
                            if (updatedList.isNotEmpty) {
                              await tenantProvider.selectTenant(updatedList.first);
                              if (!context.mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const DashboardScreen()),
                              );
                            } else {
                              // If no tenants left, stay on selector screen to show "Register New Organization"
                              setState(() {});
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tenantProvider.errorMessage ?? 'Failed to delete organization'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Delete Forever',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tenantProvider = context.watch<TenantProvider>();
    final tenants = authProvider.availableTenants;
    final activeTenant = tenantProvider.activeTenant;
    final activeDeptName = tenantProvider.selectedDepartmentName;
    final depts = tenantProvider.tenantDepartments;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Switch Workspace',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
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
                  // Section 1: Organizations
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ORGANIZATIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '${tenants.length} available',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...tenants.map((t) {
                    final isAdmin = t.isAdmin;
                    final isCurrentTenant = activeTenant?.tenantId == t.tenantId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrentTenant ? Colors.black : const Color(0xFFE2E8F0),
                          width: isCurrentTenant ? 1.8 : 1.0,
                        ),
                        boxShadow: isCurrentTenant
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCurrentTenant ? Colors.black : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isAdmin ? Icons.corporate_fare : Icons.business,
                            color: isCurrentTenant ? Colors.white : Colors.black,
                            size: 22,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.companyName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentTenant) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isAdmin
                                ? '👑 Tenant Admin • All Departments'
                                : 'Staff • ${t.departmentIds.length} Dept${t.departmentIds.length == 1 ? '' : 's'} Assigned',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                                tooltip: 'Delete Organization',
                                onPressed: () => _showDeleteOrganizationDialog(t, tenantProvider, authProvider),
                              ),
                            if (isCurrentTenant)
                              const Icon(Icons.check_circle, color: Colors.black, size: 22)
                            else
                              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                          ],
                        ),
                        onTap: () => _handleTenantSelect(t, tenantProvider),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Section 2: Departments in Active Organization
                  if (activeTenant != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DEPARTMENTS (${activeTenant.companyName.toUpperCase()})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (tenantProvider.isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select an operational department to scope inventory, store rooms, and records.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),

                    // Organization-Wide / All Departments Option (for Admin)
                    if (activeTenant.isAdmin)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (activeDeptName == null || activeDeptName == 'All Departments')
                                ? Colors.black
                                : const Color(0xFFE2E8F0),
                            width: (activeDeptName == null || activeDeptName == 'All Departments') ? 1.6 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.corporate_fare, color: Colors.black, size: 20),
                          ),
                          title: const Text(
                            'All Departments (Organization-Wide)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Full tenant administrative scope',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          trailing: (activeDeptName == null || activeDeptName == 'All Departments')
                              ? const Icon(Icons.check_circle, color: Colors.black, size: 20)
                              : null,
                          onTap: () => _handleDepartmentSelect('All Departments', activeTenant, tenantProvider),
                        ),
                      ),

                    // Listing of Departments
                    if (depts.isEmpty && !tenantProvider.isLoading && !activeTenant.isAdmin)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'No departments assigned to your account in this organization.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...depts.map((d) {
                        final isSelected = activeDeptName == d.departmentName;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.6 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF6F7F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.apartment,
                                color: isSelected ? Colors.white : Colors.black,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              d.departmentName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              d.description.isNotEmpty ? d.description : 'Operational Unit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.black, size: 20)
                                : null,
                            onTap: () => _handleDepartmentSelect(d.departmentName, activeTenant, tenantProvider),
                          ),
                        );
                      }),
                  ],

                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Register Another Organization',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _showCreateTenantDialog,
                  ),
                ],
              ),
      ),
    );
  }
}
