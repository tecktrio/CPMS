import '../../widgets/cpms_page_route.dart';
import 'package:flutter/material.dart';
import '../../widgets/cpms_form_page.dart';
import 'package:provider/provider.dart';
import '../../providers/purchase_order_provider.dart';

class ManageCustomersModal extends StatefulWidget {
  final String? selectedCustomerId;
  final ValueChanged<CustomerModel?>? onCustomerSelected;

  const ManageCustomersModal({
    super.key,
    this.selectedCustomerId,
    this.onCustomerSelected,
  });

  static Future<void> show(
    BuildContext context, {
    String? selectedCustomerId,
    ValueChanged<CustomerModel?>? onCustomerSelected,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageCustomersModal(
          selectedCustomerId: selectedCustomerId,
          onCustomerSelected: onCustomerSelected,
        ),
      ),
    );
  }

  @override
  State<ManageCustomersModal> createState() => _ManageCustomersModalState();
}

class _ManageCustomersModalState extends State<ManageCustomersModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseOrderProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateOrEditDialog({CustomerModel? customer}) async {
    final isEditing = customer != null;
    final nameCtrl = TextEditingController(text: customer?.customerName ?? '');
    final addrCtrl = TextEditingController(text: customer?.address ?? '');
    final contactCtrl =
        TextEditingController(text: customer?.contactDetails ?? '');
    final formKey = GlobalKey<FormState>();

    await openCpmsPage(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => CpmsFormPage(
            title: Text(
              isEditing ? 'Edit Customer' : 'Add New Customer',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            content: Form(
              key: formKey,
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
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. Global Foods Malta',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Customer name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'DELIVERY ADDRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: addrCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Port / Warehouse Address',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CONTACT DETAILS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: contactCtrl,
                      decoration: InputDecoration(
                        hintText: 'Phone or Email',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDlgState(() => saving = true);
                        final poProv = context.read<PurchaseOrderProvider>();
                        CustomerModel? result;
                        if (isEditing) {
                          result = await poProv.updateCustomer(
                            customerId: customer.customerId,
                            customerName: nameCtrl.text.trim(),
                            address: addrCtrl.text.trim(),
                            contactDetails: contactCtrl.text.trim(),
                          );
                        } else {
                          result = await poProv.createCustomer(
                            customerName: nameCtrl.text.trim(),
                            address: addrCtrl.text.trim(),
                            contactDetails: contactCtrl.text.trim(),
                          );
                        }

                        if (!mounted) return;
                        if (result != null) {
                          if (!isEditing ||
                              widget.selectedCustomerId == result.customerId) {
                            widget.onCustomerSelected?.call(result);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing
                                  ? 'Updated customer "${result.customerName}"'
                                  : 'Added customer "${result.customerName}"'),
                              backgroundColor: Colors.black,
                            ),
                          );
                        } else {
                          setDlgState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(poProv.errorMessage ??
                                  'Failed to save customer'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Update Customer' : 'Save Customer',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(CustomerModel customer) async {
    final confirm = await openCpmsPage<bool>(
      context: context,
      builder: (ctx) => CpmsFormPage(
        title: const Text(
          'Delete Customer?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete "${customer.customerName}"? Existing purchase orders will retain their saved snapshot.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isBusy = true);
    final poProv = context.read<PurchaseOrderProvider>();
    final ok = await poProv.deleteCustomer(customer.customerId);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (ok) {
      if (widget.selectedCustomerId == customer.customerId) {
        widget.onCustomerSelected?.call(null);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${customer.customerName}"'),
          backgroundColor: Colors.black,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(poProv.errorMessage ?? 'Failed to delete customer'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<PurchaseOrderProvider>().customers;
    final filtered = customers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.customerName.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q) ||
          c.contactDetails.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Manage Customers',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : () => _showCreateOrEditDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              const SizedBox(height: 14),
              // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search customers by name, address, or contact...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Customers list
          Expanded(
            child: _isBusy
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline,
                                size: 42, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 10),
                            const Text(
                              'No customers found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showCreateOrEditDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Customer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final isSelected =
                              widget.selectedCustomerId == c.customerId;
                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF0FDF4)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              onTap: () {
                                widget.onCustomerSelected?.call(c);
                                Navigator.pop(context);
                              },
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? const Color(0xFF16A34A)
                                    : Colors.black,
                                radius: 18,
                                child: Text(
                                  c.customerName.isNotEmpty
                                      ? c.customerName[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              title: Text(
                                c.customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              subtitle: (c.address.isNotEmpty ||
                                      c.contactDetails.isNotEmpty)
                                  ? Text(
                                      [
                                        if (c.address.isNotEmpty) c.address,
                                        if (c.contactDetails.isNotEmpty)
                                          c.contactDetails,
                                      ].join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 19, color: Color(0xFF0F766E)),
                                    tooltip: 'Edit Customer',
                                    onPressed: () =>
                                        _showCreateOrEditDialog(customer: c),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 19, color: Color(0xFFDC2626)),
                                    tooltip: 'Delete Customer',
                                    onPressed: () => _confirmDelete(c),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

