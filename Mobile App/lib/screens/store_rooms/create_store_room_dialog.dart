import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cpms_form_dialog.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class CreateStoreRoomDialog extends StatefulWidget {
  const CreateStoreRoomDialog({super.key});

  @override
  State<CreateStoreRoomDialog> createState() => _CreateStoreRoomDialogState();
}

class _CreateStoreRoomDialogState extends State<CreateStoreRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _tempController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final inventory = context.read<InventoryProvider>();
    final temp = double.tryParse(_tempController.text.trim());

    final success = await inventory.createStoreRoom(
      roomName: _nameController.text,
      description: _descController.text.trim(),
      temperature: temp,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cold room registered successfully'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to create room'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CpmsFormDialog(
      icon: Icons.warehouse_outlined,
      title: const Text('Add Cold Store Room'),
      content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  prefixIcon: Icon(Icons.label_outline, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Room name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.notes_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tempController,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Temperature (°C, optional)',
                  prefixIcon: Icon(Icons.thermostat, size: 20),
                ),
                validator: (val) {
                  final input = val?.trim() ?? '';
                  if (input.isEmpty) return null;
                  return double.tryParse(input)?.isFinite == true
                      ? null
                      : 'Enter a valid temperature';
                },
              ),
            ],
          ),
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.adminStorage),
          onPressed: _submit,
          child: const Text('Create Room'),
        ),
      ],
    );
  }
}

