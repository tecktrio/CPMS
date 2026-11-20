import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';

class ManagePackagingMaterialsModal extends StatefulWidget {
  const ManagePackagingMaterialsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManagePackagingMaterialsModal(),
    );
  }

  @override
  State<ManagePackagingMaterialsModal> createState() =>
      _ManagePackagingMaterialsModalState();
}

class _ManagePackagingMaterialsModalState
    extends State<ManagePackagingMaterialsModal> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadPackagingMaterials(silent: true);
    });
  }

  Future<void> _showCreateOrEditDialog({PackagingMaterialModel? material}) async {
    final isEditing = material != null;
    final nameController = TextEditingController(text: material?.name ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          isEditing ? 'Edit Packaging Material' : 'Create Packaging Material',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MATERIAL NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Duplex, Corrugated Box',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Material name is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final inv = context.read<InventoryProvider>();
              bool success = false;
              if (isEditing) {
                success = await inv.updatePackagingMaterial(
                  idOrName: material.materialId.isNotEmpty
                      ? material.materialId
                      : material.name,
                  name: nameController.text.trim(),
                );
              } else {
                success = await inv.createPackagingMaterial(
                  name: nameController.text.trim(),
                );
              }
              if (mounted) setState(() => _isLoading = false);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        inv.errorMessage ?? 'Failed to save packaging material'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteMaterial(PackagingMaterialModel material) async {
    setState(() => _isLoading = true);
    final inv = context.read<InventoryProvider>();
    final count = await inv.checkPackagingMaterialItemsCount(
      material.materialId.isNotEmpty ? material.materialId : material.name,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Icon(
              count > 0 ? Icons.warning_amber_rounded : Icons.delete_outline,
              color: const Color(0xFFDC2626),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Delete Packaging Material',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                      text: 'Are you sure you want to delete the packaging material "'),
                  TextSpan(
                    text: material.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '"?'),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
            if (count > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF87171)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WARNING: There are $count packing material item(s) currently registered with name "${material.name}". If you delete this packaging material, these $count item(s) will also be permanently deleted!',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      setState(() => _isLoading = true);
      final ok = await inv.deletePackagingMaterial(
        material.materialId.isNotEmpty ? material.materialId : material.name,
      );
      if (mounted) setState(() => _isLoading = false);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Packaging material "${material.name}" deleted'),
            backgroundColor: Colors.black,
          ),
        );
      } else if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                inv.errorMessage ?? 'Failed to delete packaging material'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final inventory = context.watch<InventoryProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canManage = isAdmin ||
        tenant.hasPermission(AppPermissions.packagingMaterialManage) ||
        tenant.hasPermission(AppPermissions.itemCategoryManage);

    final materials = inventory.packagingMaterials.isNotEmpty
        ? inventory.packagingMaterials
        : [
            PackagingMaterialModel(
                materialId: 'preset_dup', name: 'Duplex', isPreset: true),
            PackagingMaterialModel(
                materialId: 'preset_rid', name: 'Rider', isPreset: true),
            PackagingMaterialModel(
                materialId: 'preset_pwr',
                name: 'Pouches with rider',
                isPreset: true),
            PackagingMaterialModel(
                materialId: 'preset_pou', name: 'Pouches', isPreset: true),
            PackagingMaterialModel(
                materialId: 'preset_buc', name: 'Bucket', isPreset: true),
            PackagingMaterialModel(
                materialId: 'preset_tub', name: 'Tub', isPreset: true),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Packaging Materials',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage packaging materials for your organization',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: materials.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final mat = materials[idx];
                final count = inventory.items
                    .where((i) =>
                        i.itemType == 'PACKAGING' &&
                        i.itemName.toLowerCase() == mat.name.toLowerCase())
                    .length;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(
                    mat.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '$count item(s) using this material',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canManage) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Color(0xFF0F766E),
                          ),
                          tooltip: 'Edit Packaging Material Name',
                          onPressed: () =>
                              _showCreateOrEditDialog(material: mat),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Color(0xFFDC2626),
                          ),
                          tooltip: 'Delete Packaging Material',
                          onPressed: () => _confirmDeleteMaterial(mat),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add Packaging Material',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () => _showCreateOrEditDialog(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

