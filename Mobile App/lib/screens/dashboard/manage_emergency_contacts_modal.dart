import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/emergency_contacts_provider.dart';

class ManageEmergencyContactsModal extends StatelessWidget {
  const ManageEmergencyContactsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManageEmergencyContactsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmergencyContactsProvider>();
    final contacts = provider.contacts;

    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      padding: EdgeInsets.only(bottom: viewInsets),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: const Icon(
                    Icons.contact_phone_outlined,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Manage Emergency Contacts',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Administrator Department Privilege',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Add Contact Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${contacts.length} Hotlines Configured',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Contact',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _openContactDialog(context),
                ),
              ],
            ),
          ),

          // Contacts List
          Expanded(
            child: provider.isLoading && contacts.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF064E3B)),
                  )
                : contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.phone_disabled_outlined,
                              size: 48,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No emergency contacts yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap "+ Add Contact" above to register hotlines.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: contacts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = contacts[index];
                          final iconData = _resolveIcon(item.iconType);
                          final colors = _resolveColors(item.iconType);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors['bg'],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colors['border']!,
                                    ),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: colors['icon'],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (item.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          item.subtitle,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        item.phoneNumber,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF064E3B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                    color: Color(0xFF0F766E),
                                  ),
                                  tooltip: 'Edit Contact',
                                  onPressed: () => _openContactDialog(
                                    context,
                                    existing: item,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 19,
                                    color: Color(0xFFEF4444),
                                  ),
                                  tooltip: 'Delete Contact',
                                  onPressed: () => _confirmDeleteContact(
                                    context,
                                    item,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  static IconData _resolveIcon(String iconType) {
    switch (iconType.toLowerCase()) {
      case 'safety':
        return Icons.gpp_good_outlined;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'general':
      case 'phone':
        return Icons.support_agent_rounded;
      case 'security':
      case 'warning':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  static Map<String, Color> _resolveColors(String iconType) {
    switch (iconType.toLowerCase()) {
      case 'safety':
        return {
          'icon': const Color(0xFF16A34A),
          'bg': const Color(0xFFF0FDF4),
          'border': const Color(0xFFDCFCE7),
        };
      case 'medical':
        return {
          'icon': const Color(0xFF2563EB),
          'bg': const Color(0xFFEFF6FF),
          'border': const Color(0xFFDBEAFE),
        };
      case 'general':
      case 'phone':
        return {
          'icon': const Color(0xFF0F766E),
          'bg': const Color(0xFFF0FDFA),
          'border': const Color(0xFFCCFBF1),
        };
      case 'security':
      case 'warning':
      default:
        return {
          'icon': const Color(0xFFEF4444),
          'bg': const Color(0xFFFEF2F2),
          'border': const Color(0xFFFEE2E2),
        };
    }
  }

  static void _openContactDialog(
    BuildContext context, {
    EmergencyContactModel? existing,
  }) {
    showDialog(
      context: context,
      builder: (_) => _EmergencyContactFormDialog(existing: existing),
    );
  }

  static void _confirmDeleteContact(
    BuildContext context,
    EmergencyContactModel item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Emergency Contact'),
        content: Text(
          'Are you sure you want to remove "${item.title}" (${item.phoneNumber}) from organization emergency contacts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<EmergencyContactsProvider>()
                  .deleteContact(item.contactId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Emergency contact deleted'
                          : 'Failed to delete emergency contact',
                    ),
                    backgroundColor:
                        success ? const Color(0xFF0F766E) : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactFormDialog extends StatefulWidget {
  final EmergencyContactModel? existing;

  const _EmergencyContactFormDialog({this.existing});

  @override
  State<_EmergencyContactFormDialog> createState() =>
      _EmergencyContactFormDialogState();
}

class _EmergencyContactFormDialogState
    extends State<_EmergencyContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _phoneController;
  String _selectedIconType = 'security';
  bool _isSaving = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _subtitleController =
        TextEditingController(text: widget.existing?.subtitle ?? '');
    _phoneController =
        TextEditingController(text: widget.existing?.phoneNumber ?? '');
    _selectedIconType = widget.existing?.iconType ?? 'security';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<EmergencyContactsProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updateContact(
        contactId: widget.existing!.contactId,
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        iconType: _selectedIconType,
      );
    } else {
      success = await provider.createContact(
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        iconType: _selectedIconType,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Emergency contact updated successfully!'
                : 'Emergency contact added successfully!',
          ),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Failed to save emergency contact.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Emergency Contact' : 'Add Emergency Contact',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title / Unit Name *',
                  hintText: 'e.g. Facility Security & Control',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Subtitle / Personnel / Extension',
                  hintText: 'e.g. Control Room • Ext. 101',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'e.g. +1 (800) 555-0199',
                  prefixIcon: Icon(Icons.phone, size: 18),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Category & Badge',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('security', 'Security', Icons.warning_amber),
                  _buildTypeChip('safety', 'Safety / EHS', Icons.gpp_good),
                  _buildTypeChip('medical', 'Medical', Icons.medical_services),
                  _buildTypeChip('general', 'General', Icons.support_agent),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF064E3B),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Save Changes' : 'Add Contact'),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _selectedIconType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedIconType = type);
      },
    );
  }
}
