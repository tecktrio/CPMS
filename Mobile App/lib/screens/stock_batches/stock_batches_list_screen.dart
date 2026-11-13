import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class StockBatchesListScreen extends StatefulWidget {
  const StockBatchesListScreen({super.key});

  @override
  State<StockBatchesListScreen> createState() => _StockBatchesListScreenState();
}

class _StockBatchesListScreenState extends State<StockBatchesListScreen> {
  String _searchQuery = '';
  bool _filterExpiringOnly = false;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inv = context.read<InventoryProvider>();
      inv.loadStockBatches();
      inv.loadExpiringSoon(7);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    final batches = inventory.stockBatches.where((b) {
      final catalogItem = inventory.items.where((item) => item.itemId == b.itemId);
      final specification = catalogItem.isNotEmpty ? catalogItem.first.specification : '';
      final matchesSearch = b.batchNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (b.itemName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (b.itemSku?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          specification.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesExpiry = !_filterExpiringOnly || (b.daysUntilExpiry <= 7 && b.daysUntilExpiry >= 0);
      return matchesSearch && matchesExpiry;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Batches & FEFO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              inventory.loadStockBatches();
              inventory.loadExpiringSoon(7);
            },
          ),
          const UserProfileAvatar(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search batch number, SKU or item...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    fillColor: Color(0xFFF8FAFC),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      selected: !_filterExpiringOnly,
                      label: Text('All Batches (${inventory.stockBatches.length})'),
                      onSelected: (_) => setState(() => _filterExpiringOnly = false),
                      selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: !_filterExpiringOnly ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                        fontWeight: !_filterExpiringOnly ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _filterExpiringOnly,
                      label: Text('⚠️ Near Expiry ≤ 7 Days (${inventory.expiringSoonBatches.length})'),
                      onSelected: (_) => setState(() => _filterExpiringOnly = true),
                      selectedColor: const Color(0xFFFEF2F2),
                      side: _filterExpiringOnly
                          ? const BorderSide(color: Color(0xFFFECACA))
                          : null,
                      labelStyle: TextStyle(
                        color: _filterExpiringOnly ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        fontWeight: _filterExpiringOnly ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: Colors.black,
              onRefresh: () async {
                await Future.wait([
                  inventory.loadStockBatches(),
                  inventory.loadExpiringSoon(7),
                  inventory.loadItems(),
                ]);
              },
              child: inventory.isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : batches.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.45,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No batches match your query'
                                          : 'No inventory batches on rack',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: batches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final batch = batches[index];
                            final catalogItems = inventory.items
                                .where((item) => item.itemId == batch.itemId);
                            final specification = catalogItems.isNotEmpty
                                ? catalogItems.first.specification
                                : '';
                            final isExpired = batch.daysUntilExpiry < 0;
                            final isNearExpiry = batch.daysUntilExpiry >= 0 && batch.daysUntilExpiry <= 7;

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(
                                  color: isExpired
                                      ? const Color(0xFFFCA5A5)
                                      : isNearExpiry
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: (isExpired
                                                    ? Colors.red
                                                    : isNearExpiry
                                                        ? Colors.orange
                                                        : const Color(0xFF0F766E))
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Icons.qr_code_2,
                                            color: isExpired
                                                ? Colors.red
                                                : isNearExpiry
                                                    ? Colors.orange
                                                    : const Color(0xFF0F766E),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Batch: ${batch.batchNumber}',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${batch.itemSku ?? ''} • ${batch.itemName ?? 'Item ID: ${batch.itemId}'}${specification.isNotEmpty ? ' • $specification' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isExpired
                                                ? const Color(0xFFFEF2F2)
                                                : isNearExpiry
                                                    ? const Color(0xFFFFFBEB)
                                                    : const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isExpired
                                                  ? const Color(0xFFFECACA)
                                                  : isNearExpiry
                                                      ? const Color(0xFFFDE68A)
                                                      : const Color(0xFFBBF7D0),
                                            ),
                                          ),
                                          child: Text(
                                            isExpired
                                                ? 'EXPIRED'
                                                : isNearExpiry
                                                    ? '${batch.daysUntilExpiry}d left'
                                                    : '${batch.daysUntilExpiry}d safe',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isExpired
                                                  ? Colors.red
                                                  : isNearExpiry
                                                      ? Colors.orange.shade800
                                                      : Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 12),

                                    // Batch Info Details
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildDetail(
                                          'Available',
                                          '${batch.availableQuantity} Units',
                                          isBold: true,
                                        ),
                                        _buildDetail(
                                          'Room / Bin',
                                          '${batch.storeRoomCode ?? 'Room'} / ${batch.storageLocationId}',
                                        ),
                                        _buildDetail(
                                          'Expiry (FEFO)',
                                          batch.expiryDate != null
                                              ? _dateFormat.format(batch.expiryDate!)
                                              : 'N/A',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(String title, String val, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
