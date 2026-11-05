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
          content: Text('Please select at least one department for this staff member.'),
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Staff department assignments updated!'
                : 'User added to organization departments!',
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

                // Email Address
                TextFormField(
                  controller: _emailController,
                  enabled: !isEditing,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'User Email Address *',
                    hintText: 'e.g. operator@cyanfoods.com',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    filled: isEditing,
                    fillColor: isEditing ? const Color(0xFFF1F5F9) : null,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty || !val.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Department Multi-Select Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assign Departments *',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${_selectedDepartmentIds.length} Selected',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Departments Checkbox List
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
                              final isChecked = _selectedDepartmentIds.contains(d.departmentId);

                              return CheckboxListTile(
                                dense: true,
                                value: isChecked,
                                activeColor: const Color(0xFF0F766E),
                                title: Text(
                                  d.departmentName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  d.description.isNotEmpty
                                      ? d.description
                                      : '${d.permissionIds.length} permissions granted',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedDepartmentIds.add(d.departmentId);
                                    } else {
                                      _selectedDepartmentIds.remove(d.departmentId);
                                    }
                                  });
                                },
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
