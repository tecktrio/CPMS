import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../departments/departments_list_screen.dart';
import '../items/item_detail_screen.dart';
import '../items/items_list_screen.dart';
import '../purchase_orders/purchase_orders_list_screen.dart';
import '../store_rooms/store_rooms_list_screen.dart';
import '../stock_batches/inward_batch_screen.dart';
import '../tenant/tenant_selector_screen.dart';
import '../../utils/app_update_helper.dart';
import '../../widgets/sync_status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  final int initialNavIndex;
  const DashboardScreen({super.key, this.initialNavIndex = 2});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedDepartmentName;
  late int _currentNavIndex;

  // Universal Search State
  final TextEditingController _searchController = TextEditingController();
  String _universalSearchQuery = '';
  String _selectedSearchModule = 'ALL'; // 'ALL', 'ITEMS', 'STORE_ROOMS', 'DEPARTMENTS', 'STAFF'

  // Alerts View State
  String _selectedAlertFilter = 'ALL'; // 'ALL', 'CRITICAL', 'RESOLVED'

  // Settings View State
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedTimezone = 'English (US) — UTC-5 EST';
  bool _settingsInitialized = false;
  bool _isSavingSettings = false;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final tenant = context.read<TenantProvider>();
    final inventory = context.read<InventoryProvider>();
    final dept = context.read<DepartmentProvider>();
    await Future.wait([
      tenant.loadTenantPermissions(),
      tenant.loadTenantDepartments(),
      dept.loadTenantUsers(),
      inventory.loadItems(),
      inventory.loadStoreRooms(),
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
                        borderRadius: BorderRadius.circular(4),
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
                          borderRadius: BorderRadius.circular(4),
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

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final filename = picked.name;

      if (!context.mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Uploading profile picture to AWS S3...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final ok = await auth.updateProfilePicture(bytes, filename);
      if (context.mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Color(0xFF0D9488),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Upload failed'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
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
                Consumer<AuthProvider>(
                  builder: (context, currentAuth, _) {
                    final currentUser = currentAuth.user ?? user;
                    final avatarUrl = ApiConstants.resolveImageUrl(currentUser?.avatarUrl);
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => _pickAndUploadAvatar(context),
                          borderRadius: BorderRadius.circular(35),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFF1E293B),
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Text(
                                        currentUser != null && currentUser.fullName.isNotEmpty
                                            ? currentUser.fullName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickAndUploadAvatar(context),
                          child: const Text(
                            'Change Photo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentUser?.fullName ?? 'Authenticated User',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          currentUser?.emailAddress ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    );
                  },
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
    setState(() => _currentNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final auth = context.watch<AuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final activeTenant = tenant.activeTenant;
    final user = auth.user;
    final isAdmin = tenant.isTenantAdmin;
    final deptCount = tenant.userDepartmentCount;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isWide = screenWidth >= 650;

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

    final departmentsBadgeCount = tenant.tenantDepartments.isNotEmpty
        ? tenant.tenantDepartments.length
        : 8;
    final staffBadgeCount = deptProvider.tenantUsers.isNotEmpty
        ? deptProvider.tenantUsers.length
        : 184;

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
        icon: Icons.inbox_outlined,
        isPermitted: hasStoreRoomAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoreRoomsListScreen()),
          );
        },
      ),
      _DashboardModuleItem(
        title: 'Purchase Orders',
        subtitle: 'Orders & Shipment Planning',
        icon: Icons.receipt_long_outlined,
        isPermitted: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PurchaseOrdersListScreen()),
          );
        },
      ),
      _DashboardModuleItem(
        title: 'Users & Departments',
        subtitle: 'Staff, Structure & RBAC',
        badgeText: staffBadgeCount > 0 ? '$staffBadgeCount Users' : '$departmentsBadgeCount Depts',
        icon: Icons.people_outline,
        isPermitted: hasDeptAccess || hasUserAccess,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const DepartmentsListScreen()),
          );
        },
      ),
    ];

    final allowedModules = modules.where((m) => m.isPermitted).toList();
    final hasAlerts = inventory.items.any((i) => i.isBelowReorderThreshold);

    final tenantDisplayName = (activeTenant?.companyName ?? 'trends').toLowerCase();
    final userName = user != null && user.fullName.isNotEmpty
        ? user.fullName
        : 'Sarah Jenkins';
    final userRoleSubtitle = isAdmin
        ? 'Org Admin'
        : (deptCount == 1 ? resolvedDeptName : '$deptCount Depts');
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final userAvatarUrl = ApiConstants.resolveImageUrl(user?.avatarUrl);

    final horizontalPadding = isWide ? 40.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Centered with Max Width on wide screens)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isWide ? 20 : 14,
                  ),
                  child: Row(
                    children: [
                      // Tenant Brand & Switcher
                      Text(
                        tenantDisplayName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.7,
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
                        borderRadius: BorderRadius.circular(4),
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

                      // Real-time Sync Status Indicator
                      const SyncStatusIndicator(),
                      const SizedBox(width: 8),

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
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFFE2E8F0),
                              backgroundImage: userAvatarUrl != null
                                  ? NetworkImage(userAvatarUrl)
                                  : null,
                              child: userAvatarUrl == null
                                  ? Text(
                                      userInitial,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    )
                                  : null,
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
              ),
            ),

            // Tab Body: Search (Tab 0), Alerts (Tab 1), Modules (Tab 2), Settings (Tab 3)
            Expanded(
              child: _buildCurrentTabBody(
                isWide: isWide,
                horizontalPadding: horizontalPadding,
                tenant: tenant,
                inventory: inventory,
                deptProvider: deptProvider,
                allowedModules: allowedModules,
                resolvedDeptName: resolvedDeptName,
              ),
            ),

            // Bottom Navigation Bar (Centered with max width on wide screens)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.search,
                        label: 'Search',
                        isActive: _currentNavIndex == 0,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.notifications_none_outlined,
                        label: 'Alerts',
                        hasBadge: hasAlerts,
                        isActive: _currentNavIndex == 1,
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
                        isActive: _currentNavIndex == 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabBody({
    required bool isWide,
    required double horizontalPadding,
    required TenantProvider tenant,
    required InventoryProvider inventory,
    required DepartmentProvider deptProvider,
    required List<_DashboardModuleItem> allowedModules,
    required String resolvedDeptName,
  }) {
    if (_currentNavIndex == 0) {
      return _buildUniversalSearchView(
        isWide: isWide,
        horizontalPadding: horizontalPadding,
        tenant: tenant,
        inventory: inventory,
        deptProvider: deptProvider,
      );
    } else if (_currentNavIndex == 1) {
      return _buildAlertsView(
        isWide: isWide,
        horizontalPadding: horizontalPadding,
        inventory: inventory,
      );
    } else if (_currentNavIndex == 3) {
      return _buildSettingsView(
        isWide: isWide,
        horizontalPadding: horizontalPadding,
        tenant: tenant,
      );
    }

    // Default: Modules Operations Tab (Tab 2)
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isWide ? 12 : 8,
            ),
            children: [
              // Department Section Header
              Text(
                isWide ? 'Department' : 'DEPARTMENT',
                style: TextStyle(
                  fontSize: isWide ? 26 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: isWide ? -0.5 : 0.8,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select or switch department to re-scope operational modules',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Department Card
              InkWell(
                onTap: () => _showDepartmentSelector(context, tenant),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 20 : 16,
                    vertical: isWide ? 18 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
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
                              style: TextStyle(
                                fontSize: isWide ? 17 : 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isWide
                                  ? 'Switch Department across organizations to re-scope modules'
                                  : 'Switch Department',
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
                          Icons.swap_horiz,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isWide ? 36 : 28),

              // Manage Operations Section Header
              Text(
                'Manage Operations',
                style: TextStyle(
                  fontSize: isWide ? 26 : 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select a module to view records, manage assets, and configure workflows.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Module Cards (Responsive Grid on Tablets/Web, List on Mobile)
              if (allowedModules.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'No operational modules permitted for your current department scope.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                )
              else if (isWide)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 3.2,
                  ),
                  itemCount: allowedModules.length,
                  itemBuilder: (context, index) {
                    return _buildOperationCard(allowedModules[index], isWide: true);
                  },
                )
              else
                ...allowedModules.map((mod) => _buildOperationCard(mod, isWide: false)),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // UNIVERSAL SEARCH SCREEN IMPLEMENTATION
  // ==========================================
  Widget _buildUniversalSearchView({
    required bool isWide,
    required double horizontalPadding,
    required TenantProvider tenant,
    required InventoryProvider inventory,
    required DepartmentProvider deptProvider,
  }) {
    final query = _universalSearchQuery.trim().toLowerCase();

    // Filter Items
    final matchingItems = inventory.items.where((i) {
      if (query.isEmpty) return true;
      return i.itemName.toLowerCase().contains(query) ||
          i.sku.toLowerCase().contains(query) ||
          i.itemType.toLowerCase().contains(query) ||
          (i.division != null && i.division!.toLowerCase().contains(query));
    }).toList();

    // Filter Store Rooms
    final matchingRooms = inventory.storeRooms.where((r) {
      if (query.isEmpty) return true;
      return r.roomName.toLowerCase().contains(query) ||
          r.roomCode.toLowerCase().contains(query) ||
          r.divisions.any((div) => div.toLowerCase().contains(query));
    }).toList();

    // Filter Departments
    final matchingDepts = tenant.tenantDepartments.where((d) {
      if (query.isEmpty) return true;
      return d.departmentName.toLowerCase().contains(query) ||
          d.description.toLowerCase().contains(query);
    }).toList();

    // Filter Staff Members
    final matchingStaff = deptProvider.tenantUsers.where((u) {
      if (query.isEmpty) return true;
      return u.fullName.toLowerCase().contains(query) ||
          u.emailAddress.toLowerCase().contains(query);
    }).toList();

    final showItems = _selectedSearchModule == 'ALL' || _selectedSearchModule == 'ITEMS';
    final showRooms = _selectedSearchModule == 'ALL' || _selectedSearchModule == 'STORE_ROOMS';
    final showDepts = _selectedSearchModule == 'ALL' || _selectedSearchModule == 'USERS_DEPTS';
    final showStaff = _selectedSearchModule == 'ALL' || _selectedSearchModule == 'USERS_DEPTS';

    final totalResults = (showItems ? matchingItems.length : 0) +
        (showRooms ? matchingRooms.length : 0) +
        (showDepts ? matchingDepts.length : 0) +
        (showStaff ? matchingStaff.length : 0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search across all modules...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 22, color: Colors.black),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel, size: 20, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _universalSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _universalSearchQuery = val;
                    });
                  },
                ),
              ),
            ),

            // Module Filter Pills (Horizontal Scroll)
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                children: [
                  _buildSearchFilterPill(
                    id: 'ALL',
                    label: 'All Modules',
                    icon: Icons.grid_view_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildSearchFilterPill(
                    id: 'ITEMS',
                    label: 'Items & Products',
                    icon: Icons.view_in_ar_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildSearchFilterPill(
                    id: 'STORE_ROOMS',
                    label: 'Store Rooms',
                    icon: Icons.inbox_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildSearchFilterPill(
                    id: 'USERS_DEPTS',
                    label: 'Users & Departments',
                    icon: Icons.people_outline,
                  ),
                ],
              ),
            ),

            const Divider(height: 12, color: Color(0xFFF1F5F9)),

            // Search Results List
            Expanded(
              child: totalResults == 0
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'Type a keyword above to search across items, store rooms, departments, and staff.'
                                : 'No matching results found for "$query".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
                      children: [
                        // SECTION: ITEMS & PRODUCTS
                        if (showItems && matchingItems.isNotEmpty) ...[
                          _buildSearchSectionHeader('ITEMS & PRODUCTS'),
                          ...matchingItems.map((item) {
                            final room = inventory.storeRooms.firstWhere(
                              (r) => r.storeRoomId == item.storeRoomId,
                              orElse: () => StoreRoomModel(
                                storeRoomId: '',
                                tenantId: '',
                                roomCode: '',
                                roomName: 'Store Room',
                                totalCapacityUnits: 0,
                                currentOccupancyUnits: 0,
                                capacityUtilizationPercentage: 0,
                                activeBatchesCount: 0,
                                isActive: true,
                              ),
                            );
                            final divInfo = item.division != null && item.division!.isNotEmpty
                                ? item.division!
                                : 'Default Section';

                            return _buildSearchResultCard(
                              leadingIcon: Icons.view_in_ar_outlined,
                              imageUrl: item.imageUrl,
                              title: item.itemName,
                              subtitleLine1: item.itemType.replaceAll('_', ' '),
                              subtitleLine2: '${room.roomName} • $divInfo',
                              badgeText: '${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit}',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ItemDetailScreen(item: item),
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // SECTION: STORE ROOMS
                        if (showRooms && matchingRooms.isNotEmpty) ...[
                          _buildSearchSectionHeader('STORE ROOMS'),
                          ...matchingRooms.map((room) {
                            final divCount = room.divisions.length;
                            return _buildSearchResultCard(
                              leadingIcon: Icons.inbox_outlined,
                              title: '${room.roomName} (${room.roomCode})',
                              subtitleLine1: 'Capacity: ${room.capacityUtilizationPercentage.toStringAsFixed(0)}% • $divCount Sections active',
                              subtitleLine2: room.temperature != null ? 'Temp: ${room.temperature}°C' : 'Standard Store Room',
                              badgeText: room.temperature != null ? '${room.temperature}°C' : 'Active',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StoreRoomsListScreen(),
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // SECTION: DEPARTMENTS
                        if (showDepts && matchingDepts.isNotEmpty) ...[
                          _buildSearchSectionHeader('DEPARTMENTS'),
                          ...matchingDepts.map((dept) {
                            return _buildSearchResultCard(
                              leadingIcon: Icons.apartment,
                              title: dept.departmentName,
                              subtitleLine1: dept.description.isNotEmpty
                                  ? dept.description
                                  : 'Operational Unit',
                              subtitleLine2: '${dept.permissionIds.length} Permissions configured',
                              badgeText: 'Assigned',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DepartmentsListScreen(initialTabIndex: 0),
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // SECTION: STAFF DIRECTORY
                        if (showStaff && matchingStaff.isNotEmpty) ...[
                          _buildSearchSectionHeader('USERS'),
                          ...matchingStaff.map((staff) {
                            return _buildSearchResultCard(
                              leadingIcon: Icons.people_outline,
                              imageUrl: staff.avatarUrl,
                              title: staff.fullName.isNotEmpty ? staff.fullName : staff.emailAddress,
                              subtitleLine1: staff.emailAddress,
                              subtitleLine2: '${staff.departmentIds.length} Assigned Departments',
                              badgeText: staff.accountStatus.toUpperCase(),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DepartmentsListScreen(initialTabIndex: 0),
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterPill({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedSearchModule == id;
    return InkWell(
      onTap: () => setState(() => _selectedSearchModule = id),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard({
    required IconData leadingIcon,
    String? imageUrl,
    required String title,
    String? subtitleLine1,
    String? subtitleLine2,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    final resolvedUrl = ApiConstants.resolveImageUrl(imageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: resolvedUrl != null
                    ? Image.network(
                        resolvedUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(leadingIcon, size: 22, color: Colors.black),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Icon(leadingIcon, size: 22, color: Colors.black),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    if (subtitleLine1 != null && subtitleLine1.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleLine1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (subtitleLine2 != null && subtitleLine2.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleLine2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertFilterPill({required String id, required String label}) {
    final isSelected = _selectedAlertFilter == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAlertFilter = id;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ALERTS VIEW
  // ==========================================
  Widget _buildAlertsView({
    required bool isWide,
    required double horizontalPadding,
    required InventoryProvider inventory,
  }) {
    final alertItems = inventory.items.where((i) => i.isBelowReorderThreshold).toList();
    final criticalCount = alertItems.length;

    List<ItemModel> displayedItems = [];
    if (_selectedAlertFilter == 'ALL' || _selectedAlertFilter == 'CRITICAL') {
      displayedItems = alertItems;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          children: [
            // Header Row: Alerts + [ • 2 Critical ]
            Row(
              children: [
                const Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.6,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$criticalCount Critical',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'System notifications, threshold triggers, and operational events requiring attention.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Filter Pills Row
            Row(
              children: [
                _buildAlertFilterPill(
                  id: 'ALL',
                  label: 'All Alerts ($criticalCount)',
                ),
                const SizedBox(width: 8),
                _buildAlertFilterPill(
                  id: 'CRITICAL',
                  label: 'Critical ($criticalCount)',
                ),
                const SizedBox(width: 8),
                _buildAlertFilterPill(
                  id: 'RESOLVED',
                  label: 'Resolved (0)',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Alerts List
            if (_selectedAlertFilter == 'RESOLVED')
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.done_all_rounded, size: 40, color: Color(0xFF10B981)),
                    SizedBox(height: 10),
                    Text(
                      'No resolved alerts to display',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Past resolved events will appear here once archived.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else if (displayedItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
                    SizedBox(height: 12),
                    Text(
                      'All stock levels are optimal!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No inventory items have dropped below their reorder threshold.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...displayedItems.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: item),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row: Amber Warning Icon + Details + Chevron
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFB45309),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                        children: [
                                          const TextSpan(text: 'SKU: '),
                                          TextSpan(
                                            text: item.sku,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const TextSpan(text: '  •  Stock: '),
                                          TextSpan(
                                            text:
                                                '${item.totalAvailableStock.toStringAsFixed(0)} ${item.measurementUnit}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // Bottom Row: Auto-flagged info + Shortfall alert
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Min: ${item.reorderThresholdQuantity.toStringAsFixed(0)} ${item.measurementUnit}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Shortfall: ${item.reorderShortfallQuantity.toStringAsFixed(0)} ${item.measurementUnit}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Direct Link to Fixing Page (Inward Stock)
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InwardBatchScreen(
                                      initialItemId: item.itemId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.build_outlined, size: 14),
                              label: const Text(
                                'Fix Alert (Inward Stock)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SETTINGS VIEW
  // ==========================================
  void _initSettingsFields(AuthUser? user) {
    if (_settingsInitialized || user == null) return;
    final parts = user.fullName.trim().split(' ');
    _firstNameController.text = parts.isNotEmpty ? parts.first : '';
    _lastNameController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _phoneController.text = user.phoneNumber ?? '';
    _settingsInitialized = true;
  }

  Widget _buildSettingsFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildSettingsTextField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        fillColor: Colors.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSettingsView({
    required bool isWide,
    required double horizontalPadding,
    required TenantProvider tenant,
  }) {
    final auth = context.watch<AuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final user = auth.user;
    final activeTenant = tenant.activeTenant;
    final isAdmin = tenant.isTenantAdmin;
    final deptCount = tenant.userDepartmentCount;

    String resolvedDeptName = 'Direct transit & dispatch ops';
    if (!isAdmin && deptCount == 1 && activeTenant != null) {
      final deptId = activeTenant.departmentIds.firstOrNull;
      final match = tenant.tenantDepartments.firstWhere(
        (d) => d.departmentId == deptId,
        orElse: () => DepartmentModel(
          departmentId: '',
          tenantId: '',
          departmentName: 'Direct transit & dispatch ops',
          description: '',
          permissionIds: [],
          isActive: true,
        ),
      );
      if (match.departmentName.isNotEmpty) {
        resolvedDeptName = match.departmentName;
      }
    }

    _initSettingsFields(user);

    final userName = user != null && user.fullName.isNotEmpty
        ? user.fullName
        : 'Sarah Jenkins';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final userAvatarUrl = ApiConstants.resolveImageUrl(user?.avatarUrl);
    final tenantDisplayName = (activeTenant?.companyName ?? 'trends').toLowerCase();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          children: [
            // Page Header
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage profile, credentials, and app preferences',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with camera badge
                      InkWell(
                        onTap: () => _pickAndUploadAvatar(context),
                        borderRadius: BorderRadius.circular(38),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: const Color(0xFF1E293B),
                              backgroundImage: userAvatarUrl != null
                                  ? NetworkImage(userAvatarUrl)
                                  : null,
                              child: userAvatarUrl == null
                                  ? Text(
                                      userInitial,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdmin
                                    ? 'ORGANIZATION ADMIN'
                                    : 'OPERATIONS SPECIALIST',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              resolvedDeptName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () => _pickAndUploadAvatar(context),
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text(
                          'Upload photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () async {
                          final ok = await auth.removeProfilePicture();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Profile picture removed and deleted from S3.'
                                      : 'Failed to remove profile picture.',
                                ),
                                backgroundColor:
                                    ok ? const Color(0xFF0F766E) : Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PERSONAL DETAILS Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PERSONAL DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Editable',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Personal Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingsFieldLabel('First Name'),
                  _buildSettingsTextField(_firstNameController, 'Sarah'),
                  const SizedBox(height: 14),

                  _buildSettingsFieldLabel('Last Name'),
                  _buildSettingsTextField(_lastNameController, 'Jenkins'),
                  const SizedBox(height: 14),

                  _buildSettingsFieldLabel('Mobile Number'),
                  _buildSettingsTextField(
                    _phoneController,
                    '+1 (555) 234-8901',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  _buildSettingsFieldLabel('Regional Format & Timezone'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTimezone,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF475569)),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'English (US) — UTC-5 EST',
                            child: Text('English (US) — UTC-5 EST'),
                          ),
                          DropdownMenuItem(
                            value: 'English (UK) — UTC+0 GMT',
                            child: Text('English (UK) — UTC+0 GMT'),
                          ),
                          DropdownMenuItem(
                            value: 'English (IN) — UTC+5:30 IST',
                            child: Text('English (IN) — UTC+5:30 IST'),
                          ),
                          DropdownMenuItem(
                            value: 'English (AU) — UTC+10 AEST',
                            child: Text('English (AU) — UTC+10 AEST'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedTimezone = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Changes Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _isSavingSettings
                          ? null
                          : () async {
                              final firstName = _firstNameController.text.trim();
                              final lastName = _lastNameController.text.trim();
                              final fullName = [firstName, lastName]
                                  .where((p) => p.isNotEmpty)
                                  .join(' ');
                              final phone = _phoneController.text.trim();

                              if (fullName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your name'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() => _isSavingSettings = true);
                              final authProvider = context.read<AuthProvider>();
                              final ok = await authProvider.updateProfile(
                                fullName: fullName,
                                phoneNumber: phone,
                              );
                              if (mounted) {
                                setState(() => _isSavingSettings = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Personal details saved successfully!'
                                        : (authProvider.errorMessage ?? 'Update failed')),
                                    backgroundColor:
                                        ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                                  ),
                                );
                              }
                            },
                      child: _isSavingSettings
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CORPORATE CREDENTIALS Section
            Row(
              children: const [
                Icon(Icons.lock_outline, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 6),
                Text(
                  'CORPORATE CREDENTIALS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Corporate Credentials Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shield Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Managed by your organization administrator. These security values cannot be modified directly.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Work Email
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Work Email',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'Enterprise SSO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user?.emailAddress ?? 'sarah.jenkins@trendslogistics.corp',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contact IT administrator to update corporate address',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Designation & Role
                  const Text(
                    'Designation & Role',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isAdmin
                                ? 'Senior Operations Director / Org Admin'
                                : 'Operations Specialist / Staff',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Designations are strictly tied to enterprise access control (RBAC)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // APP & UPDATES Section
            Row(
              children: const [
                Icon(Icons.system_update_alt_outlined, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 6),
                Text(
                  'APP & UPDATES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // App Updates Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.smartphone_outlined,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CPMS Mobile',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Installed Version: v${AppUpdateHelper.appVersion} (Build ${AppUpdateHelper.buildNumber})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Stay up to date with the latest features, security patches, and performance improvements.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () => AppUpdateHelper.openStore(context: context),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'Check for Updates in Store',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Log Out All Sessions Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE4E6),
                  foregroundColor: const Color(0xFFBE123C),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () async {
                  await auth.signOut();
                  tenant.clear();
                  inventory.clear();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/signin',
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Log Out All Sessions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Footer info
            Center(
              child: Column(
                children: [
                  Text(
                    '${tenantDisplayName.toUpperCase()} MOBILE V${AppUpdateHelper.appVersion} (BUILD ${AppUpdateHelper.buildNumber})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'End-to-End Encrypted Transit Terminal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION ITEM BUILDER
  // ==========================================
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    bool isActive = false,
    bool hasBadge = false,
  }) {
    return InkWell(
      onTap: () => _handleNavTap(index),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
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

  Widget _buildOperationCard(_DashboardModuleItem mod, {required bool isWide}) {
    return Container(
      margin: EdgeInsets.only(bottom: isWide ? 0 : 12),
      child: InkWell(
        onTap: mod.onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 18 : 16,
            vertical: isWide ? 16 : 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            mod.title,
                            style: TextStyle(
                              fontSize: isWide ? 16 : 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mod.badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              mod.badgeText!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mod.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
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
}

class _DashboardModuleItem {
  final String title;
  final String subtitle;
  final String? badgeText;
  final IconData icon;
  final bool isPermitted;
  final VoidCallback onTap;

  _DashboardModuleItem({
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.icon,
    required this.isPermitted,
    required this.onTap,
  });
}
