import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'create_store_room_screen.dart';

class StoreRoomsListScreen extends StatefulWidget {
  const StoreRoomsListScreen({super.key});

  @override
  State<StoreRoomsListScreen> createState() => _StoreRoomsListScreenState();
}

class _StoreRoomsListScreenState extends State<StoreRoomsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadStoreRooms();
    });
  }

  void _showEditRoomDialog(BuildContext context, StoreRoomModel room) {
    final nameCtrl = TextEditingController(text: room.roomName);
    final tempCtrl = TextEditingController(
      text: room.temperature != null ? room.temperature.toString() : '',
    );
    final capacityCtrl =
        TextEditingController(text: room.totalCapacityUnits.toString());
    final List<TextEditingController> divisionCtrls = room.divisions
        .map((d) => TextEditingController(text: d))
        .toList();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Edit Store Room: ${room.roomCode}'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Room Name *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tempCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Temperature (°C) (Optional)',
                        hintText: 'Leave empty for Ambient',
                      ),
                      validator: (v) {
                        if (v != null &&
                            v.trim().isNotEmpty &&
                            double.tryParse(v.trim()) == null) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: capacityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Capacity (Kg/Units) *'),
                      validator: (v) {
                        if (v == null || double.tryParse(v.trim()) == null) {
                          return 'Enter valid capacity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Divisions / Sections',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF0284C7)),
                          onPressed: () {
                            setDialogState(() {
                              divisionCtrls.add(
                                TextEditingController(
                                  text: 'Section ${divisionCtrls.length + 1}',
                                ),
                              );
                            });
                          },
                          tooltip: 'Add Division',
                        ),
                      ],
                    ),
                    ...List.generate(divisionCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: divisionCtrls[i],
                                decoration: InputDecoration(
                                  labelText: 'Division ${i + 1}',
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () {
                                setDialogState(() {
                                  divisionCtrls[i].dispose();
                                  divisionCtrls.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final inventory = context.read<InventoryProvider>();
                  final divisions = divisionCtrls
                      .map((c) => c.text.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  final temp = tempCtrl.text.trim().isNotEmpty
                      ? double.tryParse(tempCtrl.text.trim())
                      : null;

                  final ok = await inventory.updateStoreRoom(
                    storeRoomId: room.storeRoomId,
                    roomName: nameCtrl.text.trim(),
                    temperature: temp,
                    totalCapacityUnits:
                        double.parse(capacityCtrl.text.trim()),
                    divisions: divisions,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Store room updated successfully'
                            : (inventory.errorMessage ?? 'Update failed')),
                        backgroundColor:
                            ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                      ),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context, StoreRoomModel room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Store Room: ${room.roomCode}?'),
        content: Text(
          'Are you sure you want to deactivate or remove "${room.roomName}" (${room.roomCode})? Note: A store room cannot be deleted if active stock or batches are present.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.deleteStoreRoom(room.storeRoomId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Store room deleted successfully'
                        : (inventory.errorMessage ?? 'Delete failed')),
                    backgroundColor:
                        ok ? const Color(0xFF0F766E) : Colors.red.shade700,
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

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canCreate = isAdmin || tenant.hasPermission(AppPermissions.storeroomCreate);
    final canUpdate = isAdmin || tenant.hasPermission(AppPermissions.storeroomUpdate);
    final canDelete = isAdmin || tenant.hasPermission(AppPermissions.storeroomDelete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => inventory.loadStoreRooms(),
          ),
          const UserProfileAvatar(),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Store Room',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateStoreRoomScreen()),
                );
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: inventory.loadStoreRooms,
        child: inventory.isLoading
            ? const Center(child: CircularProgressIndicator())
            : inventory.storeRooms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Store Rooms Registered',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Register store rooms to manage physical storage and divisions.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: inventory.storeRooms.length,
                    itemBuilder: (context, index) {
                      final room = inventory.storeRooms[index];
                      final util = room.capacityUtilizationPercentage;

                      Color utilColor = const Color(0xFF16A34A);
                      if (util >= 90) {
                        utilColor = const Color(0xFFDC2626);
                      } else if (util >= 70) {
                        utilColor = const Color(0xFFD97706);
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      room.roomCode,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      room.roomName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          room.temperature != null
                                              ? Icons.thermostat
                                              : Icons.air,
                                          size: 14,
                                          color: const Color(0xFF0284C7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          room.temperature != null
                                              ? '${room.temperature!.toStringAsFixed(1)} °C'
                                              : 'Ambient',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canUpdate) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      color: const Color(0xFF0F766E),
                                      tooltip: 'Edit Store Room',
                                      onPressed: () =>
                                          _showEditRoomDialog(context, room),
                                    ),
                                  ],
                                  if (canDelete) ...[
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      color: const Color(0xFFDC2626),
                                      tooltip: 'Delete Store Room',
                                      onPressed: () =>
                                          _confirmDeleteRoom(context, room),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Occupancy progress bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Capacity: ${room.totalCapacityUnits.toStringAsFixed(1)} Units',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${util.toStringAsFixed(1)}% full',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: utilColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (util / 100).clamp(0.0, 1.0),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: AlwaysStoppedAnimation<Color>(utilColor),
                                  minHeight: 7,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Divisions / Sections display
                              if (room.divisions.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.grid_view_outlined,
                                      size: 13,
                                      color: Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${room.divisions.length} Division(s):',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: room.divisions.map((div) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        div,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ] else
                                const Text(
                                  'No divisions configured for this store room',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
