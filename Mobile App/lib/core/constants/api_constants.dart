class ApiConstants {
  // Configured server IP for network / physical device connectivity
  static const String serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: 'http://32.236.228.113:3000',
  );

  static String get baseUrl => '$serverHost/api/v1';

  static String? resolveImageUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
    final trimmed = pathOrUrl.trim();

    // Map any private S3 direct URLs to our secure backend storage proxy
    if (trimmed.contains('.amazonaws.com/')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final relativePath = uri.pathSegments.join('/');
        return '$serverHost/api/v1/storage/$relativePath';
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$serverHost$trimmed';
    }
    return '$serverHost/$trimmed';
  }

  // Auth & Profile endpoints
  static const String signUp = '/auth/sign-up';
  static const String signIn = '/auth/sign-in';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String userProfile = '/auth/me';

  // Tenant endpoints
  static const String tenants = '/tenants';
  static String tenantById(String tenantId) => '/tenants/$tenantId';
  static String tenantPermissions(String tenantId) =>
      '/tenants/$tenantId/permissions';
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

