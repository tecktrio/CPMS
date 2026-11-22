import 'dart:convert';
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

  Map<String, dynamic> toJson() {
    return {
      'department_id': departmentId,
      'tenant_id': tenantId,
      'department_name': departmentName,
      'description': description,
      'permission_ids': permissionIds,
      'is_active': isActive,
    };
  }
}

class TenantProvider extends ChangeNotifier {
  final ApiClient apiClient;

  TenantOption? _activeTenant;
  List<DepartmentModel> _tenantDepartments = [];
  final Set<String> _userPermissions = {};
  bool _isLoading = false;
  bool _hasLoadedPermissions = false;
  String? _errorMessage;
  Future<void>? _inFlightPermissionsFuture;

  TenantProvider({required this.apiClient});

  TenantOption? get activeTenant => _activeTenant;
  String? get selectedDepartmentName {
    if (_activeTenant == null) return null;
    if (_activeTenant!.departmentIds.isNotEmpty) {
      for (final assignedId in _activeTenant!.departmentIds) {
        for (final d in _tenantDepartments) {
          if (d.departmentId == assignedId) {
            return d.departmentName;
          }
        }
      }
    }
    if (_activeTenant!.isAdmin) return 'Administrator';
    if (_tenantDepartments.isNotEmpty) {
      return _tenantDepartments.first.departmentName;
    }
    return 'Assigned Department';
  }
  List<DepartmentModel> get tenantDepartments => _tenantDepartments;
  Set<String> get userPermissions => _userPermissions;
  bool get isLoading => _isLoading;
  bool get hasLoadedPermissions => _hasLoadedPermissions;
  String? get errorMessage => _errorMessage;

  bool get isTenantSelected => _activeTenant != null;
  bool get isTenantAdmin {
    if (_activeTenant == null) return false;
    // Operational staff in specific departments (Sales, Store Room, Supervisor, QC, etc.)
    // are strictly scoped to their assigned department's permissions.
    if (_activeTenant!.departmentIds.isNotEmpty) {
      final deptName = selectedDepartmentName?.toLowerCase() ?? '';
      if (deptName.isNotEmpty && !deptName.contains('admin')) {
        return false;
      }
    }
    return _activeTenant?.isAdmin ?? false;
  }

  /// Whether the user is in the Administrator department or is a Tenant Admin
  bool get isUserInAdministratorDepartment {
    if (_activeTenant == null) return false;
    if (_activeTenant!.isAdmin) return true;
    final dept = selectedDepartmentName?.toLowerCase() ?? '';
    return dept == 'administrator' || dept.contains('admin');
  }

  /// Whether the user is strictly in the Supervisor department (not Admin, Sales, PM, etc.)
  bool get isUserInSupervisorDepartment {
    if (_activeTenant == null) return false;
    if (isTenantAdmin || isUserInAdministratorDepartment) return false;
    for (final assignedId in _activeTenant!.departmentIds) {
      for (final d in _tenantDepartments) {
        if (d.departmentId == assignedId &&
            d.departmentName.trim().toLowerCase().contains('supervisor')) {
          return true;
        }
      }
    }
    final dept = selectedDepartmentName?.toLowerCase() ?? '';
    return dept.contains('supervisor');
  }

  /// Whether the user is strictly in the Packer department (not Admin, PM, etc.)
  bool get isUserInPackerDepartment {
    if (_activeTenant == null) return false;
    if (isTenantAdmin || isUserInAdministratorDepartment) return false;
    for (final assignedId in _activeTenant!.departmentIds) {
      for (final d in _tenantDepartments) {
        if (d.departmentId == assignedId &&
            d.departmentName.trim().toLowerCase().contains('pack')) {
          return true;
        }
      }
    }
    final dept = selectedDepartmentName?.toLowerCase() ?? '';
    return dept.contains('pack');
  }

  /// Whether the user is strictly in the QC department (not Admin, PM, etc.)
  bool get isUserInQcDepartment {
    if (_activeTenant == null) return false;
    if (isTenantAdmin || isUserInAdministratorDepartment) return false;
    for (final assignedId in _activeTenant!.departmentIds) {
      for (final d in _tenantDepartments) {
        if (d.departmentId == assignedId) {
          final name = d.departmentName.trim().toLowerCase();
          if (name == 'qc' || name.contains('qc') || name.contains('quality')) {
            return true;
          }
        }
      }
    }
    final dept = selectedDepartmentName?.toLowerCase() ?? '';
    return dept == 'qc' || dept.contains('qc') || dept.contains('quality');
  }

