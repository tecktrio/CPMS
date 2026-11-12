import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/sync/sync_manager.dart';

class StoreRoomModel {
  final String storeRoomId;
  final String tenantId;
  final String roomCode;
  final String roomName;
  final double? temperature;
  final double totalCapacityUnits;
  final double currentOccupancyUnits;
  final double capacityUtilizationPercentage;
  final int activeBatchesCount;
  final List<String> divisions;
  final bool isActive;

  StoreRoomModel({
    required this.storeRoomId,
    required this.tenantId,
    required this.roomCode,
    required this.roomName,
    this.temperature,
    required this.totalCapacityUnits,
    required this.currentOccupancyUnits,
    required this.capacityUtilizationPercentage,
    required this.activeBatchesCount,
    this.divisions = const [],
    required this.isActive,
  });

  StoreRoomModel copyWith({
    String? storeRoomId,
    String? tenantId,
    String? roomCode,
    String? roomName,
    double? temperature,
    double? totalCapacityUnits,
    double? currentOccupancyUnits,
    double? capacityUtilizationPercentage,
    int? activeBatchesCount,
    List<String>? divisions,
    bool? isActive,
  }) {
    return StoreRoomModel(
      storeRoomId: storeRoomId ?? this.storeRoomId,
      tenantId: tenantId ?? this.tenantId,
      roomCode: roomCode ?? this.roomCode,
      roomName: roomName ?? this.roomName,
      temperature: temperature ?? this.temperature,
      totalCapacityUnits: totalCapacityUnits ?? this.totalCapacityUnits,
      currentOccupancyUnits: currentOccupancyUnits ?? this.currentOccupancyUnits,
      capacityUtilizationPercentage:
          capacityUtilizationPercentage ?? this.capacityUtilizationPercentage,
      activeBatchesCount: activeBatchesCount ?? this.activeBatchesCount,
      divisions: divisions ?? this.divisions,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'store_room_id': storeRoomId,
        'tenant_id': tenantId,
        'room_code': roomCode,
        'room_name': roomName,
        'temperature': temperature,
        'total_capacity_units': totalCapacityUnits,
        'current_occupancy_units': currentOccupancyUnits,
        'capacity_utilization_percentage': capacityUtilizationPercentage,
        'active_batches_count': activeBatchesCount,
        'divisions': divisions,
        'is_active': isActive,
      };

  factory StoreRoomModel.fromJson(Map<String, dynamic> json) {
    return StoreRoomModel(
      storeRoomId: json['store_room_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      roomCode: json['room_code'] ?? '',
      roomName: json['room_name'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble(),
      totalCapacityUnits: (json['total_capacity_units'] as num?)?.toDouble() ?? 0.0,
      currentOccupancyUnits:
          (json['current_occupancy_units'] as num?)?.toDouble() ?? 0.0,
      capacityUtilizationPercentage:
          (json['capacity_utilization_percentage'] as num?)?.toDouble() ?? 0.0,
      activeBatchesCount: json['active_batches_count'] ?? 0,
      divisions: (json['divisions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: json['is_active'] ?? true,
    );
  }
}

class ItemModel {
  final String itemId;
  final String tenantId;
  final String sku;
  final String itemName;
  final String itemType;
  final String measurementUnit;
  final double reorderThresholdQuantity;
  final double totalAvailableStock;
  final bool isBelowReorderThreshold;
  final double reorderShortfallQuantity;
  final String? storeRoomId;
  final String? locationCode;
  final String? division;
  final String? imageUrl;
  final bool isActive;

  ItemModel({
    required this.itemId,
    required this.tenantId,
    required this.sku,
    required this.itemName,
    required this.itemType,
    required this.measurementUnit,
    required this.reorderThresholdQuantity,
    required this.totalAvailableStock,
    required this.isBelowReorderThreshold,
    required this.reorderShortfallQuantity,
    this.storeRoomId,
    this.locationCode,
    this.division,
    this.imageUrl,
    required this.isActive,
  });

  ItemModel copyWith({
    String? itemId,
    String? tenantId,
    String? sku,
    String? itemName,
    String? itemType,
    String? measurementUnit,
    double? reorderThresholdQuantity,
    double? totalAvailableStock,
    bool? isBelowReorderThreshold,
    double? reorderShortfallQuantity,
    String? storeRoomId,
    String? locationCode,
    String? division,
    String? imageUrl,
    bool? isActive,
    bool clearStoreRoom = false,
  }) {
    final newStock = totalAvailableStock ?? this.totalAvailableStock;
    final newThreshold =
        reorderThresholdQuantity ?? this.reorderThresholdQuantity;
    final below = newStock <= newThreshold;
    final shortfall = below ? (newThreshold - newStock) : 0.0;

    return ItemModel(
      itemId: itemId ?? this.itemId,
      tenantId: tenantId ?? this.tenantId,
      sku: sku ?? this.sku,
      itemName: itemName ?? this.itemName,
      itemType: itemType ?? this.itemType,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      reorderThresholdQuantity: newThreshold,
      totalAvailableStock: newStock,
      isBelowReorderThreshold: isBelowReorderThreshold ?? below,
      reorderShortfallQuantity: reorderShortfallQuantity ?? shortfall,
      storeRoomId: clearStoreRoom ? null : (storeRoomId ?? this.storeRoomId),
      locationCode: clearStoreRoom ? null : (locationCode ?? this.locationCode),
      division: clearStoreRoom ? null : (division ?? this.division),
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'tenant_id': tenantId,
        'sku': sku,
        'item_name': itemName,
        'item_type': itemType,
        'measurement_unit': measurementUnit,
        'reorder_threshold_quantity': reorderThresholdQuantity,
        'total_available_stock': totalAvailableStock,
        'is_below_reorder_threshold': isBelowReorderThreshold,
        'reorder_shortfall_quantity': reorderShortfallQuantity,
        'storage_location_details': {
          'store_room_id': storeRoomId,
          'location_code': locationCode,
          'division': division,
        },
        'image_url': imageUrl,
        'is_active': isActive,
      };

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    String? sId;
    String? lCode;
    String? div;
    if (json['storage_location_details'] is Map) {
      sId = json['storage_location_details']['store_room_id']?.toString();
      lCode = json['storage_location_details']['location_code']?.toString();
      div = json['storage_location_details']['division']?.toString();
    }

    final stock = (json['total_available_stock'] as num?)?.toDouble() ??
        (json['current_stock_quantity'] as num?)?.toDouble() ??
        (json['stock_quantity'] as num?)?.toDouble() ??
        0.0;

    return ItemModel(
      itemId: json['item_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      sku: json['sku'] ?? '',
      itemName: json['item_name'] ?? '',
      itemType: json['item_type'] ?? 'RAW_MATERIAL',
      measurementUnit: json['measurement_unit'] ?? 'KILOGRAM',
      reorderThresholdQuantity:
          (json['reorder_threshold_quantity'] as num?)?.toDouble() ?? 0.0,
      totalAvailableStock: stock,
      isBelowReorderThreshold: json['is_below_reorder_threshold'] == true,
      reorderShortfallQuantity:
          (json['reorder_shortfall_quantity'] as num?)?.toDouble() ?? 0.0,
      storeRoomId: sId,
      locationCode: lCode,
      division: div,
      imageUrl: json['image_url'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class StockBatchModel {
  final String batchId;
  final String tenantId;
  final String itemId;
  final String? itemName;
  final String? itemSku;
  final String batchNumber;
  final String storeRoomId;
  final String? storeRoomCode;
  final String storageLocationId;
  final double availableQuantity;
  final DateTime? manufacturingDate;
  final DateTime? expiryDate;
  final String batchStatus;
  final int daysUntilExpiry;

  StockBatchModel({
    required this.batchId,
    required this.tenantId,
    required this.itemId,
    this.itemName,
    this.itemSku,
    required this.batchNumber,
    required this.storeRoomId,
    this.storeRoomCode,
    required this.storageLocationId,
    required this.availableQuantity,
    this.manufacturingDate,
    this.expiryDate,
    required this.batchStatus,
    this.daysUntilExpiry = 0,
  });

  factory StockBatchModel.fromJson(Map<String, dynamic> json) {
    DateTime? mDate;
    if (json['manufacturing_date'] != null) {
      mDate = DateTime.tryParse(json['manufacturing_date']);
    }
    DateTime? eDate;
    if (json['expiry_date'] != null) {
      eDate = DateTime.tryParse(json['expiry_date']);
    }

    return StockBatchModel(
      batchId: json['batch_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'],
      itemSku: json['item_sku'],
      batchNumber: json['batch_number'] ?? '',
      storeRoomId: json['store_room_id'] ?? '',
      storeRoomCode: json['store_room_code'],
      storageLocationId: json['storage_location_id'] ?? '',
      availableQuantity:
          (json['available_quantity'] as num?)?.toDouble() ?? 0.0,
      manufacturingDate: mDate,
      expiryDate: eDate,
      batchStatus: json['batch_status'] ?? 'ACTIVE',
      daysUntilExpiry: json['days_until_expiry'] ?? 0,
    );
  }
}

class FefoSuggestedBatch {
  final String batchId;
  final String batchNumber;
  final double availableStock;
  final double suggestedDeductionQuantity;
  double operatorConfirmedQuantity;
  final DateTime? expiryDate;
  final String storeRoomId;

  FefoSuggestedBatch({
    required this.batchId,
    required this.batchNumber,
    required this.availableStock,
    required this.suggestedDeductionQuantity,
    required this.operatorConfirmedQuantity,
    this.expiryDate,
    required this.storeRoomId,
  });

  factory FefoSuggestedBatch.fromJson(Map<String, dynamic> json) {
    final suggested =
        (json['suggested_deduction_quantity'] as num?)?.toDouble() ?? 0.0;
    return FefoSuggestedBatch(
      batchId: json['batch_id'] ?? '',
      batchNumber: json['batch_number'] ?? '',
      availableStock: (json['available_stock'] as num?)?.toDouble() ?? 0.0,
      suggestedDeductionQuantity: suggested,
      operatorConfirmedQuantity: suggested,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'])
          : null,
      storeRoomId: json['store_room_id'] ?? '',
    );
  }
}

class FefoAllocationResult {
  final String itemId;
  final double requestedQuantity;
  final double totalAllocatedQuantity;
  final double shortfallQuantity;
  final bool hasShortfall;
  final List<FefoSuggestedBatch> suggestedBatches;

  FefoAllocationResult({
    required this.itemId,
    required this.requestedQuantity,
    required this.totalAllocatedQuantity,
    required this.shortfallQuantity,
    required this.hasShortfall,
    required this.suggestedBatches,
  });

  factory FefoAllocationResult.fromJson(Map<String, dynamic> json) {
    return FefoAllocationResult(
      itemId: json['item_id'] ?? '',
      requestedQuantity:
          (json['requested_quantity'] as num?)?.toDouble() ?? 0.0,
      totalAllocatedQuantity:
          (json['total_allocated_quantity'] as num?)?.toDouble() ?? 0.0,
      shortfallQuantity:
          (json['shortfall_quantity'] as num?)?.toDouble() ?? 0.0,
      hasShortfall: json['has_shortfall'] == true,
      suggestedBatches: (json['suggested_batches'] as List<dynamic>?)
              ?.map((item) => FefoSuggestedBatch.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class InventoryProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final SyncManager syncManager = SyncManager();

  List<StoreRoomModel> _storeRooms = [];
  List<ItemModel> _items = [];
  List<StockBatchModel> _stockBatches = [];
  List<StockBatchModel> _expiringSoonBatches = [];

  bool _isLoading = false;
  String? _errorMessage;

  InventoryProvider({required this.apiClient}) {
    syncManager.initialize(apiClient: apiClient);
    // Instant initial restore from local persistent storage cache
    _restoreLocalCache();
  }

  List<StoreRoomModel> get storeRooms => _storeRooms;
  List<ItemModel> get items => _items;
  List<StockBatchModel> get stockBatches => _stockBatches;
  List<StockBatchModel> get expiringSoonBatches => _expiringSoonBatches;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clear() {
    _storeRooms = [];
    _items = [];
    _stockBatches = [];
    _expiringSoonBatches = [];
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Local Cache Restoration (Instant UI load without blocking server)
  // ---------------------------------------------------------------------------

  Future<void> _restoreLocalCache() async {
    final cachedRooms = await syncManager.loadCachedStoreRooms();
    if (cachedRooms.isNotEmpty && _storeRooms.isEmpty) {
      _storeRooms =
          cachedRooms.map((json) => StoreRoomModel.fromJson(json)).toList();
      notifyListeners();
    }

    final cachedItems = await syncManager.loadCachedItems();
    if (cachedItems.isNotEmpty && _items.isEmpty) {
      _items = cachedItems.map((json) => ItemModel.fromJson(json)).toList();
      notifyListeners();
    }
  }

  void _persistItemsLocally() {
    syncManager.saveCachedItems(_items.map((i) => i.toJson()).toList());
  }

  void _persistStoreRoomsLocally() {
    syncManager.saveCachedStoreRooms(_storeRooms.map((r) => r.toJson()).toList());
  }

  // ---------------------------------------------------------------------------
  // Store Rooms
  // ---------------------------------------------------------------------------

  Future<void> loadStoreRooms({bool silent = false}) async {
    if (!silent && _storeRooms.isEmpty) {
      _setLoading(true);
    }
    try {
      final res = await apiClient.get(ApiConstants.storeRooms);
      if (res is List) {
        _storeRooms = res.map((item) => StoreRoomModel.fromJson(item)).toList();
        _persistStoreRoomsLocally();
      }
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  Future<bool> createStoreRoom({
    required String roomCode,
    required String roomName,
    double? temperature,
    required double totalCapacityUnits,
    List<String>? divisions,
  }) async {
    // 1. Instant optimistic local creation
    final tempId = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticRoom = StoreRoomModel(
      storeRoomId: tempId,
      tenantId: apiClient.activeTenantId ?? '',
      roomCode: roomCode.trim().toUpperCase(),
      roomName: roomName.trim(),
      temperature: temperature,
      totalCapacityUnits: totalCapacityUnits,
      currentOccupancyUnits: 0.0,
      capacityUtilizationPercentage: 0.0,
      activeBatchesCount: 0,
      divisions: divisions ?? [],
      isActive: true,
    );

    _storeRooms.insert(0, optimisticRoom);
    _persistStoreRoomsLocally();
    notifyListeners();

    // 2. Queue for background live sync
    final body = <String, dynamic>{
      'room_code': roomCode.trim().toUpperCase(),
      'room_name': roomName.trim(),
      'total_capacity_units': totalCapacityUnits,
    };
    if (temperature != null) body['temperature'] = temperature;
    if (divisions != null && divisions.isNotEmpty) body['divisions'] = divisions;

    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.createStoreRoom,
      targetId: tempId,
      payload: body,
      createdAt: DateTime.now(),
    ));

    return true;
  }

  Future<bool> updateStoreRoom({
    required String storeRoomId,
    String? roomCode,
    String? roomName,
    double? temperature,
    double? totalCapacityUnits,
    List<String>? divisions,
  }) async {
    // 1. Instant optimistic update
    final index = _storeRooms.indexWhere((r) => r.storeRoomId == storeRoomId);
    if (index != -1) {
      final existing = _storeRooms[index];
      _storeRooms[index] = existing.copyWith(
        roomCode: roomCode?.trim().toUpperCase(),
        roomName: roomName?.trim(),
        temperature: temperature,
        totalCapacityUnits: totalCapacityUnits,
        divisions: divisions,
      );
      _persistStoreRoomsLocally();
      notifyListeners();
    }

    // 2. Queue for background live sync
    final body = <String, dynamic>{};
    if (roomCode != null && roomCode.isNotEmpty) {
      body['room_code'] = roomCode.trim().toUpperCase();
    }
    if (roomName != null && roomName.isNotEmpty) {
      body['room_name'] = roomName.trim();
    }
    if (temperature != null) body['temperature'] = temperature;
    if (totalCapacityUnits != null) {
      body['total_capacity_units'] = totalCapacityUnits;
    }
    if (divisions != null) body['divisions'] = divisions;

    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.updateStoreRoom,
      targetId: storeRoomId,
      payload: body,
      createdAt: DateTime.now(),
    ));

    return true;
  }

  Future<bool> deleteStoreRoom(String storeRoomId) async {
    // 1. Instant optimistic deletion
    _storeRooms.removeWhere((r) => r.storeRoomId == storeRoomId);
    _persistStoreRoomsLocally();
    notifyListeners();

    // 2. Queue for background live sync
    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.deleteStoreRoom,
      targetId: storeRoomId,
      payload: {},
      createdAt: DateTime.now(),
    ));

    return true;
  }

  // ---------------------------------------------------------------------------
  // Items Management (Optimistic local-first + Live Sync)
  // ---------------------------------------------------------------------------

  Future<void> loadItems({bool silent = false}) async {
    if (!silent && _items.isEmpty) {
      _setLoading(true);
    }
    try {
      final res = await apiClient.get(ApiConstants.items);
      if (res is List) {
        _items = res.map((item) => ItemModel.fromJson(item)).toList();
        _persistItemsLocally();
      }
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  Future<String?> uploadItemImage(List<int> bytes, String filename) async {
    try {
      final res = await apiClient.multipartPost(
        '${ApiConstants.items}/upload-image',
        bytes: bytes,
        filename: filename,
        fileField: 'image',
      );
      if (res is Map<String, dynamic> && res['image_url'] != null) {
        return res['image_url'].toString();
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateItemImage(
    String itemId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      await apiClient.multipartPost(
        '${ApiConstants.items}/$itemId/image',
        bytes: bytes,
        filename: filename,
        fileField: 'image',
      );
      await loadItems(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> removeItemImage(String itemId) async {
    // Optimistic image removal
    final index = _items.indexWhere((i) => i.itemId == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(imageUrl: '');
      _persistItemsLocally();
      notifyListeners();
    }

    try {
      await apiClient.put('${ApiConstants.items}/$itemId', body: {'image_url': null});
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> createItem({
    required String sku,
    required String itemName,
    required String itemType,
    required String measurementUnit,
    required double reorderThreshold,
    String? storeRoomId,
    String? locationCode,
    String? division,
    double? stockQuantity,
    String? imageUrl,
  }) async {
    final cleanSku = sku.trim().toUpperCase();
    final cleanName = itemName.trim();
    final initialStock = stockQuantity ?? 0.0;
    final tempId = 'item_${DateTime.now().millisecondsSinceEpoch}';
    final hasStoreRoom = storeRoomId != null && storeRoomId.isNotEmpty;

    // 1. INSTANT OPTIMISTIC INSERTION
    final optimisticItem = ItemModel(
      itemId: tempId,
      tenantId: apiClient.activeTenantId ?? '',
      sku: cleanSku,
      itemName: cleanName,
      itemType: itemType,
      measurementUnit: measurementUnit,
      reorderThresholdQuantity: reorderThreshold,
      totalAvailableStock: initialStock,
      isBelowReorderThreshold: initialStock <= reorderThreshold,
      reorderShortfallQuantity:
          initialStock <= reorderThreshold ? (reorderThreshold - initialStock) : 0.0,
      storeRoomId: hasStoreRoom ? storeRoomId : null,
      locationCode: hasStoreRoom ? (locationCode ?? division ?? 'LOC-01') : null,
      division: hasStoreRoom ? (division ?? 'Default Section') : null,
      imageUrl: imageUrl,
      isActive: true,
    );

    _items.insert(0, optimisticItem);
    _persistItemsLocally();
    notifyListeners();

    // 2. ENQUEUE FOR BACKGROUND LIVE SYNC
    final body = <String, dynamic>{
      'sku': cleanSku,
      'item_name': cleanName,
      'item_type': itemType,
      'measurement_unit': measurementUnit,
      'reorder_threshold_quantity': reorderThreshold,
      'stock_quantity': initialStock,
    };

    if (hasStoreRoom) {
      body['storage_location_details'] = {
        'store_room_id': storeRoomId,
        'location_code': (locationCode != null && locationCode.isNotEmpty)
            ? locationCode.trim()
            : (division != null && division.isNotEmpty ? division : 'LOC-01'),
        'division': division ?? '',
        'rack_identifier': 'R1',
        'shelf_identifier': 'S1',
        'bin_identifier': 'B1',
        'allowed_category': itemType,
        'is_active': true,
      };
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['image_url'] = imageUrl;
    }

    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.createItem,
      targetId: tempId,
      payload: body,
      createdAt: DateTime.now(),
    ));

    return true;
  }

  Future<bool> updateItem({
    required String itemId,
    String? itemName,
    String? itemType,
    String? measurementUnit,
    double? reorderThreshold,
    String? storeRoomId,
    String? division,
    double? stockQuantity,
    String? imageUrl,
    bool clearStoreRoom = false,
  }) async {
    // 1. INSTANT OPTIMISTIC UPDATE IN LOCAL MEMORY & DISK CACHE
    final index = _items.indexWhere((i) => i.itemId == itemId);
    if (index != -1) {
      final existing = _items[index];
      _items[index] = existing.copyWith(
        itemName: itemName?.trim(),
        itemType: itemType,
        measurementUnit: measurementUnit,
        reorderThresholdQuantity: reorderThreshold,
        totalAvailableStock: stockQuantity,
        storeRoomId: clearStoreRoom ? null : (storeRoomId ?? existing.storeRoomId),
        division: clearStoreRoom ? null : (division ?? existing.division),
        imageUrl: imageUrl,
        clearStoreRoom: clearStoreRoom,
      );
      _persistItemsLocally();
      notifyListeners();
    }

    // 2. ENQUEUE FOR BACKGROUND LIVE SYNC
    final body = <String, dynamic>{};
    if (itemName != null && itemName.isNotEmpty) body['item_name'] = itemName.trim();
    if (itemType != null) body['item_type'] = itemType;
    if (measurementUnit != null) body['measurement_unit'] = measurementUnit;
    if (reorderThreshold != null) body['reorder_threshold_quantity'] = reorderThreshold;
    if (stockQuantity != null) body['stock_quantity'] = stockQuantity;
    if (imageUrl != null) {
      body['image_url'] = imageUrl.isEmpty ? null : imageUrl;
    }

    if (clearStoreRoom) {
      body['storage_location_details'] = {
        'store_room_id': null,
        'location_code': '',
        'division': '',
      };
    } else if (storeRoomId != null || division != null) {
      final loc = <String, dynamic>{
        'location_code': division ?? 'LOC-01',
        'division': division ?? '',
      };
      if (storeRoomId != null) {
        loc['store_room_id'] = storeRoomId.isEmpty ? null : storeRoomId;
      }
      body['storage_location_details'] = loc;
    }

    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.updateItem,
      targetId: itemId,
      payload: body,
      createdAt: DateTime.now(),
    ));

    return true;
  }

  Future<bool> updateItemStock(String itemId, double newQuantity) async {
    final clamped = newQuantity < 0 ? 0.0 : newQuantity;

    // 1. INSTANT OPTIMISTIC STOCK UPDATE IN ZERO MILLISECONDS
    final index = _items.indexWhere((i) => i.itemId == itemId);
    if (index != -1) {
      final existing = _items[index];
      _items[index] = existing.copyWith(totalAvailableStock: clamped);
      _persistItemsLocally();
      notifyListeners();
    }

    // 2. ENQUEUE FOR LIVE BACKGROUND SYNC
    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.updateItemStock,
      targetId: itemId,
      payload: {'stock_quantity': clamped},
      createdAt: DateTime.now(),
    ));

    return true;
  }

  Future<bool> deleteItem(String itemId) async {
    // 1. INSTANT OPTIMISTIC REMOVAL
    _items.removeWhere((i) => i.itemId == itemId);
    _persistItemsLocally();
    notifyListeners();

    // 2. ENQUEUE LIVE BACKGROUND SYNC
    syncManager.enqueue(SyncOperation(
      id: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: SyncOperationType.deleteItem,
      targetId: itemId,
      payload: {},
      createdAt: DateTime.now(),
    ));

    return true;
  }

  // ---------------------------------------------------------------------------
  // Stock Batches
  // ---------------------------------------------------------------------------

  Future<void> loadStockBatches() async {
    try {
      final res = await apiClient.get(ApiConstants.stockBatches);
      if (res is List) {
        _stockBatches =
            res.map((item) => StockBatchModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> loadExpiringSoon([int days = 7]) async {
    try {
      final res =
          await apiClient.get('${ApiConstants.expiringSoonBatches}?days=$days');
      if (res is List) {
        _expiringSoonBatches =
            res.map((item) => StockBatchModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> inwardBatchReceipt({
    required String itemId,
    required String batchNumber,
    required String storeRoomId,
    required String storageLocationId,
    required double quantity,
    required DateTime manufacturingDate,
    required DateTime expiryDate,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.post(ApiConstants.stockBatches, body: {
        'item_id': itemId,
        'batch_number': batchNumber.trim().toUpperCase(),
        'store_room_id': storeRoomId,
        'storage_location_id': storageLocationId.trim(),
        'available_quantity': quantity,
        'manufacturing_date': manufacturingDate.toIso8601String(),
        'expiry_date': expiryDate.toIso8601String(),
      });
      await Future.wait([
        loadStockBatches(),
        loadStoreRooms(silent: true),
        loadItems(silent: true),
      ]);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<FefoAllocationResult?> getFefoAllocationSuggestion({
    required String itemId,
    required double requestedQuantity,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await apiClient.post(ApiConstants.suggestFefo, body: {
        'item_id': itemId,
        'requested_quantity': requestedQuantity,
      });
      _setLoading(false);
      if (res is Map<String, dynamic>) {
        return FefoAllocationResult.fromJson(res);
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return null;
    }
  }

  Future<bool> confirmBatchDeduction({
    required String itemId,
    required List<Map<String, dynamic>> deductions,
    String? purpose,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final body = <String, dynamic>{
        'item_id': itemId,
        'deductions': deductions,
      };
      if (purpose != null) body['purpose'] = purpose;
      await apiClient.post(ApiConstants.deductBatches, body: body);
      await Future.wait([
        loadStockBatches(),
        loadStoreRooms(silent: true),
        loadItems(silent: true),
      ]);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
