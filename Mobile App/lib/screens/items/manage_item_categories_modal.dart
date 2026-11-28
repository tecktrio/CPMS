import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cpms_page_title.dart';
import '../../widgets/cpms_form_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';

class ManageItemCategoriesModal extends StatefulWidget {
  const ManageItemCategoriesModal({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManageItemCategoriesModal(),
      ),
    );
  }

  @override
  State<ManageItemCategoriesModal> createState() =>
      _ManageItemCategoriesModalState();
}

class _ManageItemCategoriesModalState extends State<ManageItemCategoriesModal> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadItemCategories(silent: true);
    });
  }

  Future<void> _showCreateOrEditDialog({ItemCategoryModel? category}) async {
    final isEditing = category != null;
    final codeController = TextEditingController(text: category?.code ?? '');
    final labelController = TextEditingController(text: category?.label ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => CpmsFormDialog(
        title: Text(
          isEditing ? 'Edit Category' : 'Create Item Category',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEditing) ...[
                const Text(
                  'CATEGORY CODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. SPARE_PARTS',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppTheme.workspaceBorder),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Category code is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                'CATEGORY NAME / LABEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: labelController,
                decoration: InputDecoration(
                  hintText: 'e.g. Spare Parts & Tools',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppTheme.workspaceBorder),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Category label is required';
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
              backgroundColor: AppTheme.adminItems,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final inv = context.read<InventoryProvider>();
              bool success = false;
              if (isEditing) {
                success = await inv.updateItemCategory(
                  code: category.code,
                  label: labelController.text.trim(),
                );
              } else {
                success = await inv.createItemCategory(
                  code: codeController.text.trim().toUpperCase(),
                  label: labelController.text.trim(),
                );
              }
              if (mounted) setState(() => _isLoading = false);
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(inv.errorMessage ?? 'Failed to save category'),
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

  Future<void> _confirmDeleteCategory(ItemCategoryModel category) async {
    setState(() => _isLoading = true);
    final inv = context.read<InventoryProvider>();
    final count = await inv.checkCategoryItemsCount(category.code);
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
                'Delete Category',
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
                  const TextSpan(text: 'Are you sure you want to delete the category "'),
                  TextSpan(
                    text: category.label,
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
                        'WARNING: There are $count item(s) currently in this category. If you delete this category, these $count item(s) and their stock records will also be permanently deleted!',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      setState(() => _isLoading = true);
      final ok = await inv.deleteItemCategory(category.code);
      if (mounted) setState(() => _isLoading = false);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${category.label}" deleted'),
            backgroundColor: AppTheme.adminItems,
          ),
        );
      } else if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inv.errorMessage ?? 'Failed to delete category'),
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
    final canManage =
        isAdmin || tenant.hasPermission(AppPermissions.itemCategoryManage);

    // Default categories if empty
    final categories = inventory.itemCategories.isNotEmpty
        ? inventory.itemCategories
        : [
            ItemCategoryModel(
              categoryId: 'preset_rm',
              code: 'RAW_MATERIAL',
              label: 'Raw Materials',
              isPreset: true,
            ),
            ItemCategoryModel(
              categoryId: 'preset_fg',
              code: 'FINISHED_GOOD',
              label: 'Finished Goods',
              isPreset: true,
            ),
            ItemCategoryModel(
              categoryId: 'preset_pack',
              code: 'PACKAGING',
              label: 'Packing Materials',
              isPreset: true,
            ),
          ];

    return Scaffold(
      backgroundColor: AppTheme.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.adminCanvas,
        foregroundColor: AppTheme.adminInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.adminInk, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const CpmsPageTitle(
          'Item categories',
          icon: Icons.category_outlined,
          accent: AppTheme.adminItems,
        ),
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adminItems,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add New',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: () => _showCreateOrEditDialog(),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.workspaceBorder),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final cat = categories[idx];
                final count =
                    inventory.items.where((i) => i.itemType == cat.code).length;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(
                    cat.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Code: ${cat.code} • $count item(s)',
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
                          tooltip: 'Edit Category Name',
                          onPressed: () =>
                              _showCreateOrEditDialog(category: cat),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Color(0xFFDC2626),
                          ),
                          tooltip: 'Delete Category',
                          onPressed: () => _confirmDeleteCategory(cat),
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
                  backgroundColor: AppTheme.adminItems,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add New Category',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () => _showCreateOrEditDialog(),
              ),
            ),
          ],
        ],
      ),
    ),
  ),
),
);
  }
}
