import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';

class CreateStoreRoomDialog extends StatefulWidget {
  const CreateStoreRoomDialog({super.key});

  @override
  State<CreateStoreRoomDialog> createState() => _CreateStoreRoomDialogState();
}

class _CreateStoreRoomDialogState extends State<CreateStoreRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _tempController = TextEditingController(text: '-18.0');
  final _capacityController = TextEditingController(text: '100.0');

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _tempController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final inventory = context.read<InventoryProvider>();
    final temp = double.tryParse(_tempController.text) ?? -18.0;
    final capacity = double.tryParse(_capacityController.text) ?? 100.0;

    final success = await inventory.createStoreRoom(
      roomCode: _codeController.text,
      roomName: _nameController.text,
      temperature: temp,
      totalCapacityUnits: capacity,
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
    return AlertDialog(
      title: const Text('Add Cold Store Room'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Room Code',
                  hintText: 'e.g. CR-01',
                  prefixIcon: Icon(Icons.qr_code, size: 20),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Room code is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g. Blast Freezer Room',
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
                controller: _tempController,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Target Temperature (°C)',
                  hintText: '-18.0',
                  prefixIcon: Icon(Icons.thermostat, size: 20),
                ),
                validator: (val) {
                  if (val == null || double.tryParse(val) == null) {
                    return 'Enter valid temperature';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Maximum Capacity (Units)',
                  hintText: '100.0',
                  prefixIcon: Icon(Icons.storage, size: 20),
                ),
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter valid capacity > 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create Room'),
        ),
      ],
    );
  }
}

