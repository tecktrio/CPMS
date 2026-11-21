import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class EmergencyContactModel {
  final String contactId;
  final String tenantId;
  final String title;
  final String subtitle;
  final String phoneNumber;
  final String iconType;
  final int priorityOrder;
  final bool isActive;

  EmergencyContactModel({
    required this.contactId,
    required this.tenantId,
    required this.title,
    required this.subtitle,
    required this.phoneNumber,
    this.iconType = 'warning',
    this.priorityOrder = 0,
    this.isActive = true,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      contactId: json['contact_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      iconType: json['icon_type'] ?? 'warning',
      priorityOrder: json['priority_order'] is num
          ? (json['priority_order'] as num).toInt()
          : 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class EmergencyContactsProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<EmergencyContactModel> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  EmergencyContactsProvider({required this.apiClient});

  List<EmergencyContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loadContacts() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await apiClient.get(ApiConstants.emergencyContacts);
      if (res is List) {
        _contacts = res
            .map((item) =>
                EmergencyContactModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  Future<bool> createContact({
    required String title,
    String? subtitle,
    required String phoneNumber,
    String? iconType,
    int? priorityOrder,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final body = <String, dynamic>{
        'title': title.trim(),
        'subtitle': subtitle?.trim() ?? '',
        'phone_number': phoneNumber.trim(),
        'icon_type': iconType ?? 'warning',
        'priority_order': priorityOrder ?? (_contacts.length + 1),
      };
      await apiClient.post(ApiConstants.emergencyContacts, body: body);
      await loadContacts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateContact({
    required String contactId,
    String? title,
    String? subtitle,
    String? phoneNumber,
    String? iconType,
    int? priorityOrder,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title.trim();
      if (subtitle != null) body['subtitle'] = subtitle.trim();
      if (phoneNumber != null) body['phone_number'] = phoneNumber.trim();
      if (iconType != null) body['icon_type'] = iconType;
      if (priorityOrder != null) body['priority_order'] = priorityOrder;

      await apiClient.put(
        ApiConstants.emergencyContactById(contactId),
        body: body,
      );
      await loadContacts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteContact(String contactId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.delete(ApiConstants.emergencyContactById(contactId));
      await loadContacts();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }
}
