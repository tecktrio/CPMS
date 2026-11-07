import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class InwardBatchScreen extends StatefulWidget {
  final String? initialItemId;

  const InwardBatchScreen({super.key, this.initialItemId});

  @override
  State<InwardBatchScreen> createState() => _InwardBatchScreenState();
}

class _InwardBatchScreenState extends State<InwardBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationIdController = TextEditingController(text: 'LOC-A1');

  String? _selectedItemId;
  String? _selectedStoreRoomId;
  DateTime _mfgDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 90));
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.initialItemId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventory = context.read<InventoryProvider>();
      await Future.wait([
        inventory.loadItems(),
        inventory.loadStoreRooms(),
      ]);
      if (mounted) {
        setState(() {
          if (_selectedItemId == null && inventory.items.isNotEmpty) {
            _selectedItemId = inventory.items.first.itemId;
          }
          if (_selectedStoreRoomId == null && inventory.storeRooms.isNotEmpty) {
            _selectedStoreRoomId = inventory.storeRooms.first.storeRoomId;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _locationIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemId == null || _selectedStoreRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select item SKU and target cold room.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final inventory = context.read<InventoryProvider>();
    final success = await inventory.inwardBatchReceipt(
      itemId: _selectedItemId!,
      batchNumber: _batchNumberController.text.trim().toUpperCase(),
      storeRoomId: _selectedStoreRoomId!,
      storageLocationId: _locationIdController.text.trim(),
      quantity: double.tryParse(_quantityController.text) ?? 0,
      manufacturingDate: _mfgDate,
      expiryDate: _expiryDate,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch "${_batchNumberController.text.toUpperCase()}" stocked successfully!'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to inward batch.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inward Stock Receipt'),
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
                    Icon(Icons.qr_code_scanner_outlined, color: Color(0xFF8B5CF6), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operational Module: Stock Batches & FEFO Picking\nPermission: permission.batch.create',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Item SKU Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedItemId,
                decoration: const InputDecoration(
                  labelText: 'Select Item SKU *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: inventory.items
                    .map((item) => DropdownMenuItem(
                          value: item.itemId,
                          child: Text('${item.sku} — ${item.itemName}'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedItemId = val),
                validator: (val) => val == null ? 'Item SKU is required' : null,
              ),
              const SizedBox(height: 16),

              // Batch Number
              TextFormField(
                controller: _batchNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Lot / Batch Number *',
                  hintText: 'e.g., BATCH-2026-X1',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Batch number required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quantity & Target Room
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity (Kg) *',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                      validator: (val) {
                        if (val == null || double.tryParse(val) == null) {
                          return 'Valid qty required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStoreRoomId,
                      decoration: const InputDecoration(labelText: 'Cold Room *'),
                      items: inventory.storeRooms
                          .map((r) => DropdownMenuItem(
                                value: r.storeRoomId,
                                child: Text(r.roomName),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedStoreRoomId = val),
                      validator: (val) => val == null ? 'Select room' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dates (Mfg & Expiry)
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mfg Date', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      subtitle: Text(dateFormat.format(_mfgDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _mfgDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _mfgDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Expiry Date', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      subtitle: Text(dateFormat.format(_expiryDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      trailing: const Icon(Icons.event_busy, size: 18, color: Colors.red),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate,
                          firstDate: _mfgDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _expiryDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rack Location ID
              TextFormField(
                controller: _locationIdController,
                decoration: const InputDecoration(
                  labelText: 'Rack / Bay Location *',
                  hintText: 'e.g., LOC-BAY-03',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Location required' : null,
              ),
              const SizedBox(height: 30),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.input_outlined),
                  label: Text(_isSubmitting ? 'Inwarding Batch...' : 'Inward Stock Receipt'),
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
