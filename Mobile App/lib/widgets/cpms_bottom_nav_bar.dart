import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inventory_provider.dart';
import '../providers/tenant_provider.dart';
import '../core/constants/permissions.dart';
import '../core/theme/app_theme.dart';
import '../screens/dashboard/department_workspace.dart';
import '../screens/dashboard/dashboard_screen.dart';

/// A universal, persistent bottom navigation bar available across all pages in the CPMS application.
class CpmsBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onNavTap;

  const CpmsBottomNavBar({super.key, this.currentIndex = 2, this.onNavTap});

  void _handleTap(BuildContext context, int index) {
    if (onNavTap != null) {
      onNavTap!(index);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(initialNavIndex: index),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final workspace = DepartmentWorkspace.resolve(tenant);
    final showAlerts =
        tenant.hasPermission(AppPermissions.storeroomRead) &&
        tenant.hasPermission(AppPermissions.itemRead);
    final accent = workspace?.color ?? const Color(0xFF0F172A);
    final hasAlerts = inventory.items.any((i) => i.isBelowReorderThreshold);

    if (workspace == DepartmentWorkspace.administrator) {
      return ColoredBox(
        color: AppTheme.adminCanvas,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: NavigationBar(
                  height: 64,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: AppTheme.adminTint,
                  selectedIndex: switch (currentIndex) {
                    1 => 1,
                    3 => 2,
                    _ => 0,
                  },
                  onDestinationSelected: (index) =>
                      _handleTap(context, const [2, 1, 3][index]),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(
                        Icons.dashboard_outlined,
                        color: AppTheme.adminInk,
                      ),
                      selectedIcon: Icon(
                        Icons.dashboard_rounded,
                        color: AppTheme.adminInk,
                      ),
                      label: 'Administration',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: hasAlerts,
                        child: const Icon(
                          Icons.notifications_none_outlined,
                          color: AppTheme.adminInk,
                        ),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: hasAlerts,
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: AppTheme.adminInk,
                        ),
                      ),
                      label: 'Alerts',
                    ),
                    const NavigationDestination(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: AppTheme.adminInk,
                      ),
                      selectedIcon: Icon(
                        Icons.settings_rounded,
                        color: AppTheme.adminInk,
                      ),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (showAlerts)
                  _buildNavItem(
                    context: context,
                    accent: accent,
                    index: 1,
                    icon: Icons.notifications_none_outlined,
                    label: 'Alerts',
                    hasBadge: hasAlerts,
                    isActive: currentIndex == 1,
                  ),
                _buildNavItem(
                  context: context,
                  accent: accent,
                  index: 2,
                  icon: workspace?.icon ?? Icons.grid_view_rounded,
                  label: workspace?.label ?? 'Modules',
                  isActive: currentIndex == 2,
                ),
                _buildNavItem(
                  context: context,
                  accent: accent,
                  index: 3,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isActive: currentIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required Color accent,
    required IconData icon,
    required String label,
    bool isActive = false,
    bool hasBadge = false,
  }) {
    return InkWell(
      onTap: () => _handleTap(context, index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
                  ),
                  if (hasBadge)
                    Positioned(
                      top: 2,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), // Red badge indicator
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
                color: isActive ? accent : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
