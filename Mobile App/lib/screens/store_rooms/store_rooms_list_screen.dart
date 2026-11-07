import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cold Store Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => inventory.loadStoreRooms(),
          ),
          const UserProfileAvatar(),
          const SizedBox(width: 4),
        ],
      ),
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
                          Icons.ac_unit,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Cold Rooms Registered',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Register cold storage rooms to manage temperature and capacity.',
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
                        margin: const EdgeInsets.only(bottom: 10),
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
                                        const Icon(
                                          Icons.thermostat,
                                          size: 14,
                                          color: Color(0xFF0284C7),
                                        ),
                                        Text(
                                          '${room.temperature.toStringAsFixed(1)} °C',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Occupancy progress bar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Occupancy: ${room.currentOccupancyUnits.toStringAsFixed(1)} / ${room.totalCapacityUnits.toStringAsFixed(1)} Units',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${util.toStringAsFixed(1)}%',
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
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${room.activeBatchesCount} active batch(es) stored',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
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
    );
  }
}
