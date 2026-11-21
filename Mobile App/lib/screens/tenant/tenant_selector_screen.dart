import 'package:flutter/material.dart';
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
  final _newOrgController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

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

  @override
  void dispose() {
    _newOrgController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTenant() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _newOrgController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    final tenantProvider = context.read<TenantProvider>();
    final authProvider = context.read<AuthProvider>();

    final created = await tenantProvider.createTenant(name);
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (created != null) {
      final currentList = List<TenantOption>.from(authProvider.availableTenants);
      currentList.add(created);
      authProvider.updateAvailableTenants(currentList);

      await tenantProvider.selectTenant(created);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tenantProvider.errorMessage ?? 'Failed to create organization'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tenantProvider = context.watch<TenantProvider>();
    final user = authProvider.user;

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circular Icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          size: 36,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // User greeting chip
                      if (user != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                '@${user.userName.isNotEmpty ? user.userName : user.fullName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Heading
                      const Text(
                        'You are not in any organization',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        'To begin managing products, batches, purchase orders and cold rooms, register a new organization workspace.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Input field
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ORGANIZATION / COMPANY NAME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newOrgController,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Cyan Cold Chain Logistics',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(Icons.business, color: Color(0xFF94A3B8), size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF04482D), width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your organization name';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF04482D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isCreating ? null : _handleCreateTenant,
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_business_rounded, size: 20),
                          label: Text(
                            _isCreating ? 'Creating Workspace...' : 'Create New Organization',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
