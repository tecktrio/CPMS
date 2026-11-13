import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../services/purchase_order_export_service.dart';
import '../items/create_item_screen.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  final PurchaseOrderModel? existingPo;

  const CreatePurchaseOrderScreen({super.key, this.existingPo});

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _poNumberCtrl;
  late final TextEditingController _notesCtrl;

  late DateTime _poDate;
  DateTime? _expectedShippingDate;

  late String _status;

  CustomerModel? _selectedCustomer;
  final List<PurchaseOrderItemModel> _orderItems = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final po = widget.existingPo;

    _poNumberCtrl = TextEditingController(text: po?.poNumber ?? '');
    _notesCtrl = TextEditingController(text: po?.notes ?? '');
    _poDate = po?.poDate ?? DateTime.now();
    _expectedShippingDate = po?.expectedShippingDate;
    _status = po?.status ?? 'CONFIRMED';

    if (po != null) {
      _orderItems.addAll(po.items);
      _selectedCustomer = CustomerModel(
        customerId: po.customerId,
        tenantId: po.tenantId,
        customerName: po.customerName,
        address: po.customerAddress,
        contactDetails: po.customerContact,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final poProv = context.read<PurchaseOrderProvider>();
      final invProv = context.read<InventoryProvider>();

      await Future.wait([
        poProv.loadCustomers(),
        invProv.loadItems(),
      ]);

      if (po != null && mounted) {
        final match =
            poProv.customers.where((c) => c.customerId == po.customerId);
        if (match.isNotEmpty) {
          setState(() {
            _selectedCustomer = match.first;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _poNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _totalCartons =>
      _orderItems.fold(0, (sum, it) => sum + it.cartons);

  int get _totalPackets =>
      _orderItems.fold(0, (sum, it) => sum + it.totalPackets);

  Future<void> _selectPoDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _poDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _poDate = picked);
    }
  }

  Future<void> _selectShippingDate() async {
    final initial = _expectedShippingDate ?? _poDate.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _expectedShippingDate = picked);
    }
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Row(
            children: [
              Icon(Icons.business_outlined, size: 22, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'Add New Customer',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CUSTOMER / CONSIGNEE NAME *',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'e.g. KDM TRADING, MALTA',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Customer name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ADDRESS (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Delivery or warehouse address...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CONTACT DETAILS (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: contactCtrl,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Phone number or email...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: isCreating
                  ? null
                  : () async {
                      if (!dialogFormKey.currentState!.validate()) return;
                      setDlgState(() => isCreating = true);
                      final poProv = context.read<PurchaseOrderProvider>();
                      final created = await poProv.createCustomer(
                        customerName: nameCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        contactDetails: contactCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        if (created != null) {
                          setState(() => _selectedCustomer = created);
                        }
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Customer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerPickerModal() {
    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final customers = context.watch<PurchaseOrderProvider>().customers;
          final filtered = customers.where((c) {
            return c.customerName.toLowerCase().contains(query.toLowerCase()) ||
                c.address.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Customer / Consignee',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Add New',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddCustomerDialog();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search customer...',
                                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setModalState(() => query = val.trim());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_outlined, size: 36, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 8),
                                const Text(
                                  'No customers found',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add This Customer'),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showAddCustomerDialog();
                                  },
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, i) {
                              final c = filtered[i];
                              final isSelected = _selectedCustomer?.customerId == c.customerId;
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.black : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.business,
                                    size: 18,
                                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                                title: Text(
                                  c.customerName,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                subtitle: c.address.isNotEmpty
                                    ? Text(
                                        c.address,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.black)
                                    : null,
                                onTap: () {
                                  setState(() => _selectedCustomer = c);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddItemModal({PurchaseOrderItemModel? editItem, int? editIndex}) {
    final invProv = context.read<InventoryProvider>();
    final items = invProv.items;

    ItemModel? selectedCatalogItem;
    if (editItem != null) {
      final match = items.where((i) => i.itemId == editItem.itemId);
      if (match.isNotEmpty) selectedCatalogItem = match.first;
    }

    final packetCtrl = TextEditingController(
      text: editItem != null ? editItem.packetPerCarton.toString() : '10',
    );
    final cartonCtrl = TextEditingController(
      text: editItem != null ? editItem.cartons.toString() : '20',
    );
    final qtyPerPacketCtrl = TextEditingController(
      text: editItem != null
          ? (editItem.quantityPerPacket.truncateToDouble() ==
                  editItem.quantityPerPacket
              ? editItem.quantityPerPacket.toInt().toString()
              : editItem.quantityPerPacket.toString())
          : '1',
    );

    String itemSearchQuery = '';
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredItems = items.where((i) {
            final q = itemSearchQuery.toLowerCase();
            return q.isEmpty ||
                i.itemName.toLowerCase().contains(q) ||
                i.sku.toLowerCase().contains(q);
          }).toList();

          final int ppc = int.tryParse(packetCtrl.text.trim()) ?? 0;
          final int cartons = int.tryParse(cartonCtrl.text.trim()) ?? 0;
          final double qpp =
              double.tryParse(qtyPerPacketCtrl.text.trim()) ?? 1.0;
          final int previewTotalPackets = ppc * cartons;
          final double previewTotalQty = previewTotalPackets * qpp;
          final unitStr =
              selectedCatalogItem?.measurementUnit.toUpperCase() ?? '';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        editItem != null ? 'Edit Order Item' : 'Add Item to Purchase Order',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // 1. Item Selector with Search
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SELECT CATALOG ITEM *',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final inv = context.read<InventoryProvider>();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateItemScreen(),
                            ),
                          );
                          if (!mounted) return;
                          setModalState(() {
                            if (inv.items.isNotEmpty) {
                              selectedCatalogItem = inv.items.first;
                            }
                          });
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 13, color: Colors.black),
                            SizedBox(width: 3),
                            Text(
                              'Register New Item',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (selectedCatalogItem != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E),
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
                                  selectedCatalogItem!.itemName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${selectedCatalogItem!.sku} • ${selectedCatalogItem!.measurementUnit.toUpperCase()}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() => selectedCatalogItem = null);
                            },
                            child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Search bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                hintText: 'Search SKU or item title...',
                                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setModalState(() => itemSearchQuery = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Scrollable Dropdown List
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('No items match search',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B))),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final inv = context.read<InventoryProvider>();
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CreateItemScreen(),
                                          ),
                                        );
                                        if (!mounted) return;
                                        setModalState(() {
                                          if (inv.items.isNotEmpty) {
                                            selectedCatalogItem =
                                                inv.items.first;
                                          }
                                        });
                                      },
                                      icon: const Icon(Icons.add,
                                          size: 14, color: Colors.black),
                                      label: const Text(
                                        'Register New Item',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, idx) {
                                final it = filteredItems[idx];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    it.itemName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${it.sku} • ${it.itemType.replaceAll('_', ' ')}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  onTap: () {
                                    setModalState(() => selectedCatalogItem = it);
                                  },
                                );
                              },
                            ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 2. Quantity inputs: Packets Per Carton & Cartons
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PACKETS PER CARTON *',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: packetCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                hintText: '10',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CARTONS *',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: cartonCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                hintText: '20',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 3. Quantity per packet (Weight / Unit / Pack size)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'QUANTITY PER PACKET *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (unitStr.isNotEmpty)
                            Text(
                              'Base Unit: $unitStr',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: qtyPerPacketCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          hintText: '1.0',
                          suffixText: unitStr.isNotEmpty ? unitStr : null,
                          suffixStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Calculated Packets & Quantity Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL PACKETS:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$previewTotalPackets Packets',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'TOTAL QUANTITY:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${previewTotalQty.toStringAsFixed(previewTotalQty.truncateToDouble() == previewTotalQty ? 0 : 2)} $unitStr',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

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
                      onPressed: () {
                        if (selectedCatalogItem == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select an item from the catalog')),
                          );
                          return;
                        }

                        final p = int.tryParse(packetCtrl.text.trim()) ?? 0;
                        final c = int.tryParse(cartonCtrl.text.trim()) ?? 0;
                        final qpp = double.tryParse(qtyPerPacketCtrl.text.trim()) ?? 1.0;
                        if (p <= 0 || c <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid quantities for packets and cartons')),
                          );
                          return;
                        }

                        final newItem = PurchaseOrderItemModel(
                          itemId: selectedCatalogItem!.itemId,
                          itemName: selectedCatalogItem!.itemName,
                          sku: selectedCatalogItem!.sku,
                          packetPerCarton: p,
                          cartons: c,
                          quantityPerPacket: qpp > 0 ? qpp : 1.0,
                          unit: selectedCatalogItem!.measurementUnit,
                        );

                        setState(() {
                          if (editIndex != null && editIndex >= 0 && editIndex < _orderItems.length) {
                            _orderItems[editIndex] = newItem;
                          } else {
                            _orderItems.add(newItem);
                          }
                        });

                        Navigator.pop(ctx);
                      },
                      child: Text(
                        editItem != null ? 'Update Item' : 'Add Item to Order',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusOption(String code, String label) {
    final isSelected = _status.toUpperCase() == code;
    return InkWell(
      onTap: () => setState(() => _status = code),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit({bool asDraft = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a Customer / Consignee')),
      );
      return;
    }

    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to the purchase order')),
      );
      return;
    }

    final targetStatus = asDraft
        ? 'DRAFT'
        : (_status == 'DRAFT' && widget.existingPo == null
            ? 'CONFIRMED'
            : _status);

    setState(() => _isSaving = true);
    final poProv = context.read<PurchaseOrderProvider>();

    bool ok = false;
    if (widget.existingPo != null) {
      ok = await poProv.updatePurchaseOrder(
        poId: widget.existingPo!.poId,
        poNumber: _poNumberCtrl.text.trim().toUpperCase(),
        poDate: _poDate,
        expectedShippingDate: _expectedShippingDate,
        customerId: _selectedCustomer!.customerId,
        customerName: _selectedCustomer!.customerName,
        customerAddress: _selectedCustomer!.address,
        customerContact: _selectedCustomer!.contactDetails,
        items: _orderItems,
        status: targetStatus,
        notes: _notesCtrl.text.trim(),
      );
    } else {
      ok = await poProv.createPurchaseOrder(
        poNumber: _poNumberCtrl.text.trim().toUpperCase(),
        poDate: _poDate,
        expectedShippingDate: _expectedShippingDate,
        customerId: _selectedCustomer!.customerId,
        customerName: _selectedCustomer!.customerName,
        customerAddress: _selectedCustomer!.address,
        customerContact: _selectedCustomer!.contactDetails,
        items: _orderItems,
        status: targetStatus,
        notes: _notesCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      final successMsg = asDraft
          ? 'Purchase Order saved as draft!'
          : (widget.existingPo != null
              ? 'Purchase Order updated successfully!'
              : 'Purchase Order created successfully!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.black,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(poProv.errorMessage ?? 'Failed to save purchase order'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPo != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

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
        title: Text(
          isEdit ? 'Edit Purchase Order' : 'Create Purchase Order',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 28 : 16,
                20,
                isWide ? 28 : 16,
                100,
              ),
          children: [
            // 1. PO Number
            const Text(
              'PURCHASE ORDER NUMBER *',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _poNumberCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g. MALTA-PO-2026-01',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.tag, size: 20, color: Color(0xFF64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'PO Number is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // 2. Dates Row (PO Date & Expected Shipping Date)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PO DATE *',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _selectPoDate,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateFormat.format(_poDate),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXP. SHIPPING DATE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _selectShippingDate,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _expectedShippingDate != null
                                      ? dateFormat.format(_expectedShippingDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _expectedShippingDate != null ? Colors.black : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. Customer / Consignee Selector with Add Option
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CUSTOMER / CONSIGNEE *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                InkWell(
                  onTap: _showAddCustomerDialog,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '+ Add New Customer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            InkWell(
              onTap: _showCustomerPickerModal,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedCustomer != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCustomer!.customerName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                if (_selectedCustomer!.address.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _selectedCustomer!.address,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            )
                          : const Text(
                              'Select Consignee / Customer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    const Icon(Icons.swap_horiz,
                        size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 4. Items & Cartons Table Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDER ITEMS & CARTONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_orderItems.length} Products • $_totalCartons Total Cartons',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateItemScreen(),
                          ),
                        );
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          '+ Register Item',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showAddItemModal(),
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
              ],
            ),
            const SizedBox(height: 12),

            // Items Table Card
            if (_orderItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 40, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 10),
                    const Text(
                      'No items added yet',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap "+ Add Item" to select products, or register a new item.',
                      textAlign: TextAlign.center,
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
                        setState(() {});
                      },
                      icon: const Icon(Icons.add, size: 15, color: Colors.black),
                      label: const Text(
                        'Register New Item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Black Table Header
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              'SL.',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'ITEMS',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'QTY/PKT',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'PKT/CTN',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'CTNS',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 28),
                        ],
                      ),
                    ),

                    // Table rows
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _orderItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final item = _orderItems[idx];
                        return Container(
                          color: idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      item.sku.isNotEmpty
                                          ? '${item.sku} • ${item.totalPackets} pkts'
                                          : '${item.totalPackets} pkts',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  PurchaseOrderExportService.formatQtyPerPacketShort(item.quantityPerPacket, item.unit),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF334155)),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.packetPerCarton}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.cartons}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                              SizedBox(
                                width: 28,
                                child: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                                  padding: EdgeInsets.zero,
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showAddItemModal(editItem: item, editIndex: idx);
                                    } else if (action == 'delete') {
                                      setState(() => _orderItems.removeAt(idx));
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit Item'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Remove', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Table Footer showing TOTAL CARTONS
                    Container(
                      color: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Row(
                        children: [
                          const SizedBox(width: 26),
                          const Expanded(
                            flex: 4,
                            child: Text(
                              'TOTAL CARTONS',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: SizedBox.shrink(),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '$_totalPackets pkts',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '$_totalCartons',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 5. Order Status Selection
            const Text(
              'ORDER STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusOption('CONFIRMED', 'Confirmed'),
                _buildStatusOption('DRAFT', 'Draft'),
                _buildStatusOption('IN_PRODUCTION', 'In Production'),
                _buildStatusOption('SHIPPED', 'Shipped'),
                _buildStatusOption('DELIVERED', 'Delivered'),
                _buildStatusOption('CANCELLED', 'Cancelled'),
              ],
            ),

            const SizedBox(height: 20),

            // 6. Notes / Remarks
            const Text(
              'NOTES & PACKAGING INSTRUCTIONS (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. Temperature controlled -18°C frozen cargo shipping',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  bottomNavigationBar: SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            children: [
              // Secondary Outline: Save as Draft
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: _isSaving ? null : () => _submit(asDraft: true),
                    icon: const Icon(Icons.edit_note_outlined, size: 18),
                    label: const Text(
                      'Save Draft',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Primary Solid Black: Create or Save Changes
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: _isSaving ? null : () => _submit(asDraft: false),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEdit ? 'Save Changes' : 'Create Purchase Order',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
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

