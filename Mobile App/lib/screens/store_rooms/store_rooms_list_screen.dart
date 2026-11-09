import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import 'create_store_room_screen.dart';
import 'store_room_detail_screen.dart';

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
      context.read<InventoryProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;
    final canCreate =
        isAdmin || tenant.hasPermission(AppPermissions.storeroomCreate);

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
        title: const Text(
          'Store Rooms',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
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
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: canCreate
          ? Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Create Store Room',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateStoreRoomScreen(),
                    ),
                  );
                  if (context.mounted) {
                    context.read<InventoryProvider>().loadStoreRooms();
                  }
                },
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await inventory.loadStoreRooms();
          await inventory.loadItems();
        },
        child: inventory.isLoading && inventory.storeRooms.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : inventory.storeRooms.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Store Rooms Registered',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Register store rooms to manage physical storage and divisions.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                    itemCount: inventory.storeRooms.length + 1,
                    itemBuilder: (context, index) {
                      // Footer after last item
                      if (index == inventory.storeRooms.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Developed by Bigburry Hypersystems LLP',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }

                      final room = inventory.storeRooms[index];
                      final util = room.capacityUtilizationPercentage;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoreRoomDetailScreen(room: room),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Code Badge, Name, Chevron
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          room.roomCode,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          room.roomName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                            letterSpacing: -0.3,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Row 2: Capacity & Utilization Pill
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Capacity:  ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${room.totalCapacityUnits.toStringAsFixed(1)} Units',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(6),
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

                                  const SizedBox(height: 12),
                                  const Divider(
                                      height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 12),

                                  // Row 3: Divisions Count
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.grid_view_outlined,
                                        size: 15,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${room.divisions.length} Divisions',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
