import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class CreateDepartmentScreen extends StatefulWidget {
  final DepartmentModel? existingDepartment;

  const CreateDepartmentScreen({super.key, this.existingDepartment});

  @override
  State<CreateDepartmentScreen> createState() => _CreateDepartmentScreenState();
}

class _CreateDepartmentScreenState extends State<CreateDepartmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _selectedPermissions = {};
  bool _isSubmitting = false;

  bool get isEditing => widget.existingDepartment != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.existingDepartment!.departmentName;
      _descController.text = widget.existingDepartment!.description;
      _selectedPermissions.addAll(widget.existingDepartment!.permissionIds);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DepartmentProvider>().loadSystemPermissions();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 permission for this department.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final deptProvider = context.read<DepartmentProvider>();
    final tenantProvider = context.read<TenantProvider>();

    bool success;
    if (isEditing) {
      success = await deptProvider.updateDepartment(
        departmentId: widget.existingDepartment!.departmentId,
        departmentName: _nameController.text.trim(),
        description: _descController.text.trim(),
        permissionIds: _selectedPermissions.toList(),
      );
    } else {
      success = await deptProvider.createDepartment(
        departmentName: _nameController.text.trim(),
        description: _descController.text.trim(),
        permissionIds: _selectedPermissions.toList(),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      await tenantProvider.loadTenantDepartments();
      if (!mounted) return;
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
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deptProvider.errorMessage ?? 'Failed to save department.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deptProvider = context.watch<DepartmentProvider>();
    final permissions = deptProvider.systemPermissions;

    // Group permissions by module
    final Map<String, List<SystemPermissionModel>> grouped = {};
    for (final p in permissions) {
      grouped.putIfAbsent(p.module, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Department & Permissions' : 'Create Department'),
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
                    const Icon(Icons.apartment, color: Color(0xFFD97706), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'Operational Module: Departments & Roles\nPermission: permission.department.update'
                            : 'Operational Module: Departments & Roles\nPermission: permission.department.create',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Department Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Department Name *',
                  hintText: 'e.g., Cold Chain Quality Control',
                  prefixIcon: Icon(Icons.apartment),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Department name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief summary of roles & responsibilities',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Permissions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Department Permissions *',
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
                      '${_selectedPermissions.length} Selected',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (deptProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, idx) {
                    final moduleName = grouped.keys.elementAt(idx);
                    final permsInModule = grouped[moduleName]!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(
                          moduleName.toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${permsInModule.where((p) => _selectedPermissions.contains(p.permissionId)).length} of ${permsInModule.length} selected',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        children: permsInModule.map((p) {
                          final isChecked = _selectedPermissions.contains(p.permissionId);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(p.displayName, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(p.permissionId, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            value: isChecked,
                            activeColor: const Color(0xFF0F766E),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPermissions.add(p.permissionId);
                                } else {
                                  _selectedPermissions.remove(p.permissionId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 30),

              // Save Button
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
                  label: Text(_isSubmitting ? 'Saving...' : (isEditing ? 'Save Changes' : 'Create Department')),
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
