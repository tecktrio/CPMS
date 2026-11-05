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
    return _userPermissions.contains(permissionId);
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

  Future<void> loadTenantDepartments() async {
    if (_activeTenant == null) return;
    _setLoading(true);

    try {
      final res = await apiClient.get(ApiConstants.departments);
      if (res is List) {
        _tenantDepartments =
            res.map((item) => DepartmentModel.fromJson(item)).toList();
      }

      // Compute aggregated permissions for this user in this tenant
      _computeUserPermissions();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  void _computeUserPermissions() {
    _userPermissions.clear();

    if (_activeTenant == null) return;

    if (_activeTenant!.isAdmin || _activeTenant!.hasAllDepartmentsAccess) {
      // Admin has all permissions from all departments
      for (final dept in _tenantDepartments) {
        _userPermissions.addAll(dept.permissionIds);
      }
      return;
    }

    // Operator: aggregate permissions ONLY from the departments they are assigned to
    final assignedDeptIds = Set<String>.from(_activeTenant!.departmentIds);
    for (final dept in _tenantDepartments) {
      if (assignedDeptIds.contains(dept.departmentId)) {
        _userPermissions.addAll(dept.permissionIds);
      }
    }
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
