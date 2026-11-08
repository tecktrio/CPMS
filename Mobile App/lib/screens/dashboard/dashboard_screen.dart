import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../departments/departments_list_screen.dart';
import '../items/items_list_screen.dart';
import '../store_rooms/store_rooms_list_screen.dart';
import '../tenant/tenant_selector_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedDepartmentName;
  int _currentNavIndex = 2; // Default to 'Modules'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final tenant = context.read<TenantProvider>();
    final inventory = context.read<InventoryProvider>();
    await Future.wait([
      tenant.loadTenantPermissions(),
      tenant.loadTenantDepartments(),
      inventory.loadItems(),
    ]);
  }

  void _showDepartmentSelector(BuildContext context, TenantProvider tenant) {
    final depts = tenant.tenantDepartments;
    final isAdmin = tenant.isTenantAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Switch Department',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select an operational department to scope modules and records',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),

                if (isAdmin)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.corporate_fare, color: Colors.black),
                    ),
                    title: const Text(
                      'All Departments (Organization-Wide)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: const Text('Full tenant administrative access',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    trailing: (_selectedDepartmentName == null ||
                            _selectedDepartmentName == 'All Departments')
                        ? const Icon(Icons.check_circle, color: Colors.black)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedDepartmentName = 'All Departments';
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Switched to Organization-Wide context'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),

                if (depts.isEmpty && !isAdmin)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No other departments assigned to your account.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  ...depts.map((d) {
                    final isSelected = _selectedDepartmentName == d.departmentName;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.apartment, color: Colors.black),
                      ),
                      title: Text(
                        d.departmentName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      subtitle: Text(
                        d.description.isNotEmpty ? d.description : 'Operational Unit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.black)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedDepartmentName = d.departmentName;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${d.departmentName}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlertsModal(BuildContext context) {
    final inventory = context.read<InventoryProvider>();
    final alertItems =
        inventory.items.where((i) => i.isBelowReorderThreshold).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFD97706), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Low Stock & Reorder Alerts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${alertItems.length} Warnings',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (alertItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'All inventory stocks are healthy and above reorder thresholds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: alertItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = alertItems[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.itemName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(
                            'SKU: ${item.sku} • Stock: ${item.totalAvailableStock} ${item.measurementUnit} (Min: ${item.reorderThresholdQuantity})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ItemsListScreen()),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileModal(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final tenant = context.read<TenantProvider>();
    final user = auth.user;
    final activeTenant = tenant.activeTenant;

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
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1E293B),
                  child: Text(
                    user != null && user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.fullName ?? 'Authenticated User',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  user?.emailAddress ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Switch Organization',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(activeTenant?.companyName ?? 'Organization'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TenantSelectorScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await auth.signOut();
                    tenant.clear();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleNavTap(int index) {
    if (index == 0) {
      // Search -> open items list screen with instant search
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ItemsListScreen()),
      );
    } else if (index == 1) {
      // Alerts
      _showAlertsModal(context);
    } else if (index == 2) {
      setState(() => _currentNavIndex = 2);
    } else if (index == 3) {
      // Settings
      _showProfileModal(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final auth = context.watch<AuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final activeTenant = tenant.activeTenant;
    final user = auth.user;
    final isAdmin = tenant.isTenantAdmin;
    final deptCount = tenant.userDepartmentCount;

    // Resolve displayed department name
    String resolvedDeptName = 'Operations & Logistics';
    if (_selectedDepartmentName != null &&
        _selectedDepartmentName!.isNotEmpty) {
      resolvedDeptName = _selectedDepartmentName!;
    } else if (!isAdmin && activeTenant != null && activeTenant.departmentIds.length == 1) {
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
        resolvedDeptName = match.departmentName;
      }
    } else if (tenant.tenantDepartments.isNotEmpty) {
      resolvedDeptName = tenant.tenantDepartments.first.departmentName;
    }

    // Module permission gating
    final hasItemAccess = isAdmin || tenant.hasAnyPermissionInModule('item');
    final hasStoreRoomAccess = isAdmin || tenant.hasAnyPermissionInModule('storeroom');
    final hasDeptAccess = isAdmin || tenant.hasAnyPermissionInModule('department');
    final hasUserAccess = isAdmin || tenant.hasAnyPermissionInModule('user');

    final modules = <_DashboardModuleItem>[
      _DashboardModuleItem(
        title: 'Items & Products',
        subtitle: 'Catalog & Stock Management',
        icon: Icons.view_in_ar_outlined,
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
        icon: Icons.dns_outlined,
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
        icon: Icons.apartment,
        isPermitted: hasDeptAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const DepartmentsListScreen(initialTabIndex: 0)),
          );
        },
      ),
      _DashboardModuleItem(
        title: 'Staff Directory',
        subtitle: 'Team & Access Control',
        icon: Icons.people_outline,
        isPermitted: hasUserAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const DepartmentsListScreen(initialTabIndex: 1)),
          );
        },
      ),
    ];

    final allowedModules = modules.where((m) => m.isPermitted).toList();
    final hasAlerts =
        inventory.items.any((i) => i.isBelowReorderThreshold);

    final tenantDisplayName = (activeTenant?.companyName ?? 'trends').toLowerCase();
    final userName = user != null && user.fullName.isNotEmpty
        ? user.fullName
        : 'Sarah Jenkins';
    final userRoleSubtitle = isAdmin
        ? 'Org Admin'
        : (deptCount == 1 ? resolvedDeptName : '$deptCount Depts');
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  // Tenant Brand & Switcher
                  Text(
                    tenantDisplayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TenantSelectorScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F3F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        size: 18,
                        color: Color(0xFF495057),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // User Info & Avatar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        userRoleSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _showProfileModal(context),
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1E293B),
                          child: Text(
                            userInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // DEPARTMENT Section Header
                    const Text(
                      'DEPARTMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select or switch department to re-scope operational modules',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // DEPARTMENT Card
                    InkWell(
                      onTap: () => _showDepartmentSelector(context, tenant),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Icon(
                                Icons.apartment,
                                size: 22,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    resolvedDeptName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Switch Department',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Manage Operations Section Header
                    const Text(
                      'Manage Operations',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a module to view records, manage assets, and configure workflows.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Module Cards
                    if (allowedModules.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text(
                            'No operational modules permitted for your current department scope.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ),
                      )
                    else
                      ...allowedModules.map((mod) => _buildOperationCard(mod)),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.search,
                    label: 'Search',
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.notifications_none_outlined,
                    label: 'Alerts',
                    hasBadge: hasAlerts,
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.grid_view_rounded,
                    label: 'Modules',
                    isActive: _currentNavIndex == 2,
                  ),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(_DashboardModuleItem mod) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: mod.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Icon(
                  mod.icon,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mod.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mod.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    bool isActive = false,
    bool hasBadge = false,
  }) {
    return InkWell(
      onTap: () => _handleNavTap(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      icon,
                      color: const Color(0xFF4B5563),
                      size: 22,
                    ),
                  ),
                  if (hasBadge)
                    Positioned(
                      top: 2,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? Colors.black : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardModuleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPermitted;
  final VoidCallback onTap;

  _DashboardModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isPermitted,
    required this.onTap,
  });
}
