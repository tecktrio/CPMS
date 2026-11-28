import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/api_client.dart';
import 'core/sync/sync_manager.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/department_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/purchase_order_provider.dart';
import 'providers/tenant_provider.dart';
import 'providers/production_provider.dart';
import 'providers/emergency_contacts_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tenant/tenant_selector_screen.dart';
import 'utils/app_update_helper.dart';
import 'widgets/sync_status_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final prefs = await SharedPreferences.getInstance();
  final savedToken = prefs.getString('cpms_auth_token') ?? prefs.getString('cims_auth_token');
  final savedTenantId = prefs.getString('cpms_active_tenant') ?? prefs.getString('cims_active_tenant');

  if (savedToken != null && savedToken.isNotEmpty) {
    apiClient.setAuthToken(savedToken);
  }
  if (savedTenantId != null && savedTenantId.isNotEmpty) {
    apiClient.setActiveTenantId(savedTenantId);
  }

  await SyncManager().restoreQueue();
  runApp(CpmsMobileApp(apiClient: apiClient));
}

class CpmsMobileApp extends StatelessWidget {
  final ApiClient? apiClient;

  const CpmsMobileApp({super.key, this.apiClient});

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
        ChangeNotifierProvider(
          create: (_) => PurchaseOrderProvider(apiClient: client),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductionProvider(apiClient: client),
        ),
        ChangeNotifierProvider(
          create: (_) => EmergencyContactsProvider(apiClient: client),
        ),
      ],
      child: MaterialApp(
        title: 'Cyan CPMS Product Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            const Positioned(
              top: 0,
              left: 0,
              child: IgnorePointer(
                child: SafeArea(
                  right: false,
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.all(7),
                    child: SyncStatusIndicator(),
                  ),
                ),
              ),
            ),
          ],
        ),
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

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _tenantRestorationAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateHelper.checkForImmediateUpdate();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppUpdateHelper.checkForImmediateUpdate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
      if ((!tenant.hasLoadedPermissions || tenant.isLoading) && !tenant.isTenantAdmin) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Loading workspace modules...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Setting up permissions for ${tenant.activeTenant?.companyName ?? "your organization"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const DashboardScreen();
    }

    return const TenantSelectorScreen();
  }
}
