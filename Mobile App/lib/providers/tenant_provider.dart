import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import 'auth_provider.dart';

class DepartmentModel {
  final String departmentId;
  final String tenantId;
  final String departmentName;
  final String description;
  final List<String> permissionIds;
  final bool isActive;

  DepartmentModel({
    required this.departmentId,
    required this.tenantId,
    required this.departmentName,
    required this.description,
    required this.permissionIds,
    required this.isActive,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      departmentId: json['department_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      departmentName: json['department_name'] ?? '',
      description: json['description'] ?? '',
      permissionIds: (json['permission_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive: json['is_active'] ?? true,
    );
  }
}

class TenantProvider extends ChangeNotifier {
  final ApiClient apiClient;

  TenantOption? _activeTenant;
  List<DepartmentModel> _tenantDepartments = [];
  final Set<String> _userPermissions = {};
  bool _isLoading = false;
  String? _errorMessage;

  TenantProvider({required this.apiClient});

  TenantOption? get activeTenant => _activeTenant;
  List<DepartmentModel> get tenantDepartments => _tenantDepartments;
  Set<String> get userPermissions => _userPermissions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isTenantSelected => _activeTenant != null;
  bool get isTenantAdmin => _activeTenant?.isAdmin ?? false;

  /// Returns the number of departments the user has access to in the active organization
  int get userDepartmentCount {
    if (_activeTenant == null) return 0;
    if (_activeTenant!.isAdmin || _activeTenant!.hasAllDepartmentsAccess) {
      return _tenantDepartments.length;
    }
    return _activeTenant!.departmentIds.length;
  }

  /// Evaluates whether the authenticated user has permission to perform a specific action
  bool hasPermission(String permissionId) {
    if (_activeTenant == null) return false;
    // Tenant Admin automatically has superadmin access across all modules
    if (_activeTenant!.isAdmin || _activeTenant!.hasAllDepartmentsAccess) {
      return true;
    }

    if (_userPermissions.contains(permissionId)) return true;

    // Auto-grant read permission if user has any action permission in that module
    if (permissionId.endsWith('.read')) {
      final parts = permissionId.split('.');
      if (parts.length >= 3) {
        final modulePrefix = 'permission.${parts[1]}.';
        if (_userPermissions.any((p) => p.startsWith(modulePrefix))) {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if user has ANY permission in a given module (e.g. 'item', 'storeroom', 'department', 'user')
  bool hasAnyPermissionInModule(String module) {
    if (_activeTenant == null) return false;
    if (_activeTenant!.isAdmin || _activeTenant!.hasAllDepartmentsAccess) {
      return true;
    }
    final prefix = 'permission.$module.';
    return _userPermissions.any((p) => p.startsWith(prefix));
  }

  Future<void> selectTenant(TenantOption tenant) async {
    _activeTenant = tenant;
    apiClient.setActiveTenantId(tenant.tenantId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cims_active_tenant', tenant.tenantId);

    await loadTenantDepartments();
    notifyListeners();
  }

  Future<void> restoreSavedTenant(List<TenantOption> availableTenants) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTenantId = prefs.getString('cims_active_tenant');
    if (savedTenantId != null && savedTenantId.isNotEmpty) {
      final match = availableTenants.cast<TenantOption?>().firstWhere(
        (t) => t?.tenantId == savedTenantId,
        orElse: () => null,
      );
      if (match != null) {
        _activeTenant = match;
        apiClient.setActiveTenantId(savedTenantId);
        await loadTenantDepartments();
        notifyListeners();
      }
    }
  }

  void clear() {
    _activeTenant = null;
    _tenantDepartments = [];
    _userPermissions.clear();
    apiClient.setActiveTenantId(null);
    notifyListeners();
  }

  Future<void> loadTenantPermissions() async {
    if (_activeTenant == null) return;
    _setLoading(true);

    try {
      dynamic res;
      // 1. Try /tenants/:id/permissions
      try {
        res = await apiClient.get(
          ApiConstants.tenantPermissions(_activeTenant!.tenantId),
        );
      } catch (_) {
        // Fallback 1: try /tenants/:id/my-permissions
        try {
          res = await apiClient.get(
            ApiConstants.tenantMyPermissions(_activeTenant!.tenantId),
          );
        } catch (_) {
          // Fallback 2: try /tenants/:id
          try {
            res = await apiClient.get(
              ApiConstants.tenantById(_activeTenant!.tenantId),
            );
          } catch (_) {}
        }
      }

      if (res is Map<String, dynamic>) {
        if (res['permissions'] is List) {
          _userPermissions.clear();
          for (final p in res['permissions']) {
            final s = p.toString();
            _userPermissions.add(s);
            final parts = s.split('.');
            if (parts.length >= 3) {
              _userPermissions.add('permission.${parts[1]}.read');
            }
          }
        }

        final isAdmin = res['is_admin'] == true || _activeTenant!.isAdmin;
        final hasAllAccess = res['has_all_departments_access'] == true ||
            _activeTenant!.hasAllDepartmentsAccess;

        List<String> latestDeptIds = _activeTenant!.departmentIds;
        if (res['department_ids'] is List) {
          latestDeptIds = (res['department_ids'] as List)
              .map((d) => d.toString())
              .toList();
        }

        _activeTenant = TenantOption(
          tenantId: _activeTenant!.tenantId,
          companyName: res['company_name']?.toString() ?? _activeTenant!.companyName,
          isAdmin: isAdmin,
          hasAllDepartmentsAccess: hasAllAccess,
          departmentIds: latestDeptIds,
        );

        if (res['departments'] is List) {
          _tenantDepartments = (res['departments'] as List)
              .map((item) => DepartmentModel.fromJson(item))
              .toList();
        }
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> loadTenantDepartments() async {
    await loadTenantPermissions();
  }

  Future<TenantOption?> createTenant(String companyName) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await apiClient.post(ApiConstants.tenants, body: {
        'company_name': companyName.trim(),
      });

      _setLoading(false);

      if (res is Map<String, dynamic> && res['tenant'] != null) {
        final t = res['tenant'];
        final newOption = TenantOption(
          tenantId: t['tenant_id'],
          companyName: t['company_name'],
          isAdmin: true,
          hasAllDepartmentsAccess: true,
          departmentIds: [],
        );
        await selectTenant(newOption);
        return newOption;
      }
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return null;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
