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
    _usernameController.dispose();
    super.dispose();
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

              // Username
              TextFormField(
                controller: _usernameController,
                enabled: !isEditing,
                keyboardType: TextInputType.text,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Staff Username (@username) *',
                  hintText: 'e.g. janedoe',
                  prefixIcon: const Icon(Icons.alternate_email),
                  filled: isEditing,
                  fillColor: isEditing ? const Color(0xFFF8FAFC) : null,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Username is required';
                  return null;
                },
              ),
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
