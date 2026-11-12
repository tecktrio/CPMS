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
  final _tempController = TextEditingController();
  final _capacityController = TextEditingController(text: '1000');
  final _divisionCountController = TextEditingController(text: '2');

  final List<TextEditingController> _divisionControllers = [
    TextEditingController(text: 'Section A'),
    TextEditingController(text: 'Section B'),
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _nameController.dispose();
    _tempController.dispose();
    _capacityController.dispose();
    _divisionCountController.dispose();
    for (final c in _divisionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _generateDivisions(int count) {
    if (count <= 0 || count > 50) return;
    setState(() {
      for (final c in _divisionControllers) {
        c.dispose();
      }
      _divisionControllers.clear();
      for (int i = 1; i <= count; i++) {
        _divisionControllers.add(TextEditingController(text: 'Section $i'));
      }
    });
  }

  void _addDivision() {
    setState(() {
      final nextNum = _divisionControllers.length + 1;
      _divisionControllers.add(TextEditingController(text: 'Section $nextNum'));
      _divisionCountController.text = _divisionControllers.length.toString();
    });
  }

  void _removeDivision(int index) {
    setState(() {
      _divisionControllers[index].dispose();
      _divisionControllers.removeAt(index);
      _divisionCountController.text = _divisionControllers.length.toString();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final inventory = context.read<InventoryProvider>();
    final divisions = _divisionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final temp = _tempController.text.trim().isNotEmpty
        ? double.tryParse(_tempController.text.trim())
        : null;

    final success = await inventory.createStoreRoom(
      roomCode: _roomCodeController.text.trim().toUpperCase(),
      roomName: _nameController.text.trim(),
      temperature: temp,
      totalCapacityUnits: double.tryParse(_capacityController.text.trim()) ?? 1000,
      divisions: divisions,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Store Room "${_nameController.text.trim()}" created successfully!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to create store room.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Row(
              children: const [
                Text(
                  'Create Store Room',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 20,
              20,
              isWide ? 28 : 20,
              32,
            ),
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
                    Icon(Icons.meeting_room_outlined, color: Color(0xFF0284C7), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operational Module: Store Rooms\nPermission: permission.storeroom.create',
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
                  labelText: 'Store Room Name *',
                  hintText: 'e.g., Main Dry Store or Freezer Room 1',
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
                  hintText: 'e.g., SR-01',
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

              // Temperature (Optional) & Capacity
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tempController,
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Temperature (°C) (Optional)',
                        hintText: 'Leave blank for Ambient',
                        prefixIcon: Icon(Icons.thermostat),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty && double.tryParse(val.trim()) == null) {
                          return 'Enter valid number';
                        }
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
                        labelText: 'Capacity (Kg/Units) *',
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
              const SizedBox(height: 24),

              // Divisions / Sections Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Divisions & Sections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Define areas/sections where items will be stored',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _addDivision,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Section'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Division Generator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Number of Divisions:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        controller: _divisionCountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        final count = int.tryParse(_divisionCountController.text.trim()) ?? 0;
                        if (count > 0) _generateDivisions(count);
                      },
                      child: const Text('Generate', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Division List
              ...List.generate(_divisionControllers.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${idx + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _divisionControllers[idx],
                          decoration: InputDecoration(
                            labelText: 'Division / Section ${idx + 1}',
                            hintText: 'e.g. Rack A, Shelf 1, Zone B',
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_divisionControllers.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => _removeDivision(idx),
                          tooltip: 'Remove Division',
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Creating Room...'
                        : 'Create Store Room',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}
