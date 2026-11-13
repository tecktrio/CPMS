import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class CustomerModel {
  final String customerId;
  final String tenantId;
  final String customerName;
  final String address;
  final String contactDetails;
  final bool isActive;

  CustomerModel({
    required this.customerId,
    required this.tenantId,
    required this.customerName,
    this.address = '',
    this.contactDetails = '',
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'tenant_id': tenantId,
        'customer_name': customerName,
        'address': address,
        'contact_details': contactDetails,
        'is_active': isActive,
      };

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      customerId: json['customer_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      address: json['address'] ?? '',
      contactDetails: json['contact_details'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }
}

class PurchaseOrderItemModel {
  final String itemId;
  final String itemName;
  final String sku;
  final int packetPerCarton;
  final int cartons;
  final int totalPackets;
  final double quantityPerPacket;
  final String unit;

  PurchaseOrderItemModel({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.packetPerCarton,
    required this.cartons,
    int? totalPackets,
    this.quantityPerPacket = 1.0,
    this.unit = '',
  }) : totalPackets = totalPackets ?? (packetPerCarton * cartons);

  double get totalQuantity => totalPackets * quantityPerPacket;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_name': itemName,
        'sku': sku,
        'packet_per_carton': packetPerCarton,
        'cartons': cartons,
        'total_packets': totalPackets,
        'quantity_per_packet': quantityPerPacket,
        'unit': unit,
      };

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    final perCarton = (json['packet_per_carton'] as num?)?.toInt() ?? 0;
    final cartons = (json['cartons'] as num?)?.toInt() ?? 0;
    final total = (json['total_packets'] as num?)?.toInt() ?? (perCarton * cartons);
    final qtyPerPacket = (json['quantity_per_packet'] as num?)?.toDouble() ?? 1.0;

    return PurchaseOrderItemModel(
      itemId: json['item_id'] ?? '',
      itemName: json['item_name'] ?? '',
      sku: json['sku'] ?? '',
      packetPerCarton: perCarton,
      cartons: cartons,
      totalPackets: total,
      quantityPerPacket: qtyPerPacket,
      unit: json['unit'] ?? '',
    );
  }
}

class PurchaseOrderModel {
  final String poId;
  final String tenantId;
  final String poNumber;
  final DateTime poDate;
  final DateTime? expectedShippingDate;
  final String customerId;
  final String customerName;
  final String customerAddress;
  final String customerContact;
  final List<PurchaseOrderItemModel> items;
  final int totalCartons;
  final int totalPackets;
  final int totalItemsCount;
  final String status;
  final String notes;
  final DateTime? createdAt;

  PurchaseOrderModel({
    required this.poId,
    required this.tenantId,
    required this.poNumber,
    required this.poDate,
    this.expectedShippingDate,
    required this.customerId,
    required this.customerName,
    this.customerAddress = '',
    this.customerContact = '',
    required this.items,
    required this.totalCartons,
    required this.totalPackets,
    required this.totalItemsCount,
    this.status = 'CONFIRMED',
    this.notes = '',
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'po_id': poId,
        'tenant_id': tenantId,
        'po_number': poNumber,
        'po_date': poDate.toIso8601String(),
        'expected_shipping_date': expectedShippingDate?.toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_address': customerAddress,
        'customer_contact': customerContact,
        'items': items.map((i) => i.toJson()).toList(),
        'total_cartons': totalCartons,
        'total_packets': totalPackets,
        'total_items_count': totalItemsCount,
        'status': status,
        'notes': notes,
        'created_at': createdAt?.toIso8601String(),
      };

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    List<PurchaseOrderItemModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => PurchaseOrderItemModel.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    }

    DateTime parsedDate;
    if (json['po_date'] != null) {
      parsedDate = DateTime.tryParse(json['po_date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? shippingDate;
    if (json['expected_shipping_date'] != null) {
      shippingDate = DateTime.tryParse(json['expected_shipping_date'].toString());
    }

    DateTime? created;
    if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString());
    }

    return PurchaseOrderModel(
      poId: json['po_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      poNumber: json['po_number'] ?? '',
      poDate: parsedDate,
      expectedShippingDate: shippingDate,
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerAddress: json['customer_address'] ?? '',
      customerContact: json['customer_contact'] ?? '',
      items: parsedItems,
      totalCartons: (json['total_cartons'] as num?)?.toInt() ?? 0,
      totalPackets: (json['total_packets'] as num?)?.toInt() ?? 0,
      totalItemsCount: (json['total_items_count'] as num?)?.toInt() ?? parsedItems.length,
      status: json['status'] ?? 'CONFIRMED',
      notes: json['notes'] ?? '',
      createdAt: created,
    );
  }
}

class PurchaseOrderProvider with ChangeNotifier {
  final ApiClient apiClient;

