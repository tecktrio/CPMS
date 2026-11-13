import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../items/item_detail_screen.dart';
import '../items/create_item_screen.dart';

class StoreRoomDetailScreen extends StatefulWidget {
  final StoreRoomModel room;

  const StoreRoomDetailScreen({super.key, required this.room});

  @override
  State<StoreRoomDetailScreen> createState() => _StoreRoomDetailScreenState();
}

class _StoreRoomDetailScreenState extends State<StoreRoomDetailScreen> {
  void _showAddDivisionDialog(StoreRoomModel room) {
    final divController = TextEditingController(
      text: 'Section ${room.divisions.length + 1}',
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
                hintText: 'e.g. Section 3 (Freezer Shelf)',
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
                totalCapacityUnits: room.totalCapacityUnits,
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

  void _showEditRoomBottomSheet(StoreRoomModel room) {
    final nameCtrl = TextEditingController(text: room.roomName);
    final tempCtrl = TextEditingController(
      text: room.temperature != null ? room.temperature.toString() : '',
    );
    final capacityCtrl = TextEditingController(
      text: room.totalCapacityUnits.toStringAsFixed(0),
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
                                hintText: 'e.g. Trends Cold Room',
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
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TEMPERATURE (°C)',
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
                                          hintText: '-18.0',
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
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CAPACITY (UNITS) *',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF64748B),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: capacityCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                        decoration: InputDecoration(
                                          hintText: '100',
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
                                        validator: (v) {
                                          if (v == null || double.tryParse(v.trim()) == null) {
                                            return 'Enter valid capacity';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                                          text: 'Section ${divisionCtrls.length + 1}',
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
                                          hintText: 'Section ${i + 1}',
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
                            temperature: temp,
                            totalCapacityUnits: double.parse(capacityCtrl.text.trim()),
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
                'Stored in ${room.roomName} (${sri.division})',
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
                      hintText: 'Enter new division name',
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
                      : (selected == '+ Custom Division' ? 'Default Section' : selected);
                  final ok = await inventory.updateStoreRoomItemDivision(
                    storeRoomId: room.storeRoomId,
                    itemId: item.itemId,
                    division: finalDiv,
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

    // Get live store room from provider state
    final currentRoom = inventory.storeRooms.firstWhere(
      (r) => r.storeRoomId == widget.room.storeRoomId,
      orElse: () => widget.room,
    );

    final util = currentRoom.capacityUtilizationPercentage;
    final isAmbient = currentRoom.temperature == null;
    final tempStr =
        !isAmbient ? '${currentRoom.temperature!.toStringAsFixed(1)} °C' : 'Ambient';

    // Items stored in this store room
    final roomItems = currentRoom.items;

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
        centerTitle: true,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FACILITY ZONE 01',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Store Room Details',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black, size: 22),
            tooltip: 'Refresh',
            onPressed: () {
              inventory.loadStoreRooms();
              inventory.loadItems();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: () async {
          await Future.wait([
            inventory.loadStoreRooms(),
            inventory.loadItems(),
          ]);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 28 : 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Summary Metric (Store Room Items Only - Uber Style)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STORE ROOM ITEMS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF71717A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${roomItems.length}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(2),
                                border:
                                    Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.black87,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 1. Store Room Hero Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Black Badge with roomCode / ID
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          currentRoom.roomCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    currentRoom.roomName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '#${currentRoom.roomCode}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zone: ${currentRoom.roomName.toLowerCase().contains('cold') ? 'North Cold Bay' : 'Central Logistics Zone'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Active Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: currentRoom.isActive
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: currentRoom.isActive
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentRoom.isActive
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currentRoom.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: currentRoom.isActive
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Description paragraph
                  Text(
                    (currentRoom.temperature != null && currentRoom.temperature! <= 0)
                        ? 'Primary sub-zero cold logistics and preservation storage unit configured for pallet storage.'
                        : 'Climate-regulated ambient preservation storage unit configured for pallet and container storage.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Side-by-Side Metric Boxes
                  Row(
                    children: [
                      // Set Temperature Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text(
                                    'SET TEMPERATURE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Icon(
                                    Icons.swap_vert,
                                    size: 16,
                                    color: Color(0xFF0284C7),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tempStr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Target ±0.5° tolerance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Location Zone Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text(
                                    'LOCATION ZONE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_on,
                                    size: 15,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Bay ${currentRoom.roomCode} • Sector C',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'North Facility',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Capacity & Volume Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.storage_outlined,
                              size: 15,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'CAPACITY & VOLUME',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${util.toStringAsFixed(1)}% FULL',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Allocation Numbers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currentRoom.currentOccupancyUnits.toStringAsFixed(1)} Units Allocated',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Max ${currentRoom.totalCapacityUnits.toStringAsFixed(1)} Units',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Custom Progress Bar with Indicator Dot
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 7,
                          width: double.infinity,
                          color: const Color(0xFFE2E8F0),
                        ),
                        FractionallySizedBox(
                          widthFactor: (util / 100).clamp(0.02, 1.0),
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Status Callout
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF16A34A),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            util == 0.0
                                ? 'Complete volume available. Ready for immediate pallet intake.'
                                : (util < 80.0
                                    ? 'Healthy operational volume with immediate intake bandwidth.'
                                    : 'Nearing storage threshold. Plan batch reallocation.'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Configured Divisions Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.grid_view_outlined,
                              size: 15,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'CONFIGURED DIVISIONS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${currentRoom.divisions.length} Divisions',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Division Items List
                  if (currentRoom.divisions.isNotEmpty)
                    ...List.generate(currentRoom.divisions.length, (idx) {
                      final divName = currentRoom.divisions[idx];
                      final itemsInDiv = roomItems.where((i) => i.division == divName).length;
                      final perDivCapacity = (currentRoom.totalCapacityUnits /
                              currentRoom.divisions.length)
                          .toStringAsFixed(1);
                      final tag = 'S${idx + 1}';
                      final subLabel = idx == 0 ? 'Upper Deck' : 'Floor Staging';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    divName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$subLabel • $perDivCapacity Units Allocated',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$itemsInDiv Items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 4),

                  // Add Division Button (Dashed border box)
                  if (canUpdate)
                    InkWell(
                      onTap: () => _showAddDivisionDialog(currentRoom),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.black),
                            SizedBox(width: 6),
                            Text(
                              'Add Division',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

              const SizedBox(height: 14),

            // 4. Store Room Items Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 15,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'STORE ROOM ITEMS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${roomItems.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (canUpdate)
                        InkWell(
                          onTap: () => _showAddItemToRoomSheet(currentRoom),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add Item',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Search within room items if there are any & Register Item link
                  if (roomItems.isNotEmpty) ...[
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Search items in ${currentRoom.roomName}...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => setState(() => _itemSearchQuery = val.trim()),
                      ),
                    ),
                    if (canUpdate) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
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
                            '+ Register New Item',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],

                  // Items List or Empty State
                  if (roomItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Text(
                            'No items assigned to this store room',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Search your catalog and assign items to this room, or register a new item.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          if (canUpdate) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.search, size: 16),
                                  label: const Text('Search & Add Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                  onPressed: () => _showAddItemToRoomSheet(currentRoom),
                                ),
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
                          ],
                        ],
                      ),
                    )
                  else ...[
                    ...roomItems.where((sri) {
                      if (_itemSearchQuery.isEmpty) return true;
                      final q = _itemSearchQuery.toLowerCase();
                      final item = inventory.items.firstWhere(
                        (i) => i.itemId == sri.itemId,
                        orElse: () => ItemModel(
                          itemId: sri.itemId,
                          tenantId: currentRoom.tenantId,
                          sku: '',
                          itemName: sri.itemId,
                          itemType: '',
                          measurementUnit: 'UNIT',
                          reorderThresholdQuantity: 0,
                          totalAvailableStock: sri.quantity,
                          isBelowReorderThreshold: false,
                          reorderShortfallQuantity: 0,
                          isActive: true,
                        ),
                      );
                      return item.itemName.toLowerCase().contains(q) ||
                          item.sku.toLowerCase().contains(q) ||
                          item.specification.toLowerCase().contains(q) ||
                          sri.division.toLowerCase().contains(q);
                    }).map((sri) {
                      final item = inventory.items.firstWhere(
                        (i) => i.itemId == sri.itemId,
                        orElse: () => ItemModel(
                          itemId: sri.itemId,
                          tenantId: currentRoom.tenantId,
                          sku: '',
                          itemName: sri.itemId,
                          itemType: '',
                          measurementUnit: 'UNIT',
                          reorderThresholdQuantity: 0,
                          totalAvailableStock: sri.quantity,
                          isBelowReorderThreshold: false,
                          reorderShortfallQuantity: 0,
                          isActive: true,
                        ),
                      );
                      final resolvedImg = ApiConstants.resolveImageUrl(item.imageUrl);
                      final divText = sri.division.isNotEmpty
                          ? sri.division
                          : 'General Section';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Item Picture + Title + SKU & Division badges + Popup Menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: resolvedImg != null
                                        ? Image.network(
                                            resolvedImg,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.inventory_2_outlined,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Details: Title, SKU, Division, Description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (item.sku.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                              child: Text(
                                                item.sku,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF334155),
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(2),
                                              border: Border.all(color: const Color(0xFFBBF7D0)),
                                            ),
                                            child: Text(
                                              item.specification,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF15803D),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.meeting_room_outlined, size: 11, color: Color(0xFF4338CA)),
                                                const SizedBox(width: 3),
                                                Text(
                                                  divText,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF4338CA),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Actions Menu
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF71717A)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onSelected: (val) {
                                    if (val == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ItemDetailScreen(item: item),
                                        ),
                                      );
                                    } else if (val == 'move') {
                                      _showMoveDivisionDialog(item, currentRoom);
                                    } else if (val == 'remove') {
                                      _confirmRemoveItemFromRoom(item, currentRoom);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('View Item Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    if (canUpdate && currentRoom.divisions.length > 1)
                                      const PopupMenuItem(
                                        value: 'move',
                                        child: Row(
                                          children: [
                                            Icon(Icons.swap_horiz, size: 18),
                                            SizedBox(width: 8),
                                            Text('Change Division', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    if (canUpdate)
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                            SizedBox(width: 8),
                                            Text('Remove from Room', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 10),

                            // Bottom Row: Quantity Stepper & Label below picture, title & description
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left: unit count + total raw qty
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'COUNT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF71717A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (item.quantity > 1) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '= ${(sri.quantity * item.quantity).toStringAsFixed((sri.quantity * item.quantity).truncateToDouble() == (sri.quantity * item.quantity) ? 0 : 2)} ${item.measurementUnit} total',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (canUpdate)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: sri.quantity > 0
                                            ? () {
                                                final newQty = (sri.quantity - 1.0).clamp(0.0, 99999999.0);
                                                inventory.updateStoreRoomItemQuantity(
                                                  storeRoomId: currentRoom.storeRoomId,
                                                  itemId: item.itemId,
                                                  quantity: newQty,
                                                );
                                              }
                                            : null,
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.remove, size: 16, color: Colors.black),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _showEditItemQuantityDialog(
                                          item,
                                          sri,
                                          currentRoom,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            sri.quantity.toStringAsFixed(sri.quantity.truncateToDouble() == sri.quantity ? 0 : 1),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          final newQty = sri.quantity + 1.0;
                                          inventory.updateStoreRoomItemQuantity(
                                            storeRoomId: currentRoom.storeRoomId,
                                            itemId: item.itemId,
                                            quantity: newQty,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.add, size: 16, color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sri.quantity.toStringAsFixed(sri.quantity.truncateToDouble() == sri.quantity ? 0 : 1),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Action Buttons
            if (canUpdate) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit Store Room Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => _showEditRoomBottomSheet(currentRoom),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (canDelete) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    backgroundColor: Colors.white,
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFEE2E2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Delete Store Room',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  onPressed: () => _confirmDeleteRoom(currentRoom),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Footer
            const Center(
              child: Text(
                'DEVELOPED BY BIGBURRY HYPERSYSTEMS LLP',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
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
              _buildFilterChip('PACKAGING', 'Packaging'),
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
                                    'In this room (${matchInThisRoom.first.division})',
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
                        item.quantity > 1
                            ? 'SKU: ${item.sku} • ${item.totalAvailableStock.toStringAsFixed(1)} ${item.measurementUnit} total stock'
                            : 'SKU: ${item.sku} • Stock: ${item.totalAvailableStock} ${item.measurementUnit}',
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
                        hintText: 'Enter new division name (e.g. Section 1)',
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
              hintText: '0',
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
                              : 'Default Section')
                          : (_selectedDivision ??
                              (widget.room.divisions.isNotEmpty
                                  ? widget.room.divisions.first
                                  : 'Default Section'));
                      final qty = double.tryParse(_initialQtyCtrl.text.trim()) ?? 0.0;

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      final ok = await inventory.addItemToStoreRoom(
                        storeRoomId: widget.room.storeRoomId,
                        itemId: item.itemId,
                        division: targetDiv,
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
