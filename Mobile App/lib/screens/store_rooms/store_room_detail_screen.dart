import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../items/create_item_screen.dart';
import 'store_room_item_detail_screen.dart';

class StoreRoomDetailScreen extends StatefulWidget {
  final StoreRoomModel room;

  const StoreRoomDetailScreen({super.key, required this.room});

  @override
  State<StoreRoomDetailScreen> createState() => _StoreRoomDetailScreenState();
}

class _StoreRoomDetailScreenState extends State<StoreRoomDetailScreen> {
  void _showAddDivisionDialog(StoreRoomModel room) {
    final divController = TextEditingController(
      text: 'Division - section ${room.divisions.length + 1}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'Add New Division',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a section, rack, or aisle name to partition this store room.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: divController,
              autofocus: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.grid_view_outlined, size: 20),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
            ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              final newDiv = divController.text.trim();
              if (newDiv.isEmpty) return;
              Navigator.pop(ctx);

              final inventory = context.read<InventoryProvider>();
              final updatedDivs = [...room.divisions, newDiv];
              final ok = await inventory.updateStoreRoom(
                storeRoomId: room.storeRoomId,
                roomName: room.roomName,
                temperature: room.temperature,
                divisions: updatedDivs,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Added division "$newDiv" successfully'
                        : (inventory.errorMessage ?? 'Failed to add division')),
                    backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Add Division', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditDivisionDialog(StoreRoomModel room, int index) {
    if (index < 0 || index >= room.divisions.length) return;
    final currentDivName = room.divisions[index];
    final divController = TextEditingController(text: currentDivName);
    final roomItems = room.items;
    final itemsInDiv = roomItems.where((i) => i.division == currentDivName).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, size: 20, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Edit Division',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update the name of this division. All assigned items will be updated automatically.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: divController,
              autofocus: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.grid_view_outlined, size: 20),
              ),
            ),
            if (itemsInDiv > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$itemsInDiv allocated items will be safely moved to the updated division.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteDivision(room, index);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () async {
                      final updatedName = divController.text.trim();
                      if (updatedName.isEmpty || updatedName == currentDivName) {
                        Navigator.pop(ctx);
                        return;
                      }
                      Navigator.pop(ctx);

                      final inventory = context.read<InventoryProvider>();
                      final updatedDivs = List<String>.from(room.divisions);
                      updatedDivs[index] = updatedName;

                      final ok = await inventory.updateStoreRoom(
                        storeRoomId: room.storeRoomId,
                        roomName: room.roomName,
                        temperature: room.temperature,
                        divisions: updatedDivs,
                      );

                      // Ensure item assignments sync if name changed using division_id
                      final divId = room.divisionObjects.length > index
                          ? room.divisionObjects[index].divisionId
                          : room.getDivisionId(currentDivName);

                      for (final it in room.items) {
                        if ((it.divisionId.isNotEmpty && it.divisionId == divId) ||
                            it.division == currentDivName ||
                            room.resolveFormattedDivisionName(it) == currentDivName) {
                          await inventory.updateStoreRoomItemDivision(
                            storeRoomId: room.storeRoomId,
                            itemId: it.itemId,
                            division: updatedName,
                            divisionId: divId,
                          );
                        }
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Division updated to "$updatedName"'
                                : (inventory.errorMessage ?? 'Failed to update division')),
                            backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                          ),
                        );
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDivision(StoreRoomModel room, int index) {
    if (index < 0 || index >= room.divisions.length) return;
    final divToDelete = room.divisions[index];
    final itemsInDiv = room.items.where((i) => i.division == divToDelete).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'Delete Division',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete division "$divToDelete"?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (itemsInDiv > 0)
              Text(
                'Warning: $itemsInDiv items are currently allocated to this division. They will be reassigned to the default section.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
              )
            else
              const Text(
                'This division will be permanently removed from this store room.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              final updatedDivs = List<String>.from(room.divisions)..removeAt(index);
              final divId = room.divisionObjects.length > index
                  ? room.divisionObjects[index].divisionId
                  : room.getDivisionId(divToDelete);
              final fallbackDiv = updatedDivs.isNotEmpty ? updatedDivs[0] : 'Division - section 1';
              final fallbackDivId = room.getDivisionId(fallbackDiv);

              final ok = await inventory.updateStoreRoom(
                storeRoomId: room.storeRoomId,
                roomName: room.roomName,
                temperature: room.temperature,
                divisions: updatedDivs,
              );

              // Reassign any orphaned items
              for (final it in room.items) {
                if ((it.divisionId.isNotEmpty && it.divisionId == divId) ||
                    it.division == divToDelete ||
                    room.resolveFormattedDivisionName(it) == divToDelete) {
                  await inventory.updateStoreRoomItemDivision(
                    storeRoomId: room.storeRoomId,
                    itemId: it.itemId,
                    division: fallbackDiv,
                    divisionId: fallbackDivId,
                  );
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Division "$divToDelete" removed'
                        : (inventory.errorMessage ?? 'Failed to delete division')),
                    backgroundColor: ok ? Colors.black : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Delete Division', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditRoomBottomSheet(StoreRoomModel room) {
    final nameCtrl = TextEditingController(text: room.roomName);
    final descCtrl = TextEditingController(text: room.description);
    final tempCtrl = TextEditingController(
      text: room.temperature != null ? room.temperature.toString() : '',
    );
    final List<TextEditingController> divisionCtrls =
        room.divisions.map((d) => TextEditingController(text: d)).toList();

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Store Room Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STORE ROOM NAME *',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: nameCtrl,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Room name is required' : null,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'DESCRIPTION (OPTIONAL)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: descCtrl,
                              maxLines: 2,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'TEMPERATURE (°C) (OPTIONAL)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: tempCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                signed: true,
                                decimal: true,
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: Colors.black, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'CONFIGURED DIVISIONS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setSheetState(() {
                                      divisionCtrls.add(
                                        TextEditingController(
                                          text: 'Division - section ${divisionCtrls.length + 1}',
                                        ),
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.add, size: 16, color: Colors.black),
                                  label: const Text(
                                    'Add Section',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...List.generate(divisionCtrls.length, (i) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: divisionCtrls[i],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide:
                                                const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                            borderSide:
                                                const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Color(0xFFDC2626), size: 20),
                                      onPressed: () {
                                        setSheetState(() {
                                          divisionCtrls[i].dispose();
                                          divisionCtrls.removeAt(i);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final messenger = ScaffoldMessenger.of(context);
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
                            description: descCtrl.text.trim(),
                            temperature: temp,
                            divisions: divisions,
                          );

                          if (mounted) {
                            messenger.showSnackBar(
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
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteRoom(StoreRoomModel room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(
          'Delete Store Room: ${room.roomCode}?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${room.roomName}" (${room.roomCode})? Note: A store room cannot be deleted if active stock or batches are present.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              final ok = await inventory.deleteStoreRoom(room.storeRoomId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Store room deleted successfully'
                        : (inventory.errorMessage ?? 'Delete failed')),
                    backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
                if (ok) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _itemSearchQuery = '';
  String? _selectedDivisionFilter;
  String? _selectedTypeFilter;
  bool _isGridView = false;
  bool _sortAscending = true;

  void _showAddItemToRoomSheet(StoreRoomModel room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddItemToRoomModal(
        room: room,
        onItemAssigned: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _showEditItemQuantityDialog(
    ItemModel item,
    StoreRoomItemModel sri,
    StoreRoomModel room,
  ) {
    final qtyCtrl = TextEditingController(text: sri.quantity.toStringAsFixed(sri.quantity.truncateToDouble() == sri.quantity ? 0 : 1));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(
          'Set Count: ${item.itemName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stored in ${room.roomName} (${room.resolveFormattedDivisionName(sri)})',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (item.quantity > 1) ...[
                const SizedBox(height: 4),
                Text(
                  'Each item = ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.measurementUnit}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: item.quantity > 1
                      ? 'Count of "${item.itemName}" *'
                      : 'Count *',
                  suffixText: null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (_) => setDlgState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter count';
                  final n = double.tryParse(val.trim());
                  if (n == null || n < 0) return 'Enter valid non-negative number';
                  return null;
                },
              ),
              if (item.quantity > 1) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final count = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                    final total = count * item.quantity;
                    final totalStr = total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);
                    return Text(
                      '= $totalStr ${item.measurementUnit} total',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
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
              final qty = double.parse(qtyCtrl.text.trim());
              Navigator.pop(ctx);
              final inventory = context.read<InventoryProvider>();
              await inventory.updateStoreRoomItemQuantity(
                storeRoomId: room.storeRoomId,
                itemId: item.itemId,
                quantity: qty,
              );
            },
            child: const Text('Save Count',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      ),
    );
  }

  // ignore: unused_element
  void _showSetMinimumCountDialog(
    ItemModel item,
    StoreRoomItemModel sri,
    StoreRoomModel room,
  ) {
    final controller = TextEditingController(
      text: sri.minCount.toStringAsFixed(
        sri.minCount.truncateToDouble() == sri.minCount ? 0 : 2,
      ),
    );
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('Minimum Count: ${item.itemName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Minimum count',
              helperText: 'Set to 0 to disable the minimum.',
            ),
            validator: (value) {
              final count = double.tryParse(value?.trim() ?? '');
              if (count == null || count < 0) return 'Enter a valid non-negative count';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final minCount = double.parse(controller.text.trim());
              Navigator.pop(ctx);
              await context.read<InventoryProvider>().updateStoreRoomItemQuantity(
                    storeRoomId: room.storeRoomId,
                    itemId: item.itemId,
                    quantity: sri.quantity,
                    minCount: minCount,
                  );
            },
            child: const Text('Save Minimum'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showMoveDivisionDialog(ItemModel item, StoreRoomModel room) {
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();

    final List<String> availableDivisions = [];
    if (room.divisions.isNotEmpty) {
      availableDivisions.addAll(room.divisions);
      if (!availableDivisions.contains('Default Section')) {
        availableDivisions.add('Default Section');
      }
    } else {
      availableDivisions.addAll(['Default Section', 'Section 1', 'Section 2', 'Section 3']);
    }
    if (!availableDivisions.contains('+ Custom Division')) {
      availableDivisions.add('+ Custom Division');
    }

    String selected = (item.division != null && availableDivisions.contains(item.division))
        ? item.division!
        : availableDivisions.first;
    final customCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            title: Text(
              'Move "${item.itemName}"',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select division within ${room.roomName}:',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: availableDivisions.contains(selected)
                      ? selected
                      : availableDivisions.first,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    prefixIcon: const Icon(
                      Icons.grid_view_outlined,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: availableDivisions.map((div) {
                    final isCustom = div == '+ Custom Division';
                    return DropdownMenuItem<String>(
                      value: div,
                      child: Text(
                        div,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCustom ? FontWeight.w800 : FontWeight.w600,
                          color: isCustom ? const Color(0xFF0F766E) : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() => selected = val);
                    }
                  },
                ),
                if (selected == '+ Custom Division') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: customCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      prefixIcon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final finalDiv = (selected == '+ Custom Division' && customCtrl.text.trim().isNotEmpty)
                      ? customCtrl.text.trim()
                      : (selected == '+ Custom Division' ? 'Division - section 1' : selected);
                  final divId = room.getDivisionId(finalDiv);
                  final ok = await inventory.updateStoreRoomItemDivision(
                    storeRoomId: room.storeRoomId,
                    itemId: item.itemId,
                    division: finalDiv,
                    divisionId: divId,
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Moved "${item.itemName}" to $finalDiv'
                            : (inventory.errorMessage ?? 'Failed to move division')),
                        backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                      ),
                    );
                  }
                },
                child: const Text('Move Division', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ignore: unused_element
  void _confirmRemoveItemFromRoom(ItemModel item, StoreRoomModel room) {
    final messenger = ScaffoldMessenger.of(context);
    final inventory = context.read<InventoryProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'Remove from Store Room?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove "${item.itemName}" from "${room.roomName}"? The item will remain in your tenant catalog.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await inventory.removeItemFromStoreRoom(
                storeRoomId: room.storeRoomId,
                itemId: item.itemId,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Removed "${item.itemName}" from ${room.roomName}'
                        : (inventory.errorMessage ?? 'Failed to remove item')),
                    backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Remove Item', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final canUpdate = isAdmin || tenant.hasPermission(AppPermissions.storeroomUpdate);
    final canDelete = isAdmin || tenant.hasPermission(AppPermissions.storeroomDelete);

    final currentRoom = inventory.storeRooms.firstWhere(
      (r) => r.storeRoomId == widget.room.storeRoomId,
      orElse: () => widget.room,
    );

    final isAmbient = currentRoom.temperature == null;
    final tempStr = !isAmbient ? '${currentRoom.temperature!.toStringAsFixed(1)} °C' : 'Ambient';
    final roomItems = currentRoom.items;

    // Filter items based on search and filters
    var filteredItems = roomItems.where((sri) {
      final item = inventory.items.firstWhere(
        (i) => i.itemId == sri.itemId,
        orElse: () => ItemModel(
          itemId: sri.itemId,
          tenantId: currentRoom.tenantId,
          sku: '',
          itemName: sri.itemId,
          itemType: 'FINISHED GOOD',
          measurementUnit: 'UNIT',
          reorderThresholdQuantity: 0,
          totalAvailableStock: sri.quantity,
          isBelowReorderThreshold: false,
          reorderShortfallQuantity: 0,
          isActive: true,
        ),
      );

      if (_itemSearchQuery.isNotEmpty) {
        final q = _itemSearchQuery.toLowerCase();
        final divName = currentRoom.resolveFormattedDivisionName(sri);
        final matches = item.itemName.toLowerCase().contains(q) ||
            item.sku.toLowerCase().contains(q) ||
            item.specification.toLowerCase().contains(q) ||
            divName.toLowerCase().contains(q) ||
            sri.division.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_selectedDivisionFilter != null && _selectedDivisionFilter != 'All') {
        final divName = currentRoom.resolveFormattedDivisionName(sri);
        final selectedFilter = _selectedDivisionFilter!;
        if (divName != selectedFilter &&
            sri.division != selectedFilter &&
            sri.divisionId != currentRoom.getDivisionId(selectedFilter)) {
          return false;
        }
      }

      if (_selectedTypeFilter != null && _selectedTypeFilter != 'All') {
        if (!item.itemType.toLowerCase().contains(_selectedTypeFilter!.toLowerCase())) return false;
      }

      return true;
    }).toList();

    // Sort items
    filteredItems.sort((a, b) {
      final itemA = inventory.items.firstWhere((i) => i.itemId == a.itemId, orElse: () => ItemModel(itemId: a.itemId, tenantId: '', sku: '', itemName: a.itemId, itemType: '', measurementUnit: '', reorderThresholdQuantity: 0, totalAvailableStock: 0, isBelowReorderThreshold: false, reorderShortfallQuantity: 0, isActive: true));
      final itemB = inventory.items.firstWhere((i) => i.itemId == b.itemId, orElse: () => ItemModel(itemId: b.itemId, tenantId: '', sku: '', itemName: b.itemId, itemType: '', measurementUnit: '', reorderThresholdQuantity: 0, totalAvailableStock: 0, isBelowReorderThreshold: false, reorderShortfallQuantity: 0, isActive: true));
      return _sortAscending
          ? itemA.itemName.compareTo(itemB.itemName)
          : itemB.itemName.compareTo(itemA.itemName);
    });

    final totalUnits = roomItems.fold<double>(0, (sum, sri) => sum + sri.quantity).toInt();
    final divisionsList = ['All', ...currentRoom.divisions];
    final typeList = ['All', 'Finished Good', 'Raw Material', 'Packaging', 'WIP'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          currentRoom.roomName,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A), size: 20),
            tooltip: 'Refresh',
            onPressed: () {
              inventory.loadStoreRooms();
              inventory.loadItems();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        onRefresh: () async {
          await Future.wait([
            inventory.loadStoreRooms(),
            inventory.loadItems(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP HERO CARD
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, heroConstraints) {
                        final isNarrow = heroConstraints.maxWidth < 640;

                        final leftInfo = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Black square badge with room number
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    currentRoom.roomCode.isNotEmpty ? currentRoom.roomCode : '1',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentRoom.roomName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Zone: ${currentRoom.roomCode.isNotEmpty ? 'North Bay • ${currentRoom.roomCode}' : 'North Cold Bay'}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentRoom.description.isNotEmpty
                                  ? currentRoom.description
                                  : 'Climate-regulated ambient preservation storage unit configured for pallet and container storage.',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF475569),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Pill Badges
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.swap_vert, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '$tempStr (Target ±0.5° tolerance)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Bay ${currentRoom.roomCode.isNotEmpty ? currentRoom.roomCode : '1'} • Sector C • North Facility',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );

                        final metricCard = Container(
                          width: isNarrow ? double.infinity : 170,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'STORE ROOM ITEMS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: isNarrow ? Alignment.centerLeft : Alignment.centerRight,
                                child: Text(
                                  '${roomItems.length}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              leftInfo,
                              const SizedBox(height: 16),
                              metricCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: leftInfo),
                            const SizedBox(width: 24),
                            metricCard,
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. MAIN STORE ROOM ITEMS CARD
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF0F172A)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'STORE ROOM ITEMS',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${roomItems.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (canUpdate)
                                FilledButton.icon(
                                  onPressed: () => _showAddItemToRoomSheet(currentRoom),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Search and Filter Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: LayoutBuilder(
                            builder: (context, filterConstraints) {
                              final isNarrow = filterConstraints.maxWidth < 640;

                              final searchWidget = SizedBox(
                                height: 40,
                                child: TextField(
                                  onChanged: (val) => setState(() => _itemSearchQuery = val),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                                    suffixIcon: _itemSearchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                            onPressed: () => setState(() => _itemSearchQuery = ''),
                                          )
                                        : Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: const Text(
                                              '⌘K',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                            ),
                                          ),
                                    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
                                    hintText: 'Search items in ${currentRoom.roomName}...',
                                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              );

                              final filterButtons = [
                                // Division Filter Popup
                                PopupMenuButton<String>(
                                  initialValue: _selectedDivisionFilter ?? 'All',
                                  onSelected: (val) {
                                    if (val == '__manage__') {
                                      _showAddDivisionDialog(currentRoom);
                                    } else if (val == '__edit_first__') {
                                      _showEditDivisionDialog(currentRoom, 0);
                                    } else {
                                      setState(() => _selectedDivisionFilter = val == 'All' ? null : val);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    ...divisionsList.map((d) => PopupMenuItem<String>(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))),
                                    if (canUpdate) ...[
                                      const PopupMenuDivider(),
                                      const PopupMenuItem<String>(
                                        value: '__manage__',
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF0F172A)),
                                            SizedBox(width: 8),
                                            Text('Add Division', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                      if (currentRoom.divisions.isNotEmpty)
                                        const PopupMenuItem<String>(
                                          value: '__edit_first__',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                                              SizedBox(width: 8),
                                              Text('Edit Divisions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ],
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_offer_outlined, size: 15, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Division: ${_selectedDivisionFilter ?? 'All'}',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Type Filter Popup
                                PopupMenuButton<String>(
                                  initialValue: _selectedTypeFilter ?? 'All',
                                  onSelected: (val) => setState(() => _selectedTypeFilter = val == 'All' ? null : val),
                                  itemBuilder: (ctx) => typeList.map((t) => PopupMenuItem<String>(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.filter_alt_outlined, size: 15, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Type: ${_selectedTypeFilter ?? 'All'}',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // View Toggle (List / Grid)
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.reorder,
                                          size: 18,
                                          color: !_isGridView ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                        onPressed: () => setState(() => _isGridView = false),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        constraints: const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.grid_view,
                                          size: 18,
                                          color: _isGridView ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                        onPressed: () => setState(() => _isGridView = true),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              ];

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    searchWidget,
                                    const SizedBox(height: 10),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: filterButtons,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: searchWidget),
                                  const SizedBox(width: 10),
                                  ...filterButtons,
                                ],
                              );
                            },
                          ),
                        ),

                        // Table Divider
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Table Header
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              // Name
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _sortAscending = !_sortAscending),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Name',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(_sortAscending ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 14, color: const Color(0xFF475569)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // In-Stock Qty
                              const SizedBox(
                                width: 120,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('In-Stock Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Table Content
                        if (filteredItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _itemSearchQuery.isNotEmpty
                                        ? 'No items matching "$_itemSearchQuery"'
                                        : 'No items currently in this store room',
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredItems.length,
                            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, index) {
                              final sri = filteredItems[index];
                              final item = inventory.items.firstWhere(
                                (i) => i.itemId == sri.itemId,
                                orElse: () => ItemModel(
                                  itemId: sri.itemId,
                                  tenantId: currentRoom.tenantId,
                                  sku: '',
                                  itemName: sri.itemId,
                                  itemType: 'FINISHED GOOD',
                                  measurementUnit: 'UNIT',
                                  reorderThresholdQuantity: 0,
                                  totalAvailableStock: sri.quantity,
                                  isBelowReorderThreshold: false,
                                  reorderShortfallQuantity: 0,
                                  isActive: true,
                                ),
                              );

                              final isOrange = index % 2 == 0;

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (c) => StoreRoomItemDetailScreen(
                                        storeRoomId: currentRoom.storeRoomId,
                                        itemId: sri.itemId,
                                      ),
                                    ),
                                  ).then((_) => inventory.loadStoreRooms());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Icon + Name
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: isOrange ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.description_outlined,
                                                size: 18,
                                                color: isOrange ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.itemName,
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${currentRoom.resolveFormattedDivisionName(sri)} • Packets Per Carton: ${item.reorderThresholdQuantity > 0 ? item.reorderThresholdQuantity.toInt() : 14}',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // In-Stock Qty (Stepper)
                                      SizedBox(
                                        width: 120,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: canUpdate
                                                      ? () => _showEditItemQuantityDialog(item, sri, currentRoom)
                                                      : null,
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    child: Text('−', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  child: Text(
                                                    '${sri.quantity.toInt()}',
                                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: canUpdate
                                                      ? () => _showEditItemQuantityDialog(item, sri, currentRoom)
                                                      : null,
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    child: Text('+', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        // Table Footer
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Showing ${filteredItems.length} of ${roomItems.length} items in this store room  •  $totalUnits units total allocated',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              const Text(
                                'Page 1 of 1',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. BOTTOM ACTIONS
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (canDelete)
                        OutlinedButton.icon(
                          onPressed: () => _confirmDeleteRoom(currentRoom),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                          label: const Text('Delete Store Room', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (canUpdate)
                        FilledButton.icon(
                          onPressed: () => _showEditRoomBottomSheet(currentRoom),
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                          label: const Text('Edit Store Room Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 4. COPYRIGHT FOOTER
                  const Center(
                    child: Text(
                      'Developed by Bigburry Hypersystems',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddItemToRoomModal extends StatefulWidget {
  final StoreRoomModel room;
  final VoidCallback onItemAssigned;

  const _AddItemToRoomModal({
    required this.room,
    required this.onItemAssigned,
  });

  @override
  State<_AddItemToRoomModal> createState() => _AddItemToRoomModalState();
}

class _AddItemToRoomModalState extends State<_AddItemToRoomModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _customDivCtrl = TextEditingController();
  final TextEditingController _initialQtyCtrl = TextEditingController(text: '0');
  String _searchQuery = '';
  String _categoryFilter = 'ALL';
  ItemModel? _selectedItem;
  String? _selectedDivision;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    if (widget.room.divisions.isNotEmpty) {
      _selectedDivision = widget.room.divisions.first;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customDivCtrl.dispose();
    _initialQtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final allItems = inventory.items;

    final filtered = allItems.where((item) {
      if (_categoryFilter == 'UNASSIGNED') {
        if (inventory.storeRooms
            .any((r) => r.items.any((it) => it.itemId == item.itemId))) {
          return false;
        }
      } else if (_categoryFilter != 'ALL' && item.itemType != _categoryFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = item.itemName.toLowerCase().contains(q);
        final matchSku = item.sku.toLowerCase().contains(q);
        final matchSpec = item.specification.toLowerCase().contains(q);
        if (!matchName && !matchSku && !matchSpec) return false;
      }
      return true;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: _selectedItem == null
            ? _buildCatalogSearchView(context, inventory, filtered, allItems)
            : _buildDivisionSelectionView(context, inventory),
      ),
    );
  }

  Widget _buildCatalogSearchView(
    BuildContext context,
    InventoryProvider inventory,
    List<ItemModel> filtered,
    List<ItemModel> allItems,
  ) {
    final unassignedCount = allItems
        .where((i) => !inventory.storeRooms
            .any((r) => r.items.any((it) => it.itemId == i.itemId)))
        .length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Item to ${widget.room.roomName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text(
                          'Search catalog or ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateItemScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          child: const Text(
                            'register new item',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Search Field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search items by name, SKU...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
        ),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All (${allItems.length})'),
              const SizedBox(width: 6),
              _buildFilterChip('UNASSIGNED', 'Unassigned ($unassignedCount)'),
              const SizedBox(width: 6),
              _buildFilterChip('RAW_MATERIAL', 'Raw Materials'),
              const SizedBox(width: 6),
              _buildFilterChip('FINISHED_GOOD', 'Finished Goods'),
              const SizedBox(width: 6),
              _buildFilterChip('PACKAGING', 'Packing Materials'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Items List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text(
                        'No matching items found',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting your search query or filters',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateItemScreen(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.add, size: 15, color: Colors.black),
                        label: const Text(
                          'Register New Item',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final matchInThisRoom = widget.room.items.where((it) => it.itemId == item.itemId);
                    final isAlreadyInRoom = matchInThisRoom.isNotEmpty;
                    final isUnassigned = !inventory.storeRooms.any((r) => r.items.any((it) => it.itemId == item.itemId));
                    final resolvedImg = ApiConstants.resolveImageUrl(item.imageUrl);

                    String otherRoomName = '';
                    if (!isAlreadyInRoom && !isUnassigned) {
                      final matchRoom = inventory.storeRooms.where(
                        (r) => r.storeRoomId != widget.room.storeRoomId &&
                            r.items.any((it) => it.itemId == item.itemId),
                      );
                      otherRoomName = matchRoom.isNotEmpty ? matchRoom.first.roomName : 'Other Room';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isAlreadyInRoom
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: resolvedImg != null
                                ? Image.network(
                                    resolvedImg,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  )
                                : const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                        title: Text(
                          item.itemName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.sku,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Text(
                                  item.specification,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              if (isAlreadyInRoom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'In this room (${widget.room.resolveFormattedDivisionName(matchInThisRoom.first)})',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                )
                              else if (isUnassigned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Unassigned',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'In $otherRoomName',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              Text(
                                item.quantity > 1
                                    ? '${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit} stock'
                                    : '${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAlreadyInRoom ? const Color(0xFFF1F5F9) : Colors.black,
                            foregroundColor: isAlreadyInRoom ? const Color(0xFF475569) : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedItem = item;
                              if (matchInThisRoom.isNotEmpty) {
                                _selectedDivision = matchInThisRoom.first.division;
                                _initialQtyCtrl.text = matchInThisRoom.first.quantity.toString();
                              } else {
                                _selectedDivision = widget.room.divisions.isNotEmpty
                                    ? widget.room.divisions.first
                                    : 'Default Section';
                                _initialQtyCtrl.text = '0';
                              }
                            });
                          },
                          child: Text(
                            isAlreadyInRoom ? 'Change' : '+ Add',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDivisionSelectionView(
    BuildContext context,
    InventoryProvider inventory,
  ) {
    final item = _selectedItem!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Back
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedItem = null),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Select Division in Store Room',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Selected Item Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${item.sku} • ${item.specification} • Stock: ${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'ASSIGN TO DIVISION IN ${widget.room.roomName.toUpperCase()}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Builder(
            builder: (context) {
              final List<String> availableDivisions = [];
              if (widget.room.divisions.isNotEmpty) {
                availableDivisions.addAll(widget.room.divisions);
                if (!availableDivisions.contains('Default Section')) {
                  availableDivisions.add('Default Section');
                }
              } else {
                availableDivisions.addAll(['Default Section', 'Section 1', 'Section 2', 'Section 3']);
              }
              if (!availableDivisions.contains('+ Custom Division')) {
                availableDivisions.add('+ Custom Division');
              }

              final currentSelectedDiv = (_selectedDivision != null && availableDivisions.contains(_selectedDivision))
                  ? _selectedDivision!
                  : availableDivisions.first;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: currentSelectedDiv,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(
                        Icons.grid_view_outlined,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: availableDivisions.map((div) {
                      final isCustom = div == '+ Custom Division';
                      return DropdownMenuItem<String>(
                        value: div,
                        child: Text(
                          div,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCustom ? FontWeight.w800 : FontWeight.w600,
                            color: isCustom ? const Color(0xFF0F766E) : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDivision = val);
                      }
                    },
                  ),
                  if (currentSelectedDiv == '+ Custom Division') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customDivCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.black, width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          Text(
            'COUNT',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.quantity > 1
                ? 'Each item = ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.measurementUnit}'
                : 'Enter item count stored in this room',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _initialQtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF94A3B8)),
              suffixText: null,
              suffixStyle: null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          if (item.quantity > 1) ...[
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _initialQtyCtrl,
              builder: (context, value, _) {
                final count = double.tryParse(value.text.trim()) ?? 0.0;
                final total = count * item.quantity;
                final totalStr = total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);
                return Text(
                  '= $totalStr ${item.measurementUnit} total',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
                );
              },
            ),
          ],

          const SizedBox(height: 20),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _isAssigning
                  ? null
                  : () async {
                      setState(() => _isAssigning = true);
                      final isCustom = _selectedDivision == '+ Custom Division';
                      final targetDiv = isCustom
                          ? (_customDivCtrl.text.trim().isNotEmpty
                              ? _customDivCtrl.text.trim()
                              : 'Division - section 1')
                          : (_selectedDivision ??
                              (widget.room.divisions.isNotEmpty
                                  ? widget.room.divisions.first
                                  : 'Division - section 1'));
                      final qty = double.tryParse(_initialQtyCtrl.text.trim()) ?? 0.0;
                      final targetDivId = widget.room.getDivisionId(targetDiv);

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      final ok = await inventory.addItemToStoreRoom(
                        storeRoomId: widget.room.storeRoomId,
                        itemId: item.itemId,
                        division: targetDiv,
                        divisionId: targetDivId,
                        quantity: qty,
                      );

                      if (!mounted) return;
                      setState(() => _isAssigning = false);
                      navigator.pop();

                      widget.onItemAssigned();

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Saved "${item.itemName}" in ${widget.room.roomName} ($targetDiv, $qty ${item.measurementUnit})'
                              : (inventory.errorMessage ?? 'Failed to assign item')),
                          backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red.shade700,
                        ),
                      );
                    },
              child: _isAssigning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Save to ${widget.room.roomName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSel = _categoryFilter == key;
    return InkWell(
      onTap: () => setState(() => _categoryFilter = key),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? Colors.black : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
