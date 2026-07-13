import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'superadmin_dashboard_screen.dart';
import 'employee_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum LoginMode { admin, employee }

class _LoginScreenState extends State<LoginScreen> {
  // ---- Admin login controllers/state ----
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  // ---- Employee login controllers/state ----
  final _employeeFormKey = GlobalKey<FormState>();
  final _employeeEmailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isEmployeeLoading = false;
  bool _otpSent = false; // step 1 done -> show OTP field
  int _resendSeconds = 0;

  // ---- Which tab is active ----
  LoginMode _mode = LoginMode.admin;

  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  // ---------------------------------------------------------------
  // Load saved email/password (if Remember Me was checked earlier)
  // ---------------------------------------------------------------
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe) {
        final savedEmail = prefs.getString('saved_email') ?? '';
        final savedPassword =
            await _secureStorage.read(key: 'saved_password') ?? '';

        if (mounted) {
          setState(() {
            _rememberMe = true;
            _emailController.text = savedEmail;
            _passwordController.text = savedPassword;
          });
        }
      }
    } catch (e) {
      print('⚠️ Could not load saved credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_email', _emailController.text.trim());
      await _secureStorage.write(
        key: 'saved_password',
        value: _passwordController.text.trim(),
      );
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
      await _secureStorage.delete(key: 'saved_password');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _employeeEmailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // ADMIN LOGIN (unchanged)
  // ---------------------------------------------------------------
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();

      final payload = {
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      };
      print("📦 Login Payload: $payload");

      final response = await apiService.login(
        payload["email"]!,
        payload["password"]!,
      );

      print("📥 Login Response: $response");

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response["success"] == true) {
        await _saveCredentials();
        _navigateAfterLogin(response["user"]);
      } else {
        _showError(response["message"] ?? "Login failed");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError("Login failed: $e");
    }
  }

  // ---------------------------------------------------------------
  // EMPLOYEE LOGIN - STEP 1: send OTP to email
  // ---------------------------------------------------------------
  Future<void> _handleSendOtp() async {
    final email = _employeeEmailController.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your registered email");
      return;
    }
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError("Enter a valid email");
      return;
    }

    setState(() => _isEmployeeLoading = true);

    try {
      final apiService = ApiService();
      final response = await apiService.employeeSendOtp(email);

      print("📥 Send OTP Response: $response");

      if (!mounted) return;
      setState(() => _isEmployeeLoading = false);

      if (response["success"] == true) {
        setState(() {
          _otpSent = true;
          _resendSeconds = 30;
        });
        _startResendTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP sent to your email"),
            backgroundColor: Colors.green,
          ),
        );

        // Dev mode fallback — backend agar OTP wapas bhejta hai (SMTP not configured),
        // to convenience ke liye field me pre-fill kar do
        if (response["otp"] != null) {
          _otpController.text = response["otp"].toString();
        }
      } else {
        _showError(response["message"] ?? "Failed to send OTP");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEmployeeLoading = false);
      _showError("Failed to send OTP: $e");
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
        _startResendTimer();
      }
    });
  }

  // ---------------------------------------------------------------
  // EMPLOYEE LOGIN - STEP 2: verify OTP
  // ---------------------------------------------------------------
  Future<void> _handleVerifyOtp() async {
    final email = _employeeEmailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showError("Please enter the OTP");
      return;
    }

    setState(() => _isEmployeeLoading = true);

    try {
      final apiService = ApiService();
      final response = await apiService.employeeVerifyOtp(email, otp);

      print("📥 Verify OTP Response: $response");

      if (!mounted) return;
      setState(() => _isEmployeeLoading = false);

      if (response["success"] == true) {
        _navigateAfterLogin(response["user"]);
      } else {
        _showError(response["message"] ?? "Invalid OTP");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEmployeeLoading = false);
      _showError("Verification failed: $e");
    }
  }

  // ---------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------
 void _navigateAfterLogin(Map<String, dynamic> userData) {
  final role = (userData["role"] ?? "").toString().trim().toLowerCase();

  if (role == "employee") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeDashboardScreen(user: userData),
      ),
    );
  } else if (role == "admin") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(user: userData),
      ),
    );
  } else if (role == "superadmin") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SuperAdminDashboardScreen(user: userData),
      ),
    );
  } else {
    _showError("Unknown role");
  }
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              _buildHeader(),

              const SizedBox(height: 40),

              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to your CRM account',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // 👇 NEW — Admin / Employee toggle
              _buildModeToggle(),

              const SizedBox(height: 28),

              // 👇 Conditional form based on selected mode
              _mode == LoginMode.admin
                  ? _buildAdminLoginForm()
                  : _buildEmployeeLoginForm(),

              const SizedBox(height: 32),

              // Sign up link — only relevant for admin
              if (_mode == LoginMode.admin)
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      children: [
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            ),
                            child: const Text(
                              'Create account',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // NEW — Admin / Employee toggle widget
  // ---------------------------------------------------------------
  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Login as Admin',
              selected: _mode == LoginMode.admin,
              onTap: () => setState(() => _mode = LoginMode.admin),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              label: 'Login as Employee',
              selected: _mode == LoginMode.employee,
              onTap: () => setState(() => _mode = LoginMode.employee),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // ADMIN FORM (email + password) — same as before
  // ---------------------------------------------------------------
  Widget _buildAdminLoginForm() {
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              CrmTextField(
                label: 'Email address',
                hint: 'you@company.com',
                prefixIcon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(v)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CrmTextField(
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to forgot password
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // NEW — EMPLOYEE FORM (email -> OTP -> verify)
  // ---------------------------------------------------------------
  Widget _buildEmployeeLoginForm() {
    return Form(
      key: _employeeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrmTextField(
            label: 'Registered email',
            hint: 'employee@company.com',
            prefixIcon: Icons.email_outlined,
            controller: _employeeEmailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_otpSent, // OTP bhejne ke baad email lock kar do
          ),
          const SizedBox(height: 16),

          if (_otpSent) ...[
            CrmTextField(
              label: 'Enter OTP',
              hint: '6-digit code sent to your email',
              prefixIcon: Icons.lock_clock_outlined,
              controller: _otpController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _resendSeconds > 0
                      ? 'Resend OTP in ${_resendSeconds}s'
                      : "Didn't get the code?",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 6),
                if (_resendSeconds == 0)
                  GestureDetector(
                    onTap: _isEmployeeLoading ? null : _handleSendOtp,
                    child: const Text(
                      'Resend',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isEmployeeLoading
                  ? null
                  : (_otpSent ? _handleVerifyOtp : _handleSendOtp),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isEmployeeLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _otpSent ? 'Verify & Sign In' : 'Send OTP',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          if (_otpSent) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _otpSent = false;
                    _otpController.clear();
                  });
                },
                child: const Text(
                  'Use a different email',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/logo.jpg',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'CRM',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}