// Edit Customer screen — editing an existing customer's profile, reviewing /
// editing / deleting their visit history, and logging a brand new visit for
// them. This used to share one giant widget with AddCustomerScreen; splitting
// it out keeps each screen focused on what it actually does.
//
// Place in lib/screens/edit_customer_screen.dart (adjust relative imports to
// match your project layout).

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:country_code_picker/country_code_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/crm_text_field.dart';
import '../widgets/customer_common_widgets.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'edit_visit_screen.dart';

class EditCustomerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic> customerToEdit;
  /// Jump straight into the "log a new visit" form (e.g. deep-linked from a
  /// "Add Visit" action elsewhere in the app) instead of the profile editor.
  final bool startWithNewVisit;

  const EditCustomerScreen({
    super.key,
    required this.employees,
    required this.customers,
    required this.customerToEdit,
    this.startWithNewVisit = false,
  });

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // Personal information
  final _customerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _visitNumberController = TextEditingController();

  // New-visit fields (only used while _showNewVisitForm is true)
  final _dateController = TextEditingController();
  final _purposeOfVisitController = TextEditingController();
  final _goldController = TextEditingController();
  final _diamondController = TextEditingController();
  final _polkiController = TextEditingController();
  final _requirementController = TextEditingController();
  final _helperController = TextEditingController();
  final _reminderController = TextEditingController();
  final _reminderTimeController = TextEditingController();
  final _reminderMessageController = TextEditingController();
  final _referenceNoteController = TextEditingController();
  final _customProfessionController = TextEditingController();
  final _customCommunityController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final _customCityController = TextEditingController();

  File? _additionalInfoImageFile;
  String? _existingAdditionalInfoImageUrl;
  File? _customerImageFile;
  String? _existingCustomerImageUrl;

  String _conclusion = 'Pending';
  List<File> _goldImages = [];
  List<File> _diamondImages = [];
  List<File> _polkiImages = [];
  List<String> _existingGoldImageUrls = [];
  List<String> _existingDiamondImageUrls = [];
  List<String> _existingPolkiImageUrls = [];
  TimeOfDay? _reminderTime;

  List<Map<String, dynamic>> _visits = [];
  List<bool> _visitExpanded = [];

  String _countryCode = '+91';
  String? _selectedEmployee;
  String? _selectedBranch;
  bool _isReferenceCustomer = false;
  String? _selectedReferredBy;
  int? _birthdayDay;
  int? _birthdayMonth;
  int? _anniversaryDay;
  int? _anniversaryMonth;
  String? _selectedProfession;
  String? _selectedCommunity;
  String? _duplicateWarning;
  Map<String, dynamic>? _duplicateMatch;
  Timer? _duplicateCheckDebounce;
  String _selectedTitle = 'Mr.';

  // Address
  List<csc.Country> _countryList = [];
  List<csc.State> _stateList = [];
  List<csc.City> _cityList = [];
  String? _selectedCountryCode;
  String? _selectedCountry;
  String? _selectedStateCode;
  String? _selectedState;
  String? _selectedCity;
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;
  bool _cityNotInList = false;

  String? _pendingCountryName;
  String? _pendingStateName;
  String? _pendingCityName;

  List<Map<String, dynamic>> _branches = [];
  bool _isLoadingBranches = false;
  bool _isLoading = false;

  bool _showNewVisitForm = false;

  List<String> _professionOptionsList = [];
  List<String> _communityOptionsList = [];

  @override
  void initState() {
    super.initState();
    _customerNameController.addListener(_forceUppercaseName);
    _loadBranches();
    _loadOptions().then((_) {
      _prefillForEdit(widget.customerToEdit);
      _loadCountries();

      if (widget.startWithNewVisit) {
        setState(() {
          _showNewVisitForm = true;
          _clearNewVisitFields();
          _visitNumberController.text = (_visits.length + 1).toString();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
  }

  void _forceUppercaseName() {
    final text = _customerNameController.text;
    final upper = text.toUpperCase();
    if (text != upper) {
      final selection = _customerNameController.selection;
      _customerNameController.value = _customerNameController.value.copyWith(text: upper, selection: selection);
    }
  }

  Future<void> _loadOptions() async {
    try {
      final apiProfessions = await ApiService().getDistinctProfessions();
      final apiCommunities = await ApiService().getDistinctCommunities();
      setState(() {
        _professionOptionsList = List.from(kDefaultProfessionOptions);
        _communityOptionsList = List.from(kDefaultCommunityOptions);
        for (final p in apiProfessions) {
          if (!_professionOptionsList.contains(p)) _professionOptionsList.add(p);
        }
        for (final c in apiCommunities) {
          if (!_communityOptionsList.contains(c)) _communityOptionsList.add(c);
        }
      });
    } catch (e) {
      setState(() {
        _professionOptionsList = List.from(kDefaultProfessionOptions);
        _communityOptionsList = List.from(kDefaultCommunityOptions);
      });
    }
  }

  String _getEmployeeName(dynamic idOrName) {
    if (idOrName == null) return 'Not specified';
    final value = idOrName.toString().trim();
    if (value.isEmpty) return 'Not specified';
    for (final employee in widget.employees) {
      final empId = employee['_id']?.toString() ?? employee['id']?.toString();
      if (empId != null && empId == value) return employee['name']?.toString() ?? 'Unknown';
    }
    return value;
  }

  // ================= COUNTRY / STATE / CITY =================

  Future<void> _loadCountries() async {
    setState(() => _isLoadingCountries = true);
    try {
      final countries = await csc.getAllCountries();
      countries.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _countryList = countries;
        _isLoadingCountries = false;
      });

      csc.Country? initialCountry;
      if (_pendingCountryName != null) {
        initialCountry = _countryList.firstWhere(
          (c) => c.name.toLowerCase() == _pendingCountryName!.toLowerCase(),
          orElse: () => _countryList.firstWhere((c) => c.isoCode == 'IN', orElse: () => countries.first),
        );
      }
      if (initialCountry != null) {
        setState(() {
          _selectedCountry = initialCountry!.name;
          _selectedCountryCode = initialCountry.isoCode;
        });
        await _loadStates(initialCountry.isoCode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCountries = false);
      _showLocationLoadError('countries');
    }
  }

  Future<void> _loadStates(String countryIsoCode) async {
    setState(() {
      _isLoadingStates = true;
      _stateList = [];
      _cityList = [];
    });
    try {
      final states = await csc.getStatesOfCountry(countryIsoCode);
      states.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _stateList = states;
        _isLoadingStates = false;
      });

      csc.State? initialState;
      if (_pendingStateName != null) {
        final match = states.where((s) => s.name.toLowerCase() == _pendingStateName!.toLowerCase());
        if (match.isNotEmpty) initialState = match.first;
      }
      if (initialState != null) {
        setState(() {
          _selectedState = initialState!.name;
          _selectedStateCode = initialState.isoCode;
        });
        await _loadCities(countryIsoCode, initialState.isoCode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingStates = false);
      _showLocationLoadError('states');
    }
  }

  Future<void> _loadCities(String countryIsoCode, String stateIsoCode) async {
    setState(() {
      _isLoadingCities = true;
      _cityList = [];
    });
    try {
      final cities = await csc.getStateCities(countryIsoCode, stateIsoCode);
      cities.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() => _isLoadingCities = false);

      String? matchedCityName;
      if (_pendingCityName != null) {
        final match = cities.where((c) => c.name.toLowerCase() == _pendingCityName!.toLowerCase());
        if (match.isNotEmpty) matchedCityName = match.first.name;
      }

      setState(() {
        _cityList = cities;
        if (matchedCityName != null) {
          _selectedCity = matchedCityName;
          _cityNotInList = false;
        } else if (_pendingCityName != null && _pendingCityName!.isNotEmpty) {
          _cityNotInList = true;
          _customCityController.text = _pendingCityName!;
          _selectedCity = null;
        }
        _pendingCountryName = null;
        _pendingStateName = null;
        _pendingCityName = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCities = false);
      _showLocationLoadError('cities');
    }
  }

  void _showLocationLoadError(String what) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not load $what. Check your internet and try again.'), backgroundColor: Colors.red),
    );
  }

  void _onCountryChanged(String? countryName) {
    if (countryName == null) return;
    final country = _countryList.firstWhere((c) => c.name == countryName);
    setState(() {
      _selectedCountry = country.name;
      _selectedCountryCode = country.isoCode;
      _selectedState = null;
      _selectedStateCode = null;
      _selectedCity = null;
      _cityNotInList = false;
      _customCityController.clear();
    });
    _loadStates(country.isoCode);
  }

  void _onStateChanged(String? stateName) {
    if (stateName == null || _selectedCountryCode == null) return;
    final state = _stateList.firstWhere((s) => s.name == stateName);
    setState(() {
      _selectedState = state.name;
      _selectedStateCode = state.isoCode;
      _selectedCity = null;
      _cityNotInList = false;
      _customCityController.clear();
    });
    _loadCities(_selectedCountryCode!, state.isoCode);
  }

  void _onCityChanged(String? cityName) {
    if (cityName == null) return;
    setState(() {
      if (cityName == '__other__') {
        _cityNotInList = true;
        _selectedCity = null;
      } else {
        _cityNotInList = false;
        _selectedCity = cityName;
        _customCityController.clear();
      }
    });
  }

  String _resolvedCityName() {
    if (_cityNotInList) return _customCityController.text.trim();
    return _selectedCity ?? '';
  }

  // ================= PREFILL =================

  void _prefillForEdit(Map<String, dynamic> c) {
    final rawName = c['name']?.toString() ?? '';
    final titleMatch = RegExp(r'^(Mr\.|Mrs\.|Ms\.|Dr\.)\s+', caseSensitive: false).firstMatch(rawName);
    if (titleMatch != null) {
      final matchedTitle = titleMatch.group(1)!;
      _selectedTitle = kTitleOptions.firstWhere((t) => t.toLowerCase() == matchedTitle.toLowerCase(), orElse: () => 'Mr.');
      _customerNameController.text = rawName.substring(titleMatch.end).trim().toUpperCase();
    } else {
      _customerNameController.text = rawName.toUpperCase();
    }

    _parseAddressForEdit(c['address']?.toString() ?? '');

    _existingCustomerImageUrl = c['customerImage']?.toString();
    _additionalInfoController.text = c['additionalInfo']?.toString() ?? '';
    _existingAdditionalInfoImageUrl = c['additionalInfoImage']?.toString();

    final rawPhone = c['phone']?.toString() ?? '';
    final phoneMatch = RegExp(r'^(\+\d{1,4})(\d{10})$').firstMatch(rawPhone);
    if (phoneMatch != null) {
      _countryCode = phoneMatch.group(1)!;
      _phoneController.text = phoneMatch.group(2)!;
    } else {
      _phoneController.text = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    }
    _emailController.text = c['email']?.toString() ?? '';

    final visits = c['visits'] as List? ?? [];
    _visits = visits.cast<Map<String, dynamic>>();
    _visitExpanded = List<bool>.filled(_visits.length, false);
    _visitNumberController.text = c['numberOfVisit']?.toString() ?? '1';

    if (_visits.isNotEmpty) {
      final latest = _visits.last;
      _existingGoldImageUrls = parseImageUrls(latest['goldImages']);
      _existingDiamondImageUrls = parseImageUrls(latest['diamondImages']);
      _existingPolkiImageUrls = parseImageUrls(latest['polkiImages']);
    }

    final reminder = c['reminder'];
    if (reminder != null && reminder is Map<String, dynamic>) {
      final status = reminder['status']?.toString() ?? 'pending';
      final rawDate = reminder['date']?.toString();
      if (status == 'pending' && rawDate != null && rawDate.isNotEmpty) {
        final parsedDate = DateTime.tryParse(rawDate);
        if (parsedDate != null) {
          final local = parsedDate.toLocal();
          _reminderController.text = formatDate(local);
          _reminderTime = TimeOfDay(hour: local.hour, minute: local.minute);
          _reminderTimeController.text = formatTimeOfDay(_reminderTime!);
        }
        _reminderMessageController.text = reminder['note']?.toString() ?? '';
      }
    }

    final birthdayStr = c['birthday']?.toString();
    if (birthdayStr != null && birthdayStr.contains('-')) {
      final bParts = birthdayStr.split('-');
      if (bParts.length == 2) {
        _birthdayDay = int.tryParse(bParts[0]);
        _birthdayMonth = int.tryParse(bParts[1]);
      }
    }

    final anniversaryStr = c['anniversary']?.toString();
    if (anniversaryStr != null && anniversaryStr.contains('-')) {
      final aParts = anniversaryStr.split('-');
      if (aParts.length == 2) {
        _anniversaryDay = int.tryParse(aParts[0]);
        _anniversaryMonth = int.tryParse(aParts[1]);
      }
    }

    final professionStr = c['profession']?.toString();
    if (professionStr != null && professionStr.isNotEmpty) {
      if (_professionOptionsList.contains(professionStr)) {
        _selectedProfession = professionStr;
      } else {
        _selectedProfession = 'Others';
        _customProfessionController.text = professionStr;
      }
    }

    final communityStr = c['community']?.toString();
    if (communityStr != null && communityStr.isNotEmpty) {
      if (_communityOptionsList.contains(communityStr)) {
        _selectedCommunity = communityStr;
      } else {
        _selectedCommunity = 'Others';
        _customCommunityController.text = communityStr;
      }
    }

    final branch = c['branch'];
    if (branch != null) {
      if (branch is Map<String, dynamic>) {
        _selectedBranch = branch['_id']?.toString() ?? branch['id']?.toString();
      } else if (branch is String) {
        _selectedBranch = branch;
      } else {
        _selectedBranch = branch.toString();
      }
    }

    final assigned = c['assignedTo'] ?? c['whoAttend'];
    if (assigned != null) {
      if (assigned is Map<String, dynamic>) {
        _selectedEmployee = assigned['_id']?.toString() ?? assigned['id']?.toString();
      } else if (assigned is String) {
        _selectedEmployee = assigned;
      } else {
        _selectedEmployee = assigned.toString();
      }
    }

    final referredBy = c['referredBy'];
    if (referredBy != null) {
      _isReferenceCustomer = true;
      if (referredBy is Map<String, dynamic>) {
        _selectedReferredBy = referredBy['_id']?.toString() ?? referredBy['id']?.toString();
      } else if (referredBy is String) {
        _selectedReferredBy = referredBy;
      } else {
        _selectedReferredBy = referredBy.toString();
      }
    } else {
      _isReferenceCustomer = false;
      _selectedReferredBy = null;
      _referenceNoteController.text = c['referenceNote']?.toString() ?? '';
    }
  }

  void _parseAddressForEdit(String rawAddress) {
    if (rawAddress.trim().isEmpty) {
      _addressController.text = '';
      return;
    }
    final parts = rawAddress.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 3) {
      final country = parts.removeLast();
      final state = parts.removeLast();
      final city = parts.removeLast();
      final street = parts.join(', ');
      _addressController.text = (street == '-') ? '' : street;
      _pendingCountryName = country;
      _pendingStateName = state;
      _pendingCityName = city;
    } else {
      _addressController.text = rawAddress;
    }
  }

  String _buildFullAddress() {
    final street = _addressController.text.trim();
    final city = _resolvedCityName();
    final state = _selectedState ?? '';
    final country = _selectedCountry ?? '';
    final parts = [street, city, state, country].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String _buildFullName() {
    final name = _customerNameController.text.trim().toUpperCase();
    if (name.isEmpty) return name;
    return '$_selectedTitle $name';
  }

  void _clearNewVisitFields() {
    _dateController.clear();
    _purposeOfVisitController.clear();
    _goldController.clear();
    _diamondController.clear();
    _polkiController.clear();
    _requirementController.clear();
    _helperController.clear();
    _conclusion = 'Pending';
    _goldImages = [];
    _diamondImages = [];
    _polkiImages = [];
  }

  // ---------- API ----------

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);
    try {
      final response = await ApiService().getBranches();
      if (response == null) {
        setState(() { _branches = []; _isLoadingBranches = false; });
        return;
      }
      List<dynamic> branchesData = [];
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          if (response['data'] is List) branchesData = response['data'] as List;
          else if (response['branches'] is List) branchesData = response['branches'] as List;
          else if (response['items'] is List) branchesData = response['items'] as List;
          else if (response['results'] is List) branchesData = response['results'] as List;
        } else if (response['data'] is List) {
          branchesData = response['data'] as List;
        }
        if (branchesData.isEmpty) {
          response.forEach((key, value) {
            if (value is List && value.isNotEmpty) branchesData = value;
          });
        }
      } else if (response is List) {
        branchesData = response;
      }
      setState(() {
        _branches = branchesData.map((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is String) return {'_id': item, 'name': item};
          if (item is Map) {
            final castMap = Map<String, dynamic>.from(item);
            return {
              '_id': castMap['_id']?.toString() ?? castMap['id']?.toString() ?? castMap['branchId']?.toString() ?? 'unknown',
              'name': castMap['name']?.toString() ?? castMap['branchName']?.toString() ?? 'Unknown Branch',
            };
          }
          return {'_id': 'unknown', 'name': 'Unknown Branch'};
        }).toList().cast<Map<String, dynamic>>();
        _isLoadingBranches = false;
      });
    } catch (e) {
      setState(() { _branches = []; _isLoadingBranches = false; });
    }
  }

  // ---------- DATE / TIME ----------

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateController.text = formatDate(picked));
  }

  Future<void> _selectReminderDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _reminderController.text = formatDate(picked);
        if (_reminderTime == null) {
          _reminderTime = const TimeOfDay(hour: 10, minute: 0);
          _reminderTimeController.text = formatTimeOfDay(_reminderTime!);
        }
      });
    }
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, onSurface: AppColors.textPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
        _reminderTimeController.text = formatTimeOfDay(picked);
      });
    }
  }

  // ---------- DUPLICATE CHECK ----------

  void _checkDuplicateCustomer() {
    _duplicateCheckDebounce?.cancel();
    _duplicateCheckDebounce = Timer(const Duration(milliseconds: 600), () {
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      if (phone.isEmpty && email.isEmpty) {
        if (mounted) setState(() => _duplicateWarning = null);
        return;
      }
      Map<String, dynamic>? match;
      for (final c in widget.customers) {
        if (c['_id']?.toString() == widget.customerToEdit['_id']?.toString()) continue;
        final cPhone = c['phone']?.toString().trim() ?? '';
        final cEmail = c['email']?.toString().trim().toLowerCase() ?? '';
        final phoneMatches = phone.isNotEmpty && cPhone.isNotEmpty && cPhone == phone;
        final emailMatches = email.isNotEmpty && cEmail.isNotEmpty && cEmail == email;
        if (phoneMatches || emailMatches) {
          match = c;
          break;
        }
      }
      if (match != null) {
        final branchDisplay = _resolveBranchDisplay(match['branch']);
        final visitDate = formatVisitDate(match['visitDate']);
        final isPhoneDuplicate = phone.isNotEmpty && (match['phone']?.toString().trim() ?? '') == phone;
        final isEmailDuplicate = email.isNotEmpty && (match['email']?.toString().trim().toLowerCase() ?? '') == email;
        if (mounted) {
          setState(() {
            _duplicateMatch = match;
            if (isPhoneDuplicate) {
              _duplicateWarning = 'This phone number is already added in $branchDisplay branch on $visitDate. Tap to view this customer.';
            } else if (isEmailDuplicate) {
              _duplicateWarning = 'This email is already added in $branchDisplay branch on $visitDate. Tap to view this customer.';
            }
          });
        }
      } else {
        if (mounted) setState(() { _duplicateWarning = null; _duplicateMatch = null; });
      }
    });
  }

  String _resolveBranchDisplay(dynamic branch) {
    if (branch == null) return 'Unknown Branch';
    if (branch is Map) {
      final name = branch['name']?.toString();
      final city = branch['city']?.toString();
      if (name != null && name.isNotEmpty) {
        return (city != null && city.isNotEmpty) ? '$name, $city' : name;
      }
    }
    final branchId = branch is Map ? (branch['_id']?.toString() ?? branch['id']?.toString()) : branch.toString();
    if (branchId == null || branchId.isEmpty) return 'Unknown Branch';
    for (final b in _branches) {
      final bId = b['_id']?.toString() ?? b['id']?.toString();
      if (bId == branchId) {
        final name = b['name']?.toString() ?? branchId;
        final city = b['city']?.toString();
        return (city != null && city.isNotEmpty) ? '$name, $city' : name;
      }
    }
    return branchId;
  }

  void _openDuplicateCustomer() {
    if (_duplicateMatch == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EditCustomerScreen(
          employees: widget.employees,
          customers: widget.customers,
          customerToEdit: _duplicateMatch!,
        ),
      ),
    );
  }

  // ---------- IMAGE PICKING ----------

  Future<void> _showImageSourceOptions(String type) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Add Photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () { Navigator.pop(context); _pickImage(type, ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(type, ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (photo != null) _addImageToList(type, File(photo.path));
      } else {
        final pickedImages = await _picker.pickMultiImage(imageQuality: 80);
        for (final img in pickedImages) {
          _addImageToList(type, File(img.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addImageToList(String type, File file) {
    setState(() {
      if (type == 'gold') _goldImages.add(file);
      else if (type == 'diamond') _diamondImages.add(file);
      else if (type == 'polki') _polkiImages.add(file);
    });
  }

  void _removeImage(String type, int index) {
    setState(() {
      final images = type == 'gold' ? _goldImages : (type == 'diamond' ? _diamondImages : _polkiImages);
      if (index >= 0 && index < images.length) images.removeAt(index);
    });
  }

  Future<void> _pickCustomerImage() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Customer Photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (photo != null) setState(() => _customerImageFile = File(photo.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (photo != null) setState(() => _customerImageFile = File(photo.path));
              },
            ),
            if (_customerImageFile != null || _existingCustomerImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() { _customerImageFile = null; _existingCustomerImageUrl = null; });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAdditionalInfoImage() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('Additional Info Photo', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (photo != null) setState(() => _additionalInfoImageFile = File(photo.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (photo != null) setState(() => _additionalInfoImageFile = File(photo.path));
              },
            ),
            if (_additionalInfoImageFile != null || _existingAdditionalInfoImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() { _additionalInfoImageFile = null; _existingAdditionalInfoImageUrl = null; });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _viewImage({List<String>? networkUrls, List<File>? files, required int initialIndex, String? title}) {
    FullScreenImageViewer.open(context, networkUrls: networkUrls, files: files, initialIndex: initialIndex, title: title);
  }

  // ---------- NOTIFICATION ----------

  Future<void> _handleReminderNotification({
    required String? customerId,
    required String customerName,
    DateTime? reminderDateTime,
    String? reminderMessage,
  }) async {
    if (customerId == null || customerId.isEmpty) return;
    try {
      final notificationService = NotificationService();
      if (reminderDateTime != null && reminderMessage != null && reminderMessage.isNotEmpty) {
        await notificationService.scheduleReminder(
          customerId: customerId,
          customerName: customerName,
          reminderDate: reminderDateTime,
          message: reminderMessage,
        );
      } else {
        await notificationService.cancelReminder(customerId);
      }
    } catch (e) {
      // Silent
    }
  }

  // ---------- SCROLL ----------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- VISIT HISTORY ACTIONS ----------

  Future<void> _openEditVisit(Map<String, dynamic> visit, int index) async {
    final rawVisitNumber = visit['visitNumber'];
    final visitNumber = rawVisitNumber is int ? rawVisitNumber : int.tryParse(rawVisitNumber?.toString() ?? '') ?? (index + 1);

    final updatedCustomer = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditVisitScreen(
          customerId: widget.customerToEdit['_id'].toString(),
          visitNumber: visitNumber,
          visit: visit,
          employees: widget.employees,
        ),
      ),
    );

    if (updatedCustomer != null && mounted) {
      setState(() {
        final visits = updatedCustomer['visits'] as List? ?? [];
        _visits = visits.cast<Map<String, dynamic>>();
        _visitExpanded = List<bool>.filled(_visits.length, false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit updated successfully!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _confirmFulfillRequirement(Map<String, dynamic> visit, int index) async {
    final visitNumber = index + 1;
    final requirementText = visit['requirement']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Requirement Available'),
        content: Text('Mark "$requirementText" as available in stock?\n\nThis will move it out of the pending requirements list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark Available', style: TextStyle(color: AppColors.success))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final customerId = widget.customerToEdit['_id'].toString();
      final response = await ApiService().fulfillRequirement(customerId, visitNumber);
      if (response['success'] == true) {
        setState(() { _visits[index]['requirementStatus'] = 'fulfilled'; _isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Requirement marked as available. Contact the customer!'), backgroundColor: AppColors.success),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['message'] ?? 'Failed to update requirement'}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDeleteVisit(Map<String, dynamic> visit, int index) async {
    final visitNumber = index + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Visit'),
        content: Text('Are you sure you want to delete Visit #$visitNumber? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final customerId = widget.customerToEdit['_id'].toString();
      final response = await ApiService().deleteVisit(customerId, visitNumber);
      if (response['success'] == true) {
        setState(() {
          _visits.removeAt(index);
          _visitExpanded = List<bool>.filled(_visits.length, false);
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Visit deleted successfully!'), backgroundColor: AppColors.success),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['message'] ?? 'Failed to delete visit'}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  // ---------- SAVE ----------

  Future<void> _save() async {
    if (_showNewVisitForm) {
      await _saveNewVisit();
    } else {
      await _saveCustomerProfile();
    }
  }

  Future<void> _saveNewVisit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who attended'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final customerId = widget.customerToEdit['_id'].toString();
      String? reminderMessageStr;
      DateTime? reminderDateTime;
      final reminderDateText = _reminderController.text.trim();
      final reminderMessageText = _reminderMessageController.text.trim();
      if (reminderDateText.isNotEmpty && reminderMessageText.isNotEmpty) {
        final parts = reminderDateText.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]) ?? DateTime.now().year;
          final month = int.tryParse(parts[1]) ?? DateTime.now().month;
          final day = int.tryParse(parts[2]) ?? DateTime.now().day;
          final hour = _reminderTime?.hour ?? 10;
          final minute = _reminderTime?.minute ?? 0;
          reminderDateTime = DateTime(year, month, day, hour, minute);
          reminderMessageStr = reminderMessageText;
        }
      }

      final visitData = <String, dynamic>{
        'purposeOfVisit': _purposeOfVisitController.text.trim(),
        'gold': _goldController.text.trim(),
        'diamond': _diamondController.text.trim(),
        'polki': _polkiController.text.trim(),
        'requirement': _requirementController.text.trim(),
        'conclusion': mapConclusionToServer(_conclusion),
        'whoAttend': _selectedEmployee,
        'helper': _helperController.text.trim(),
        'visitDate': _dateController.text.trim(),
      };

      final response = await ApiService().addVisitToCustomer(customerId, visitData, _goldImages, _diamondImages, _polkiImages);

      if (response['success'] == true) {
        final customerName = _customerNameController.text.trim();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleReminderNotification(
              customerId: customerId,
              customerName: customerName,
              reminderDateTime: reminderDateTime,
              reminderMessage: reminderMessageStr,
            );
          }
        });

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Visit #${_visitNumberController.text} added successfully!'), backgroundColor: AppColors.success, duration: const Duration(seconds: 2)),
          );
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['message'] ?? 'Failed to save'}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _saveCustomerProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }
    if (_selectedCountry == null || _selectedState == null || _resolvedCityName().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select city, state and country'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who attended'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }
    if (_isReferenceCustomer && _selectedReferredBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the referring customer, or switch to Write Note'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();

      String? reminderDateStr;
      String? reminderMessageStr;
      DateTime? reminderDateTime;
      final reminderDateText = _reminderController.text.trim();
      final reminderMessageText = _reminderMessageController.text.trim();
      if (reminderDateText.isNotEmpty && reminderMessageText.isNotEmpty) {
        final parts = reminderDateText.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]) ?? DateTime.now().year;
          final month = int.tryParse(parts[1]) ?? DateTime.now().month;
          final day = int.tryParse(parts[2]) ?? DateTime.now().day;
          final hour = _reminderTime?.hour ?? 10;
          final minute = _reminderTime?.minute ?? 0;
          reminderDateTime = DateTime(year, month, day, hour, minute);
          reminderDateStr = reminderDateTime.toUtc().toIso8601String();
          reminderMessageStr = reminderMessageText;
        }
      }

      String? finalProfession;
      if (_selectedProfession != null) {
        finalProfession = _selectedProfession == 'Others' ? _customProfessionController.text.trim() : _selectedProfession;
      }
      String? finalCommunity;
      if (_selectedCommunity != null) {
        finalCommunity = _selectedCommunity == 'Others' ? _customCommunityController.text.trim() : _selectedCommunity;
      }

      final additionalInfoText = _additionalInfoController.text.trim();
      final customerId = widget.customerToEdit['_id'].toString();

      final customerData = <String, dynamic>{
        'name': _buildFullName(),
        'phone': '$_countryCode${_phoneController.text.trim()}',
        'address': _buildFullAddress(),
        'numberOfVisit': _visitNumberController.text.trim(),
        'assignedTo': _selectedEmployee,
        'whoAttend': _selectedEmployee,
        'referenceNote': _isReferenceCustomer ? '' : _referenceNoteController.text.trim(),
      };

      final email = _emailController.text.trim();
      if (email.isNotEmpty) customerData['email'] = email;
      if (reminderDateStr != null && reminderDateStr.isNotEmpty) customerData['reminderDate'] = reminderDateStr;
      if (reminderMessageStr != null && reminderMessageStr.isNotEmpty) customerData['reminderMessage'] = reminderMessageStr;
      if (_birthdayDay != null && _birthdayMonth != null) {
        customerData['birthday'] = '${_birthdayDay!.toString().padLeft(2, '0')}-${_birthdayMonth!.toString().padLeft(2, '0')}';
      }
      if (_anniversaryDay != null && _anniversaryMonth != null) {
        customerData['anniversary'] = '${_anniversaryDay!.toString().padLeft(2, '0')}-${_anniversaryMonth!.toString().padLeft(2, '0')}';
      }
      if (finalProfession != null && finalProfession.isNotEmpty) customerData['profession'] = finalProfession;
      if (finalCommunity != null && finalCommunity.isNotEmpty) customerData['community'] = finalCommunity;
      if (_isReferenceCustomer && _selectedReferredBy != null) customerData['referredBy'] = _selectedReferredBy;
      if (!customerData.containsKey('reminderDate')) customerData['clearReminder'] = true;
      // Send additionalInfo on edit — empty string clears it on the backend
      // (backend trims it, so '' becomes undefined there).
      customerData['additionalInfo'] = additionalInfoText;

      final response = await apiService.updateCustomer(
        customerId,
        customerData,
        customerImage: _customerImageFile,
        additionalInfoImage: _additionalInfoImageFile,
      );

      if (response['success'] == true) {
        final customerName = _customerNameController.text.trim();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleReminderNotification(
              customerId: customerId,
              customerName: customerName,
              reminderDateTime: reminderDateTime,
              reminderMessage: reminderMessageStr,
            );
          }
        });

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer updated successfully!'), backgroundColor: AppColors.success, duration: Duration(seconds: 2)),
          );
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response['message'] ?? 'Failed to save'}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.removeListener(_forceUppercaseName);
    _customerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _visitNumberController.dispose();
    _dateController.dispose();
    _purposeOfVisitController.dispose();
    _goldController.dispose();
    _diamondController.dispose();
    _polkiController.dispose();
    _requirementController.dispose();
    _helperController.dispose();
    _reminderController.dispose();
    _reminderTimeController.dispose();
    _reminderMessageController.dispose();
    _referenceNoteController.dispose();
    _customProfessionController.dispose();
    _customCommunityController.dispose();
    _customCityController.dispose();
    _additionalInfoController.dispose();
    _duplicateCheckDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final title = _showNewVisitForm ? 'Add New Visit' : 'Edit Customer';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      floatingActionButton: !_showNewVisitForm
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _showNewVisitForm = true;
                  _clearNewVisitFields();
                  _visitNumberController.text = (_visits.length + 1).toString();
                });
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: _isLoading
          ? LoadingBody(message: _showNewVisitForm ? 'Adding visit...' : 'Updating customer...')
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                child: _showNewVisitForm ? _buildNewVisitForm() : _buildProfileForm(),
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : StickySaveBar(
              isLoading: _isLoading,
              label: _showNewVisitForm ? 'Add Visit' : 'Update Customer',
              onSave: _save,
              secondaryLabel: _showNewVisitForm ? 'Cancel' : null,
              onSecondary: _showNewVisitForm
                  ? () => setState(() {
                        _showNewVisitForm = false;
                        _clearNewVisitFields();
                      })
                  : null,
            ),
    );
  }

  // ---- PROFILE (edit customer) FORM ----

  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPersonalInfoSection(),
        const SizedBox(height: 14),
        _buildAddressAndBranchSection(),
        const SizedBox(height: 14),
        if (_visits.isNotEmpty) ...[
          SectionCard(
            icon: Icons.history_rounded,
            title: 'Visit History (${_visits.length})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tap the pencil icon to edit a visit, the trash icon to delete it, or a photo to view it full-screen.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ..._visits.asMap().entries.map((entry) => _buildVisitCard(entry.value, entry.key)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        SectionCard(
          icon: Icons.badge_outlined,
          title: 'Staff Information',
          child: AppDropdownField<String>(
            label: 'Assigned To *',
            icon: Icons.person,
            value: _selectedEmployee,
            items: widget.employees.map((e) => DropdownMenuItem<String>(value: e['_id'].toString(), child: Text(e['name'] ?? 'Unknown'))).toList(),
            onChanged: (value) => setState(() => _selectedEmployee = value),
            validator: (value) => value == null ? 'Please select an employee' : null,
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(icon: Icons.notes_rounded, title: 'Additional Information', child: _buildAdditionalInfoSection()),
        const SizedBox(height: 14),
        _buildReminderSection(),
        const SizedBox(height: 14),
        SectionCard(
          icon: Icons.cake_outlined,
          title: 'Personal Milestones',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBirthdayField(),
              const SizedBox(height: 16),
              _buildAnniversaryField(),
              const SizedBox(height: 16),
              _buildProfessionField(),
              const SizedBox(height: 16),
              _buildCommunityField(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(icon: Icons.family_restroom, title: 'Reference', child: _buildReferenceSection()),
      ],
    );
  }

  // ---- NEW VISIT FORM ----

  Widget _buildNewVisitForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          icon: Icons.add_circle_outline,
          title: 'New Visit #${_visits.length + 1}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: CrmTextField(
                    label: 'Visit Date *',
                    hint: 'Select visit date',
                    prefixIcon: Icons.calendar_today,
                    controller: _dateController,
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Visit date is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CrmTextField(
                label: 'Purpose of Visit *',
                hint: 'Reason for visit',
                prefixIcon: Icons.info_outline,
                controller: _purposeOfVisitController,
                validator: (v) => v?.trim().isEmpty ?? true ? 'Purpose of visit is required' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          icon: Icons.diamond_outlined,
          title: 'Jewelry Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CrmTextField(label: 'Gold Details', hint: 'Gold weight, purity, etc.', prefixIcon: Icons.workspace_premium, controller: _goldController),
              const SizedBox(height: 8),
              ImageUploadSection(
                label: 'Gold Images',
                localImages: _goldImages,
                existingUrls: const [],
                onAddPhoto: () => _showImageSourceOptions('gold'),
                onRemoveLocal: (i) => _removeImage('gold', i),
                onViewImage: _viewImage,
              ),
              const SizedBox(height: 8),
              CrmTextField(label: 'Diamond Details', hint: 'Diamond carat, clarity, etc.', prefixIcon: Icons.diamond, controller: _diamondController),
              const SizedBox(height: 8),
              ImageUploadSection(
                label: 'Diamond Images',
                localImages: _diamondImages,
                existingUrls: const [],
                onAddPhoto: () => _showImageSourceOptions('diamond'),
                onRemoveLocal: (i) => _removeImage('diamond', i),
                onViewImage: _viewImage,
              ),
              const SizedBox(height: 8),
              CrmTextField(label: 'Polki Details', hint: 'Polki weight, etc.', prefixIcon: Icons.star_outline, controller: _polkiController),
              const SizedBox(height: 8),
              ImageUploadSection(
                label: 'Polki Images',
                localImages: _polkiImages,
                existingUrls: const [],
                onAddPhoto: () => _showImageSourceOptions('polki'),
                onRemoveLocal: (i) => _removeImage('polki', i),
                onViewImage: _viewImage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          icon: Icons.flag_outlined,
          title: 'Conclusion',
          child: ConclusionSelector(value: _conclusion, onChanged: (v) => setState(() => _conclusion = v)),
        ),
        const SizedBox(height: 14),
        SectionCard(
          icon: Icons.checklist_rounded,
          title: 'Requirement',
          child: CrmTextField(label: 'Requirement', hint: 'Specific requirements', prefixIcon: Icons.checklist, controller: _requirementController, maxLines: 2),
        ),
        const SizedBox(height: 14),
        SectionCard(
          icon: Icons.badge_outlined,
          title: 'Staff Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDropdownField<String>(
                label: 'Who Attended *',
                icon: Icons.person,
                value: _selectedEmployee,
                items: widget.employees.map((e) => DropdownMenuItem<String>(value: e['_id'].toString(), child: Text(e['name'] ?? 'Unknown'))).toList(),
                onChanged: (value) => setState(() => _selectedEmployee = value),
                validator: (value) => value == null ? 'Please select who attended' : null,
              ),
              const SizedBox(height: 12),
              CrmTextField(label: 'Helper', hint: 'Helper name', prefixIcon: Icons.handshake, controller: _helperController),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildReminderSection(),
      ],
    );
  }

  // ---- SHARED SECTION BUILDERS ----

  Widget _buildPersonalInfoSection() {
    return SectionCard(
      icon: Icons.person_outline,
      title: 'Personal Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ProfileImagePicker(
              localFile: _customerImageFile,
              existingUrl: _existingCustomerImageUrl,
              onPick: _pickCustomerImage,
              onView: _viewImage,
              title: 'Customer Photo',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 116,
                child: AppDropdownField<String>(
                  label: 'Title',
                  icon: Icons.badge_outlined,
                  value: _selectedTitle,
                  items: kTitleOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.visible, softWrap: false))).toList(),
                  onChanged: (v) => setState(() => _selectedTitle = v ?? 'Mr.'),
                  dense: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CrmTextField(
                  label: 'Customer Name',
                  hint: 'Enter customer name',
                  prefixIcon: Icons.person,
                  controller: _customerNameController,
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Customer name is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Phone Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CountryCodePicker(
                  onChanged: (country) => setState(() => _countryCode = country.dialCode ?? '+91'),
                  initialSelection: 'IN',
                  favorite: const ['+91', 'IN'],
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  padding: EdgeInsets.zero,
                  flagWidth: 24,
                  textStyle: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
                Container(height: 28, width: 1, color: AppColors.border),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    onChanged: (_) => _checkDuplicateCustomer(),
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'add phone number',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Phone number is required';
                      if (value.length != 10) return 'Enter a valid 10-digit number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CrmTextField(
            label: 'Email (optional)',
            hint: 'example@gmail.com',
            prefixIcon: Icons.email,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _checkDuplicateCustomer(),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
              }
              return null;
            },
          ),
          if (_duplicateWarning != null) ...[
            const SizedBox(height: 10),
            DuplicateWarningBanner(message: _duplicateWarning!, onTap: _duplicateMatch != null ? _openDuplicateCustomer : null),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressAndBranchSection() {
    final preview = _buildFullAddress();
    return SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Address & Branch',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Don't know the exact address? No problem — just pick the city, state and country below.",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          CrmTextField(
            label: 'Street / Locality (optional)',
            hint: 'House no., street, landmark — leave blank if unknown',
            prefixIcon: Icons.home_outlined,
            controller: _addressController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppDropdownField<String>(
            label: 'Country *',
            icon: Icons.public,
            loading: _isLoadingCountries,
            hint: 'Select Country',
            value: _selectedCountry,
            items: _countryList.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
            onChanged: _onCountryChanged,
            validator: (v) => v == null ? 'Select a country' : null,
          ),
          const SizedBox(height: 10),
          AppDropdownField<String>(
            label: 'State *',
            icon: Icons.map_outlined,
            loading: _isLoadingStates,
            hint: _selectedCountryCode == null ? 'Select a country first' : 'Select State',
            value: _selectedState,
            items: _stateList.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(),
            onChanged: _onStateChanged,
            validator: (v) => v == null ? 'Select a state' : null,
          ),
          const SizedBox(height: 10),
          AppDropdownField<String>(
            label: 'City *',
            icon: Icons.location_city,
            loading: _isLoadingCities,
            hint: _selectedStateCode == null ? 'Select a state first' : 'Select City',
            value: _cityNotInList ? null : _selectedCity,
            items: [
              ..._cityList.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
              const DropdownMenuItem(value: '__other__', child: Text("Other / not listed")),
            ],
            onChanged: _onCityChanged,
            validator: (v) {
              if (_cityNotInList) return _customCityController.text.trim().isEmpty ? 'Type the city name' : null;
              return v == null ? 'Select a city' : null;
            },
          ),
          if (_cityNotInList) ...[
            const SizedBox(height: 8),
            CrmTextField(
              label: 'City name',
              hint: 'Type the city name',
              prefixIcon: Icons.edit,
              controller: _customCityController,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Will be saved as: ${preview.isEmpty ? '—' : preview}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 14),
          AppDropdownField<String>(
            label: 'Branch',
            icon: Icons.store,
            loading: _isLoadingBranches,
            hint: _branches.isEmpty && !_isLoadingBranches ? 'No branches available' : 'Select Branch',
            value: _selectedBranch,
            items: _branches.map((branch) {
              final branchId = branch['_id']?.toString() ?? branch['id']?.toString() ?? branch['branchId']?.toString();
              final displayName = '${branch['name']} (${branch['city']})';
              return DropdownMenuItem<String>(value: branchId, child: Text(displayName));
            }).toList(),
            onChanged: (value) => setState(() => _selectedBranch = value),
          ),
          const SizedBox(height: 14),
          CrmTextField(
            label: 'Number of Visit',
            hint: 'How many times visited',
            prefixIcon: Icons.timeline,
            controller: _visitNumberController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    ImageProvider? imageProvider;
    String? viewerUrl;
    File? viewerFile;
    if (_additionalInfoImageFile != null) {
      imageProvider = FileImage(_additionalInfoImageFile!);
      viewerFile = _additionalInfoImageFile;
    } else if (_existingAdditionalInfoImageUrl != null && _existingAdditionalInfoImageUrl!.isNotEmpty) {
      final url = ApiService.getImageUrl(_existingAdditionalInfoImageUrl!);
      imageProvider = NetworkImage(url);
      viewerUrl = url;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CrmTextField(
          label: 'Additional Info (optional)',
          hint: 'Any extra notes about the customer',
          prefixIcon: Icons.notes,
          controller: _additionalInfoController,
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: imageProvider == null
              ? _pickAdditionalInfoImage
              : () {
                  if (viewerFile != null) {
                    _viewImage(files: [viewerFile], initialIndex: 0, title: 'Additional Info Photo');
                  } else if (viewerUrl != null) {
                    _viewImage(networkUrls: [viewerUrl], initialIndex: 0, title: 'Additional Info Photo');
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: DottedBox(
            child: imageProvider == null
                ? Column(
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 26, color: AppColors.primary.withOpacity(0.7)),
                      const SizedBox(height: 4),
                      const Text('Add Additional Info Image (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  )
                : Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image(image: imageProvider, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.zoom_in, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickAdditionalInfoImage,
                        child: const Text('Tap image to view · tap here to change or remove', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return SectionCard(
      icon: Icons.alarm,
      title: 'Reminder (optional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _selectReminderDate(context),
            child: AbsorbPointer(
              child: CrmTextField(label: 'Reminder Date', hint: 'Select reminder date', prefixIcon: Icons.alarm, controller: _reminderController),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _selectReminderTime(context),
            child: AbsorbPointer(
              child: CrmTextField(label: 'Reminder Time', hint: 'Select reminder time', prefixIcon: Icons.access_time, controller: _reminderTimeController),
            ),
          ),
          const SizedBox(height: 12),
          CrmTextField(
            label: 'Reminder Message',
            hint: 'e.g. Customer wants order confirmation',
            prefixIcon: Icons.message,
            controller: _reminderMessageController,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Birthday (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppDropdownField<int>(
                label: 'Day',
                icon: Icons.today,
                value: _birthdayDay,
                items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                onChanged: (v) => setState(() => _birthdayDay = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppDropdownField<int>(
                label: 'Month',
                icon: Icons.calendar_month,
                value: _birthdayMonth,
                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(kMonths[m - 1]))).toList(),
                onChanged: (v) => setState(() => _birthdayMonth = v),
              ),
            ),
            if (_birthdayDay != null || _birthdayMonth != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                tooltip: 'Clear birthday',
                onPressed: () => setState(() { _birthdayDay = null; _birthdayMonth = null; }),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAnniversaryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Anniversary (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppDropdownField<int>(
                label: 'Day',
                icon: Icons.today,
                value: _anniversaryDay,
                items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                onChanged: (v) => setState(() => _anniversaryDay = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppDropdownField<int>(
                label: 'Month',
                icon: Icons.calendar_month,
                value: _anniversaryMonth,
                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(kMonths[m - 1]))).toList(),
                onChanged: (v) => setState(() => _anniversaryMonth = v),
              ),
            ),
            if (_anniversaryDay != null || _anniversaryMonth != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                tooltip: 'Clear anniversary',
                onPressed: () => setState(() { _anniversaryDay = null; _anniversaryMonth = null; }),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildProfessionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdownField<String>(
          label: 'Profession (optional)',
          icon: Icons.work,
          hint: 'Select Profession',
          value: _selectedProfession,
          items: _professionOptionsList.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _selectedProfession = v),
        ),
        if (_selectedProfession == 'Others') ...[
          const SizedBox(height: 8),
          CrmTextField(label: 'Specify Profession', hint: 'Type profession', prefixIcon: Icons.edit, controller: _customProfessionController),
        ],
      ],
    );
  }

  Widget _buildCommunityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdownField<String>(
          label: 'Community (optional)',
          icon: Icons.groups,
          hint: 'Select Community',
          value: _selectedCommunity,
          items: _communityOptionsList.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _selectedCommunity = v),
        ),
        if (_selectedCommunity == 'Others') ...[
          const SizedBox(height: 8),
          CrmTextField(label: 'Specify Community', hint: 'Type community', prefixIcon: Icons.edit, controller: _customCommunityController),
        ],
      ],
    );
  }

  Widget _buildReferenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Write Note'),
                selected: !_isReferenceCustomer,
                selectedColor: AppColors.primary.withOpacity(0.15),
                onSelected: (_) => setState(() { _isReferenceCustomer = false; _selectedReferredBy = null; }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Select Customer'),
                selected: _isReferenceCustomer,
                selectedColor: AppColors.primary.withOpacity(0.15),
                onSelected: (_) => setState(() { _isReferenceCustomer = true; _referenceNoteController.clear(); }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_isReferenceCustomer)
          CrmTextField(
            label: 'Reference Note',
            hint: 'e.g. Saw our Instagram ad, walk-in, referred by neighbor...',
            prefixIcon: Icons.comment,
            controller: _referenceNoteController,
            maxLines: 2,
          )
        else
          AppDropdownField<String>(
            label: 'Referred By',
            icon: Icons.family_restroom,
            hint: 'Select the customer who referred them',
            value: _selectedReferredBy,
            items: widget.customers.map((c) => DropdownMenuItem<String>(value: c['_id'].toString(), child: Text(c['name'] ?? 'Unknown'))).toList(),
            onChanged: (value) => setState(() => _selectedReferredBy = value),
            validator: (value) => (_isReferenceCustomer && value == null) ? 'Please select a referring customer' : null,
          ),
      ],
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit, int index) {
    final visitNumber = index + 1;
    final date = visit['visitDate']?.toString() ?? '';
    final purpose = visit['purposeOfVisit']?.toString() ?? 'No purpose';
    final gold = visit['gold']?.toString() ?? '';
    final diamond = visit['diamond']?.toString() ?? '';
    final polki = visit['polki']?.toString() ?? '';
    final conclusionServer = visit['conclusion']?.toString() ?? 'Pending';
    final conclusionUI = mapConclusionToUI(conclusionServer);
    final requirement = visit['requirement']?.toString() ?? '';
    final requirementStatus = visit['requirementStatus']?.toString() ?? 'none';
    final helper = visit['helper']?.toString() ?? '';
    final whoAttendName = _getEmployeeName(visit['whoAttend']);
    final goldImages = parseImageUrls(visit['goldImages']);
    final diamondImages = parseImageUrls(visit['diamondImages']);
    final polkiImages = parseImageUrls(visit['polkiImages']);

    final accentColor = conclusionUI == 'Sold'
        ? AppColors.success
        : conclusionUI == 'On Order'
            ? Colors.blue
            : conclusionUI == 'On Approval'
                ? Colors.purple
                : conclusionUI == 'Shortlisted'
                    ? Colors.teal
                    : conclusionUI == 'Just See'
                        ? Colors.orange
                        : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 4), top: BorderSide(color: AppColors.border.withOpacity(0.7)), right: BorderSide(color: AppColors.border.withOpacity(0.7)), bottom: BorderSide(color: AppColors.border.withOpacity(0.7))),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _visitExpanded[index],
          onExpansionChanged: (expanded) => setState(() => _visitExpanded[index] = expanded),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                child: Text('#$visitNumber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(purpose, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                    Text(date.isNotEmpty ? formatVisitDate(date) : 'No date', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(conclusionUI, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.edit, size: 20, color: AppColors.primary), tooltip: 'Edit this visit', onPressed: () => _openEditVisit(visit, index)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), tooltip: 'Delete this visit', onPressed: () => _confirmDeleteVisit(visit, index)),
            ],
          ),
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Date', date.isNotEmpty ? formatVisitDate(date) : 'Not set'),
                  _buildDetailRow('Purpose', purpose),
                  if (gold.isNotEmpty) _buildDetailRow('Gold', gold),
                  if (diamond.isNotEmpty) _buildDetailRow('Diamond', diamond),
                  if (polki.isNotEmpty) _buildDetailRow('Polki', polki),
                  if (requirement.isNotEmpty) _buildRequirementRow(requirement, requirementStatus, visit, index),
                  if (helper.isNotEmpty) _buildDetailRow('Helper', helper),
                  _buildDetailRow('Attended by', whoAttendName),
                  if (goldImages.isNotEmpty) _buildImageRow('Gold Images', goldImages),
                  if (diamondImages.isNotEmpty) _buildImageRow('Diamond Images', diamondImages),
                  if (polkiImages.isNotEmpty) _buildImageRow('Polki Images', polkiImages),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(onPressed: () => _openEditVisit(visit, index), icon: const Icon(Icons.edit, size: 16), label: const Text('Edit')),
                      TextButton.icon(onPressed: () => _confirmDeleteVisit(visit, index), icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), label: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String requirement, String status, Map<String, dynamic> visit, int index) {
    final isPending = status == 'pending';
    final isFulfilled = status == 'fulfilled';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 100, child: Text('Requirement:', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(requirement, style: const TextStyle(color: AppColors.textPrimary))),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        isFulfilled ? 'Available' : 'Pending',
                        style: TextStyle(color: isFulfilled ? Colors.white : Colors.orange[800], fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                      backgroundColor: isFulfilled ? AppColors.success : Colors.orange.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                if (isPending) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _confirmFulfillRequirement(visit, index),
                        child: const Text(
                          'Mark Available',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageRow(String label, List<String> imageUrls) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, i) {
                final url = ApiService.getImageUrl(imageUrls[i]);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _viewImage(networkUrls: imageUrls.map((u) => ApiService.getImageUrl(u)).toList(), initialIndex: i, title: label),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}