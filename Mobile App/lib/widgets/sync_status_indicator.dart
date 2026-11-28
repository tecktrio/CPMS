import 'package:flutter/material.dart';

import '../core/sync/sync_manager.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final syncManager = SyncManager();
    return StreamBuilder<int>(
      stream: syncManager.queueCountStream,
      initialData: syncManager.pendingCount,
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? 0) > 0;
        return Semantics(
          label: pending ? 'Local changes pending sync' : 'No pending local changes',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: pending ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 9),
          ),
        );
      },
    );
  }
}
