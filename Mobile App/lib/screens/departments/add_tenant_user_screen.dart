import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class AddTenantUserScreen extends StatefulWidget {
  final TenantUserModel? existingUser;

  const AddTenantUserScreen({super.key, this.existingUser});

  @override
  State<AddTenantUserScreen> createState() => _AddTenantUserScreenState();
}

class _AddTenantUserScreenState extends State<AddTenantUserScreen> {
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
          content: Text('Please select 1 department to assign this staff user.'),
          backgroundColor: Colors.red,
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
      success = await deptProvider.addTenantUser(
        userName: _usernameController.text.trim().toLowerCase(),
        departmentIds: [_selectedDepartmentId!],
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Staff user permissions updated successfully!'
                : 'Staff user @${_usernameController.text.trim()} added successfully!',
          ),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deptProvider.errorMessage ?? 'Failed to save staff user.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final departments = tenant.tenantDepartments;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Update Staff Departments' : 'Add Staff Member'),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: Color(0xFF0F766E), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'Operational Module: Staff Directory\nPermission: permission.user.update'
                            : 'Operational Module: Staff Directory\nPermission: permission.user.add',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Username / Global User Search
              if (isEditing)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.existingUser!.userName.isNotEmpty
                                  ? '@${widget.existingUser!.userName} • ${widget.existingUser!.emailAddress}'
                                  : widget.existingUser!.emailAddress,
                              style: const TextStyle(
                                fontSize: 12,
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSuggestion!.fullName.isNotEmpty
                                        ? _selectedSuggestion!.fullName
                                        : _selectedSuggestion!.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Selected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${_selectedSuggestion!.userName} • ${_selectedSuggestion!.emailAddress}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        tooltip: 'Change User',
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
                    hintText: 'e.g. johndoe or john@example.com',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _usernameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _usernameController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please search and select a staff user';
                    }
                    return null;
                  },
                ),
                if (_isSearchingUsers)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Searching global registered users...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_userSuggestions.isNotEmpty && _selectedSuggestion == null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _userSuggestions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final s = _userSuggestions[idx];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: s.isAvailable
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF94A3B8),
                            child: Text(
                              (s.fullName.isNotEmpty
                                      ? s.fullName[0]
                                      : s.userName.isNotEmpty
                                          ? s.userName[0]
                                          : 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            s.fullName.isNotEmpty ? s.fullName : s.userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '@${s.userName} • ${s.emailAddress}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: s.isInCurrentTenant
                                  ? const Color(0xFFFEF3C7)
                                  : s.isInOtherTenant
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.isInCurrentTenant
                                  ? 'Already Member'
                                  : s.isInOtherTenant
                                      ? (s.otherTenantName != null
                                          ? 'In: ${s.otherTenantName}'
                                          : 'In Another Org')
                                      : 'Available',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: s.isInCurrentTenant
                                    ? const Color(0xFFB45309)
                                    : s.isInOtherTenant
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                          onTap: () {
                            if (s.isInCurrentTenant) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This user is already a member of this organization.',
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
                                    'This user is already a member of ${s.otherTenantName ?? "another organization"}. Users cannot belong to multiple organizations.',
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
              const SizedBox(height: 24),

              // Department Assignment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assign Department *',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Text(
                      _selectedDepartmentId != null ? '1 Selected' : 'Required',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the department this staff user belongs to. In this organization, each user is assigned to exactly one department.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),

              departments.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No departments configured. Please create a department first.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: departments.length,
                      itemBuilder: (context, idx) {
                        final d = departments[idx];
                        final isChecked = _selectedDepartmentId == d.departmentId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isChecked ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
                              width: isChecked ? 1.5 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() {
                                _selectedDepartmentId = d.departmentId;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(d.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text('${d.permissionIds.length} permissions granted', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 20,
                                    height: 20,
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
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 30),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSubmitting ? 'Saving...' : (isEditing ? 'Update Staff User' : 'Add Staff to Tenant')),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
