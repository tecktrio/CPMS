import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../dashboard/dashboard_screen.dart';

class TenantSelectorScreen extends StatefulWidget {
  const TenantSelectorScreen({super.key});

  @override
  State<TenantSelectorScreen> createState() => _TenantSelectorScreenState();
}

class _TenantSelectorScreenState extends State<TenantSelectorScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final tenantProvider = context.read<TenantProvider>();
      if (auth.availableTenants.isNotEmpty) {
        tenantProvider.selectTenant(auth.availableTenants.first).then((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          }
        });
      }
    });
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final authProvider = context.read<AuthProvider>();
    final tenantProvider = context.read<TenantProvider>();

    final tenants = await authProvider.refreshAvailableTenants();

    if (!mounted) return;
    setState(() => _isRefreshing = false);

    if (tenants.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization found! Loading workspace...'),
          backgroundColor: Color(0xFF04482D),
        ),
      );
      await tenantProvider.selectTenant(tenants.first);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      final username = authProvider.user?.userName ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            username.isNotEmpty
                ? 'No organization assigned yet. Please contact your tenant admin to add @$username.'
                : 'No organization assigned yet. Please contact your tenant admin to add your username.',
          ),
          backgroundColor: const Color(0xFF0F172A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tenantProvider = context.watch<TenantProvider>();
    final user = authProvider.user;
    final availableTenants = authProvider.availableTenants;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'CPMS Workspace',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.black),
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
            onPressed: () async {
              tenantProvider.clear();
              await authProvider.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF04482D),
          onRefresh: _handleRefresh,
          child: Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: availableTenants.isNotEmpty
                        ? _buildTenantList(availableTenants, tenantProvider)
                        : _buildNoOrganizationView(user),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoOrganizationView(dynamic user) {
    final userName = user != null && user.userName.isNotEmpty
        ? user.userName
        : (user?.fullName ?? '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular Icon
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
          ),
          child: const Icon(
            Icons.domain_verification_rounded,
            size: 38,
            color: Color(0xFF16A34A),
          ),
        ),
        const SizedBox(height: 20),

        // User Username Pill with tap to copy
        if (userName.isNotEmpty)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: userName));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Username @$userName copied to clipboard'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF04482D),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alternate_email, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),

        // Title
        const Text(
          'No Organization Assigned',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),

        // Description instructing user to contact tenant admin
        Text(
          userName.isNotEmpty
              ? 'Contact your tenant admin to add your username (@$userName) to your organization\'s workspace.'
              : 'Contact your tenant admin to add your username to your organization\'s workspace.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        // Info notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Once your administrator adds your account in the system, tap the refresh button below to enter your workspace.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Refresh Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isRefreshing ? null : _handleRefresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              _isRefreshing ? 'Checking Status...' : 'Refresh Status',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sign Out link
        Center(
          child: TextButton.icon(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final tenantProvider = context.read<TenantProvider>();
              tenantProvider.clear();
              await authProvider.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
            },
            icon: const Icon(Icons.logout, size: 16, color: Color(0xFF64748B)),
            label: const Text(
              'Sign Out / Switch Account',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTenantList(List<TenantOption> tenants, TenantProvider tenantProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Organization',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a workspace to continue',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        ...tenants.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              title: Text(
                t.companyName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              subtitle: t.isAdmin
                  ? const Text('Administrator', style: TextStyle(fontSize: 11, color: Color(0xFF04482D), fontWeight: FontWeight.w600))
                  : null,
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              onTap: () async {
                await tenantProvider.selectTenant(t);
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              },
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isRefreshing ? null : _handleRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh Organizations', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
