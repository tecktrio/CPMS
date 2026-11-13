import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

enum SyncOperationType {
  createItem,
  updateItem,
  updateItemStock,
  deleteItem,
  createStoreRoom,
  updateStoreRoom,
  deleteStoreRoom,
  addStoreRoomItem,
  updateStoreRoomItemQuantity,
  removeStoreRoomItem,
}

enum SyncStatus {
  idle,
  syncing,
  offline,
}

class SyncOperation {
  final String id;
  final SyncOperationType type;
  final String targetId; // itemId or storeRoomId or tempId
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.targetId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'targetId': targetId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        id: json['id'] ?? '',
        type: SyncOperationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => SyncOperationType.updateItem,
        ),
        targetId: json['targetId'] ?? '',
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        retryCount: json['retryCount'] ?? 0,
      );
}

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  ApiClient? _apiClient;
  Timer? _syncTimer;
  bool _isProcessingQueue = false;

  final List<SyncOperation> _queue = [];
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _queueCountController = StreamController<int>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get queueCountStream => _queueCountController.stream;
  int get pendingCount => _queue.length;

  static const String _kQueueKey = 'cpms_sync_queue_v1';
  static const String _kItemsCacheKey = 'cpms_cache_items_v1';
  static const String _kStoreRoomsCacheKey = 'cpms_cache_store_rooms_v1';

  void initialize({required ApiClient apiClient}) {
    _apiClient = apiClient;
    _loadQueue();
    // Start periodic background sync check every 4 seconds
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      processQueue();
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
    _queueCountController.close();
  }

  // ---------------------------------------------------------------------------
  // Local Persistent Caches
  // ---------------------------------------------------------------------------

  Future<void> saveCachedItems(List<Map<String, dynamic>> rawList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kItemsCacheKey, jsonEncode(rawList));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadCachedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kItemsCacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveCachedStoreRooms(List<Map<String, dynamic>> rawList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStoreRoomsCacheKey, jsonEncode(rawList));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadCachedStoreRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kStoreRoomsCacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  // ---------------------------------------------------------------------------
  // Sync Queue Operations
  // ---------------------------------------------------------------------------

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kQueueKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          _queue.clear();
          for (final item in decoded) {
            _queue.add(SyncOperation.fromJson(item));
          }
          _queueCountController.add(_queue.length);
        }
      }
    } catch (_) {}
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = _queue.map((op) => op.toJson()).toList();
      await prefs.setString(_kQueueKey, jsonEncode(serialized));
      _queueCountController.add(_queue.length);
    } catch (_) {}
  }

  Future<void> enqueue(SyncOperation op) async {
    // Coalesce / deduplicate rapid updates to same target
    if (op.type == SyncOperationType.updateItemStock ||
        op.type == SyncOperationType.updateItem) {
      _queue.removeWhere((existing) =>
          existing.targetId == op.targetId &&
          (existing.type == SyncOperationType.updateItemStock ||
              existing.type == SyncOperationType.updateItem));
    }

    _queue.add(op);
    await _persistQueue();

    // Trigger immediate background sync
    processQueue();
  }

  Future<void> processQueue({Function()? onBatchSynced}) async {
    if (_isProcessingQueue || _queue.isEmpty || _apiClient == null) return;
    if (_apiClient!.authToken == null || _apiClient!.authToken!.isEmpty) return;

    _isProcessingQueue = true;
    _syncStatusController.add(SyncStatus.syncing);

    final List<SyncOperation> successfullyProcessed = [];

    for (final op in List<SyncOperation>.from(_queue)) {
      try {
        final success = await _executeOperation(op);
        if (success) {
          successfullyProcessed.add(op);
        } else {
          op.retryCount++;
          if (op.retryCount > 8) {
            // Drop unrecoverable operation after 8 retries to prevent blocking
            successfullyProcessed.add(op);
          }
        }
      } catch (e) {
        // Network / connectivity issue, pause queue processing
        _syncStatusController.add(SyncStatus.offline);
        break;
      }
    }

    if (successfullyProcessed.isNotEmpty) {
      _queue.removeWhere((op) => successfullyProcessed.any((s) => s.id == op.id));
      await _persistQueue();
      if (onBatchSynced != null) onBatchSynced();
    }

    _isProcessingQueue = false;
    _syncStatusController.add(_queue.isEmpty ? SyncStatus.idle : SyncStatus.offline);
  }

  Future<bool> _executeOperation(SyncOperation op) async {
    final client = _apiClient!;
    switch (op.type) {
      case SyncOperationType.createItem:
        await client.post('/items', body: op.payload);
        return true;

      case SyncOperationType.updateItem:
      case SyncOperationType.updateItemStock:
        await client.put('/items/${op.targetId}', body: op.payload);
        return true;

      case SyncOperationType.deleteItem:
        await client.delete('/items/${op.targetId}');
        return true;

      case SyncOperationType.createStoreRoom:
        await client.post('/store-rooms', body: op.payload);
        return true;

      case SyncOperationType.updateStoreRoom:
        await client.put('/store-rooms/${op.targetId}', body: op.payload);
        return true;

      case SyncOperationType.deleteStoreRoom:
        await client.delete('/store-rooms/${op.targetId}');
        return true;

      case SyncOperationType.addStoreRoomItem:
        await client.post('/store-rooms/${op.targetId}/items', body: op.payload);
        return true;

      case SyncOperationType.updateStoreRoomItemQuantity:
        await client.put(
          '/store-rooms/${op.targetId}/items/${op.payload['item_id']}/quantity',
          body: {
            'quantity': op.payload['quantity'],
            if (op.payload['division'] != null) 'division': op.payload['division'],
            if (op.payload['min_count'] != null) 'min_count': op.payload['min_count'],
          },
        );
        return true;

      case SyncOperationType.removeStoreRoomItem:
        await client.delete('/store-rooms/${op.targetId}/items/${op.payload['item_id']}');
        return true;
    }
  }
}