  List<PurchaseOrderModel> _purchaseOrders = [];
  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  PurchaseOrderProvider({required this.apiClient});

  List<PurchaseOrderModel> get purchaseOrders => _purchaseOrders;
  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ===================== CUSTOMERS =====================

  Future<void> loadCustomers() async {
    try {
      final res = await apiClient.get(ApiConstants.customers);
      if (res is List) {
        _customers = res
            .map((c) => CustomerModel.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load customers: $e');
    }
  }

  Future<CustomerModel?> createCustomer({
    required String customerName,
    String? address,
    String? contactDetails,
  }) async {
    try {
      final res = await apiClient.post(
        ApiConstants.customers,
        body: {
          'customer_name': customerName.trim(),
          if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
          if (contactDetails != null && contactDetails.trim().isNotEmpty)
            'contact_details': contactDetails.trim(),
        },
      );

      final created = CustomerModel.fromJson(Map<String, dynamic>.from(res));
      final idx = _customers.indexWhere((c) => c.customerId == created.customerId);
      if (idx >= 0) {
        _customers[idx] = created;
      } else {
        _customers.insert(0, created);
      }
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error creating customer: $e');
      return null;
    }
  }

  // ===================== PURCHASE ORDERS =====================

  Future<void> loadPurchaseOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get(ApiConstants.purchaseOrders);
      if (res is List) {
        _purchaseOrders = res
            .map((po) => PurchaseOrderModel.fromJson(Map<String, dynamic>.from(po)))
            .toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading purchase orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPurchaseOrder({
    required String poNumber,
    required DateTime poDate,
    DateTime? expectedShippingDate,
    required String customerId,
    required String customerName,
    String? customerAddress,
    String? customerContact,
    required List<PurchaseOrderItemModel> items,
    String status = 'CONFIRMED',
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'po_number': poNumber.trim().toUpperCase(),
        'po_date': poDate.toIso8601String(),
        if (expectedShippingDate != null)
          'expected_shipping_date': expectedShippingDate.toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName.trim(),
        if (customerAddress != null && customerAddress.trim().isNotEmpty)
          'customer_address': customerAddress.trim(),
        if (customerContact != null && customerContact.trim().isNotEmpty)
          'customer_contact': customerContact.trim(),
        'items': items.map((i) => i.toJson()).toList(),
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

      final res = await apiClient.post(ApiConstants.purchaseOrders, body: body);
      final created = PurchaseOrderModel.fromJson(Map<String, dynamic>.from(res));
      _purchaseOrders.insert(0, created);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error creating purchase order: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePurchaseOrder({
    required String poId,
    String? poNumber,
    DateTime? poDate,
    DateTime? expectedShippingDate,
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? customerContact,
    List<PurchaseOrderItemModel>? items,
    String? status,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (poNumber != null) body['po_number'] = poNumber.trim().toUpperCase();
      if (poDate != null) body['po_date'] = poDate.toIso8601String();
      if (expectedShippingDate != null) {
        body['expected_shipping_date'] = expectedShippingDate.toIso8601String();
      }
      if (customerId != null) body['customer_id'] = customerId;
      if (customerName != null) body['customer_name'] = customerName.trim();
      if (customerAddress != null) body['customer_address'] = customerAddress.trim();
      if (customerContact != null) body['customer_contact'] = customerContact.trim();
      if (items != null) body['items'] = items.map((i) => i.toJson()).toList();
      if (status != null) body['status'] = status;
      if (notes != null) body['notes'] = notes.trim();

      final res = await apiClient.put(
        '${ApiConstants.purchaseOrders}/$poId',
        body: body,
      );

      final updated = PurchaseOrderModel.fromJson(Map<String, dynamic>.from(res));
      final idx = _purchaseOrders.indexWhere((p) => p.poId == poId);
      if (idx >= 0) {
        _purchaseOrders[idx] = updated;
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error updating purchase order: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePurchaseOrder(String poId) async {
    try {
      await apiClient.delete('${ApiConstants.purchaseOrders}/$poId');
      _purchaseOrders.removeWhere((p) => p.poId == poId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error deleting purchase order: $e');
      return false;
    }
  }
}
