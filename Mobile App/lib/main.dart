import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/department_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/tenant_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tenant/tenant_selector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final prefs = await SharedPreferences.getInstance();
  final savedToken = prefs.getString('cims_auth_token');
  final savedTenantId = prefs.getString('cims_active_tenant');

  if (savedToken != null && savedToken.isNotEmpty) {
    apiClient.setAuthToken(savedToken);
  }
  if (savedTenantId != null && savedTenantId.isNotEmpty) {
    apiClient.setActiveTenantId(savedTenantId);
  }

  runApp(CimsMobileApp(apiClient: apiClient));
}

class CimsMobileApp extends StatelessWidget {
  final ApiClient? apiClient;

  const CimsMobileApp({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    final client = apiClient ?? ApiClient();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiClient: client)..initSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => TenantProvider(apiClient: client),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(apiClient: client),
        ),
        ChangeNotifierProvider(
          create: (_) => DepartmentProvider(apiClient: client),
        ),
      ],
      child: MaterialApp(
        title: 'Cyan CIMS Cold Chain Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
        routes: {
          '/signin': (_) => const SignInScreen(),
          '/tenants': (_) => const TenantSelectorScreen(),
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _tenantRestorationAttempted = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenant = context.watch<TenantProvider>();

    if (auth.isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const SignInScreen();
    }

    if (!_tenantRestorationAttempted &&
        auth.availableTenants.isNotEmpty &&
        !tenant.isTenantSelected) {
      _tenantRestorationAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        tenant.restoreSavedTenant(auth.availableTenants);
      });
    }

    if (tenant.isTenantSelected) {
      return const DashboardScreen();
    }

    return const TenantSelectorScreen();
  }
}
