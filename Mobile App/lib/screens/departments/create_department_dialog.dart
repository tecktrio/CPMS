import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';

class CreateDepartmentDialog extends StatefulWidget {
  final DepartmentModel? existingDepartment;

  const CreateDepartmentDialog({super.key, this.existingDepartment});

  @override
  State<CreateDepartmentDialog> createState() => _CreateDepartmentDialogState();
}

class _CreateDepartmentDialogState extends State<CreateDepartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  final Set<String> _selectedPermissionIds = {};
  bool _isSubmitting = false;

  bool get isEditing => widget.existingDepartment != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.existingDepartment!.departmentName;
      _descController.text = widget.existingDepartment!.description;
      _selectedPermissionIds.addAll(widget.existingDepartment!.permissionIds);
    }

    final dept = context.read<DepartmentProvider>();
    if (dept.systemPermissions.isEmpty) {
      dept.loadSystemPermissions();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPermissionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign at least one permission to this department.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final deptProvider = context.read<DepartmentProvider>();
    final tenantProvider = context.read<TenantProvider>();

    final finalPermissions = Set<String>.from(_selectedPermissionIds);
    for (final permId in _selectedPermissionIds) {
      final parts = permId.split('.');
      if (parts.length >= 3) {
        finalPermissions.add('permission.${parts[1]}.read');
      }
    }

    bool success;
    if (isEditing) {
      success = await deptProvider.updateDepartment(
        departmentId: widget.existingDepartment!.departmentId,
        departmentName: _nameController.text.trim(),
        description: _descController.text.trim(),
        permissionIds: finalPermissions.toList(),
      );
    } else {
      success = await deptProvider.createDepartment(
        departmentName: _nameController.text.trim(),
        description: _descController.text.trim(),
        permissionIds: finalPermissions.toList(),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      await tenantProvider.loadTenantDepartments();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Department "${_nameController.text.trim()}" updated successfully!'
                : 'Department "${_nameController.text.trim()}" created successfully!',
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
    final deptProvider = context.watch<DepartmentProvider>();
    final modules = deptProvider.permissionsByModule;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
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
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note : Icons.apartment,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Department' : 'Create Tenant Department',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isEditing
                                ? 'Update name, description, and manage allocated permissions.'
                                : 'Define role boundaries and operational permissions.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Department Name *',
                    hintText: 'e.g. Quality Assurance & Lab',
                    prefixIcon: Icon(Icons.domain, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Department name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g. Responsible for raw milk quality checks and inward staging',
                    prefixIcon: Icon(Icons.notes, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // Permissions List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manage Department Permissions *',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${_selectedPermissionIds.length} Selected',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Permissions Modules Checkboxes
                Expanded(
                  child: deptProvider.isLoading && modules.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            children: modules.entries.map((entry) {
                              final moduleName = entry.key;
                              final perms = entry.value;

                              return ExpansionTile(
                                initiallyExpanded: true,
                                title: Text(
                                  moduleName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                children: perms.map((p) {
                                  final isChecked = _selectedPermissionIds.contains(p.permissionId);
                                  return CheckboxListTile(
                                    dense: true,
                                    value: isChecked,
                                    activeColor: const Color(0xFF0F766E),
                                    title: Text(
                                      p.displayName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      p.description,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPermissionIds.add(p.permissionId);
                                          // Auto-select read permission for this module
                                          for (final m in perms) {
                                            if (m.permissionId.endsWith('.read')) {
                                              _selectedPermissionIds.add(m.permissionId);
                                            }
                                          }
                                        } else {
                                          if (p.permissionId.endsWith('.read')) {
                                            final hasOther = perms.any((m) =>
                                                m.permissionId != p.permissionId &&
                                                _selectedPermissionIds.contains(m.permissionId));
                                            if (hasOther) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Read permission is required when other module permissions are selected.'),
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                              return;
                                            }
                                          }
                                          _selectedPermissionIds.remove(p.permissionId);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              );
                            }).toList(),
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
                          : Text(isEditing ? 'Save Changes' : 'Create Department'),
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
