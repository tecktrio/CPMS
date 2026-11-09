import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class AuthUser {
  final String userId;
  final String fullName;
  final String emailAddress;
  final String? avatarUrl;
  final String? phoneNumber;

  AuthUser({
    required this.userId,
    required this.fullName,
    required this.emailAddress,
    this.avatarUrl,
    this.phoneNumber,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      emailAddress: json['email_address'] ?? '',
      avatarUrl: json['avatar_url'],
      phoneNumber: json['phone_number'],
    );
  }

  AuthUser copyWith({
    String? userId,
    String? fullName,
    String? emailAddress,
    String? avatarUrl,
    String? phoneNumber,
  }) {
    return AuthUser(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      emailAddress: emailAddress ?? this.emailAddress,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class TenantOption {
  final String tenantId;
  final String companyName;
  final bool isAdmin;
  final bool hasAllDepartmentsAccess;
  final List<String> departmentIds;

  TenantOption({
    required this.tenantId,
    required this.companyName,
    required this.isAdmin,
    this.hasAllDepartmentsAccess = false,
    this.departmentIds = const [],
  });

  factory TenantOption.fromJson(Map<String, dynamic> json) {
    return TenantOption(
      tenantId: json['tenant_id'] ?? '',
      companyName: json['company_name'] ?? '',
      isAdmin: json['is_admin'] == true,
      hasAllDepartmentsAccess: json['has_all_departments_access'] == true || json['is_admin'] == true,
      departmentIds: (json['department_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;

  String? _token;
  AuthUser? _user;
  List<TenantOption> _availableTenants = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  AuthProvider({required this.apiClient});

  String? get token => _token;
  AuthUser? get user => _user;
  List<TenantOption> get availableTenants => _availableTenants;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;

  Future<void> initSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('cpms_auth_token') ?? prefs.getString('cims_auth_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        apiClient.setAuthToken(savedToken);
        try {
          final profileRes = await apiClient.get(ApiConstants.userProfile);
          if (profileRes is Map<String, dynamic>) {
            _user = AuthUser.fromJson(profileRes);
          }
          final tenantsRes = await apiClient.get(ApiConstants.tenants);
          if (tenantsRes is List) {
            _availableTenants = tenantsRes
                .map((item) => TenantOption.fromJson(item))
                .toList();
          }
        } catch (_) {
          _token = null;
          apiClient.setAuthToken(null);
          await prefs.remove('cpms_auth_token');
          await prefs.remove('cims_auth_token');
        }
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await apiClient.post(ApiConstants.signUp, body: {
        'full_name': fullName.trim(),
        'email_address': email.trim().toLowerCase(),
        'password': password,
      });
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await apiClient.post(ApiConstants.signIn, body: {
        'email_address': email.trim().toLowerCase(),
        'password': password,
      });

      // If OTP is skipped, the server returns access_token immediately!
      if (res is Map<String, dynamic> && res['access_token'] != null) {
        _token = res['access_token'];
        apiClient.setAuthToken(_token);

        if (res['user'] != null) {
          _user = AuthUser.fromJson(res['user']);
        }

        if (res['available_tenants'] != null &&
            res['available_tenants'] is List) {
          _availableTenants = (res['available_tenants'] as List)
              .map((item) => TenantOption.fromJson(item))
              .toList();
        }

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) {
          await prefs.setString('cpms_auth_token', _token!);
        }
      }

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await apiClient.post(ApiConstants.verifyOtp, body: {
        'email_address': email.trim().toLowerCase(),
        'otp_code': otpCode.trim(),
      });

      if (res is Map<String, dynamic>) {
        _token = res['access_token'];
        apiClient.setAuthToken(_token);

        if (res['user'] != null) {
          _user = AuthUser.fromJson(res['user']);
        }

        if (res['available_tenants'] != null && res['available_tenants'] is List) {
          _availableTenants = (res['available_tenants'] as List)
              .map((item) => TenantOption.fromJson(item))
              .toList();
        }

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) {
          await prefs.setString('cpms_auth_token', _token!);
        }
      }

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> resendOtp(String email) async {
    await apiClient.post(ApiConstants.resendOtp, body: {
      'email_address': email.trim().toLowerCase(),
    });
  }

  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await apiClient.post(ApiConstants.forgotPassword, body: {
        'email_address': email.trim().toLowerCase(),
      });
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await apiClient.post(ApiConstants.resetPassword, body: {
        'email_address': email.trim().toLowerCase(),
        'otp_code': otpCode.trim(),
        'new_password': newPassword,
      });
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfilePicture(List<int> bytes, String filename) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await apiClient.multipartPost(
        '/users/avatar',
        bytes: bytes,
        filename: filename,
        fileField: 'image',
      );

      if (res is Map<String, dynamic> && res['avatar_url'] != null) {
        final newAvatarUrl = res['avatar_url'].toString();
        if (_user != null) {
          _user = _user!.copyWith(avatarUrl: newAvatarUrl);
        }
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

  Future<bool> removeProfilePicture() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await apiClient.delete('/users/avatar');
      if (_user != null) {
        _user = _user!.copyWith(avatarUrl: '');
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

  Future<bool> updateProfile({
    required String fullName,
    String? phoneNumber,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await apiClient.put('/users/profile', body: {
        'full_name': fullName.trim(),
        if (phoneNumber != null) 'phone_number': phoneNumber.trim(),
      });

      if (res is Map<String, dynamic>) {
        _user = AuthUser.fromJson(res);
      } else if (_user != null) {
        _user = _user!.copyWith(
          fullName: fullName.trim(),
          phoneNumber: phoneNumber?.trim(),
        );
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

  Future<void> signOut() async {
    _token = null;
    _user = null;
    _availableTenants = [];
    apiClient.setAuthToken(null);
    apiClient.setActiveTenantId(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cpms_auth_token');
    await prefs.remove('cpms_active_tenant');
    await prefs.remove('cims_auth_token');
    await prefs.remove('cims_active_tenant');
    notifyListeners();
  }

  void updateAvailableTenants(List<TenantOption> list) {
    _availableTenants = list;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}

