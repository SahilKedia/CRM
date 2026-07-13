import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../services/api_service.dart'; // Import your API service

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _agreeToTerms = false;
  int _currentStep = 0;

  // Branch related variables
  String? _selectedBranchId;
  bool _isLoadingBranches = false;
  List<Map<String, dynamic>> _branches = [];
  String? _branchErrorMessage;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
      _branchErrorMessage = null;
    });

    try {
      // Try to get branches with authentication
      final response = await _apiService.getBranches();

      print("==============");
      print("Branches Response: $response");
      print("==============");

      // Check if the response is successful
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          // Extract branches data
          List<dynamic> branchData = [];

          if (response['data'] != null && response['data'] is List) {
            branchData = response['data'];
          } else if (response['branches'] != null && response['branches'] is List) {
            branchData = response['branches'];
          }

          if (branchData.isNotEmpty) {
            setState(() {
              _branches = List<Map<String, dynamic>>.from(branchData);
              if (_branches.isNotEmpty) {
                _selectedBranchId = _branches.first["_id"]?.toString() ??
                                   _branches.first["id"]?.toString();
              }
              _isLoadingBranches = false;
              _branchErrorMessage = null;
            });
            print("✅ Loaded ${_branches.length} branches successfully");
          } else {
            setState(() {
              _isLoadingBranches = false;
              _branchErrorMessage = "No branches found in the system";
            });
          }
        } else {
          // If authentication failed or other error
          String errorMsg = response['message'] ?? 'Failed to load branches';

          // Check if it's an authentication error
          if (errorMsg.toLowerCase().contains('authentication') ||
              errorMsg.toLowerCase().contains('login again') ||
              errorMsg.toLowerCase().contains('token')) {
            errorMsg = '⚠️ Authentication required. Please login first to load branches.';
          }

          setState(() {
            _isLoadingBranches = false;
            _branchErrorMessage = errorMsg;
          });
        }
      } else {
        setState(() {
          _isLoadingBranches = false;
          _branchErrorMessage = "Invalid response format from server";
        });
      }
    } catch (e) {
      print("❌ Error loading branches: $e");
      setState(() {
        _isLoadingBranches = false;
        _branchErrorMessage = "Error: ${e.toString()}";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not load branches: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to Terms & Privacy Policy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final signupPayload = {
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        "phone": _phoneController.text.trim(),
        "company": _companyController.text.trim(),
        "branch": _selectedBranchId,
        "role": _selectedRole.toLowerCase(),
      };

      // 👉 DEBUG: see exactly what is being sent
      print("📦 Signup Payload: $signupPayload");
      print("🎭 Selected Role (dropdown): $_selectedRole");

      // Uses ApiService so it goes through the same base URL (with port)
      // and error handling as every other request in the app, instead of
      // a hand-rolled URL that was missing the :5000 port.
      final data = await _apiService.signup(signupPayload);

      print("📥 Signup Response: $data");

      setState(() => _isLoading = false);

      if (data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Account created successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Signup Failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate step 1 fields
      if (_nameController.text.isEmpty ||
          _companyController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Check if branches are loaded
      if (_isLoadingBranches) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait while branches are loading...'),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }

      if (_branches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No branches available. Please contact support.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedBranchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a branch'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    setState(() => _currentStep = 1);
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
              const SizedBox(height: 16),

              // Back button + progress
              _buildTopBar(),

              const SizedBox(height: 32),

              // Header
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _currentStep == 0
                    ? 'Tell us about yourself'
                    : 'Set up your login credentials',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Step indicator
              _buildStepIndicator(),

              const SizedBox(height: 28),

              // Form
              Form(
                key: _formKey,
                child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
              ),

              const SizedBox(height: 24),

              // Action button
              if (_currentStep == 0)
                ElevatedButton(
                  onPressed: _nextStep,
                  child: const Text('Continue'),
                )
              else
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),

              const SizedBox(height: 24),

              // Sign in link
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'Already have an account? ',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign in',
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

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _currentStep == 1
              ? () => setState(() => _currentStep = 0)
              : () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppColors.textPrimary),
          ),
        ),
        const Spacer(),
        Text(
          'Step ${_currentStep + 1} of 2',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(2, (i) {
        final isActive = i <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        CrmTextField(
          label: 'Full name',
          hint: 'e.g. Sunidhi Sharma',
          prefixIcon: Icons.person_outline,
          controller: _nameController,
          validator: (v) =>
              v == null || v.isEmpty ? 'Full name is required' : null,
        ),
        const SizedBox(height: 16),
        CrmTextField(
          label: 'Company name',
          hint: 'e.g. DigitalMonk',
          prefixIcon: Icons.business_outlined,
          controller: _companyController,
          validator: (v) =>
              v == null || v.isEmpty ? 'Company name is required' : null,
        ),
        const SizedBox(height: 16),

        // Branch dropdown - loading from database
        _buildBranchDropdown(),
        const SizedBox(height: 16),

        // Role selector
        _buildRoleSelector(),
      ],
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Branch / Location *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),

        _isLoadingBranches
            ? Container(
                height: 55,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading branches...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _branchErrorMessage != null
                        ? Colors.red
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  hint: Text(
                    _branches.isEmpty ? "No branches available" : "Select Branch",
                    style: TextStyle(
                      color: _branches.isEmpty ? Colors.red : AppColors.textSecondary,
                    ),
                  ),
                  items: _branches.map((branch) {
                    // Try different field names for name and city
                    final name = branch["name"]?.toString() ??
                                branch["branchName"]?.toString() ??
                                branch["branch_name"]?.toString() ??
                                "Unknown Branch";
                    final city = branch["city"]?.toString() ??
                                branch["location"]?.toString() ??
                                branch["address"]?.toString() ??
                                "";
                    final id = branch["_id"]?.toString() ??
                              branch["id"]?.toString() ??
                              branch["branchId"]?.toString() ??
                              "";

                    final displayName = city.isNotEmpty
                        ? "$name ($city)"
                        : name;

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _branches.isEmpty ? null : (value) {
                    setState(() {
                      _selectedBranchId = value;
                    });
                  },
                  validator: (value) {
                    if (_branches.isEmpty) {
                      return "No branches available";
                    }
                    if (value == null || value.isEmpty) {
                      return "Please select a branch";
                    }
                    return null;
                  },
                ),
              ),

        if (_branchErrorMessage != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _branchErrorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Retry button if there's an error
        if (_branchErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _loadBranches,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Loading Branches'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
      ],
    );
  }

  String _selectedRole = 'Admin';
  final _roles = [
    'Employee',
    'Admin',
    'Super-Admin',
  ];

  Widget _buildRoleSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: const InputDecoration(
        labelText: 'Job title',
        prefixIcon:
            Icon(Icons.badge_outlined, color: AppColors.textSecondary, size: 20),
      ),
      items: _roles
          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
          .toList(),
      onChanged: (v) => setState(() => _selectedRole = v!),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        CrmTextField(
          label: 'Work email',
          hint: 'you@company.com',
          prefixIcon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CrmTextField(
          label: 'Phone number',
          hint: 'e.g. +919876543210',
          prefixIcon: Icons.phone_outlined,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Phone number is required';
            if (v.trim().length < 10) return 'Enter a valid phone number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CrmTextField(
          label: 'Password',
          hint: 'Min. 8 characters',
          prefixIcon: Icons.lock_outline,
          controller: _passwordController,
          isPassword: true,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 8) return 'Minimum 8 characters required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CrmTextField(
          label: 'Confirm password',
          hint: 'Re-enter your password',
          prefixIcon: Icons.lock_outline,
          controller: _confirmPasswordController,
          isPassword: true,
          textInputAction: TextInputAction.done,
          validator: (v) {
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Password strength indicator
        _buildPasswordStrength(),

        const SizedBox(height: 20),

        // Terms checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _agreeToTerms,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  text: 'I agree to the ',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) strength++;

    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      AppColors.border,
      AppColors.error,
      Colors.orange,
      Colors.amber,
      AppColors.success,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? colors[strength] : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        if (password.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Password strength: ${labels[strength]}',
            style: TextStyle(
              fontSize: 12,
              color: colors[strength],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
