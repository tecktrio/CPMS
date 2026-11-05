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
  final _emailController = TextEditingController();
  final Set<String> _selectedDepartmentIds = {};
  bool _isSubmitting = false;

  bool get isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _emailController.text = widget.existingUser!.emailAddress;
      _selectedDepartmentIds.addAll(widget.existingUser!.departmentIds);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartmentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 department to assign permissions to this staff user.'),
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
        departmentIds: _selectedDepartmentIds.toList(),
      );
    } else {
      success = await deptProvider.addTenantUser(
        emailAddress: _emailController.text.trim().toLowerCase(),
        departmentIds: _selectedDepartmentIds.toList(),
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
                : 'Staff user ${_emailController.text.trim()} added successfully!',
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

              // Email Address
              TextFormField(
                controller: _emailController,
                enabled: !isEditing,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Staff Email Address *',
                  hintText: 'user@company.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: isEditing,
                  fillColor: isEditing ? const Color(0xFFF8FAFC) : null,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!val.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Department Assignment
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Assign Departments *',
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
                      '${_selectedDepartmentIds.length} Selected',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the departments this staff user belongs to. Their permissions will be aggregated across all selected departments.',
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
                        final isChecked = _selectedDepartmentIds.contains(d.departmentId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isChecked ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
                              width: isChecked ? 1.5 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            dense: true,
                            title: Text(d.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${d.permissionIds.length} permissions granted'),
                            value: isChecked,
                            activeColor: const Color(0xFF0F766E),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedDepartmentIds.add(d.departmentId);
                                } else {
                                  _selectedDepartmentIds.remove(d.departmentId);
                                }
                              });
                            },
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
