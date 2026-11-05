import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class SystemPermissionModel {
  final String permissionId;
  final String module;
  final String action;
  final String displayName;
  final String description;

  SystemPermissionModel({
    required this.permissionId,
    required this.module,
    required this.action,
    required this.displayName,
    required this.description,
  });

  factory SystemPermissionModel.fromJson(Map<String, dynamic> json) {
    return SystemPermissionModel(
      permissionId: json['permission_id'] ?? '',
      module: json['module'] ?? '',
      action: json['action'] ?? '',
      displayName: json['display_name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class TenantUserModel {
  final String userId;
  final String fullName;
  final String emailAddress;
  final List<String> departmentIds;
  final String accountStatus;

  TenantUserModel({
    required this.userId,
    required this.fullName,
    required this.emailAddress,
    required this.departmentIds,
    required this.accountStatus,
  });

  factory TenantUserModel.fromJson(Map<String, dynamic> json) {
    return TenantUserModel(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      emailAddress: json['email_address'] ?? '',
      departmentIds: (json['department_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      accountStatus: json['account_status'] ?? 'ACTIVE',
    );
  }
}

class DepartmentProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<SystemPermissionModel> _systemPermissions = [];
  final Map<String, List<SystemPermissionModel>> _permissionsByModule = {};
  List<TenantUserModel> _tenantUsers = [];

  bool _isLoading = false;
  String? _errorMessage;

  DepartmentProvider({required this.apiClient});

  List<SystemPermissionModel> get systemPermissions => _systemPermissions;
  Map<String, List<SystemPermissionModel>> get permissionsByModule =>
      _permissionsByModule;
  List<TenantUserModel> get tenantUsers => _tenantUsers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadSystemPermissions() async {
    _setLoading(true);
    try {
      final res = await apiClient.get(ApiConstants.permissions);
      if (res is List) {
        _systemPermissions =
            res.map((item) => SystemPermissionModel.fromJson(item)).toList();

        _permissionsByModule.clear();
        for (final p in _systemPermissions) {
          if (!_permissionsByModule.containsKey(p.module)) {
            _permissionsByModule[p.module] = [];
          }
          _permissionsByModule[p.module]!.add(p);
        }
      }
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  Future<bool> createDepartment({
    required String departmentName,
    String? description,
    required List<String> permissionIds,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.post(ApiConstants.departments, body: {
        'department_name': departmentName.trim(),
        'description': description?.trim() ?? '',
        'permission_ids': permissionIds,
      });
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateDepartment({
    required String departmentId,
    required String departmentName,
    String? description,
    required List<String> permissionIds,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.put(ApiConstants.departmentDetails(departmentId), body: {
        'department_name': departmentName.trim(),
        'description': description?.trim() ?? '',
        'permission_ids': permissionIds,
      });
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteDepartment(String departmentId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.delete(ApiConstants.departmentDetails(departmentId));
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadTenantUsers() async {
    _setLoading(true);
    try {
      final res = await apiClient.get(ApiConstants.usersDirectory);
      if (res is List) {
        _tenantUsers =
            res.map((item) => TenantUserModel.fromJson(item)).toList();
      }
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  Future<bool> addTenantUser({
    required String emailAddress,
    required List<String> departmentIds,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.post(ApiConstants.addUserToTenant, body: {
        'email_address': emailAddress.trim().toLowerCase(),
        'department_ids': departmentIds,
      });
      await loadTenantUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateTenantUser({
    required String userId,
    required List<String> departmentIds,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.put(ApiConstants.tenantUsers(userId), body: {
        'department_ids': departmentIds,
      });
      await loadTenantUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> removeUserFromTenant(String userId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await apiClient.delete(ApiConstants.tenantUsers(userId));
      await loadTenantUsers();
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
