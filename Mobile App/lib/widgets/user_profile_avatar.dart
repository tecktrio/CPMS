import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/inventory_provider.dart';
import '../screens/tenant/tenant_selector_screen.dart';
import '../utils/app_update_helper.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenant = context.watch<TenantProvider>();
    final user = auth.user;
    final activeTenant = tenant.activeTenant;

    String initials = 'BU';
    if (user != null && user.fullName.trim().isNotEmpty) {
      final parts = user.fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts[0].length >= 2) {
        initials = parts[0].substring(0, 2).toUpperCase();
      } else {
        initials = parts[0][0].toUpperCase();
      }
    }

    final avatarUrl = ApiConstants.resolveImageUrl(user?.avatarUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Tooltip(
        message: user?.fullName ?? 'User Profile',
        child: InkWell(
          onTap: () => _showProfileDialog(context, user, activeTenant, tenant, auth),
          borderRadius: BorderRadius.circular(24),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF111827),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(BuildContext context, AuthProvider auth) async {
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
            content: Text('Error selecting image: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
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
                Consumer<AuthProvider>(
                  builder: (context, currentAuth, _) {
                    final currentUser = currentAuth.user ?? user;
                    final modalAvatarUrl = ApiConstants.resolveImageUrl(currentUser?.avatarUrl);
                    return Row(
                      children: [
                        InkWell(
                          onTap: () => _pickAndUploadPhoto(context, currentAuth),
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                backgroundImage: modalAvatarUrl != null
                                    ? NetworkImage(modalAvatarUrl)
                                    : null,
                                child: modalAvatarUrl == null
                                    ? Text(
                                        (currentUser != null && currentUser.fullName.isNotEmpty)
                                            ? currentUser.fullName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Color(0xFF0F766E),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 24,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser?.fullName ?? 'Operator',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                currentUser?.emailAddress ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
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
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _pickAndUploadPhoto(context, currentAuth),
                                    child: const Text(
                                      'Edit Photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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

                // Check for Updates
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.system_update_alt_outlined, color: Color(0xFF0F766E)),
                  title: const Text(
                    'Check for Updates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: const Text(
                    'Version ${AppUpdateHelper.appVersion} (${AppUpdateHelper.buildNumber}) • Google Play / App Store',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Store',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.open_in_new, size: 12, color: Colors.black),
                      ],
                    ),
                  ),
                  onTap: () {
                    AppUpdateHelper.openStore(context: context);
                  },
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
                      context.read<InventoryProvider>().clear();
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
