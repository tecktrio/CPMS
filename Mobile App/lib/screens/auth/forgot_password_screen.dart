import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

enum ForgotPasswordStep {
  enterUsername,
  findUsernames,
  verifyAndReset,
}

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialUsername;
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialUsername,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameFormKey = GlobalKey<FormState>();
  final _emailLookupFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailLookupController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ForgotPasswordStep _currentStep = ForgotPasswordStep.enterUsername;
  List<Map<String, dynamic>> _foundUsers = [];
  String? _maskedEmail;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      if (widget.initialUsername!.contains('@')) {
        _emailLookupController.text = widget.initialUsername!;
      } else {
        _usernameController.text = widget.initialUsername!;
      }
    }
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailLookupController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailLookupController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetCode([String? usernameToReset]) async {
    final username = (usernameToReset ?? _usernameController.text).trim().toLowerCase();
    if (username.isEmpty) {
      if (!_usernameFormKey.currentState!.validate()) return;
      return;
    }

    _usernameController.text = username;

    final auth = context.read<AuthProvider>();
    final result = await auth.requestPasswordReset(username);
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _maskedEmail = result['masked_email'] ?? result['email_address'];
        _currentStep = ForgotPasswordStep.verifyAndReset;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _maskedEmail != null
                ? 'Verification code sent to registered email ($_maskedEmail)'
                : 'Verification code sent to registered email address for @$username',
          ),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to send reset code'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleFindUsernames() async {
    if (!_emailLookupFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _emailLookupController.text.trim().toLowerCase();

    final users = await auth.findUsernamesByEmail(email);
    if (!mounted) return;

    if (users != null && users.isNotEmpty) {
      setState(() {
        _foundUsers = users;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${users.length} username(s) associated with $email'),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    } else {
      setState(() => _foundUsers = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'No accounts found for this email address'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final username = _usernameController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();
    final newPassword = _passwordController.text;

    final success = await auth.resetPassword(
      username: username,
      otpCode: otp,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Password reset failed'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    String appBarTitle;
    switch (_currentStep) {
      case ForgotPasswordStep.enterUsername:
        appBarTitle = 'Reset Password';
        break;
      case ForgotPasswordStep.findUsernames:
        appBarTitle = 'Find Usernames';
        break;
      case ForgotPasswordStep.verifyAndReset:
        appBarTitle = 'Set New Password';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_currentStep == ForgotPasswordStep.verifyAndReset) {
              setState(() => _currentStep = ForgotPasswordStep.enterUsername);
            } else if (_currentStep == ForgotPasswordStep.findUsernames) {
              setState(() => _currentStep = ForgotPasswordStep.enterUsername);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildCurrentStep(auth),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AuthProvider auth) {
    switch (_currentStep) {
      case ForgotPasswordStep.enterUsername:
        return _buildUsernameForm(auth);
      case ForgotPasswordStep.findUsernames:
        return _buildFindUsernamesForm(auth);
      case ForgotPasswordStep.verifyAndReset:
        return _buildResetForm(auth);
    }
  }

  // -------------------------------------------------------------
  // STEP 1: Enter Username Form
  // -------------------------------------------------------------
  Widget _buildUsernameForm(AuthProvider auth) {
    return Form(
      key: _usernameFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.lock_reset_rounded,
                size: 34,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your username and we will send a 6-digit verification code to the registered email address.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 24),

          // Username Field
          const Text(
            'USERNAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            keyboardType: TextInputType.text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. johndoe',
              prefixIcon: const Icon(Icons.alternate_email, size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Option: Forgot Username? Find by email
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() {
                  _foundUsers = [];
                  _currentStep = ForgotPasswordStep.findUsernames;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 16, color: Color(0xFF0F766E)),
                    SizedBox(width: 6),
                    Text(
                      'Forgot your username? Find by email',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Send Reset Code Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: auth.isLoading ? null : () => _handleSendResetCode(),
            child: auth.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Send Reset Code',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 16),

          // Back to Sign In
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Back to Sign In',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: Find Usernames by Email Form
  // -------------------------------------------------------------
  Widget _buildFindUsernamesForm(AuthProvider auth) {
    return Form(
      key: _emailLookupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.person_search_outlined,
                size: 34,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Find Your Username',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered email address to retrieve all usernames associated with your account.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 24),

          // Email Input
          const Text(
            'REGISTERED EMAIL ADDRESS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailLookupController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'operator@example.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email address is required';
              if (!val.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Find Usernames Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: auth.isLoading ? null : _handleFindUsernames,
            child: auth.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Find Usernames',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 16),

          // Found Usernames List
          if (_foundUsers.isNotEmpty) ...[
            const Divider(color: Color(0xFFE2E8F0), height: 32),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text(
                  'Accounts Assigned (${_foundUsers.length}):',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap any account below to send a reset code and reset password:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _foundUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final u = _foundUsers[index];
                final uName = u['user_name'] ?? '';
                final fName = u['full_name'] ?? uName;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _handleSendResetCode(uName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                          child: Text(
                            uName.isNotEmpty ? uName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@$uName',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 20),

          // Back to Username Screen
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() => _currentStep = ForgotPasswordStep.enterUsername);
              },
              icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF64748B)),
              label: const Text(
                'Back to Username Reset',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 3: Verify OTP and Set New Password Form
  // -------------------------------------------------------------
  Widget _buildResetForm(AuthProvider auth) {
    final username = _usernameController.text.trim();

    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF99F6E4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mark_email_read_outlined, color: Color(0xFF0F766E), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resetting Password for: @$username',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _maskedEmail != null
                            ? 'Verification code sent to registered email ($_maskedEmail)'
                            : 'A 6-digit code was sent to the email associated with this username.',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OTP Code
          const Text(
            '6-DIGIT VERIFICATION CODE *',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '••••••',
              counterText: '',
              prefixIcon: const Icon(Icons.password, size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().length != 6) {
                return 'Enter the complete 6-digit code';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // New Password
          const Text(
            'NEW PASSWORD *',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Confirm Password
          const Text(
            'CONFIRM NEW PASSWORD *',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (val) {
              if (val != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 26),

          // Submit Reset Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: auth.isLoading ? null : _handleResetPassword,
            child: auth.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Reset Password & Sign In',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 16),

          // Change Username or Resend Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _currentStep = ForgotPasswordStep.enterUsername);
                },
                child: const Text(
                  'Change Username',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: auth.isLoading ? null : () => _handleSendResetCode(),
                child: const Text(
                  'Resend Code',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
