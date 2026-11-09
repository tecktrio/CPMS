import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

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
    DateTime? eDate;
    if (json['manufacturing_date'] != null) {
      mDate = DateTime.tryParse(json['manufacturing_date']);
    }
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
      availableQuantity: (json['available_quantity'] as num?)?.toDouble() ?? 0.0,
      manufacturingDate: mDate,
      expiryDate: eDate,
      batchStatus: json['batch_status'] ?? 'AVAILABLE',
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

  List<StoreRoomModel> _storeRooms = [];
  List<ItemModel> _items = [];
  List<StockBatchModel> _stockBatches = [];
  List<StockBatchModel> _expiringSoonBatches = [];

  bool _isLoading = false;
  String? _errorMessage;

  InventoryProvider({required this.apiClient});

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

  Future<void> loadStoreRooms() async {
    _setLoading(true);
    try {
      final res = await apiClient.get(ApiConstants.storeRooms);
      if (res is List) {
        _storeRooms = res.map((item) => StoreRoomModel.fromJson(item)).toList();
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
    _setLoading(true);
    _errorMessage = null;
    try {
      final body = <String, dynamic>{
        'room_code': roomCode.trim().toUpperCase(),
        'room_name': roomName.trim(),
        'total_capacity_units': totalCapacityUnits,
      };
      if (temperature != null) body['temperature'] = temperature;
      if (divisions != null && divisions.isNotEmpty) body['divisions'] = divisions;

      await apiClient.post(ApiConstants.storeRooms, body: body);
      await loadStoreRooms();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateStoreRoom({
    required String storeRoomId,
    String? roomCode,
    String? roomName,
    double? temperature,
    double? totalCapacityUnits,
    List<String>? divisions,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
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

      await apiClient.put('${ApiConstants.storeRooms}/$storeRoomId', body: body);
      await loadStoreRooms();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteStoreRoom(String storeRoomId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.delete('${ApiConstants.storeRooms}/$storeRoomId');
      await loadStoreRooms();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadItems() async {
    _setLoading(true);
    try {
      final res = await apiClient.get(ApiConstants.items);
      if (res is List) {
        _items = res.map((item) => ItemModel.fromJson(item)).toList();
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
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.multipartPost(
        '${ApiConstants.items}/$itemId/image',
        bytes: bytes,
        filename: filename,
        fileField: 'image',
      );
      await loadItems();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> removeItemImage(String itemId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.put('${ApiConstants.items}/$itemId', body: {'image_url': null});
      await loadItems();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> createItem({
    required String sku,
    required String itemName,
    required String itemType,
    required String measurementUnit,
    required double reorderThreshold,
    required String storeRoomId,
    String? locationCode,
    String? division,
    double? stockQuantity,
    String? imageUrl,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final body = <String, dynamic>{
        'sku': sku.trim().toUpperCase(),
        'item_name': itemName.trim(),
        'item_type': itemType,
        'measurement_unit': measurementUnit,
        'reorder_threshold_quantity': reorderThreshold,
        'stock_quantity': stockQuantity ?? 0.0,
        'storage_location_details': {
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
        },
      };
      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['image_url'] = imageUrl;
      }
      await apiClient.post(ApiConstants.items, body: body);
      await loadItems();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
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
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final body = <String, dynamic>{};
      if (itemName != null && itemName.isNotEmpty) body['item_name'] = itemName.trim();
      if (itemType != null) body['item_type'] = itemType;
      if (measurementUnit != null) body['measurement_unit'] = measurementUnit;
      if (reorderThreshold != null) body['reorder_threshold_quantity'] = reorderThreshold;
      if (stockQuantity != null) body['stock_quantity'] = stockQuantity;
      if (imageUrl != null) {
        body['image_url'] = imageUrl.isEmpty ? null : imageUrl;
      }
      if (storeRoomId != null || division != null) {
        final loc = <String, dynamic>{
          'location_code': division ?? 'LOC-01',
          'division': division ?? '',
        };
        if (storeRoomId != null) loc['store_room_id'] = storeRoomId;
        body['storage_location_details'] = loc;
      }

      await apiClient.put('${ApiConstants.items}/$itemId', body: body);
      await loadItems();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateItemStock(String itemId, double newQuantity) async {
    final clamped = newQuantity < 0 ? 0.0 : newQuantity;
    return updateItem(itemId: itemId, stockQuantity: clamped);
  }

  Future<bool> deleteItem(String itemId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.delete('${ApiConstants.items}/$itemId');
      await loadItems();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadStockBatches() async {
    _setLoading(true);
    try {
      final res = await apiClient.get(ApiConstants.stockBatches);
      if (res is List) {
        _stockBatches =
            res.map((item) => StockBatchModel.fromJson(item)).toList();
      }
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
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
    } catch (e) {
      // Non-blocking background alert
    }
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
        loadStoreRooms(),
        loadItems(),
      ]);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Option B: Requests FEFO suggestion calculation from backend
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

  /// Option B: Operator confirms final adjusted batch deduction
  Future<bool> confirmBatchDeduction({
    required String itemId,
    required List<Map<String, dynamic>> deductions,
    String? purpose,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.post(ApiConstants.deductBatches, body: {
        'item_id': itemId,
        'deductions': deductions,
        'purpose': purpose ?? 'Production Batch Execution',
      });
      await Future.wait([
        loadStockBatches(),
        loadStoreRooms(),
        loadItems(),
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

