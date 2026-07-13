import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../services/api_service.dart';

class EditVisitScreen extends StatefulWidget {
  final String customerId;
  final int visitNumber;
  final Map<String, dynamic> visit;
  final List<Map<String, dynamic>> employees;

  const EditVisitScreen({
    super.key,
    required this.customerId,
    required this.visitNumber,
    required this.visit,
    required this.employees,
  });

  @override
  State<EditVisitScreen> createState() => _EditVisitScreenState();
}

class _EditVisitScreenState extends State<EditVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final _purposeController = TextEditingController();
  final _goldController = TextEditingController();
  final _diamondController = TextEditingController();
  final _polkiController = TextEditingController();
  final _requirementController = TextEditingController();
  final _helperController = TextEditingController();
  final _dateController = TextEditingController();

  String _conclusion = 'Pending';
  bool _approval = false;
  String? _selectedEmployee;
  bool _isSaving = false;

  // existing (network) images, per category
  List<String> _existingGold = [];
  List<String> _existingDiamond = [];
  List<String> _existingPolki = [];

  // images marked for removal
  final List<String> _removeGold = [];
  final List<String> _removeDiamond = [];
  final List<String> _removePolki = [];

  // newly picked local images
  final List<File> _newGold = [];
  final List<File> _newDiamond = [];
  final List<File> _newPolki = [];

  String _mapConclusionToServer(String uiValue) {
    switch (uiValue) {
      case 'Pending': return 'pending';
      case 'Sold': return 'sold';
      case 'Shortlisted': return 'shortlisted';
      case 'Just See': return 'just see';
      case 'On Order': return 'on order';
      case 'On Approval': return 'on approval';
      default: return uiValue.toLowerCase();
    }
  }

  String _mapConclusionToUI(String serverValue) {
    switch (serverValue) {
      case 'pending': return 'Pending';
      case 'sold': return 'Sold';
      case 'shortlisted': return 'Shortlisted';
      case 'just see': return 'Just See';
      case 'on order': return 'On Order';
      case 'on approval': return 'On Approval';
      default: return serverValue;
    }
  }

  List<String> _parseImageUrls(dynamic imageData) {
    if (imageData == null) return [];
    if (imageData is List) {
      return imageData
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((url) => url.isNotEmpty)
          .toList();
    }
    if (imageData is String && imageData.isNotEmpty) return [imageData];
    return [];
  }

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _purposeController.text = v['purposeOfVisit']?.toString() ?? '';
    _goldController.text = v['gold']?.toString() ?? '';
    _diamondController.text = v['diamond']?.toString() ?? '';
    _polkiController.text = v['polki']?.toString() ?? '';
    _requirementController.text = v['requirement']?.toString() ?? '';
    _helperController.text = v['helper']?.toString() ?? '';

    final rawDate = v['visitDate']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      _dateController.text = parsed != null
          ? '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}'
          : rawDate;
    }

    _conclusion = _mapConclusionToUI(v['conclusion']?.toString() ?? 'Pending');
    final approvalVal = v['approval'];
    _approval = approvalVal is bool
        ? approvalVal
        : approvalVal?.toString().toLowerCase() == 'approved';

    final assigned = v['whoAttend'];
    if (assigned != null) {
      _selectedEmployee = assigned is Map
          ? (assigned['_id']?.toString() ?? assigned['id']?.toString())
          : assigned.toString();
    }

    _existingGold = _parseImageUrls(v['goldImages']);
    _existingDiamond = _parseImageUrls(v['diamondImages']);
    _existingPolki = _parseImageUrls(v['polkiImages']);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickImages(String type) async {
    final images = await _picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    setState(() {
      final files = images.map((x) => File(x.path)).toList();
      if (type == 'gold') _newGold.addAll(files);
      if (type == 'diamond') _newDiamond.addAll(files);
      if (type == 'polki') _newPolki.addAll(files);
    });
  }

  void _toggleRemoveExisting(String type, String url) {
    setState(() {
      final list = type == 'gold'
          ? _removeGold
          : type == 'diamond'
              ? _removeDiamond
              : _removePolki;
      if (list.contains(url)) {
        list.remove(url);
      } else {
        list.add(url);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who attended'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final visitData = <String, dynamic>{
      'purposeOfVisit': _purposeController.text.trim(),
      'gold': _goldController.text.trim(),
      'diamond': _diamondController.text.trim(),
      'polki': _polkiController.text.trim(),
      'requirement': _requirementController.text.trim(),
      'approval': _approval ? 'approved' : 'pending',
      'conclusion': _mapConclusionToServer(_conclusion),
      'whoAttend': _selectedEmployee,
      'helper': _helperController.text.trim(),
      'visitDate': _dateController.text.trim(),
    };

    final response = await ApiService().updateVisit(
      widget.customerId,
      widget.visitNumber,
      visitData,
      _newGold,
      _newDiamond,
      _newPolki,
      removeGoldImages: _removeGold,
      removeDiamondImages: _removeDiamond,
      removePolkiImages: _removePolki,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response['success'] == true) {
      Navigator.pop(context, response['data']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${response['message'] ?? 'Failed to update visit'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _goldController.dispose();
    _diamondController.dispose();
    _polkiController.dispose();
    _requirementController.dispose();
    _helperController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Visit #${widget.visitNumber}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: CrmTextField(
                          label: 'Visit Date',
                          hint: 'Select visit date',
                          prefixIcon: Icons.calendar_today,
                          controller: _dateController,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CrmTextField(
                      label: 'Purpose of Visit',
                      hint: 'Reason for visit',
                      prefixIcon: Icons.info_outline,
                      controller: _purposeController,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CrmTextField(
                      label: 'Gold Details',
                      hint: 'Gold weight, purity, etc.',
                      prefixIcon: Icons.workspace_premium,
                      controller: _goldController,
                    ),
                    const SizedBox(height: 8),
                    _buildImageSection('gold', 'Gold Images', _existingGold, _newGold, _removeGold),
                    const SizedBox(height: 8),
                    CrmTextField(
                      label: 'Diamond Details',
                      hint: 'Diamond carat, clarity, etc.',
                      prefixIcon: Icons.diamond,
                      controller: _diamondController,
                    ),
                    const SizedBox(height: 8),
                    _buildImageSection('diamond', 'Diamond Images', _existingDiamond, _newDiamond, _removeDiamond),
                    const SizedBox(height: 8),
                    CrmTextField(
                      label: 'Polki Details',
                      hint: 'Polki weight, etc.',
                      prefixIcon: Icons.star_outline,
                      controller: _polkiController,
                    ),
                    const SizedBox(height: 8),
                    _buildImageSection('polki', 'Polki Images', _existingPolki, _newPolki, _removePolki),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _conclusion,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.flag, color: AppColors.textSecondary),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                          DropdownMenuItem(value: 'Shortlisted', child: Text('Shortlisted')),
                          DropdownMenuItem(value: 'Just See', child: Text('Just See')),
                          DropdownMenuItem(value: 'On Order', child: Text('On Order')),
                          DropdownMenuItem(value: 'On Approval', child: Text('On Approval')),
                        ],
                        onChanged: (v) => setState(() => _conclusion = v!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CrmTextField(
                      label: 'Requirement',
                      hint: 'Specific requirements',
                      prefixIcon: Icons.checklist,
                      controller: _requirementController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Approval:', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                        const SizedBox(width: 12),
                        Switch(
                          value: _approval,
                          onChanged: (v) => setState(() => _approval = v),
                          activeColor: AppColors.primary,
                        ),
                        Text(
                          _approval ? 'Approved' : 'Pending',
                          style: TextStyle(
                            color: _approval ? AppColors.success : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedEmployee,
                        hint: const Text('Who Attended *'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.person, color: AppColors.textSecondary),
                        ),
                        items: widget.employees.map((e) {
                          return DropdownMenuItem<String>(
                            value: e['_id'].toString(),
                            child: Text(e['name'] ?? 'Unknown'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedEmployee = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CrmTextField(
                      label: 'Helper',
                      hint: 'Helper name',
                      prefixIcon: Icons.handshake,
                      controller: _helperController,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

Widget _buildImageSection(
    String type,
    String label,
    List<String> existing,
    List<File> newFiles,
    List<String> removed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (existing.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: existing.length,
              itemBuilder: (context, i) {
                final url = existing[i];
                final isMarkedForRemoval = removed.contains(url);
                final imageUrl = ApiService.getImageUrl(url);
                print('🖼️ EDIT VISIT — raw url: $url');
                print('🖼️ EDIT VISIT — final url: $imageUrl');
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: isMarkedForRemoval ? 0.3 : 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              print('❌ Image load failed for: $imageUrl');
                              return const Icon(Icons.broken_image, size: 40);
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _toggleRemoveExisting(type, url),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isMarkedForRemoval ? Colors.red : Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMarkedForRemoval ? Icons.replay : Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (newFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: newFiles.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(newFiles[i], width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => newFiles.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImages(type),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(Icons.add_a_photo, size: 26, color: AppColors.primary.withOpacity(0.6)),
                const SizedBox(height: 4),
                Text('Add $label', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}