import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class CreateStoreRoomScreen extends StatefulWidget {
  const CreateStoreRoomScreen({super.key});

  @override
  State<CreateStoreRoomScreen> createState() => _CreateStoreRoomScreenState();
}

class _CreateStoreRoomScreenState extends State<CreateStoreRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _tempController = TextEditingController(text: '-18');
  final _capacityController = TextEditingController(text: '1000');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _nameController.dispose();
    _tempController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final inventory = context.read<InventoryProvider>();
    final success = await inventory.createStoreRoom(
      roomCode: _roomCodeController.text.trim().toUpperCase(),
      roomName: _nameController.text.trim(),
      temperature: double.tryParse(_tempController.text) ?? -18,
      totalCapacityUnits: double.tryParse(_capacityController.text) ?? 1000,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cold Room "${_nameController.text.trim()}" created successfully!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to create cold room.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Cold Room'),
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
                child: const Row(
                  children: [
                    Icon(Icons.ac_unit, color: Color(0xFF0284C7), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operational Module: Cold Store Rooms\nPermission: permission.storeroom.create',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Room Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name *',
                  hintText: 'e.g., Deep Freeze Room A',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Room name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Room Code
              TextFormField(
                controller: _roomCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Room Code *',
                  hintText: 'e.g., CR-01',
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Room code required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Temperature & Capacity
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tempController,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Temperature (°C) *',
                        prefixIcon: Icon(Icons.thermostat),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val) == null) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Capacity (Kg) *',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val) == null) {
                          return 'Enter valid capacity';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
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
                  label: Text(_isSubmitting ? 'Creating Room...' : 'Create Cold Room'),
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
