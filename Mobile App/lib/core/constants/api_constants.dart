class ApiConstants {
  // Configured server IP for network / physical device connectivity
  static const String serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: 'http://32.236.228.113:3000',
  );

  static String get baseUrl => '$serverHost/api/v1';

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
  static String tenantMyPermissions(String tenantId) =>
      '/tenants/$tenantId/my-permissions';
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

