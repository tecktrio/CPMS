import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/cpms_form_dialog.dart';
import '../../widgets/cpms_page_title.dart';

String tenantUserDisplayName(TenantUserModel user) {
  if (user.fullName.trim().isNotEmpty) return user.fullName.trim();
  if (user.userName.isNotEmpty) return '@${user.userName}';
  return user.emailAddress.isEmpty ? 'Staff user' : user.emailAddress;
}

class TenantUserAvatar extends StatelessWidget {
  const TenantUserAvatar({super.key, required this.user, this.radius = 20});

  final TenantUserModel user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = tenantUserDisplayName(user)
        .replaceFirst(RegExp(r'^@'), '')
        .trim();
    final parts = name.split(RegExp(r'\s+'));
    final initials = parts.length > 1
        ? '${parts.first.characters.first}${parts.last.characters.first}'
        : name.characters.take(2).join();
    final url = ApiConstants.resolveImageUrl(user.avatarUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.adminPeopleTint,
      foregroundColor: AppTheme.adminPeople,
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(initials.toUpperCase()),
    );
  }
}

class TenantUserDetailScreen extends StatefulWidget {
  const TenantUserDetailScreen({
    super.key,
    required this.userId,
    required this.canUpdate,
    required this.canDelete,
  });

  final String userId;
  final bool canUpdate;
  final bool canDelete;

  @override
  State<TenantUserDetailScreen> createState() => _TenantUserDetailScreenState();
}

class _TenantUserDetailScreenState extends State<TenantUserDetailScreen> {
  bool _removing = false;
  bool _savingDepartment = false;
  String? _selectedDepartmentId;
  String? _departmentError;

  Future<void> _saveDepartment(
    TenantUserModel user,
    String departmentId,
  ) async {
    if (!widget.canUpdate || _savingDepartment || _removing) return;
    setState(() {
      _savingDepartment = true;
      _departmentError = null;
    });
    final departments = context.read<DepartmentProvider>();
    final saved = await departments.updateTenantUser(
      userId: user.userId,
      departmentIds: [departmentId],
    );
    if (!mounted) return;
    setState(() {
      _savingDepartment = false;
      if (saved) {
        _selectedDepartmentId = null;
      } else {
        _departmentError =
            departments.errorMessage ?? 'Could not update the department.';
      }
    });
    if (saved) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Department updated.')));
    }
  }

  Future<void> _removeUser(TenantUserModel user) async {
    if (!widget.canDelete || _removing || _savingDepartment) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CpmsFormDialog(
        icon: Icons.person_remove_outlined,
        title: const Text('Remove user?'),
        content: Text(
          'Remove ${tenantUserDisplayName(user)} from this organization?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove user'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removing = true);
    final departments = context.read<DepartmentProvider>();
    final removed = await departments.removeUserFromTenant(user.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? 'User removed from the organization.'
              : departments.errorMessage ?? 'Could not remove user.',
        ),
      ),
    );
    if (removed) {
      Navigator.pop(context);
    } else {
      setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final user = context
        .watch<DepartmentProvider>()
        .tenantUsers
        .where((entry) => entry.userId == widget.userId)
        .firstOrNull;
    final departmentNames = tenant.tenantDepartments
        .where(
          (department) =>
              user?.departmentIds.contains(department.departmentId) ?? false,
        )
        .map((department) => department.departmentName)
        .join(', ');
    final availableDepartments = tenant.tenantDepartments
        .where((department) => department.isActive)
        .toList();
    final currentDepartmentId = user?.departmentIds.firstOrNull;
    final preferredDepartmentId = _selectedDepartmentId ?? currentDepartmentId;
    final departmentId =
        availableDepartments.any(
          (department) => department.departmentId == preferredDepartmentId,
        )
        ? preferredDepartmentId
        : null;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.adminCanvas,
        foregroundColor: AppTheme.adminInk,
        title: const CpmsPageTitle(
          'User details',
          icon: Icons.person_outline,
          accent: AppTheme.adminPeople,
        ),
      ),
      body: _removing
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? const Center(
              child: Text('This user is no longer in the organization.'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TenantUserAvatar(user: user, radius: 26),
                            const SizedBox(height: 12),
                            Text(
                              tenantUserDisplayName(user),
                              style: theme.textTheme.headlineSmall,
                            ),
                            if (user.userName.isNotEmpty)
                              Text('@${user.userName}'),
                            if (user.emailAddress.isNotEmpty)
                              Text(user.emailAddress),
                            const SizedBox(height: 16),
                            Text(
                              'Department',
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              departmentNames.isEmpty
                                  ? 'Unassigned'
                                  : departmentNames,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Account status',
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              user.accountStatus.toLowerCase().replaceAll(
                                '_',
                                ' ',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.canUpdate) ...[
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update department',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              if (availableDepartments.isEmpty)
                                const Text('No active departments available.')
                              else ...[
                                DropdownButtonFormField<String>(
                                  key: ValueKey(departmentId),
                                  initialValue: departmentId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Assign to department',
                                  ),
                                  items: [
                                    for (final department
                                        in availableDepartments)
                                      DropdownMenuItem(
                                        value: department.departmentId,
                                        child: Text(
                                          department.departmentName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: _savingDepartment
                                      ? null
                                      : (id) {
                                          setState(() {
                                            _selectedDepartmentId = id;
                                            _departmentError = null;
                                          });
                                        },
                                ),
                                if (_departmentError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _departmentError!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.adminPeople,
                                  ),
                                  onPressed:
                                      _savingDepartment ||
                                          departmentId == null ||
                                          (user.departmentIds.length == 1 &&
                                              departmentId ==
                                                  currentDepartmentId)
                                      ? null
                                      : () =>
                                            _saveDepartment(user, departmentId),
                                  child: Text(
                                    _savingDepartment
                                        ? 'Saving…'
                                        : 'Save department',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (widget.canDelete) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          onPressed: _savingDepartment
                              ? null
                              : () => _removeUser(user),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove user'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
