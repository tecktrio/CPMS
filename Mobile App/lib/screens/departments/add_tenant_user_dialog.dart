import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';

class AddTenantUserDialog extends StatefulWidget {
  final TenantUserModel? existingUser;

  const AddTenantUserDialog({super.key, this.existingUser});

  @override
  State<AddTenantUserDialog> createState() => _AddTenantUserDialogState();
}

class _AddTenantUserDialogState extends State<AddTenantUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  String? _selectedDepartmentId;
  bool _isSubmitting = false;

  List<GlobalUserSuggestion> _userSuggestions = [];
  bool _isSearchingUsers = false;
  Timer? _debounceTimer;
  GlobalUserSuggestion? _selectedSuggestion;

  bool get isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _usernameController.text = widget.existingUser!.userName.isNotEmpty
          ? widget.existingUser!.userName
          : widget.existingUser!.emailAddress;
      if (widget.existingUser!.departmentIds.isNotEmpty) {
        _selectedDepartmentId = widget.existingUser!.departmentIds.first;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (isEditing) return;
    _debounceTimer?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _userSuggestions = [];
        _isSearchingUsers = false;
        _selectedSuggestion = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _isSearchingUsers = true);
      final results =
          await context.read<DepartmentProvider>().searchGlobalUsers(trimmed);
      if (!mounted) return;
      setState(() {
        _userSuggestions = results;
        _isSearchingUsers = false;
      });
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select 1 department for this staff member.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final deptProvider = context.read<DepartmentProvider>();

    bool success;
    if (isEditing) {
      success = await deptProvider.updateTenantUser(
        userId: widget.existingUser!.userId,
        departmentIds: [_selectedDepartmentId!],
      );
    } else {
      final username = _selectedSuggestion != null
          ? _selectedSuggestion!.userName
          : (!_usernameController.text.contains('@')
              ? _usernameController.text.trim().toLowerCase()
              : null);
      final email = _selectedSuggestion != null
          ? _selectedSuggestion!.emailAddress
          : (_usernameController.text.contains('@')
              ? _usernameController.text.trim().toLowerCase()
              : null);

      success = await deptProvider.addTenantUser(
        userName: username,
        emailAddress: email,
        departmentIds: [_selectedDepartmentId!],
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context);
      final displayName = isEditing
          ? (widget.existingUser!.fullName.isNotEmpty
              ? widget.existingUser!.fullName
              : widget.existingUser!.userName.isNotEmpty
                  ? '@${widget.existingUser!.userName}'
                  : widget.existingUser!.emailAddress)
          : (_selectedSuggestion != null
              ? '@${_selectedSuggestion!.userName}'
              : _usernameController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Staff department assignments updated!'
                : 'User $displayName added to organization departments!',
          ),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deptProvider.errorMessage ?? 'Operation failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final departments = tenant.tenantDepartments;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEditing ? Icons.manage_accounts : Icons.person_add,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Update Staff Departments' : 'Add Staff to Organization',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Assign user to one or more organization departments.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Staff User Search / Selected User
                if (isEditing)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF0F766E),
                          child: Text(
                            (widget.existingUser!.fullName.isNotEmpty
                                    ? widget.existingUser!.fullName[0]
                                    : widget.existingUser!.userName.isNotEmpty
                                        ? widget.existingUser!.userName[0]
                                        : 'U')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existingUser!.fullName.isNotEmpty
                                    ? widget.existingUser!.fullName
                                    : 'Staff Member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                widget.existingUser!.userName.isNotEmpty
                                    ? '@${widget.existingUser!.userName} • ${widget.existingUser!.emailAddress}'
                                    : widget.existingUser!.emailAddress,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_selectedSuggestion != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF16A34A),
                          child: Text(
                            (_selectedSuggestion!.fullName.isNotEmpty
                                    ? _selectedSuggestion!.fullName[0]
                                    : _selectedSuggestion!.userName.isNotEmpty
                                        ? _selectedSuggestion!.userName[0]
                                        : 'U')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSuggestion!.fullName.isNotEmpty
                                    ? _selectedSuggestion!.fullName
                                    : _selectedSuggestion!.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '@${_selectedSuggestion!.userName} • ${_selectedSuggestion!.emailAddress}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _selectedSuggestion = null;
                              _usernameController.clear();
                              _userSuggestions = [];
                            });
                          },
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Search Staff by Username or Email *',
                      hintText: 'e.g. janedoe or user@example.com',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _usernameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _usernameController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                    validator: (val) {
                      if (_selectedSuggestion == null &&
                          (val == null || val.trim().isEmpty)) {
                        return 'Please search and select a staff user';
                      }
                      return null;
                    },
                  ),
                  if (_isSearchingUsers)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Searching global users...',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_userSuggestions.isNotEmpty &&
                      _selectedSuggestion == null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _userSuggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final s = _userSuggestions[idx];
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(
                              s.fullName.isNotEmpty ? s.fullName : s.userName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '@${s.userName} • ${s.emailAddress}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            trailing: Text(
                              s.isInCurrentTenant
                                  ? 'Member'
                                  : s.isInOtherTenant
                                      ? 'In Other Org'
                                      : 'Available',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: s.isInCurrentTenant
                                    ? Colors.orange
                                    : s.isInOtherTenant
                                        ? Colors.red
                                        : Colors.green,
                              ),
                            ),
                            onTap: () {
                              if (s.isInCurrentTenant) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Already a member of this organization',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (s.isInOtherTenant) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Already a member of ${s.otherTenantName ?? "another organization"}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                _selectedSuggestion = s;
                                _usernameController.text = s.userName;
                                _userSuggestions = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
                const SizedBox(height: 16),

                // Department Single-Select Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assign Department *',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      _selectedDepartmentId != null ? '1 Selected' : 'Required',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Departments Radio List
                Expanded(
                  child: departments.isEmpty
                      ? Center(
                          child: Text(
                            'No departments created yet. Create a department first!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: departments.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final d = departments[index];
                              final isChecked = _selectedDepartmentId == d.departmentId;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDepartmentId = d.departmentId;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d.departmentName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: isChecked ? const Color(0xFF0F766E) : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              d.description.isNotEmpty
                                                  ? d.description
                                                  : '${d.permissionIds.length} permissions granted',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: isChecked ? const Color(0xFF0F766E) : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isChecked ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: isChecked
                                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Add User'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
