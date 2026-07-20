import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../models/employee_model.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool _isLoading = false;
  String _selectedDepartment = 'Sales';

  // Country codes for phone number & emergency contact.
  // Each field has its own, in case the employee's emergency contact
  // is in a different country. Defaults to India (+91).
  String _phoneCountryCode = '+91';
  String _emergencyCountryCode = '+91';

  final List<String> _departments = [
    'Sales',
    'Marketing',
    'Finance',
  ];

  String? _selectedBranch;
  bool _isLoadingBranches = false;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final response = await ApiService().getBranches();

      print("==============");
      print(response);
      print("==============");

      List<dynamic> branchList = [];

      if (response is List) {
        branchList = response;
      } else if (response is Map<String, dynamic>) {
        if (response["branches"] != null) {
          branchList = response["branches"];
        } else if (response["data"] != null) {
          branchList = response["data"];
        } else if (response["success"] == true &&
            response["data"] is List) {
          branchList = response["data"];
        }
      }

      setState(() {
        _branches = List<Map<String, dynamic>>.from(branchList);

        if (_branches.isNotEmpty) {
          _selectedBranch = _branches.first["_id"].toString();
        }

        _isLoadingBranches = false;
      });

      print(_branches);
    } catch (e) {
      print(e);

      setState(() {
        _isLoadingBranches = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _addEmployee() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();

      // Prepare employee data - matches Node.js Employee schema exactly
      final Map<String, dynamic> employeeData = {
        'name': _nameController.text.trim(),
        // Store phone with country code prefixed, e.g. +919876543210
        'phone': '$_phoneCountryCode${_phoneController.text.trim()}',
        'department': _selectedDepartment,
        'branch': _selectedBranch,
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim().isEmpty
            ? ''
            : '$_emergencyCountryCode${_emergencyContactController.text.trim()}',
      };

      // Only add email if it's not empty (schema allows sparse/optional email)
      if (_emailController.text.trim().isNotEmpty) {
        employeeData['email'] = _emailController.text.trim();
      }

      print('📤 Sending employee data: $employeeData');

      final response = await apiService.createEmployee(employeeData);

      print('📥 Response: $response');

      if (response['success'] == true) {
        final employeeDataResponse = response['data'];
        final employee = Employee.fromJson(employeeDataResponse);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${employee.name} added successfully!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );

          Navigator.pop(context, employee);
        }
      } else {
        final errorMessage = response['message'] ?? 'Failed to add employee';
        print('❌ API Error: $errorMessage');
        print('❌ Response: $response');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding employee: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Employee',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _addEmployee,
            child: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Adding employee...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Section
                    // _buildProfilePictureSection(),
                    const SizedBox(height: 24),

                    // Personal Information
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name - Required
                    CrmTextField(
                      label: 'Full Name *',
                      hint: 'Enter employee name',
                      prefixIcon: Icons.person,
                      controller: _nameController,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Email - Optional
                    CrmTextField(
                      label: 'Email Address (Optional)',
                      hint: 'employee@company.com',
                      prefixIcon: Icons.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return null; // Optional
                        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(v!.trim())) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Phone - Required (must be unique in DB), with country code
                    _buildPhoneField(
                      label: 'Phone Number *',
                      controller: _phoneController,
                      required: true,
                      countryCode: _phoneCountryCode,
                      onCountryChanged: (code) {
                        setState(() => _phoneCountryCode = code);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Address - Optional
                    CrmTextField(
                      label: 'Address (Optional)',
                      hint: 'Street address',
                      prefixIcon: Icons.location_on,
                      controller: _addressController,
                    ),
                    const SizedBox(height: 12),

                    // Emergency Contact - Optional, with country code
                    _buildPhoneField(
                      label: 'Emergency Contact (Optional)',
                      controller: _emergencyContactController,
                      required: false,
                      countryCode: _emergencyCountryCode,
                      onCountryChanged: (code) {
                        setState(() => _emergencyCountryCode = code);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Employment Information
                    const Text(
                      'Employment Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Department - Required
                    _buildDropdownField(
                      label: 'Department *',
                      value: _selectedDepartment,
                      items: _departments,
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value!;
                        });
                      },
                      icon: Icons.business_center,
                      validator: (v) => v == null ? 'Please select a department' : null,
                    ),
                    const SizedBox(height: 12),

                    // Branch - Required
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Branch *',
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
                                child: const CircularProgressIndicator(),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBranch,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  hint: const Text("Select Branch"),
                                  items: _branches.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch["_id"].toString(),
                                      child: Text(
                                        "${branch["name"]} (${branch["city"]})",
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBranch = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Please select a branch";
                                    }
                                    return null;
                                  },
                                ),
                              ),

                        if (!_isLoadingBranches && _branches.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              "No branches found.",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addEmployee,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add Employee',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget _buildProfilePictureSection() {
  //   return Center(
  //     child: Column(
  //       children: [
  //         Stack(
  //           children: [
  //             Container(
  //               width: 100,
  //               height: 100,
  //               decoration: BoxDecoration(
  //                 shape: BoxShape.circle,
  //                 color: AppColors.primary.withOpacity(0.1),
  //                 border: Border.all(
  //                   color: AppColors.primary,
  //                   width: 2,
  //                 ),
  //               ),
  //               child: const Icon(
  //                 Icons.person,
  //                 size: 50,
  //                 color: AppColors.primary,
  //               ),
  //             ),
  //             Positioned(
  //               bottom: 0,
  //               right: 0,
  //               child: Container(
  //                 width: 30,
  //                 height: 30,
  //                 decoration: BoxDecoration(
  //                   shape: BoxShape.circle,
  //                   color: AppColors.primary,
  //                 ),
  //                 child: const Icon(
  //                   Icons.camera_alt,
  //                   color: Colors.white,
  //                   size: 16,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 8),
  //         const Text(
  //           'Tap to upload photo',
  //           style: TextStyle(
  //             fontSize: 12,
  //             color: AppColors.textSecondary,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// Phone-style field with a changeable country code picker on the left
  /// (using the country_code_picker package) and an input that only
  /// accepts digits, capped at exactly 10.
  Widget _buildPhoneField({
    required String label,
    required TextEditingController controller,
    required bool required,
    required String countryCode,
    required ValueChanged<String> onCountryChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Country code picker (tap to change country/dial code)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.border),
                  ),
                ),
                child: CountryCodePicker(
                  onChanged: (country) {
                    // country.dialCode already includes the '+', e.g. "+91"
                    onCountryChanged(country.dialCode ?? '+91');
                  },
                  initialSelection: 'IN',
                  favorite: const ['+91', 'IN', '+1', 'US'],
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  showFlag: true,
                  showFlagMain: true,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Digits-only input, max 10 digits
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '', // hides the default character counter
                    hintText: 'Enter exactly 10 digits',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (required && value.isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.isNotEmpty && value.length != 10) {
                      return 'Enter exactly 10 digits';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selected code: $countryCode',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(item),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator ?? (v) => v == null ? 'Please select a value' : null,
          ),
        ),
      ],
    );
  }
}