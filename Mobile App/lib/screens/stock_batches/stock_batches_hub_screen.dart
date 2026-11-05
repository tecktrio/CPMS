import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/permissions.dart';
import '../../providers/tenant_provider.dart';
import 'stock_batches_list_screen.dart';
import 'inward_batch_screen.dart';
import 'fefo_picking_screen.dart';
import '../../widgets/user_profile_avatar.dart';

class StockBatchesHubScreen extends StatelessWidget {
  const StockBatchesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final isAdmin = tenant.isTenantAdmin;

    final canRead = isAdmin || tenant.hasPermission(AppPermissions.batchRead);
    final canCreate = isAdmin || tenant.hasPermission(AppPermissions.batchCreate);
    final canDeduct = isAdmin || tenant.hasPermission(AppPermissions.batchDeduct);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Batches & FEFO Hub'),
        actions: const [
          UserProfileAvatar(),
          SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_scanner_outlined, color: Color(0xFF8B5CF6), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Operations & Picking',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF8B5CF6)),
                      ),
                      Text(
                        'Choose an operation page based on your allocated permissions.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (canCreate)
            _buildPermissionPageCard(
              context: context,
              title: 'Inward Stock Receipt',
              description: 'Receive new inventory lots, record expiry & mfg dates, and assign racks.',
              permissionId: AppPermissions.batchCreate,
              icon: Icons.input_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InwardBatchScreen()),
                );
              },
            ),

          if (canDeduct)
            _buildPermissionPageCard(
              context: context,
              title: 'Option B FEFO Picking Engine',
              description: 'Suggest earliest-expiry batches, review recommendations, and dispatch stock.',
              permissionId: AppPermissions.batchDeduct,
              icon: Icons.auto_awesome_motion,
              color: const Color(0xFF0F766E),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FefoPickingScreen()),
                );
              },
            ),

          if (canRead)
            _buildPermissionPageCard(
              context: context,
              title: 'Browse Batches & Expiry Timeline',
              description: 'View active batches, rack locations, and near-expiry warning alerts.',
              permissionId: AppPermissions.batchRead,
              icon: Icons.format_list_bulleted,
              color: const Color(0xFF0284C7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockBatchesListScreen()),
                );
              },
            ),

          if (!canCreate && !canDeduct && !canRead)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No accessible operations in this module. Contact your Tenant Admin.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionPageCard({
    required BuildContext context,
    required String title,
    required String description,
    required String permissionId,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Requires: $permissionId',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