  /// Whether the user is strictly in the Export department (not Admin, PM, etc.)
  bool get isUserInExportDepartment {
    if (_activeTenant == null) return false;
    if (isTenantAdmin || isUserInAdministratorDepartment) return false;
    for (final assignedId in _activeTenant!.departmentIds) {
      for (final d in _tenantDepartments) {
        if (d.departmentId == assignedId) {
          final name = d.departmentName.trim().toLowerCase();
          if (name == 'export' || name.contains('export') || name.contains('ship')) {
            return true;
          }
        }
      }
    }
    final dept = selectedDepartmentName?.toLowerCase() ?? '';
    return dept == 'export' || dept.contains('export') || dept.contains('ship');
  }

  /// Returns the number of departments the user has access to in the active organization
  int get userDepartmentCount {
    if (_activeTenant == null) return 0;
    if (isTenantAdmin || _activeTenant!.hasAllDepartmentsAccess) {
      return _tenantDepartments.length;
    }
    return _activeTenant!.departmentIds.length;
  }

  /// Evaluates whether the authenticated user has permission to perform a specific action
  bool hasPermission(String permissionId) {
    if (_activeTenant == null) return false;
    // Tenant Admin automatically has superadmin access across all modules
    if (isTenantAdmin) {
      return true;
    }

    if (_userPermissions.contains(permissionId)) return true;

    // Check all user's assigned departments permissions
    if (_activeTenant!.departmentIds.isNotEmpty) {
      for (final assignedId in _activeTenant!.departmentIds) {
        for (final d in _tenantDepartments) {
          if (d.departmentId == assignedId) {
            if (d.permissionIds.contains(permissionId)) return true;
          }
        }
      }
    }

    // Auto-grant read permission if user has any action permission in that module
    if (permissionId.endsWith('.read')) {
      final parts = permissionId.split('.');
      if (parts.length >= 3) {
        final modulePrefix = 'permission.${parts[1]}.';
        if (_userPermissions.any((p) => p.startsWith(modulePrefix))) {
          return true;
        }
        if (_activeTenant!.departmentIds.isNotEmpty) {
          for (final assignedId in _activeTenant!.departmentIds) {
            for (final d in _tenantDepartments) {
              if (d.departmentId == assignedId) {
                if (d.permissionIds.any((p) => p.startsWith(modulePrefix))) {
                  return true;
                }
              }
            }
          }
        }
      }
    }

    return false;
  }

