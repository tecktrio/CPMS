import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Android emulator uses 10.0.2.2 to access host machine localhost.
  // iOS Simulator / macOS desktop uses 127.0.0.1 or localhost.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  // Auth endpoints
  static const String signUp = '/auth/sign-up';
  static const String signIn = '/auth/sign-in';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String userProfile = '/auth/me';

  // Tenant endpoints
  static const String tenants = '/tenants';
  static const String addUserToTenant = '/tenants/add-user';
  static String tenantUsers(String userId) => '/tenants/users/$userId';
  static String removeUserFromDepartment(String userId, String deptId) =>
      '/tenants/users/$userId/departments/$deptId';

  // Directory users
  static const String usersDirectory = '/users';

  // Departments & Permissions
  static const String departments = '/departments';
  static String departmentDetails(String id) => '/departments/$id';
  static const String permissions = '/permissions';

  // Inventory & Store Rooms
  static const String storeRooms = '/store-rooms';
  static const String items = '/items';
  static const String stockBatches = '/stock-batches';
  static const String expiringSoonBatches = '/stock-batches/expiring-soon';
  static const String suggestFefo = '/stock-batches/suggest-fefo';
  static const String deductBatches = '/stock-batches/deduct-batches';
}

