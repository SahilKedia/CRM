// screens/save_employee_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../models/employee_model.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';

class SaveEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic>? employee; // Pass this context parameter when modifying data

  const SaveEmployeeScreen({super.key, this.employee});

  @override
  State<SaveEmployeeScreen> createState() => _SaveEmployeeScreenState();
}

class _SaveEmployeeScreenState extends State<SaveEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool _isLoading = false;
  String _selectedDepartment = 'Sales';
  String? _selectedBranch;
  bool _isLoadingBranches = false;
  List<Map<String, dynamic>> _branches = [];

  // Country codes for phone number & emergency contact.
  // Each field has its own, in case the emergency contact is in a
  // different country. Defaults to India (+91).
  String _phoneCountryCode = '+91';
  String _emergencyCountryCode = '+91';

  bool get isEditMode => widget.employee != null;

  final List<String> _departments = ['Sales', 'Marketing', 'Finance'];

  @override
  void initState() {
    super.initState();
    _loadBranchesAndInitialize();
  }

  Future<void> _loadBranchesAndInitialize() async {
    setState(() => _isLoadingBranches = true);
    try {
      final response = await ApiService().getBranches();
      List<dynamic> branchList = [];

      if (response is List) {
        branchList = response;
      } else if (response is Map<String, dynamic>) {
        branchList = response["branches"] ?? response["data"] ?? [];
      }

      setState(() {
        _branches = List<Map<String, dynamic>>.from(branchList);
        _initializeFormData();
        _isLoadingBranches = false;
      });
    } catch (e) {
      setState(() => _isLoadingBranches = false);
    }
  }

  /// Splits a stored phone string like "+919876543210" into a country
  /// code ("+91") and the last-10-digit local number ("9876543210").
  /// Falls back to the default +91 code if the stored value has no
  /// '+' prefix (covers old records saved before country codes existed)
  /// or isn't long enough to safely split.
  Map<String, String> _splitPhone(String? raw, String defaultCode) {
    final value = (raw ?? '').trim();

    if (value.isEmpty) {
      return {'code': defaultCode, 'number': ''};
    }

    // Strip spaces/dashes that may exist in older saved data.
    final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');

    if (cleaned.startsWith('+') && cleaned.length > 10) {
      final number = cleaned.substring(cleaned.length - 10);
      final code = cleaned.substring(0, cleaned.length - 10);
      // Only accept if what's left of the number part is all digits.
      if (RegExp(r'^\d{10}$').hasMatch(number)) {
        return {'code': code, 'number': number};
      }
    }

    // No usable '+' country code found — assume it's a plain local
    // number saved before country codes were introduced.
    final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
    final last10 = digitsOnly.length >= 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    return {'code': defaultCode, 'number': last10};
  }

  void _initializeFormData() {
    if (isEditMode && widget.employee != null) {
      final emp = widget.employee!;
      _nameController.text = emp['name'] ?? '';
      _emailController.text = emp['email'] ?? '';
      _addressController.text = emp['address'] ?? '';

      final phoneParts = _splitPhone(emp['phone'], _phoneCountryCode);
      _phoneCountryCode = phoneParts['code']!;
      _phoneController.text = phoneParts['number']!;

      final emergencyParts =
          _splitPhone(emp['emergencyContact'], _emergencyCountryCode);
      _emergencyCountryCode = emergencyParts['code']!;
      _emergencyContactController.text = emergencyParts['number']!;

      if (_departments.contains(emp['department'])) {
        _selectedDepartment = emp['department'];
      }

      if (emp['branch'] != null) {
        if (emp['branch'] is Map) {
          _selectedBranch = emp['branch']['_id']?.toString();
        } else {
          _selectedBranch = emp['branch'].toString();
        }
      }
    } else if (_branches.isNotEmpty) {
      _selectedBranch = _branches.first["_id"].toString();
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

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();

      final Map<String, dynamic> employeeData = {
        'name': _nameController.text.trim(),
        'phone': '$_phoneCountryCode${_phoneController.text.trim()}',
        'department': _selectedDepartment,
        'branch': _selectedBranch,
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim().isEmpty
            ? ''
            : '$_emergencyCountryCode${_emergencyContactController.text.trim()}',
      };

      if (_emailController.text.trim().isNotEmpty) {
        employeeData['email'] = _emailController.text.trim();
      }

      Map<String, dynamic> response;
      if (isEditMode) {
        response = await apiService.updateEmployee(widget.employee!['_id'], employeeData);
      } else {
        response = await apiService.createEmployee(employeeData);
      }

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditMode ? 'Employee updated successfully!' : 'Employee added successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final errorMessage = response['message'] ?? 'Action failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $errorMessage'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exception dynamic error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Employee' : 'Add New Employee', style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEmployee,
            child: Text(
              isEditMode ? 'UPDATE' : 'SAVE',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Saving profile details...', style: TextStyle(color: AppColors.textSecondary)),
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
                    _buildProfilePictureSection(),
                    const SizedBox(height: 24),
                    const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    CrmTextField(
                      label: 'Full Name *',
                      hint: 'Enter employee name',
                      prefixIcon: Icons.person,
                      controller: _nameController,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    CrmTextField(
                      label: 'Email Address (Optional)',
                      hint: 'employee@company.com',
                      prefixIcon: Icons.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return null;
                        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!.trim())) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Phone - Required, with changeable country code + 10-digit limit
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

                    CrmTextField(
                      label: 'Address (Optional)',
                      hint: 'Street address',
                      prefixIcon: Icons.location_on,
                      controller: _addressController,
                    ),
                    const SizedBox(height: 12),

                    // Emergency Contact - Optional, with changeable country code + 10-digit limit
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
                    const Text('Work assignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Department *',
                      value: _selectedDepartment,
                      items: _departments,
                      onChanged: (value) => setState(() => _selectedDepartment = value!),
                      icon: Icons.business_center,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Branch *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        _isLoadingBranches
                            ? Container(
                                height: 55,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                                child: const CircularProgressIndicator(),
                              )
                            : Container(
                                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBranch,
                                  isExpanded: true,
                                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                                  hint: const Text("Select Branch"),
                                  items: _branches.map((branch) {
                                    return DropdownMenuItem<String>(
                                      value: branch["_id"].toString(),
                                      child: Text("${branch["name"]} (${branch["city"]})", overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(() => _selectedBranch = value),
                                  validator: (value) => value == null || value.isEmpty ? "Please select a branch" : null,
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveEmployee,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isEditMode ? 'Update Employee details' : 'Add Employee',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(Icons.person, size: 50, color: AppColors.primary),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Tap to upload photo', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(item, style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}