  /// Checks if user has ANY permission in a given module (e.g. 'item', 'storeroom', 'department', 'user')
  bool hasAnyPermissionInModule(String module) {
    if (_activeTenant == null) return false;
    if (isTenantAdmin) {
      return true;
    }
    final prefix = 'permission.$module.';
    if (_userPermissions.any((p) => p.startsWith(prefix))) return true;

    if (_activeTenant!.departmentIds.isNotEmpty) {
      for (final assignedId in _activeTenant!.departmentIds) {
        for (final d in _tenantDepartments) {
          if (d.departmentId == assignedId) {
            if (d.permissionIds.any((p) => p.startsWith(prefix))) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  void setSelectedDepartment(String? deptName) {
    // Deprecated: user is strictly bound to single assigned department
    notifyListeners();
  }

  /// Instantly restores locally cached permissions and departments for zero-latency dashboard rendering
  Future<void> _loadCachedPermissions(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPerms = prefs.getStringList('cpms_tenant_permissions_$tenantId');
      if (cachedPerms != null && cachedPerms.isNotEmpty) {
        _userPermissions.clear();
        _userPermissions.addAll(cachedPerms);
        _hasLoadedPermissions = true;
      }
      final cachedDepts = prefs.getString('cpms_tenant_departments_$tenantId');
      if (cachedDepts != null && cachedDepts.isNotEmpty) {
        final List decoded = jsonDecode(cachedDepts);
        _tenantDepartments = decoded.map((item) => DepartmentModel.fromJson(item)).toList();
      }
    } catch (_) {}
  }

  Future<void> selectTenant(TenantOption tenant, {String? initialDepartmentName}) async {
    _activeTenant = tenant;
    apiClient.setActiveTenantId(tenant.tenantId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cpms_active_tenant', tenant.tenantId);

    // 1. Instantly load cache if available
    await _loadCachedPermissions(tenant.tenantId);

    // If cache did not have permissions and user is not admin, mark loading so listeners see loading state immediately
    if (!_hasLoadedPermissions && !tenant.isAdmin) {
      _setLoading(true);
    }
    notifyListeners();

    // 2. Fetch fresh permissions and departments from backend before completing selection
    await loadTenantPermissions();
  }

  Future<void> restoreSavedTenant(List<TenantOption> availableTenants) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTenantId = prefs.getString('cpms_active_tenant') ?? prefs.getString('cims_active_tenant');
    if (savedTenantId != null && savedTenantId.isNotEmpty) {
      final match = availableTenants.cast<TenantOption?>().firstWhere(
        (t) => t?.tenantId == savedTenantId,
        orElse: () => null,
      );
      if (match != null) {
        _activeTenant = match;
        apiClient.setActiveTenantId(savedTenantId);

        // 1. Instantly restore cached permissions
        await _loadCachedPermissions(savedTenantId);
        if (!_hasLoadedPermissions && !match.isAdmin) {
          _setLoading(true);
        }
        notifyListeners();

        // 2. Fetch fresh permissions from network
        await loadTenantPermissions();
      }
    }
  }

  void clear() {
    _activeTenant = null;
    _tenantDepartments = [];
    _userPermissions.clear();
    _hasLoadedPermissions = false;
    _inFlightPermissionsFuture = null;
    apiClient.setActiveTenantId(null);
    notifyListeners();
  }

  Future<void> loadTenantPermissions() async {
    if (_activeTenant == null) return;
    if (_inFlightPermissionsFuture != null) {
      return _inFlightPermissionsFuture!;
    }
    _inFlightPermissionsFuture = _performLoadTenantPermissions();
    try {
      await _inFlightPermissionsFuture;
    } finally {
      _inFlightPermissionsFuture = null;
    }
  }

  Future<void> _performLoadTenantPermissions() async {
    if (_activeTenant == null) return;
    final tenantId = _activeTenant!.tenantId;
    apiClient.setActiveTenantId(tenantId);

    // Only set loading if no permissions are currently available
    if (_userPermissions.isEmpty && _tenantDepartments.isEmpty) {
      _setLoading(true);
    }
    _errorMessage = null;

    try {
      dynamic res;
      // 1. Try /tenants/:id/permissions
      try {
        res = await apiClient.get(
          ApiConstants.tenantPermissions(tenantId),
        );
      } catch (_) {
        // Fallback 1: try /tenants/:id/my-permissions
        try {
          res = await apiClient.get(
            ApiConstants.tenantMyPermissions(tenantId),
          );
        } catch (_) {
          // Fallback 2: try /tenants/:id
          try {
            res = await apiClient.get(
              ApiConstants.tenantById(tenantId),
            );
          } catch (e) {
            _errorMessage = e.toString();
          }
        }
      }

      if (res is Map<String, dynamic>) {
        final Set<String> freshPermissions = {};
        if (res['permissions'] is List) {
          for (final p in res['permissions']) {
            final s = p.toString();
            freshPermissions.add(s);
            final parts = s.split('.');
            if (parts.length >= 3) {
              freshPermissions.add('permission.${parts[1]}.read');
            }
          }
        }

        final isAdmin = res.containsKey('is_admin')
            ? res['is_admin'] == true
            : _activeTenant!.isAdmin;
        final hasAllAccess = res.containsKey('has_all_departments_access')
            ? res['has_all_departments_access'] == true
            : _activeTenant!.hasAllDepartmentsAccess;

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

        List<DepartmentModel> freshDepts = [];
        if (res['departments'] is List) {
          freshDepts = (res['departments'] as List)
              .map((item) => DepartmentModel.fromJson(item))
              .toList();
        }

        _userPermissions.clear();
        _userPermissions.addAll(freshPermissions);
        _tenantDepartments = freshDepts;

        // Persist to local cache for instant cold starts
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('cpms_tenant_permissions_$tenantId', _userPermissions.toList());
          await prefs.setString(
            'cpms_tenant_departments_$tenantId',
            jsonEncode(_tenantDepartments.map((d) => d.toJson()).toList()),
          );
        } catch (_) {}
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _hasLoadedPermissions = true;
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> loadTenantDepartments() async {
    if (_tenantDepartments.isEmpty) {
      await loadTenantPermissions();
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

  Future<bool> deleteTenant(String tenantId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await apiClient.delete(ApiConstants.tenantById(tenantId));

      // If the deleted tenant was the active tenant, clear active state
      if (_activeTenant?.tenantId == tenantId) {
        clear();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cpms_active_tenant');
        await prefs.remove('cims_active_tenant');
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
