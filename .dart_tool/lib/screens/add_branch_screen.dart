import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../services/api_service.dart';
import 'branch_list_screen.dart';

class AddBranchScreen extends StatefulWidget {
  final Map<String, dynamic>? branch; // pass this for edit mode

  const AddBranchScreen({Key? key, this.branch}) : super(key: key);

  @override
  State<AddBranchScreen> createState() => _AddBranchScreenState();
}

class _AddBranchScreenState extends State<AddBranchScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _phoneController;

  bool _isLoading = false;
  bool get _isEditMode => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameController = TextEditingController(text: b?['name'] ?? '');
    _addressController = TextEditingController(text: b?['address'] ?? '');
    _cityController = TextEditingController(text: b?['city'] ?? '');
    _stateController = TextEditingController(text: b?['state'] ?? '');
    _phoneController = TextEditingController(text: b?['phone'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      final data = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      final response = _isEditMode
          ? await apiService.updateBranch(widget.branch!['_id'], data)
          : await apiService.addBranch(data);

      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.pop(context, response['branch'] ?? response['data'] ?? true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ??
                (_isEditMode ? 'Failed to update branch' : 'Failed to add branch')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Branch' : 'Add Branch'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'View Branches',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BranchListScreen()),
                );
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CrmTextField(
              controller: _nameController,
              label: 'Branch Name',
              hint: 'e.g. Jalandhar Main Branch',
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Branch name is required' : null,
            ),
            const SizedBox(height: 16),
            CrmTextField(
              controller: _addressController,
              label: 'Address',
              hint: 'Street address',
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),
            CrmTextField(
              controller: _cityController,
              label: 'City',
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'City is required' : null,
            ),
            const SizedBox(height: 16),
            CrmTextField(
              controller: _stateController,
              label: 'State',
            ),
            const SizedBox(height: 16),
            CrmTextField(
              controller: _phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveBranch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Update Branch' : 'Save Branch',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}