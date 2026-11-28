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
  moveStoreRoomItem,
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
  String? tenantId;

  SyncOperation({
    required this.id,
    required this.type,
    required this.targetId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.tenantId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'targetId': targetId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'tenantId': tenantId,
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
        tenantId: json['tenantId'] as String?,
      );
}

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  ApiClient? _apiClient;
  Timer? _syncTimer;
  bool _isProcessingQueue = false;
  Future<void>? _queueRestore;
  Future<bool> _queueWrite = Future.value(true);
  final _retryAfter = <String, DateTime>{};

  final List<SyncOperation> _queue = [];
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _queueCountController = StreamController<int>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get queueCountStream => _queueCountController.stream;
  int get pendingCount => _queue.length;

  bool hasPendingItemChanges(String? tenantId) => _queue.any(
    (op) =>
        op.tenantId == tenantId &&
        const {
          SyncOperationType.createItem,
          SyncOperationType.updateItem,
          SyncOperationType.updateItemStock,
          SyncOperationType.deleteItem,
        }.contains(op.type),
  );

  bool hasPendingStoreRoomChanges(String? tenantId) => _queue.any(
    (op) => op.tenantId == tenantId && const {
      SyncOperationType.createStoreRoom,
      SyncOperationType.updateStoreRoom,
      SyncOperationType.deleteStoreRoom,
      SyncOperationType.addStoreRoomItem,
      SyncOperationType.updateStoreRoomItemQuantity,
      SyncOperationType.moveStoreRoomItem,
      SyncOperationType.removeStoreRoomItem,
    }.contains(op.type),
  );

  static const String _kQueueKey = 'cpms_sync_queue_v1';
  static const String _kItemsCacheKey = 'cpms_cache_items_v1';
  static const String _kStoreRoomsCacheKey = 'cpms_cache_store_rooms_v1';

  void clearQueue() {
    _queue.clear();
    _retryAfter.clear();
    _queueCountController.add(0);
    _persistQueue();
    _syncStatusController.add(SyncStatus.idle);
  }

  void initialize({required ApiClient apiClient}) {
    _apiClient = apiClient;
    restoreQueue();
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

  String? _inventoryCacheKey(String prefix) {
    final tenant = _apiClient?.activeTenantId;
    final account = _apiClient?.accountCacheKey;
    if (tenant == null || account == null) return null;
    return '${prefix}_${account}_${Uri.encodeComponent(tenant)}';
  }

  Future<void> saveCachedItems(List<Map<String, dynamic>> rawList) async {
    final key = _inventoryCacheKey(_kItemsCacheKey);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(rawList));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadCachedItems() async {
    final key = _inventoryCacheKey(_kItemsCacheKey);
    if (key == null) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key != _inventoryCacheKey(_kItemsCacheKey)) return [];
      final str = prefs.getString(key);
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
    final key = _inventoryCacheKey(_kStoreRoomsCacheKey);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(rawList));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadCachedStoreRooms() async {
    final key = _inventoryCacheKey(_kStoreRoomsCacheKey);
    if (key == null) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key != _inventoryCacheKey(_kStoreRoomsCacheKey)) return [];
      final str = prefs.getString(key);
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

  Future<void> restoreQueue() => _queueRestore ??= _loadQueue();

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kQueueKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final savedTenantId = prefs.getString('cpms_active_tenant') ??
              prefs.getString('cims_active_tenant');
          for (final item in decoded) {
            final op = SyncOperation.fromJson(item);
            op.tenantId ??= savedTenantId;
            _queue.add(op);
          }
          _queueCountController.add(_queue.length);
          await _persistQueue();
        }
      }
    } catch (_) {}
  }

  Future<bool> _persistQueue() {
    final serialized = jsonEncode(_queue.map((op) => op.toJson()).toList());
    _queueWrite = _queueWrite.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setString(_kQueueKey, serialized);
      } catch (_) {
        return false;
      }
    });
    return _queueWrite;
  }

  Future<void> enqueue(SyncOperation op) async {
    op.tenantId ??= _apiClient?.activeTenantId;
    await restoreQueue();

    _queue.add(op);
    _queueCountController.add(_queue.length);
    await _persistQueue();

    // Trigger immediate background sync
    processQueue();
  }

  Future<void> processQueue({Function()? onBatchSynced}) async {
    await restoreQueue();
    final client = _apiClient;
    final tenantId = client?.activeTenantId;
    final token = client?.authToken;
    if (_isProcessingQueue || tenantId == null || tenantId.isEmpty ||
        token?.isNotEmpty != true) {
      return;
    }

    final pending = _queue.where((op) => op.tenantId == tenantId).toList();
    if (pending.isEmpty) return;

    _isProcessingQueue = true;
    _syncStatusController.add(SyncStatus.syncing);
    final savedIds = <String>{};
    final deferredTargets = <String>{};

    try {
      if (!await _persistQueue()) return;
      for (final op in pending) {
        if (client?.activeTenantId != tenantId ||
            client?.authToken != token) {
          break;
        }
        final retryAt = _retryAfter[op.id];
        if (retryAt != null && retryAt.isAfter(DateTime.now())) {
          deferredTargets.add(op.targetId);
        }
        if (deferredTargets.contains(op.targetId)) continue;

        try {
          if (await _executeOperation(op)) {
            savedIds.add(op.id);
            _retryAfter.remove(op.id);
            continue;
          }
          deferredTargets.add(op.targetId);
        } on ApiException catch (error) {
          final code = error.statusCode;
          if (code == null || code >= 500 || code == 401 || code == 429) break;
          deferredTargets.add(op.targetId);
        } catch (_) {
          break;
        }

        op.retryCount++;
        final delay = (op.retryCount * 15).clamp(15, 180).toInt();
        _retryAfter[op.id] = DateTime.now().add(Duration(seconds: delay));
      }

      if (savedIds.isNotEmpty) {
        _queue.removeWhere((op) => savedIds.contains(op.id));
        await _persistQueue();
        _queueCountController.add(_queue.length);
        onBatchSynced?.call();
      }
    } finally {
      _isProcessingQueue = false;
      _syncStatusController.add(_queue.isEmpty ? SyncStatus.idle : SyncStatus.offline);
    }
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
            if (op.payload['division_id'] != null) 'division_id': op.payload['division_id'],
            if (op.payload['min_count'] != null) 'min_count': op.payload['min_count'],
          },
        );
        return true;

      case SyncOperationType.moveStoreRoomItem:
        await client.put(
          '/store-rooms/${op.targetId}/items/${op.payload['item_id']}/division',
          body: {
            'source_division_id': op.payload['source_division_id'],
            'source_division': op.payload['source_division'],
            'division_id': op.payload['division_id'],
          },
        );
        return true;

      case SyncOperationType.removeStoreRoomItem:
        await client.delete('/store-rooms/${op.targetId}/items/${op.payload['item_id']}');
        return true;
    }
  }
}

